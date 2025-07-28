# Firebase Console Notification Setup

This guide explains how to send notifications using Firebase Console without requiring Cloud Functions.

## Overview

When you check the "Send notification to all users" checkbox in the ImageEditor, a notification document is created in Firestore. You can then manually send this notification using Firebase Console.

## Setup Steps

### 1. Flutter App Setup (Already Done)

The Flutter app automatically:
- Requests notification permissions
- Subscribes to the 'all_users' topic
- Handles incoming notifications

### 2. Admin Panel Usage

1. Open the ImageEditor component
2. Check the "Send notification to all users" checkbox
3. Save your post
4. You'll see a message: "Post saved! Notification document created. Please send it via Firebase Console > Cloud Messaging."

### 3. Sending Notifications via Firebase Console

#### Method 1: Send to Topic (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `prime-status-1db09`
3. Go to **Engage** > **Cloud Messaging**
4. Click **Send your first message**
5. Fill in the notification details:
   - **Notification title**: "New Post Available!"
   - **Notification text**: "Check out the latest post by [AdminName]"
   - **Image**: Upload the post image or use the image URL from the notification document
6. Click **Next**
7. Under **Target**, select **Topic**
8. Choose the topic: `all_users`
9. Click **Next**
10. Review and click **Publish**

#### Method 2: Send to All Users

1. Follow steps 1-6 above
2. Under **Target**, select **User segment**
3. Choose **All users**
4. Click **Next** and **Publish**

### 4. Finding Notification Data

When you create a post with notifications enabled, a document is created in the `pending_notifications` collection in Firestore. You can find this data:

1. Go to Firebase Console > **Firestore Database**
2. Navigate to `pending_notifications` collection
3. Find the latest document with your notification data

The document contains:
- `title`: "New Post Available!"
- `body`: "Check out the latest post by [AdminName]"
- `imageUrl`: URL of the post image
- `topic`: "all_users"
- `fcmData`: Additional data for the app

## Notification Content

### Default Notification:
- **Title**: "New Post Available!"
- **Body**: "Check out the latest post by [AdminName]"
- **Image**: The post image
- **Data**: Post ID, admin name, image URL

### Customizing Notifications:

You can customize the notification content in Firebase Console:

1. **Title**: Change to something more specific
2. **Body**: Add more details about the post
3. **Image**: Use the post image or a custom image
4. **Additional Data**: Add custom data for deep linking

## Testing Notifications

### Test on Device:

1. Install the Flutter app on a device
2. Grant notification permissions when prompted
3. Create a post with notifications enabled in admin panel
4. Send the notification via Firebase Console
5. Check that the notification appears on the device

### Test on Emulator:

1. Run the Flutter app on an emulator
2. Follow the same steps as above
3. Notifications should work on Android emulators

## Troubleshooting

### Common Issues:

1. **Notifications not appearing**:
   - Check if the app has notification permissions
   - Verify the app is subscribed to 'all_users' topic
   - Check Firebase Console logs for delivery status

2. **Topic subscription issues**:
   - Check Flutter app console for FCM token generation
   - Verify topic subscription in Firebase Console > Cloud Messaging > Topics

3. **Permission denied**:
   - Check Firestore security rules
   - Ensure you have proper Firebase Console access

### Debug Steps:

1. **Check FCM Token**:
   - Look at Flutter app console logs
   - Should see "FCM Token: [token]"
   - Should see "Subscribed to all_users topic"

2. **Check Topic Subscription**:
   - Go to Firebase Console > Cloud Messaging > Topics
   - Look for 'all_users' topic
   - Check subscriber count

3. **Check Notification Delivery**:
   - Go to Firebase Console > Cloud Messaging > Reports
   - Check delivery statistics

## Security Considerations

### Firestore Rules:

Make sure your Firestore security rules allow reading/writing to the `pending_notifications` collection:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /pending_notifications/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Firebase Console Access:

- Only authorized users should have access to Firebase Console
- Use Firebase App Check to prevent unauthorized access
- Monitor notification sending activity

## Cost Considerations

- **FCM**: Free for unlimited messages
- **Firestore**: Free tier includes 50K reads and 20K writes per day
- **Firebase Console**: Free to use

## Best Practices

1. **Test Notifications**: Always test on a real device before sending to all users
2. **Monitor Delivery**: Check Firebase Console reports for delivery success rates
3. **Rate Limiting**: Don't send too many notifications too quickly
4. **Content Quality**: Make notifications relevant and valuable to users
5. **Timing**: Send notifications at appropriate times for your user base

## Future Enhancements

1. **Automated Sending**: Implement Cloud Functions for automatic sending
2. **Scheduled Notifications**: Send notifications at specific times
3. **Targeted Notifications**: Send to specific user segments
4. **Rich Notifications**: Include more interactive elements
5. **Analytics**: Track notification engagement and open rates 