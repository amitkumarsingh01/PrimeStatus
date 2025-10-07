const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const Razorpay = require('razorpay');

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

// Scheduled function to check and publish scheduled posts every minute
exports.publishScheduledPosts = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  console.log('🕐 [SCHEDULED_POSTS] Checking for scheduled posts...');
  
  try {
    const now = new Date();
    console.log('🕐 [SCHEDULED_POSTS] Current time:', now.toISOString());
    
    // Query for scheduled posts that should be published now
    const scheduledPostsQuery = db.collection('admin_posts')
      .where('isScheduled', '==', true)
      .where('isPublished', '==', false)
      .where('scheduledDateTime', '<=', now.toISOString());
    
    const scheduledPostsSnapshot = await scheduledPostsQuery.get();
    
    if (scheduledPostsSnapshot.empty) {
      console.log('📭 [SCHEDULED_POSTS] No scheduled posts to publish');
      return null;
    }
    
    console.log(`📝 [SCHEDULED_POSTS] Found ${scheduledPostsSnapshot.size} scheduled posts to publish`);
    
    const batch = db.batch();
    const publishedPosts = [];
    
    scheduledPostsSnapshot.forEach(doc => {
      const postData = doc.data();
      console.log(`📝 [SCHEDULED_POSTS] Publishing post: ${doc.id}`);
      console.log(`📝 [SCHEDULED_POSTS] Scheduled for: ${postData.scheduledDateTime}`);
      
      // Update the post to mark it as published
      batch.update(doc.ref, {
        isPublished: true,
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      publishedPosts.push({
        id: doc.id,
        ...postData
      });
    });
    
    // Commit the batch update
    await batch.commit();
    console.log(`✅ [SCHEDULED_POSTS] Successfully published ${publishedPosts.length} posts`);
    
    // Send notifications for published posts (if they have notification settings)
    for (const post of publishedPosts) {
      if (post.sendNotification) {
        try {
          const notificationData = {
            title: 'New Post Available!',
            body: `Check out the latest post by PrimeStatus`,
            imageUrl: post.mainImage,
            postId: post.id,
            adminName: post.adminName,
            categories: post.categories,
            businessCategory: post.businessCategory,
            regions: post.regions,
            language: post.language,
            topic: 'all_users',
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            fcmData: {
              postId: post.id,
              adminName: post.adminName,
              imageUrl: post.mainImage,
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
          };
          
          await db.collection('pending_notifications').add(notificationData);
          console.log(`📢 [SCHEDULED_POSTS] Notification queued for post: ${post.id}`);
        } catch (notificationError) {
          console.error(`❌ [SCHEDULED_POSTS] Error creating notification for post ${post.id}:`, notificationError);
        }
      }
    }
    
    return { success: true, publishedCount: publishedPosts.length };
    
  } catch (error) {
    console.error('❌ [SCHEDULED_POSTS] Error processing scheduled posts:', error);
    return { success: false, error: error.message };
  }
});

// Test function to manually trigger scheduled posts check
exports.testScheduledPosts = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      console.log('🧪 [TEST_SCHEDULED] Manually triggering scheduled posts check...');
      
      const now = new Date();
      console.log('🧪 [TEST_SCHEDULED] Current time:', now.toISOString());
      
      // Query for scheduled posts that should be published now
      const scheduledPostsQuery = db.collection('admin_posts')
        .where('isScheduled', '==', true)
        .where('isPublished', '==', false)
        .where('scheduledDateTime', '<=', now.toISOString());
      
      const scheduledPostsSnapshot = await scheduledPostsQuery.get();
      
      if (scheduledPostsSnapshot.empty) {
        console.log('📭 [TEST_SCHEDULED] No scheduled posts to publish');
        return res.json({ success: true, message: 'No scheduled posts to publish', count: 0 });
      }
      
      console.log(`📝 [TEST_SCHEDULED] Found ${scheduledPostsSnapshot.size} scheduled posts to publish`);
      
      const batch = db.batch();
      const publishedPosts = [];
      
      scheduledPostsSnapshot.forEach(doc => {
        const postData = doc.data();
        console.log(`📝 [TEST_SCHEDULED] Publishing post: ${doc.id}`);
        console.log(`📝 [TEST_SCHEDULED] Scheduled for: ${postData.scheduledDateTime}`);
        
        // Update the post to mark it as published
        batch.update(doc.ref, {
          isPublished: true,
          publishedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        publishedPosts.push({
          id: doc.id,
          scheduledDateTime: postData.scheduledDateTime,
          adminName: postData.adminName
        });
      });
      
      // Commit the batch update
      await batch.commit();
      console.log(`✅ [TEST_SCHEDULED] Successfully published ${publishedPosts.length} posts`);
      
      res.json({ 
        success: true, 
        message: `Successfully published ${publishedPosts.length} scheduled posts`,
        publishedPosts: publishedPosts
      });
      
    } catch (error) {
      console.error('❌ [TEST_SCHEDULED] Error processing scheduled posts:', error);
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

// Update user subscription after successful payment
exports.updateUserSubscription = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { userId, planId, planTitle, amount, duration, usageType } = req.body;
      if (!userId || !planId || !planTitle || !amount || !duration || !usageType) {
        return res.status(400).json({ success: false, error: 'Missing required fields' });
      }
      const now = new Date();
      const expiryDate = new Date(now.getTime() + duration * 24 * 60 * 60 * 1000);
      // Update user document
      await db.collection('users').doc(userId).update({
        subscription: 'Premium',
        subscriptionPlanId: planId,
        subscriptionPlanTitle: planTitle,
        subscriptionStartDate: now,
        subscriptionEndDate: expiryDate,
        subscriptionStatus: 'active',
        lastPaymentDate: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // Add to subscription history
      await db.collection('users').doc(userId).collection('subscriptionHistory').add({
        planId,
        planTitle,
        amount,
        duration,
        usageType,
        startDate: now,
        endDate: expiryDate,
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.json({ success: true });
    } catch (error) {
      console.error('Error updating user subscription:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
}); 

const RAZORPAY_KEY_ID = 'rzp_live_9ssoAG3CKktfqO';
const RAZORPAY_KEY_SECRET = 'P9Kqka188NLtSDO3aYVwhE6r';

const razorpay = new Razorpay({
  key_id: RAZORPAY_KEY_ID,
  key_secret: RAZORPAY_KEY_SECRET,
});

// HTTPS function to initiate payment and create payment link
exports.initiatePayment = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      console.log('🔍 [INITIATE_PAYMENT] Request received:', req.body);
      
      const { amount, userId, orderId } = req.body;
      if (!amount || !userId || !orderId) {
        console.log('❌ [INITIATE_PAYMENT] Missing required fields');
        return res.status(400).json({ success: false, error: 'Missing required fields: amount, userId, orderId' });
      }

      console.log('📋 [INITIATE_PAYMENT] Creating payment link with Razorpay...');
      console.log('💰 [INITIATE_PAYMENT] Amount in paise:', Math.round(amount * 100));
      
      const paymentLink = await razorpay.paymentLink.create({
        amount: Math.round(amount * 100), // INR to paise
        currency: 'INR',
        description: `Payment for Order ${orderId}`,
        customer: {
          name: `User ${userId}`,
          email: `user${userId}@gmail.com`,
          contact: "7827963159",
        },
        notify: { sms: true, email: true },
        reminder_enable: true,
        callback_url: "https://www.primestatusapp.com/paymentdone.html",
        callback_method: "get"
      });

      console.log('✅ [INITIATE_PAYMENT] Payment link created successfully:', paymentLink.id);
      res.json({ success: true, payment_url: paymentLink.short_url, payment_id: paymentLink.id });
    } catch (error) {
      console.error('❌ [INITIATE_PAYMENT] Error creating payment link:', error);
      console.error('❌ [INITIATE_PAYMENT] Error details:', {
        message: error.message,
        stack: error.stack,
        code: error.code,
        statusCode: error.statusCode
      });
      res.status(500).json({ success: false, error: error.message });
    }
  });
});

// HTTPS function to check payment status
exports.checkPaymentStatus = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      console.log('🔍 [CHECK_PAYMENT] Request received:', req.body);
      
      const { paymentId } = req.body;
      if (!paymentId) {
        console.log('❌ [CHECK_PAYMENT] Missing paymentId');
        return res.status(400).json({ success: false, error: 'Missing paymentId' });
      }

      console.log('📋 [CHECK_PAYMENT] Fetching payment status for:', paymentId);
      const payment = await razorpay.paymentLink.fetch(paymentId);
      
      console.log('✅ [CHECK_PAYMENT] Payment status:', payment.status);
      res.json({ success: true, status: payment.status }); // status: 'paid', 'created', 'cancelled', etc.
    } catch (error) {
      console.error('❌ [CHECK_PAYMENT] Error fetching payment status:', error);
      console.error('❌ [CHECK_PAYMENT] Error details:', {
        message: error.message,
        stack: error.stack,
        code: error.code,
        statusCode: error.statusCode
      });
      res.status(500).json({ success: false, error: error.message });
    }
  });
}); 

// Test function to verify Razorpay credentials
exports.testRazorpay = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      console.log('🧪 [TEST_RAZORPAY] Testing Razorpay credentials...');
      console.log('🔑 [TEST_RAZORPAY] Key ID:', RAZORPAY_KEY_ID);
      console.log('🔑 [TEST_RAZORPAY] Key Secret:', RAZORPAY_KEY_SECRET ? '***' + RAZORPAY_KEY_SECRET.slice(-4) : 'NOT_SET');
      
      // Test creating a minimal payment link
      const testPaymentLink = await razorpay.paymentLink.create({
        amount: 100, // 1 INR in paise
        currency: 'INR',
        description: 'Test Payment Link',
        customer: {
          name: 'Test User',
          email: 'test@example.com',
          contact: '9876543210',
        },
      });
      
      console.log('✅ [TEST_RAZORPAY] Test payment link created:', testPaymentLink.id);
      res.json({ 
        success: true, 
        message: 'Razorpay credentials are working',
        testPaymentId: testPaymentLink.id,
        testPaymentUrl: testPaymentLink.short_url
      });
    } catch (error) {
      console.error('❌ [TEST_RAZORPAY] Error testing Razorpay:', error);
      res.status(500).json({ 
        success: false, 
        error: error.message,
        details: {
          code: error.code,
          statusCode: error.statusCode
        }
      });
    }
  });
}); 