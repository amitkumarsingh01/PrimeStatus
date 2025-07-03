# Quote Generator App

A Flutter application for creating and sharing personalized quotes with Firebase backend integration.

## Features

- **Authentication**: Google Sign-In and Phone Number authentication
- **Quote Management**: Browse, save, and create quotes
- **User Profiles**: Customizable user profiles with preferences
- **Real-time Updates**: Firebase Firestore integration for real-time data
- **Push Notifications**: Firebase Cloud Messaging integration
- **Image Sharing**: Share generated quotes as images
- **Multi-language Support**: Support for multiple languages
- **Category Filtering**: Filter quotes by categories

## Project Structure

```
lib/
├── main.dart                 # Main application entry point
├── models/                   # Data models
│   ├── user_model.dart       # User data model
│   └── quote_model.dart      # Quote data model
├── services/                 # Business logic services
│   ├── auth_service.dart     # Authentication service
│   ├── notification_service.dart # Push notification service
│   └── quote_service.dart    # Quote management service
├── screens/                  # UI screens
│   ├── splash_screen.dart    # App splash screen
│   ├── auth/                 # Authentication screens
│   │   ├── login_screen.dart
│   │   └── phone_auth_screen.dart
│   ├── home/                 # Main app screens
│   │   └── home_screen.dart
│   ├── profile/              # User profile screens
│   │   └── profile_screen.dart
│   └── quotes/               # Quote-related screens
│       ├── quote_detail_screen.dart
│       └── saved_quotes_screen.dart
└── widgets/                  # Reusable UI components
    ├── quote_card.dart       # Quote display card
    └── quote_renderer.dart   # Quote rendering widget
```

## Dependencies

### Firebase
- `firebase_core`: Firebase core functionality
- `firebase_auth`: User authentication
- `cloud_firestore`: NoSQL database
- `firebase_messaging`: Push notifications
- `firebase_storage`: File storage

### Authentication
- `google_sign_in`: Google Sign-In integration

### UI & Media
- `image_picker`: Image selection from gallery/camera
- `cached_network_image`: Efficient image loading and caching

### Utilities
- `uuid`: Unique identifier generation
- `share_plus`: Share functionality
- `path_provider`: File system access
- `permission_handler`: Permission management

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd primestatus
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication (Google Sign-In and Phone)
   - Enable Firestore Database
   - Enable Cloud Messaging
   - Download and add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

4. **Run the app**
   ```bash
   flutter run
   ```

## Key Features Implementation

### Authentication Flow
- Splash screen checks for existing user session
- Login screen with Google Sign-In and Phone authentication options
- Phone authentication with OTP verification
- Automatic user profile creation on first login

### Quote Management
- Browse quotes with category filtering
- Save/unsave quotes to user's collection
- View saved quotes in dedicated tab
- Quote detail view with sharing capabilities

### User Profile
- Editable user information (name, language, religion, state, usage type)
- Profile photo management (placeholder for image picker implementation)
- Real-time profile updates

### Data Models

#### UserModel
- User identification and contact information
- Preferences (language, religion, state, usage type)
- Quote collections (created and saved quotes)
- FCM token for notifications

#### QuoteModel
- Quote metadata (title, category, hashtags)
- Image URL and asset information
- Text and image placeholder locations
- Access control (free/premium)
- Multi-language and demographic targeting

## Future Enhancements

- [ ] Quote creation/editing functionality
- [ ] Advanced image editing features
- [ ] Social media integration
- [ ] Premium subscription system
- [ ] Analytics and user insights
- [ ] Offline support
- [ ] Dark theme support
- [ ] Accessibility improvements

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
