const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();

// Cloud Function to send notifications when a notification document is created
exports.sendNotificationToAll = functions.firestore
  .document('pending_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    console.log('Function triggered for document:', context.params.notificationId);
    
    try {
      const notificationData = snap.data();
      const notificationId = context.params.notificationId;

      console.log('Notification data:', notificationData);

      // Extract notification details
      const title = notificationData.title || 'New Post Available!';
      const body = notificationData.body || 'Check out the latest post';
      const imageUrl = notificationData.imageUrl || '';
      const postId = notificationData.postId || '';
      const adminName = notificationData.adminName || '';

      console.log('Sending notification:', { title, body, imageUrl, postId, adminName });

      // Create the notification message
      const message = {
        notification: {
          title: title,
          body: body,
          image: imageUrl
        },
        data: {
          postId: postId,
          adminName: adminName,
          imageUrl: imageUrl,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        topic: 'all_users'
      };

      // Send the notification
      const response = await admin.messaging().send(message);
      console.log('Successfully sent notification:', response);

      // Update the notification status to 'sent'
      await db.collection('pending_notifications').doc(notificationId).update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response
      });

      console.log('Notification status updated to sent');
      return { success: true, messageId: response };

    } catch (error) {
      console.error('Error in sendNotificationToAll:', error);

      try {
        // Update the notification status to 'failed'
        await db.collection('pending_notifications').doc(context.params.notificationId).update({
          status: 'failed',
          error: error.message,
          failedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('Notification status updated to failed');
      } catch (updateError) {
        console.error('Error updating notification status:', updateError);
      }

      return { success: false, error: error.message };
    }
  });

// Function to subscribe a user to the 'all_users' topic
exports.subscribeUserToTopic = functions.https.onCall(async (data, context) => {
  try {
    const { userId, fcmToken } = data;

    if (!userId || !fcmToken) {
      throw new Error('userId and fcmToken are required');
    }

    // Subscribe the token to the 'all_users' topic
    const response = await admin.messaging().subscribeToTopic([fcmToken], 'all_users');
    console.log('Successfully subscribed user to topic:', response);

    // Update user document with FCM token
    await db.collection('users').doc(userId).update({
      fcmToken: fcmToken,
      subscribedToNotifications: true,
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, response };

  } catch (error) {
    console.error('Error subscribing user to topic:', error);
    return { success: false, error: error.message };
  }
});

// Function to unsubscribe a user from the 'all_users' topic
exports.unsubscribeUserFromTopic = functions.https.onCall(async (data, context) => {
  try {
    const { userId, fcmToken } = data;

    if (!userId || !fcmToken) {
      throw new Error('userId and fcmToken are required');
    }

    // Unsubscribe the token from the 'all_users' topic
    const response = await admin.messaging().unsubscribeFromTopic([fcmToken], 'all_users');
    console.log('Successfully unsubscribed user from topic:', response);

    // Update user document
    await db.collection('users').doc(userId).update({
      subscribedToNotifications: false,
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, response };

  } catch (error) {
    console.error('Error unsubscribing user from topic:', error);
    return { success: false, error: error.message };
  }
});

// HTTP function to send test notifications
exports.sendTestNotification = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { title, body, imageUrl } = req.body;

      const message = {
        notification: {
          title: title || 'Test Notification',
          body: body || 'This is a test notification',
          image: imageUrl || ''
        },
        data: {
          test: 'true',
          timestamp: Date.now().toString()
        },
        topic: 'all_users'
      };

      const response = await admin.messaging().send(message);
      res.json({ success: true, messageId: response });

    } catch (error) {
      console.error('Error sending test notification:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
});

// HTTP function to get notification statistics
exports.getNotificationStats = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const stats = await db.collection('pending_notifications')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();

      const notifications = [];
      stats.forEach(doc => {
        notifications.push({
          id: doc.id,
          ...doc.data()
        });
      });

      res.json({ success: true, notifications });

    } catch (error) {
      console.error('Error getting notification stats:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
});

// Legacy FastAPI endpoints converted to Node.js (if needed)
exports.createUser = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { mobile_number, language, usage_type, name, profile_photo_url, religion, state, subscription } = req.body;

      const userData = {
        mobileNumber: mobile_number,
        language,
        usageType: usage_type,
        name,
        profilePhotoUrl: profile_photo_url,
        religion,
        state,
        subscription,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const docRef = await db.collection('users').add(userData);
      res.json({ success: true, userId: docRef.id });

    } catch (error) {
      console.error('Error creating user:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
});

exports.getUsers = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const usersSnapshot = await db.collection('users').get();
      const users = [];
      
      usersSnapshot.forEach(doc => {
        users.push({
          id: doc.id,
          ...doc.data()
        });
      });

      res.json({ success: true, users });

    } catch (error) {
      console.error('Error getting users:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
});

// Health check endpoint
exports.healthCheck = functions.https.onRequest((req, res) => {
  cors(req, res, () => {
    res.json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      service: 'Firebase Functions - PrimeStatus Backend'
    });
  });
}); 