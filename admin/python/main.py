from fastapi import FastAPI, File, UploadFile
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from rembg import remove
from io import BytesIO
import os
from sqlalchemy import create_engine, Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import uvicorn

# Create folders
os.makedirs("upload/input", exist_ok=True)
os.makedirs("upload/output", exist_ok=True)

app = FastAPI(title="Background Remover API")

# Allow Swagger UI file upload
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# SQLite DB Setup
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

    # Return output image as download
    return FileResponse(output_path, media_type="image/png", filename=output_filename)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)