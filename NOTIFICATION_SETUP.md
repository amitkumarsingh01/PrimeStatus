# Firebase Notification Setup Guide

This guide explains how to set up and use the notification system for the PrimeStatus app.

## Overview

The notification system allows admins to send push notifications to all app users when they create new posts. The system uses Firebase Cloud Messaging (FCM) with topics to send notifications to all devices.

## Components

1. **Admin Panel (ImageEditor.tsx)**: Checkbox to enable/disable notifications when saving posts
2. **Firebase Cloud Functions**: Automatically sends notifications when a notification document is created
3. **Flutter App**: Subscribes users to the 'all_users' topic and handles incoming notifications

## Setup Instructions

### 1. Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `prime-status-1db09`
3. Enable Cloud Functions:
   - Go to Functions in the left sidebar
   - Click "Get started"
   - Choose a billing plan (Blaze plan required for external network calls)

### 2. Service Account Key

1. In Firebase Console, go to Project Settings
2. Go to Service Accounts tab
3. Click "Generate new private key"
4. Download the JSON file
5. Place it in the `functions/` directory as `serviceAccountKey.json`
6. Update the path in `functions/main.py`:
   ```python
   cred = credentials.Certificate('serviceAccountKey.json')
   ```

### 3. Deploy Cloud Functions

1. Install Firebase CLI if not already installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Navigate to the functions directory:
   ```bash
   cd functions
   ```

4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

5. Deploy the functions:
   ```bash
   firebase deploy --only functions
   ```

### 4. Flutter App Setup

The Flutter app is already configured to:
- Request notification permissions
- Subscribe to the 'all_users' topic
- Handle incoming notifications

### 5. Admin Panel Usage

1. Open the ImageEditor component
2. You'll see a new "Notification" section in the left panel
3. Check the "Send notification to all users" checkbox
4. When you save a post, a notification will be sent to all app users

## How It Works

### When Admin Saves a Post:

1. Admin checks the notification checkbox in ImageEditor
2. Post is saved to `admin_posts` collection
3. If notification is enabled, a document is created in `notifications` collection
4. Cloud Function triggers automatically when notification document is created
5. Function sends FCM message to 'all_users' topic
6. All subscribed devices receive the notification

### Notification Content:

- **Title**: "New Post Available!"
- **Body**: "Check out the latest post by [AdminName]"
- **Image**: The post image
- **Data**: Post ID, admin name, and image URL for deep linking

### Notification Status Tracking:

The system tracks notification status in Firestore:
- `pending`: Notification created, waiting to be sent
- `sent`: Notification successfully sent
- `failed`: Notification failed to send (with error details)

## Testing

### Test Notifications:

1. Deploy the Cloud Functions
2. Open the Flutter app and grant notification permissions
3. Use the admin panel to create a post with notifications enabled
4. Check that the notification appears on the device

### Debug Notifications:

1. Check Firebase Console > Functions for execution logs
2. Check Firestore > notifications collection for status updates
3. Check Flutter app console for FCM token and subscription logs

## Troubleshooting

### Common Issues:

1. **Notifications not sending**:
   - Check if Cloud Functions are deployed
   - Verify service account key is correct
   - Check Firebase Console > Functions logs

2. **App not receiving notifications**:
   - Ensure app has notification permissions
   - Check if app is subscribed to 'all_users' topic
   - Verify FCM token is generated

3. **Permission denied errors**:
   - Check Firestore security rules
   - Verify service account has proper permissions

### Security Rules:

Make sure your Firestore security rules allow:
- Reading/writing to `notifications` collection
- Reading from `admin_posts` collection

Example rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /notifications/{document} {
      allow read, write: if request.auth != null;
    }
    match /admin_posts/{document} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## Cost Considerations

- FCM is free for unlimited messages
- Cloud Functions have a free tier (2M invocations/month)
- Firestore has a free tier (50K reads, 20K writes/day)

## Future Enhancements

1. **Targeted Notifications**: Send to specific categories or regions
2. **Scheduled Notifications**: Send notifications at specific times
3. **Rich Notifications**: Include more data and actions
4. **Analytics**: Track notification open rates and engagement
5. **A/B Testing**: Test different notification content 