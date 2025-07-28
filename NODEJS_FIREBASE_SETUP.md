# Node.js Firebase Functions Setup Guide

This guide explains how to set up and deploy the Node.js Firebase Functions for the PrimeStatus app with automatic notification system.

## Overview

The system now uses Node.js Firebase Functions that automatically send notifications when admin posts are created. No manual Firebase Console intervention is required.

## Components

1. **Admin Panel (ImageEditor.tsx)**: Checkbox to enable automatic notifications
2. **Node.js Firebase Functions**: Automatically sends notifications when triggered
3. **Flutter App**: Subscribes to topics and handles notifications

## Setup Instructions

### 1. Prerequisites

1. Install Node.js (version 18 or higher)
2. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
3. Login to Firebase:
   ```bash
   firebase login
   ```

### 2. Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `prime-status-1db09`
3. Enable Cloud Functions:
   - Go to Functions in the left sidebar
   - Click "Get started"
   - Choose a billing plan (Blaze plan required for external network calls)

### 3. Deploy Firebase Functions

1. Navigate to the functions directory:
   ```bash
   cd functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Deploy the functions:
   ```bash
   firebase deploy --only functions
   ```

   Or use the deployment script:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

### 4. Flutter App Setup

1. Add the cloud_functions dependency to `pubspec.yaml`:
   ```yaml
   dependencies:
     cloud_functions: ^5.6.9
   ```

2. Run:
   ```bash
   flutter pub get
   ```

3. The app is already configured to:
   - Request notification permissions
   - Subscribe to the 'all_users' topic
   - Call Cloud Functions for subscription management

### 5. Admin Panel Usage

1. Open the ImageEditor component
2. Check the "Send notification to all users" checkbox
3. Save your post
4. Notification will be sent automatically to all users

## Available Functions

### Automatic Functions (Triggers)

1. **sendNotificationToAll**
   - **Trigger**: Firestore document creation in `pending_notifications` collection
   - **Purpose**: Automatically sends notifications when admin creates a post
   - **Status**: Updates notification document with sent/failed status

### Callable Functions

2. **subscribeUserToTopic**
   - **Purpose**: Subscribe a user's FCM token to the 'all_users' topic
   - **Parameters**: `{ userId, fcmToken }`
   - **Usage**: Called automatically by Flutter app

3. **unsubscribeUserFromTopic**
   - **Purpose**: Unsubscribe a user's FCM token from the 'all_users' topic
   - **Parameters**: `{ userId, fcmToken }`
   - **Usage**: Called when user opts out of notifications

### HTTP Functions

4. **sendTestNotification**
   - **Purpose**: Send test notifications for debugging
   - **Method**: POST
   - **Body**: `{ title, body, imageUrl }`

5. **getNotificationStats**
   - **Purpose**: Get recent notification statistics
   - **Method**: GET
   - **Response**: List of recent notifications

6. **createUser**
   - **Purpose**: Create a new user (legacy endpoint)
   - **Method**: POST
   - **Body**: User data

7. **getUsers**
   - **Purpose**: Get all users (legacy endpoint)
   - **Method**: GET
   - **Response**: List of users

8. **healthCheck**
   - **Purpose**: Health check endpoint
   - **Method**: GET
   - **Response**: Service status

## How It Works

### When Admin Saves a Post:

1. Admin checks the notification checkbox in ImageEditor
2. Post is saved to `admin_posts` collection
3. If notification is enabled, a document is created in `pending_notifications` collection
4. **sendNotificationToAll** function triggers automatically
5. Function sends FCM message to 'all_users' topic
6. All subscribed devices receive the notification
7. Function updates notification status to 'sent' or 'failed'

### Notification Content:

- **Title**: "New Post Available!"
- **Body**: "Check out the latest post by [AdminName]"
- **Image**: The post image
- **Data**: Post ID, admin name, image URL for deep linking

### Status Tracking:

The system tracks notification status in Firestore:
- `pending`: Notification created, waiting to be sent
- `sent`: Notification successfully sent (with messageId)
- `failed`: Notification failed to send (with error details)

## Testing

### Test Notifications:

1. Deploy the Cloud Functions
2. Open the Flutter app and grant notification permissions
3. Use the admin panel to create a post with notifications enabled
4. Check that the notification appears on the device automatically

### Test HTTP Functions:

1. **Health Check**:
   ```bash
   curl https://[region]-[project-id].cloudfunctions.net/healthCheck
   ```

2. **Send Test Notification**:
   ```bash
   curl -X POST https://[region]-[project-id].cloudfunctions.net/sendTestNotification \
     -H "Content-Type: application/json" \
     -d '{"title":"Test","body":"Test notification","imageUrl":""}'
   ```

3. **Get Notification Stats**:
   ```bash
   curl https://[region]-[project-id].cloudfunctions.net/getNotificationStats
   ```

### Debug Notifications:

1. Check Firebase Console > Functions for execution logs
2. Check Firestore > pending_notifications collection for status updates
3. Check Flutter app console for FCM token and subscription logs

## Troubleshooting

### Common Issues:

1. **Functions not deploying**:
   - Check Node.js version (should be 18+)
   - Verify Firebase CLI is installed and logged in
   - Check billing plan (Blaze required)

2. **Notifications not sending**:
   - Check if Cloud Functions are deployed
   - Verify Firestore trigger is working
   - Check Firebase Console > Functions logs

3. **App not receiving notifications**:
   - Ensure app has notification permissions
   - Check if app is subscribed to 'all_users' topic
   - Verify FCM token is generated
   - Check Cloud Function logs for subscription errors

4. **Permission denied errors**:
   - Check Firestore security rules
   - Verify service account has proper permissions

### Debug Steps:

1. **Check Function Logs**:
   ```bash
   firebase functions:log
   ```

2. **Check FCM Token**:
   - Look at Flutter app console logs
   - Should see "FCM Token: [token]"
   - Should see "Subscribed to all_users topic"

3. **Check Topic Subscription**:
   - Go to Firebase Console > Cloud Messaging > Topics
   - Look for 'all_users' topic
   - Check subscriber count

4. **Check Notification Delivery**:
   - Go to Firebase Console > Cloud Messaging > Reports
   - Check delivery statistics

## Security Rules

### Firestore Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /pending_notifications/{document} {
      allow read, write: if request.auth != null;
    }
    match /admin_posts/{document} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /users/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Cost Considerations

- **FCM**: Free for unlimited messages
- **Cloud Functions**: Free tier (2M invocations/month)
- **Firestore**: Free tier (50K reads, 20K writes/day)

## Monitoring

### Firebase Console Monitoring:

1. **Functions**: Monitor execution count, errors, and performance
2. **Cloud Messaging**: Track notification delivery rates
3. **Firestore**: Monitor read/write operations

### Custom Monitoring:

1. **Notification Status**: Check `pending_notifications` collection
2. **User Subscriptions**: Monitor user FCM token updates
3. **Error Tracking**: Check function logs for failures

## Best Practices

1. **Error Handling**: All functions include proper error handling
2. **Logging**: Comprehensive logging for debugging
3. **Status Tracking**: Track notification delivery status
4. **Rate Limiting**: Built-in Firebase rate limiting
5. **Security**: Proper authentication and authorization

## Future Enhancements

1. **Scheduled Notifications**: Send notifications at specific times
2. **Targeted Notifications**: Send to specific user segments
3. **Rich Notifications**: Include more interactive elements
4. **Analytics**: Track notification engagement and open rates
5. **A/B Testing**: Test different notification content
6. **Retry Logic**: Retry failed notifications
7. **Bulk Operations**: Send multiple notifications efficiently 