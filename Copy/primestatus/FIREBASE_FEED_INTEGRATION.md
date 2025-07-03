# Firebase Feed Integration Guide

This guide explains how to set up and use the Firebase backend integration for displaying admin posts as a feed in your Flutter app.

## Overview

The integration includes:
- **Admin Post Service**: Handles all admin post operations
- **Admin Post Feed Widget**: Displays posts in a feed format
- **User Posts Widget**: Shows user's posts and liked posts in profile
- **Python Backend**: Scripts to create and manage admin posts

## Features

### 1. Admin Post Feed
- Real-time feed of admin posts
- Like/unlike functionality
- Share posts
- Create designs from posts
- Pull-to-refresh
- Error handling and loading states

### 2. User Profile Integration
- Display user's created posts
- Show user's liked posts
- Tabbed interface for organization
- Grid layout for posts

### 3. Firebase Backend
- Firestore database for posts
- Real-time updates
- User authentication integration
- Image storage support

## Setup Instructions

### 1. Firebase Configuration

Make sure your Firebase project is properly configured:

1. **Firebase Console Setup**:
   - Create a Firebase project
   - Enable Authentication (Google Sign-In)
   - Enable Firestore Database
   - Enable Storage
   - Download `google-services.json` for Android

2. **Firestore Rules**:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Admin posts can be read by anyone, created by admins
       match /admin_posts/{postId} {
         allow read: if true;
         allow create: if request.auth != null && 
           request.auth.token.admin == true;
         allow update, delete: if request.auth != null && 
           request.auth.token.admin == true;
       }
       
       // Post likes can be managed by authenticated users
       match /admin_posts/{postId}/likes/{userId} {
         allow read, write: if request.auth != null && 
           request.auth.uid == userId;
       }
       
       // Users can read and write their own data
       match /users/{userId} {
         allow read, write: if request.auth != null && 
           request.auth.uid == userId;
       }
     }
   }
   ```

### 2. Flutter App Setup

1. **Dependencies**: All required dependencies are already in `pubspec.yaml`

2. **Firebase Initialization**: Make sure Firebase is initialized in `main.dart`

3. **Run the app**: The feed integration is already integrated into the home screen

### 3. Python Backend Setup

1. **Install Dependencies**:
   ```bash
   cd primestatus/backend
   pip install -r requirements.txt
   ```

2. **Firebase Admin SDK Setup**:
   - Go to Firebase Console > Project Settings > Service Accounts
   - Generate new private key
   - Download the JSON file
   - Update the path in `admin_post_creator.py`

3. **Create Sample Posts**:
   ```bash
   python admin_post_creator.py
   ```
   Choose option 1 to create sample admin posts

## Usage

### 1. Viewing the Feed

1. **Home Tab**: Shows a preview of latest posts
2. **Feed Tab**: Dedicated tab for the full admin post feed
3. **Profile Tab**: Shows user's posts and liked posts

### 2. Interacting with Posts

- **Like/Unlike**: Tap the heart icon
- **Share**: Tap the share icon or use the menu
- **Create Design**: Tap "Create Design" button to open quote editor
- **Report**: Use the menu to report inappropriate content

### 3. User Posts

- **My Posts**: Shows posts created by the user
- **Liked Posts**: Shows posts the user has liked
- **Grid View**: Compact display of posts with images

## Database Structure

### Admin Posts Collection (`admin_posts`)

```javascript
{
  "id": "auto-generated",
  "title": "Post Title",
  "content": "Post content/quote",
  "category": "Inspiration",
  "language": "English",
  "imageUrl": "https://...",
  "adminName": "Admin Name",
  "adminPhotoUrl": "https://...",
  "likes": 42,
  "shares": 15,
  "isPublished": true,
  "createdBy": "user_id", // for user-created posts
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Likes Subcollection (`admin_posts/{postId}/likes/{userId}`)

```javascript
{
  "userId": "user_id",
  "timestamp": "timestamp"
}
```

## API Methods

### AdminPostService

```dart
// Get all admin posts for feed
Stream<QuerySnapshot> getAdminPostsFeed()

// Get posts by category
Stream<QuerySnapshot> getAdminPostsByCategory(String category)

// Get posts by language
Stream<QuerySnapshot> getAdminPostsByLanguage(String language)

// Like/unlike a post
Future<void> toggleLikeAdminPost(String postId)

// Share a post
Future<void> shareAdminPost(String postId)

// Get user's posts
Stream<List<Map<String, dynamic>>> getUserAdminPosts(String userId)

// Get user's liked posts
Stream<List<Map<String, dynamic>>> getUserLikedAdminPosts(String userId)
```

## Customization

### 1. Styling

- Modify `AdminPostFeedWidget` for feed styling
- Update `UserPostsWidget` for profile styling
- Customize colors in `app_constants.dart`

### 2. Categories

Add new categories in the Python script:
```python
sample_posts.append({
    'title': 'Your Title',
    'content': 'Your content',
    'category': 'Your Category',
    # ... other fields
})
```

### 3. Languages

Support multiple languages by adding language-specific posts:
```python
post_data['language'] = 'Hindi'  # or any other language
```

## Troubleshooting

### Common Issues

1. **Posts not loading**:
   - Check Firebase connection
   - Verify Firestore rules
   - Ensure posts have `isPublished: true`

2. **Images not displaying**:
   - Check image URLs
   - Verify network permissions
   - Use `cached_network_image` for better performance

3. **Like functionality not working**:
   - Ensure user is authenticated
   - Check Firestore rules for likes collection
   - Verify user permissions

### Debug Mode

Enable debug logging:
```dart
// In your service classes
print('Debug: ${error.toString()}');
```

## Security Considerations

1. **Authentication**: All user interactions require authentication
2. **Data Validation**: Validate all input data
3. **Rate Limiting**: Implement rate limiting for likes/shares
4. **Content Moderation**: Add content filtering for user-generated posts

## Performance Optimization

1. **Pagination**: Implement pagination for large feeds
2. **Caching**: Use cached network images
3. **Lazy Loading**: Load images on demand
4. **Indexing**: Create Firestore indexes for queries

## Future Enhancements

1. **Push Notifications**: Notify users of new posts
2. **Comments**: Add commenting system
3. **Advanced Filtering**: Filter by date, popularity, etc.
4. **Offline Support**: Cache posts for offline viewing
5. **Analytics**: Track post engagement metrics

## Support

For issues or questions:
1. Check the Firebase Console for errors
2. Review Firestore rules
3. Test with sample data
4. Check network connectivity
5. Verify authentication status 