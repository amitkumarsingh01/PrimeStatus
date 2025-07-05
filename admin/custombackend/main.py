from fastapi import FastAPI, HTTPException, File, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, firestore, storage
import os
from dotenv import load_dotenv
import uvicorn
from PIL import Image, ImageDraw, ImageFont
from rembg import remove
import requests
from io import BytesIO
import uuid
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

load_dotenv()

# Create folders for background removal
os.makedirs("upload/input", exist_ok=True)
os.makedirs("upload/output", exist_ok=True)

# Initialize Firebase
cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "serviceAccountKey.json")

if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    
    # ✅ Use correct bucket name as per your file URL
    bucket_name = "prime-status-1db09.firebasestorage.app"

    firebase_admin.initialize_app(cred, {
        'storageBucket': bucket_name
    })

db = firestore.client()
bucket = storage.bucket()

app = FastAPI(title="Crafto API")

# Allow Swagger UI file upload
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# SQLite DB Setup for background removal
DATABASE_URL = "sqlite:///./db.sqlite3"
engine = create_engine(DATABASE_URL)
Base = declarative_base()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class UploadLog(Base):
    __tablename__ = "uploads"
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String, index=True)
    result_filename = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

class OverlayRequest(BaseModel):
    user_id: str
    admin_post_id: str

def download_image(url):
    """Download image from URL"""
    try:
        response = requests.get(url)
        response.raise_for_status()
        return Image.open(BytesIO(response.content))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to download image: {str(e)}")

def get_font(font_name, font_size):
    """Get font object, fallback to default if not found"""
    try:
        # Try to use the specified font
        if font_name.lower() == 'arial':
            # Try different Arial font paths
            arial_paths = [
                "arial.ttf",
                "/System/Library/Fonts/Arial.ttf",  # macOS
                "/Windows/Fonts/arial.ttf",  # Windows
                "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",  # Linux
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",  # Linux alternative
            ]
            for path in arial_paths:
                try:
                    return ImageFont.truetype(path, font_size)
                except:
                    continue
        else:
            # Try to load other fonts
            font_paths = [
                f"{font_name}.ttf",
                f"/System/Library/Fonts/{font_name}.ttf",
                f"/Windows/Fonts/{font_name}.ttf",
            ]
            for path in font_paths:
                try:
                    return ImageFont.truetype(path, font_size)
                except:
                    continue
    except:
        pass
    
    # Ultimate fallback - use default font with approximate size
    try:
        return ImageFont.load_default()
    except:
        # If even default fails, create a minimal font
        return ImageFont.load_default()

def create_overlay_image(admin_post, user_data):
    """Create overlay image by merging user data with admin post template"""
    try:
        # Get frame dimensions first
        frame_width = admin_post['frameSize']['width']
        frame_height = admin_post['frameSize']['height']
        
        # Download the main image
        main_image = download_image(admin_post['mainImage'])
        
        # Convert to RGB if necessary
        if main_image.mode != 'RGB':
            main_image = main_image.convert('RGB')
        
        # Create a new image with the exact frame size
        overlay_image = Image.new('RGB', (frame_width, frame_height), color='white')
        
        # Resize and fit the main image to contain within the frame (maintaining aspect ratio)
        # Calculate the scaling factor to fit the image within the frame
        img_width, img_height = main_image.size
        scale_x = frame_width / img_width
        scale_y = frame_height / img_height
        scale = min(scale_x, scale_y)  # Use the smaller scale to ensure image fits
        
        # Calculate new dimensions
        new_width = int(img_width * scale)
        new_height = int(img_height * scale)
        
        # Resize the main image to fit within the frame
        main_image_resized = main_image.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Calculate position to center the image
        x_offset = (frame_width - new_width) // 2
        y_offset = (frame_height - new_height) // 2
        
        # Paste the resized main image centered in the frame
        overlay_image.paste(main_image_resized, (x_offset, y_offset))
        
        # Create drawing context for overlays
        draw = ImageDraw.Draw(overlay_image)
        
        # Add profile picture if enabled and user has one
        if admin_post.get('profileSettings', {}).get('enabled', False) and user_data.get('profilePhotoUrl'):
            try:
                profile_img = download_image(user_data['profilePhotoUrl'])
                
                # Convert to RGB if necessary
                if profile_img.mode not in ['RGB', 'RGBA']:
                    profile_img = profile_img.convert('RGBA')
                
                # Calculate profile picture position and size based on frame dimensions
                profile_size = int(admin_post['profileSettings']['size'])  # Direct pixel size
                profile_x = int((admin_post['profileSettings']['x'] / 100) * frame_width)
                profile_y = int((admin_post['profileSettings']['y'] / 100) * frame_height)
                
                # Resize profile image to exact size
                profile_img = profile_img.resize((profile_size, profile_size), Image.Resampling.LANCZOS)
                
                # Create circular mask if shape is circle
                if admin_post['profileSettings']['shape'] == 'circle':
                    # Create a circular mask
                    mask = Image.new('L', (profile_size, profile_size), 0)
                    mask_draw = ImageDraw.Draw(mask)
                    mask_draw.ellipse([0, 0, profile_size, profile_size], fill=255)
                    
                    # Apply mask to profile image
                    output = Image.new('RGBA', (profile_size, profile_size), (0, 0, 0, 0))
                    output.paste(profile_img, (0, 0))
                    output.putalpha(mask)
                    profile_img = output
                
                # Add background if enabled
                if admin_post['profileSettings'].get('hasBackground', False):
                    bg_color = admin_post['profileSettings'].get('backgroundColor', '#000000')
                    padding = 10
                    
                    if admin_post['profileSettings']['shape'] == 'circle':
                        # Circular background
                        draw.ellipse([
                            profile_x - padding, profile_y - padding,
                            profile_x + profile_size + padding, profile_y + profile_size + padding
                        ], fill=bg_color)
                    else:
                        # Rectangular background
                        draw.rectangle([
                            profile_x - padding, profile_y - padding,
                            profile_x + profile_size + padding, profile_y + profile_size + padding
                        ], fill=bg_color)
                
                # Paste profile image
                if profile_img.mode == 'RGBA':
                    overlay_image.paste(profile_img, (profile_x, profile_y), profile_img)
                else:
                    overlay_image.paste(profile_img, (profile_x, profile_y))
                    
            except Exception as e:
                print(f"Error adding profile picture: {e}")
        
        # Add name text
        if admin_post.get('textSettings') and user_data.get('name'):
            text_settings = admin_post['textSettings']
            font_size = text_settings.get('fontSize', 24)  # Direct pixel size
            font = get_font(text_settings.get('font', 'Arial'), font_size)
            
            # Calculate text position based on frame dimensions
            text_x = int((text_settings['x'] / 100) * frame_width)
            text_y = int((text_settings['y'] / 100) * frame_height)
            
            # Get text dimensions for background
            text_bbox = draw.textbbox((0, 0), user_data['name'], font=font)
            text_width = text_bbox[2] - text_bbox[0]
            text_height = text_bbox[3] - text_bbox[1]
            
            # Add background if enabled
            if text_settings.get('hasBackground', False):
                bg_color = text_settings.get('backgroundColor', '#000000')
                padding = 10
                draw.rectangle([
                    text_x - padding, text_y - padding,
                    text_x + text_width + padding, text_y + text_height + padding
                ], fill=bg_color)
            
            # Add text
            text_color = text_settings.get('color', '#ffffff')
            draw.text((text_x, text_y), user_data['name'], fill=text_color, font=font)
        
        # Add phone number for business users
        if (user_data.get('usageType') == 'Business' and 
            admin_post.get('phoneSettings', {}).get('enabled', False) and 
            user_data.get('phoneNumber')):
            
            phone_settings = admin_post['phoneSettings']
            font_size = phone_settings.get('fontSize', 24)  # Direct pixel size
            font = get_font(phone_settings.get('font', 'Arial'), font_size)
            
            # Calculate phone text position
            phone_x = int((phone_settings['x'] / 100) * frame_width)
            phone_y = int((phone_settings['y'] / 100) * frame_height)
            
            # Get phone text dimensions
            phone_bbox = draw.textbbox((0, 0), user_data['phoneNumber'], font=font)
            phone_width = phone_bbox[2] - phone_bbox[0]
            phone_height = phone_bbox[3] - phone_bbox[1]
            
            # Add background if enabled
            if phone_settings.get('hasBackground', False):
                bg_color = phone_settings.get('backgroundColor', '#000000')
                padding = 8
                draw.rectangle([
                    phone_x - padding, phone_y - padding,
                    phone_x + phone_width + padding, phone_y + phone_height + padding
                ], fill=bg_color)
            
            # Add phone text
            phone_color = phone_settings.get('color', '#ffffff')
            draw.text((phone_x, phone_y), user_data['phoneNumber'], fill=phone_color, font=font)
        
        # Add address for business users
        if (user_data.get('usageType') == 'Business' and 
            admin_post.get('addressSettings', {}).get('enabled', False) and 
            user_data.get('address')):
            
            address_settings = admin_post['addressSettings']
            font_size = address_settings.get('fontSize', 24)  # Direct pixel size
            font = get_font(address_settings.get('font', 'Arial'), font_size)
            
            # Calculate address text position
            address_x = int((address_settings['x'] / 100) * frame_width)
            address_y = int((address_settings['y'] / 100) * frame_height)
            
            # Handle long addresses by wrapping text
            address_text = user_data['address']
            max_width = frame_width - address_x - 20  # Leave some margin
            
            # Simple text wrapping
            words = address_text.split()
            lines = []
            current_line = []
            
            for word in words:
                test_line = ' '.join(current_line + [word])
                test_bbox = draw.textbbox((0, 0), test_line, font=font)
                test_width = test_bbox[2] - test_bbox[0]
                
                if test_width <= max_width:
                    current_line.append(word)
                else:
                    if current_line:
                        lines.append(' '.join(current_line))
                        current_line = [word]
                    else:
                        lines.append(word)
            
            if current_line:
                lines.append(' '.join(current_line))
            
            # Draw each line
            line_height = font_size + 5
            for i, line in enumerate(lines):
                line_y = address_y + (i * line_height)
                
                # Get line dimensions for background
                line_bbox = draw.textbbox((0, 0), line, font=font)
                line_width = line_bbox[2] - line_bbox[0]
                line_text_height = line_bbox[3] - line_bbox[1]
                
                # Add background if enabled
                if address_settings.get('hasBackground', False):
                    bg_color = address_settings.get('backgroundColor', '#000000')
                    padding = 8
                    draw.rectangle([
                        address_x - padding, line_y - padding,
                        address_x + line_width + padding, line_y + line_text_height + padding
                    ], fill=bg_color)
                
                # Add address text
                address_color = address_settings.get('color', '#ffffff')
                draw.text((address_x, line_y), line, fill=address_color, font=font)
        
        return overlay_image
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating overlay: {str(e)}")

def upload_to_firebase(image, user_id, admin_post_id):
    """Upload image to Firebase Storage and return download URL"""
    try:
        # Convert PIL Image to bytes
        img_byte_arr = BytesIO()
        image.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"overlay_posts/{user_id}_{admin_post_id}_{timestamp}_{uuid.uuid4().hex[:8]}.png"
        
        # Debug information
        print(f"Bucket name: {bucket.name}")
        print(f"Uploading file: {filename}")
        
        # Upload to Firebase Storage
        blob = bucket.blob(filename)
        blob.upload_from_file(img_byte_arr, content_type='image/png')
        
        # Generate download URL with token (similar to your existing URLs)
        blob.make_public()
        
        # Get a signed URL that matches your existing pattern
        download_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket.name}/o/{filename.replace('/', '%2F')}?alt=media"
        
        return download_url
        
    except Exception as e:
        print(f"Detailed error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error uploading image: {str(e)}")

@app.get("/admin_posts/{post_id}")
def get_admin_post(post_id: str):
    doc_ref = db.collection("admin_posts").document(post_id)
    doc = doc_ref.get()
    if doc.exists:
        return doc.to_dict()
    else:
        raise HTTPException(status_code=404, detail="Admin post not found")

@app.get("/users/{user_id}")
def get_user(user_id: str):
    doc_ref = db.collection("users").document(user_id)
    doc = doc_ref.get()
    if doc.exists:
        return doc.to_dict()
    else:
        raise HTTPException(status_code=404, detail="User not found")

@app.post("/overlay_personal")
def create_personal_overlay(request: OverlayRequest):
    """Create personal overlay with only name and profile picture"""
    try:
        # Get user data
        user_doc = db.collection("users").document(request.user_id).get()
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_data = user_doc.to_dict()
        
        # Get admin post data
        admin_doc = db.collection("admin_posts").document(request.admin_post_id).get()
        if not admin_doc.exists:
            raise HTTPException(status_code=404, detail="Admin post not found")
        
        admin_post = admin_doc.to_dict()
        
        # Debug information
        print(f"Frame Size: {admin_post['frameSize']}")
        print(f"Profile Settings: {admin_post.get('profileSettings', {})}")
        print(f"Text Settings: {admin_post.get('textSettings', {})}")
        
        # For personal overlay, we only include name and profile picture
        filtered_user_data = {
            'name': user_data.get('name', ''),
            'profilePhotoUrl': user_data.get('profilePhotoUrl', ''),
            'usageType': 'Personal'
        }
        
        # Create overlay image
        overlay_image = create_overlay_image(admin_post, filtered_user_data)
        
        # Upload to Firebase and get download URL
        download_url = upload_to_firebase(overlay_image, request.user_id, request.admin_post_id)
        
        return {
            "success": True,
            "overlay_type": "personal",
            "download_url": download_url,
            "frame_size": admin_post['frameSize'],
            "user_data_used": {
                "name": filtered_user_data['name'],
                "has_profile_photo": bool(filtered_user_data['profilePhotoUrl'])
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating personal overlay: {str(e)}")

@app.post("/overlay_business")
def create_business_overlay(request: OverlayRequest):
    """Create business overlay with all user details"""
    try:
        # Get user data
        user_doc = db.collection("users").document(request.user_id).get()
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        user_data = user_doc.to_dict()
        
        # Get admin post data
        admin_doc = db.collection("admin_posts").document(request.admin_post_id).get()
        if not admin_doc.exists:
            raise HTTPException(status_code=404, detail="Admin post not found")
        
        admin_post = admin_doc.to_dict()
        
        # Debug information
        print(f"Frame Size: {admin_post['frameSize']}")
        print(f"Phone Settings: {admin_post.get('phoneSettings', {})}")
        print(f"Address Settings: {admin_post.get('addressSettings', {})}")
        
        # For business overlay, we include all available data
        user_data['usageType'] = 'Business'
        
        # Create overlay image
        overlay_image = create_overlay_image(admin_post, user_data)
        
        # Upload to Firebase and get download URL
        download_url = upload_to_firebase(overlay_image, request.user_id, request.admin_post_id)
        
        return {
            "success": True,
            "overlay_type": "business",
            "download_url": download_url,
            "frame_size": admin_post['frameSize'],
            "user_data_used": {
                "name": user_data.get('name', ''),
                "phone_number": user_data.get('phoneNumber', ''),
                "address": user_data.get('address', ''),
                "has_profile_photo": bool(user_data.get('profilePhotoUrl', ''))
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating business overlay: {str(e)}")

# Background Removal Endpoints
@app.post("/remove-bg/")
async def remove_background(file: UploadFile = File(...)):
    contents = await file.read()

    # Open and convert to RGBA
    input_image = Image.open(BytesIO(contents)).convert("RGBA")

    # Extract base name and build PNG paths
    base_filename = os.path.splitext(file.filename)[0]
    input_path = f"upload/input/{base_filename}.png"
    output_filename = f"no-bg-{base_filename}.png"
    output_path = f"upload/output/{output_filename}"

    # Save original as PNG (to support RGBA)
    input_image.save(input_path, format="PNG")

    # Remove background and save result as PNG
    result_image = remove(input_image)
    result_image.save(output_path, format="PNG")

    # Log to SQLite
    db = SessionLocal()
    db_entry = UploadLog(filename=file.filename, result_filename=output_filename)
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    db.close()

    # Return JSON with download URL
    download_url = f"/download/{output_filename}"
    return JSONResponse(content={
        "success": True,
        "message": "Background removed successfully",
        "download_url": download_url,
        "filename": output_filename
    })

@app.get("/download/{filename}")
async def download_file(filename: str):
    file_path = f"upload/output/{filename}"
    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="image/png", filename=filename)
    else:
        return JSONResponse(content={"error": "File not found"}, status_code=404)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8005)