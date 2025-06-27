# Firebase Integration for QuoteCraft

This document outlines the Firebase integration implemented in the QuoteCraft Flutter app.

## Overview

The app uses Firebase for:
- **Authentication**: Phone number and Google Sign-In
- **Database**: Firestore for user data and quotes
- **Storage**: Firebase Storage for images
- **Real-time updates**: Firestore streams for live data

## Firebase Services

### 1. Firebase Authentication Service (`firebase_auth_service.dart`)

Handles all authentication operations:

```dart
final authService = FirebaseAuthService();

// Phone authentication
await authService.verifyPhoneNumber(
  phoneNumber: '+1234567890',
  onCodeSent: (verificationId) => print('Code sent'),
  onVerificationCompleted: (credential) => print('Auto verified'),
  onVerificationFailed: (error) => print('Verification failed'),
  onCodeAutoRetrievalTimeout: (verificationId) => print('Timeout'),
);

// Google Sign-In
UserCredential userCredential = await authService.signInWithGoogle();

// Sign out
await authService.signOut();
```

### 2. Firebase Firestore Service (`firebase_firestore_service.dart`)

Manages database operations:

```dart
final firestoreService = FirebaseFirestoreService();

// Create user
await firestoreService.createUser(
  uid: 'user123',
  mobileNumber: '+1234567890',
  name: 'John Doe',
  language: 'English',
  usageType: 'Personal',
  religion: 'Other',
  state: 'California',
);

// Create quote
String quoteId = await firestoreService.createQuote(
  userId: 'user123',
  text: 'Be the change you wish to see in the world',
  author: 'Mahatma Gandhi',
  category: 'Inspiration',
  language: 'English',
  isPublic: true,
);

// Get user quotes
Stream<QuerySnapshot> userQuotes = firestoreService.getUserQuotes('user123');
```

### 3. Firebase Storage Service (`firebase_storage_service.dart`)

Handles file uploads and downloads:

```dart
final storageService = FirebaseStorageService();

// Upload profile photo
String downloadUrl = await storageService.uploadProfilePhoto(
  imageFile,
  'user123',
);

// Upload quote image
String imageUrl = await storageService.uploadQuoteImage(
  imageFile,
  'user123',
  'quote456',
);

// Delete image
await storageService.deleteImage(imageUrl);
```

### 4. User Service (`user_service.dart`)

High-level user management:

```dart
final userService = UserService();

// Register new user
UserCredential userCredential = await userService.registerWithPhone(
  phoneNumber: '+1234567890',
  name: 'John Doe',
  language: 'English',
  usageType: 'Personal',
  religion: 'Other',
  state: 'California',
);

// Get user data
Map<String, dynamic>? userData = await userService.getUserData('user123');

// Update profile
await userService.updateProfile(
  uid: 'user123',
  name: 'John Smith',
  language: 'Spanish',
);
```

### 5. Quote Service (`quote_service.dart`)

High-level quote management:

```dart
final quoteService = QuoteService();

// Create quote
String quoteId = await quoteService.createQuote(
  text: 'Life is what happens when you\'re busy making other plans',
  author: 'John Lennon',
  category: 'Life',
  language: 'English',
  isPublic: true,
);

// Get user quotes
Stream<QuerySnapshot> userQuotes = quoteService.getUserQuotes();

// Like/unlike quote
await quoteService.toggleLike('quote123');

// Search quotes
QuerySnapshot results = await quoteService.searchQuotes('inspiration');
```

## Database Schema

### Users Collection
```json
{
  "uid": "user123",
  "mobileNumber": "+1234567890",
  "name": "John Doe",
  "language": "English",
  "usageType": "Personal",
  "religion": "Other",
  "state": "California",
  "profilePhotoUrl": "https://...",
  "subscription": "free",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

### Quotes Collection
```json
{
  "quoteId": "quote123",
  "userId": "user123",
  "text": "Be the change you wish to see in the world",
  "author": "Mahatma Gandhi",
  "category": "Inspiration",
  "language": "English",
  "imageUrl": "https://...",
  "isPublic": true,
  "likes": 42,
  "shares": 15,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

### User Quotes Collection (Subcollection)
```json
{
  "userId": "user123",
  "quotes": {
    "quote123": {
      "quoteId": "quote123",
      "text": "Be the change you wish to see in the world",
      "author": "Mahatma Gandhi",
      "category": "Inspiration",
      "language": "English",
      "imageUrl": "https://...",
      "isPublic": true,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  }
}
```

## Storage Structure

```
firebase_storage/
├── profile_photos/
│   └── user123/
│       └── uuid.jpg
├── quote_images/
│   └── user123/
│       └── quote456/
│           └── uuid.jpg
├── backgrounds/
│   ├── inspiration/
│   ├── motivation/
│   └── life/
└── temp/
    └── uuid.jpg
```

## Security Rules

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Users can read and write their own quotes
    match /user_quotes/{userId}/quotes/{quoteId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public quotes can be read by anyone, but only created by authenticated users
    match /quotes/{quoteId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // Quote likes can be managed by authenticated users
    match /quotes/{quoteId}/likes/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile photos: users can upload and read their own photos
    match /profile_photos/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Quote images: users can upload and read their own quote images
    match /quote_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Background images: anyone can read, only admins can write
    match /backgrounds/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && 
        request.auth.token.admin == true;
    }
    
    // Temporary images: users can upload and read their own temp images
    match /temp/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Usage Examples

### Authentication Flow
```dart
// 1. User enters phone number
String phoneNumber = '+1234567890';

// 2. Verify phone number
await userService.verifyPhoneNumber(
  phoneNumber: phoneNumber,
  onCodeSent: (verificationId) {
    // Store verificationId for later use
    _verificationId = verificationId;
  },
  onVerificationCompleted: (credential) async {
    // Auto-verification completed
    await userService.signInWithPhone(
      phoneNumber: phoneNumber,
      verificationId: _verificationId,
      smsCode: '', // Not needed for auto-verification
    );
  },
  onVerificationFailed: (error) {
    print('Verification failed: ${error.message}');
  },
  onCodeAutoRetrievalTimeout: (verificationId) {
    print('SMS code auto-retrieval timeout');
  },
);

// 3. User enters SMS code
await userService.signInWithPhone(
  phoneNumber: phoneNumber,
  verificationId: _verificationId,
  smsCode: '123456',
);
```

### Quote Management Flow
```dart
// 1. Create a new quote
String quoteId = await quoteService.createQuote(
  text: 'Your quote text here',
  author: 'Author Name',
  category: 'Inspiration',
  language: 'English',
  imageFile: selectedImage, // Optional
  isPublic: true,
);

// 2. Get user's quotes
Stream<QuerySnapshot> userQuotes = quoteService.getUserQuotes();
userQuotes.listen((snapshot) {
  snapshot.docs.forEach((doc) {
    Map<String, dynamic> quoteData = doc.data() as Map<String, dynamic>;
    print('Quote: ${quoteData['text']}');
  });
});

// 3. Like a quote
await quoteService.toggleLike(quoteId);

// 4. Check if user liked a quote
bool isLiked = await quoteService.isLikedByUser(quoteId);

// 5. Get quote statistics
Map<String, int> stats = await quoteService.getQuoteStats(quoteId);
print('Likes: ${stats['likes']}, Shares: ${stats['shares']}');
```

### Image Upload Flow
```dart
// 1. Pick image from gallery
File? imageFile = await ImagePicker().pickImage(source: ImageSource.gallery);

if (imageFile != null) {
  // 2. Upload profile photo
  String downloadUrl = await userService.uploadProfilePhoto(
    imageFile,
    currentUser.uid,
  );
  
  // 3. Update UI with new photo
  setState(() {
    profilePhotoUrl = downloadUrl;
  });
}
```

## Error Handling

All Firebase services include comprehensive error handling:

```dart
try {
  await userService.registerWithPhone(
    phoneNumber: '+1234567890',
    name: 'John Doe',
    // ... other parameters
  );
} catch (e) {
  // Handle specific Firebase errors
  if (e.toString().contains('email-already-in-use')) {
    print('User already exists');
  } else if (e.toString().contains('weak-password')) {
    print('Password is too weak');
  } else {
    print('Registration failed: $e');
  }
}
```

## Offline Support

The app includes offline persistence for Firestore:

```dart
// Enable offline persistence (done in main.dart)
await FirebaseConfig.enableOfflinePersistence();

// Data will be cached locally and synced when online
Stream<QuerySnapshot> userQuotes = quoteService.getUserQuotes();
// This will work offline with cached data
```

## Performance Optimization

1. **Indexed Queries**: All Firestore queries use proper indexes
2. **Pagination**: Large datasets are paginated
3. **Image Caching**: Images are cached using `cached_network_image`
4. **Offline Persistence**: Data is cached for offline access
5. **Lazy Loading**: Images and data are loaded on demand

## Testing

To test Firebase integration:

1. **Unit Tests**: Test individual service methods
2. **Integration Tests**: Test Firebase operations with test data
3. **UI Tests**: Test authentication and data flow in the UI

## Deployment

1. **Firebase Console**: Configure Firebase project
2. **Security Rules**: Deploy Firestore and Storage rules
3. **Indexes**: Create necessary Firestore indexes
4. **App Configuration**: Update app with Firebase config files

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Check Firebase Auth configuration
2. **Permission Denied**: Verify Firestore security rules
3. **Image Upload Failures**: Check Storage rules and file size limits
4. **Offline Issues**: Ensure offline persistence is enabled

### Debug Mode

Enable Firebase debug mode for development:

```dart
// In firebase_config.dart
await FirebaseAuth.instance.setSettings(
  appVerificationDisabledForTesting: true, // For testing only
);
```

## Future Enhancements

1. **Push Notifications**: Firebase Cloud Messaging
2. **Analytics**: Firebase Analytics integration
3. **Crashlytics**: Error reporting and monitoring
4. **Performance Monitoring**: App performance tracking
5. **Remote Config**: Dynamic app configuration 