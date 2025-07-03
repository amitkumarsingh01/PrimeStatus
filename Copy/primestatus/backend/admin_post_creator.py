import firebase_admin
from firebase_admin import credentials, firestore
import datetime
import random

# Initialize Firebase Admin SDK
# You'll need to download your service account key from Firebase Console
# cred = credentials.Certificate('path/to/your/serviceAccountKey.json')
# firebase_admin.initialize_app(cred)

# For testing, you can use the default credentials if you're running this locally
# firebase_admin.initialize_app()

# Initialize Firestore
db = firestore.client()

# Sample admin posts data
sample_posts = [
    {
        'title': 'Daily Inspiration',
        'content': 'Every day is a new beginning. Take a deep breath and start again.',
        'category': 'Inspiration',
        'language': 'English',
        'imageUrl': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
        'adminName': 'Prime Status Admin',
        'adminPhotoUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'likes': 42,
        'shares': 15,
        'isPublished': True,
        'createdAt': datetime.datetime.now(),
        'updatedAt': datetime.datetime.now(),
    },
    {
        'title': 'Motivational Quote',
        'content': 'Success is not final, failure is not fatal: it is the courage to continue that counts.',
        'category': 'Motivation',
        'language': 'English',
        'imageUrl': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
        'adminName': 'Prime Status Admin',
        'adminPhotoUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'likes': 38,
        'shares': 12,
        'isPublished': True,
        'createdAt': datetime.datetime.now(),
        'updatedAt': datetime.datetime.now(),
    },
    {
        'title': 'Life Wisdom',
        'content': 'The only way to do great work is to love what you do.',
        'category': 'Life',
        'language': 'English',
        'imageUrl': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
        'adminName': 'Prime Status Admin',
        'adminPhotoUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'likes': 55,
        'shares': 23,
        'isPublished': True,
        'createdAt': datetime.datetime.now(),
        'updatedAt': datetime.datetime.now(),
    },
    {
        'title': 'Spiritual Guidance',
        'content': 'Faith is taking the first step even when you don\'t see the whole staircase.',
        'category': 'Spiritual',
        'language': 'English',
        'imageUrl': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
        'adminName': 'Prime Status Admin',
        'adminPhotoUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'likes': 67,
        'shares': 18,
        'isPublished': True,
        'createdAt': datetime.datetime.now(),
        'updatedAt': datetime.datetime.now(),
    },
    {
        'title': 'Success Mindset',
        'content': 'The future belongs to those who believe in the beauty of their dreams.',
        'category': 'Success',
        'language': 'English',
        'imageUrl': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
        'adminName': 'Prime Status Admin',
        'adminPhotoUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'likes': 29,
        'shares': 8,
        'isPublished': True,
        'createdAt': datetime.datetime.now(),
        'updatedAt': datetime.datetime.now(),
    },
]

def create_sample_admin_posts():
    """Create sample admin posts in Firestore"""
    try:
        # Get reference to admin_posts collection
        admin_posts_ref = db.collection('admin_posts')
        
        # Add each sample post
        for i, post_data in enumerate(sample_posts):
            # Add some time variation to posts
            post_data['createdAt'] = datetime.datetime.now() - datetime.timedelta(hours=i*2)
            post_data['updatedAt'] = post_data['createdAt']
            
            # Add the post to Firestore
            doc_ref = admin_posts_ref.add(post_data)
            print(f"Created admin post {i+1}: {post_data['title']}")
        
        print(f"Successfully created {len(sample_posts)} admin posts!")
        
    except Exception as e:
        print(f"Error creating admin posts: {e}")

def create_user_post(user_id, post_data):
    """Create a post for a specific user"""
    try:
        # Add user-specific data
        post_data['createdBy'] = user_id
        post_data['createdAt'] = datetime.datetime.now()
        post_data['updatedAt'] = datetime.datetime.now()
        post_data['isPublished'] = True
        
        # Add to admin_posts collection
        admin_posts_ref = db.collection('admin_posts')
        doc_ref = admin_posts_ref.add(post_data)
        
        print(f"Created user post: {post_data['title']}")
        return doc_ref[1].id
        
    except Exception as e:
        print(f"Error creating user post: {e}")
        return None

def get_admin_posts():
    """Get all admin posts"""
    try:
        admin_posts_ref = db.collection('admin_posts')
        posts = admin_posts_ref.where('isPublished', '==', True).order_by('createdAt', direction=firestore.Query.DESCENDING).stream()
        
        for post in posts:
            print(f"Post ID: {post.id}")
            print(f"Title: {post.get('title')}")
            print(f"Content: {post.get('content')}")
            print(f"Likes: {post.get('likes')}")
            print("---")
            
    except Exception as e:
        print(f"Error getting admin posts: {e}")

def delete_all_admin_posts():
    """Delete all admin posts (use with caution!)"""
    try:
        admin_posts_ref = db.collection('admin_posts')
        posts = admin_posts_ref.stream()
        
        deleted_count = 0
        for post in posts:
            post.reference.delete()
            deleted_count += 1
        
        print(f"Deleted {deleted_count} admin posts")
        
    except Exception as e:
        print(f"Error deleting admin posts: {e}")

if __name__ == "__main__":
    print("Admin Post Creator")
    print("1. Create sample admin posts")
    print("2. Get all admin posts")
    print("3. Delete all admin posts")
    print("4. Create user post")
    
    choice = input("Enter your choice (1-4): ")
    
    if choice == "1":
        create_sample_admin_posts()
    elif choice == "2":
        get_admin_posts()
    elif choice == "3":
        confirm = input("Are you sure you want to delete all admin posts? (yes/no): ")
        if confirm.lower() == "yes":
            delete_all_admin_posts()
        else:
            print("Operation cancelled")
    elif choice == "4":
        user_id = input("Enter user ID: ")
        title = input("Enter post title: ")
        content = input("Enter post content: ")
        category = input("Enter category: ")
        
        post_data = {
            'title': title,
            'content': content,
            'category': category,
            'language': 'English',
            'imageUrl': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500',
            'adminName': 'User',
            'adminPhotoUrl': None,
            'likes': 0,
            'shares': 0,
        }
        
        create_user_post(user_id, post_data)
    else:
        print("Invalid choice") 