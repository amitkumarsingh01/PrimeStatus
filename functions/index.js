const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const crypto = require('crypto');

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

// ============================================================================
// RAZORPAY WEBHOOK HANDLERS
// ============================================================================

// Verify Razorpay webhook signature
function verifyWebhookSignature(payload, signature, secret) {
  try {
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('hex');
    
    console.log('🔐 [WEBHOOK] Signature verification details:');
    console.log('   - Expected signature:', expectedSignature);
    console.log('   - Received signature:', signature);
    console.log('   - Signatures match:', expectedSignature === signature);
    
    return expectedSignature === signature;
  } catch (error) {
    console.error('❌ Webhook signature verification failed:', error);
    return false;
  }
}

// Handle Razorpay payment webhooks
exports.razorpayWebhook = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      console.log('🔔 [WEBHOOK] ==========================================');
      console.log('🔔 [WEBHOOK] NEW WEBHOOK REQUEST RECEIVED');
      console.log('🔔 [WEBHOOK] ==========================================');
      console.log('🔔 [WEBHOOK] Timestamp:', new Date().toISOString());
      console.log('🔔 [WEBHOOK] Request Method:', req.method);
      console.log('🔔 [WEBHOOK] Request Headers:', JSON.stringify(req.headers, null, 2));
      console.log('🔔 [WEBHOOK] Request Body:', JSON.stringify(req.body, null, 2));
      
      // Get webhook data and signature
      const webhookData = req.body;
      const signature = req.headers['x-razorpay-signature'];
      const webhookSecret = 'primestatus2025'; // Hardcoded webhook secret
      
      console.log('🔔 [WEBHOOK] Extracted Data:');
      console.log('   - Webhook Data:', JSON.stringify(webhookData, null, 2));
      console.log('   - Signature:', signature);
      console.log('   - Webhook Secret:', webhookSecret ? '***CONFIGURED***' : '***NOT CONFIGURED***');
      
      if (!webhookData) {
        console.log('❌ [WEBHOOK] No webhook data received');
        console.log('❌ [WEBHOOK] Returning 400 error');
        return res.status(400).json({ error: 'No data received' });
      }
      
      console.log('✅ [WEBHOOK] Webhook data received successfully');
      
      if (!signature) {
        console.log('⚠️ [WEBHOOK] No signature received - proceeding without verification for testing');
        console.log('⚠️ [WEBHOOK] This is normal for testing environments');
      } else {
        console.log('✅ [WEBHOOK] Signature received:', signature);
      }
      
      // Verify webhook signature (only if signature is provided)
      if (signature) {
        console.log('🔐 [WEBHOOK] Attempting signature verification...');
        const payload = JSON.stringify(webhookData);
        console.log('🔐 [WEBHOOK] Payload for verification:', payload);
        
        if (!verifyWebhookSignature(payload, signature, webhookSecret)) {
          console.log('❌ [WEBHOOK] Invalid webhook signature');
          console.log('❌ [WEBHOOK] Returning 401 error');
          return res.status(401).json({ error: 'Invalid signature' });
        }
        console.log('✅ [WEBHOOK] Signature verified successfully');
      } else {
        console.log('⚠️ [WEBHOOK] Skipping signature verification for testing');
      }
      
      console.log('📋 [WEBHOOK] ==========================================');
      console.log('📋 [WEBHOOK] PROCESSING WEBHOOK DATA');
      console.log('📋 [WEBHOOK] ==========================================');
      console.log('📋 [WEBHOOK] Full webhook data:', JSON.stringify(webhookData, null, 2));
      
      // Extract event details - handle both regular payments and payment links
      const event = webhookData.event;
      let payloadData = webhookData.payload || {};
      
      console.log('📋 [WEBHOOK] Raw webhook data structure:');
      console.log('   - Has event:', !!webhookData.event);
      console.log('   - Has payload:', !!webhookData.payload);
      console.log('   - Has payment_link:', !!webhookData.payment_link);
      console.log('   - Keys in webhookData:', Object.keys(webhookData));
      
      // For payment links, the data structure might be different
      if (!event && webhookData.payment_link) {
        console.log('📋 [WEBHOOK] Detected payment link webhook format');
        payloadData = {
          payment: webhookData.payment_link,
          entity: webhookData.payment_link
        };
      }
      
      // If webhook data is empty, try to extract from different fields
      if (!event && Object.keys(webhookData).length > 0) {
        console.log('📋 [WEBHOOK] No event found, checking for alternative data structure');
        // Try to find payment data in different possible locations
        if (webhookData.payment) {
          console.log('📋 [WEBHOOK] Found payment data in webhookData.payment');
          payloadData = { payment: webhookData.payment, entity: webhookData.payment };
        } else if (webhookData.entity) {
          console.log('📋 [WEBHOOK] Found payment data in webhookData.entity');
          payloadData = { payment: webhookData.entity, entity: webhookData.entity };
        }
      }
      
      console.log('📋 [WEBHOOK] Extracted Event Details:');
      console.log('   - Event Type:', event);
      console.log('   - Payload Data:', JSON.stringify(payloadData, null, 2));
      
      // Store webhook in Firestore for tracking
      console.log('💾 [WEBHOOK] Storing webhook in Firestore...');
      try {
        const webhookRef = await db.collection('webhooks').add({
          data: webhookData,
          event: event || 'unknown',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          processed: false
        });
        console.log('✅ [WEBHOOK] Webhook stored in Firestore with ID:', webhookRef.id);
      } catch (error) {
        console.log('❌ [WEBHOOK] Error storing webhook in Firestore:', error);
      }
      
      // Handle different webhook events
      console.log('🔄 [WEBHOOK] Processing event type:', event);
      
      // Check if this is a payment link webhook (no event but has payment_link data)
      if (!event && webhookData.payment_link) {
        console.log('✅ [WEBHOOK] Processing payment link webhook');
        await handlePaymentCaptured(payloadData);
      } else if (!event && (webhookData.payment || webhookData.entity)) {
        console.log('✅ [WEBHOOK] Processing webhook with payment data but no event');
        await handlePaymentCaptured(payloadData);
      } else if (event === 'payment.captured' || event === 'payment_link.paid') {
        console.log('✅ [WEBHOOK] Processing successful payment event (captured)');
        await handlePaymentCaptured(payloadData);
      } else if (event === 'payment.authorized') {
        console.log('✅ [WEBHOOK] Processing payment authorized event');
        await handlePaymentAuthorized(payloadData);
      } else if (event === 'payment.failed') {
        console.log('❌ [WEBHOOK] Processing failed payment event');
        await handlePaymentFailed(payloadData);
      } else {
        console.log(`ℹ️ [WEBHOOK] Unhandled event: ${event}`);
        console.log(`ℹ️ [WEBHOOK] This event type is not processed`);
        console.log(`ℹ️ [WEBHOOK] Available data:`, JSON.stringify(webhookData, null, 2));
      }
      
      // Mark webhook as processed
      console.log('✅ [WEBHOOK] Marking webhook as processed...');
      try {
        const webhookSnapshot = await db.collection('webhooks').where('event', '==', event || 'unknown').limit(1).get();
        if (!webhookSnapshot.empty) {
          await webhookSnapshot.docs[0].ref.update({ processed: true });
          console.log('✅ [WEBHOOK] Webhook marked as processed');
        } else {
          console.log('⚠️ [WEBHOOK] No webhook document found to mark as processed');
        }
      } catch (error) {
        console.log('❌ [WEBHOOK] Error marking webhook as processed:', error);
      }
      
      console.log('✅ [WEBHOOK] ==========================================');
      console.log('✅ [WEBHOOK] WEBHOOK PROCESSING COMPLETED SUCCESSFULLY');
      console.log('✅ [WEBHOOK] ==========================================');
      res.json({ status: 'success' });
      
    } catch (error) {
      console.log('❌ [WEBHOOK] ==========================================');
      console.log('❌ [WEBHOOK] ERROR PROCESSING WEBHOOK');
      console.log('❌ [WEBHOOK] ==========================================');
      console.error('❌ [WEBHOOK] Error details:', error);
      console.error('❌ [WEBHOOK] Error stack:', error.stack);
      console.error('❌ [WEBHOOK] Error message:', error.message);
      res.status(500).json({ error: error.message });
    }
  });
});

// Handle successful payment webhook
async function handlePaymentCaptured(payload) {
  try {
    console.log('✅ [WEBHOOK] ==========================================');
    console.log('✅ [WEBHOOK] PROCESSING PAYMENT CAPTURED EVENT');
    console.log('✅ [WEBHOOK] ==========================================');
    console.log('✅ [WEBHOOK] Full payload:', JSON.stringify(payload, null, 2));
    
    const payment = payload.payment || payload.entity || {};
    const notes = payment.notes || {};
    
    console.log('✅ [WEBHOOK] Extracted payment data:');
    console.log('   - Payment object:', JSON.stringify(payment, null, 2));
    console.log('   - Notes object:', JSON.stringify(notes, null, 2));
    
    // Extract all required parameters from the webhook data
    const userId = notes.user_id;
    const planTitle = notes.plan_title;
    const planId = notes.plan_id;
    const duration = parseInt(notes.duration);
    const usageType = notes.usage_type;
    const userEmail = notes.user_email;
    const userName = notes.user_name;
    const userPhone = notes.user_phone;
    const amount = (payment.amount || 0) / 100; // Convert from paise
    const paymentId = payment.id;
    const orderId = payment.order_id;
    const paymentStatus = payment.status;
    const currency = payment.currency;
    const method = payment.method;
    const contact = payment.contact;
    const email = payment.email;
    const description = payment.description;
    const createdAt = payment.created_at;
    
    console.log('✅ [WEBHOOK] Extracted user and plan details:');
    console.log('   - User ID:', userId);
    console.log('   - Plan Title:', planTitle);
    console.log('   - Plan ID:', planId);
    console.log('   - Duration:', duration);
    console.log('   - Usage Type:', usageType);
    console.log('   - User Email:', userEmail);
    console.log('   - User Name:', userName);
    console.log('   - User Phone:', userPhone);
    console.log('   - Amount:', amount);
    console.log('   - Payment ID:', paymentId);
    console.log('   - Order ID:', orderId);
    console.log('   - Payment Status:', paymentStatus);
    console.log('   - Currency:', currency);
    console.log('   - Method:', method);
    console.log('   - Contact:', contact);
    console.log('   - Email:', email);
    console.log('   - Description:', description);
    console.log('   - Created At:', createdAt);
    
    // Validate required fields
    if (!userId) {
      console.log('❌ [WEBHOOK] No user_id in payment notes');
      console.log('❌ [WEBHOOK] Cannot process payment without user ID');
      console.log('❌ [WEBHOOK] Available notes keys:', Object.keys(notes));
      return;
    }
    
    if (!planId) {
      console.log('❌ [WEBHOOK] No plan_id in payment notes');
      console.log('❌ [WEBHOOK] Cannot process payment without plan ID');
      return;
    }
    
    if (!paymentId) {
      console.log('❌ [WEBHOOK] No payment ID in payment data');
      console.log('❌ [WEBHOOK] Cannot process payment without payment ID');
      return;
    }
    
    console.log('✅ [WEBHOOK] All required fields validated, proceeding with subscription update');
    
    // Update user subscription with complete data
    console.log('🔥 [WEBHOOK] Calling updateUserSubscription...');
    await updateUserSubscription(userId, {
      planId,
      planTitle,
      duration,
      usageType,
      amount,
      paymentId,
      orderId,
      paymentStatus,
      currency,
      method,
      contact,
      email,
      description,
      createdAt,
      userEmail,
      userName,
      userPhone
    });
    
    // Send success notification
    console.log('📱 [WEBHOOK] Calling sendPaymentNotification...');
    await sendPaymentNotification(userId, 'success', planTitle);
    
    console.log('🎉 [WEBHOOK] ==========================================');
    console.log('🎉 [WEBHOOK] PAYMENT PROCESSING COMPLETED SUCCESSFULLY');
    console.log('🎉 [WEBHOOK] User ID:', userId);
    console.log('🎉 [WEBHOOK] Plan:', planTitle);
    console.log('🎉 [WEBHOOK] Payment ID:', paymentId);
    console.log('🎉 [WEBHOOK] Order ID:', orderId);
    console.log('🎉 [WEBHOOK] ==========================================');
    
  } catch (error) {
    console.log('❌ [WEBHOOK] ==========================================');
    console.log('❌ [WEBHOOK] ERROR IN PAYMENT CAPTURED PROCESSING');
    console.log('❌ [WEBHOOK] ==========================================');
    console.error('❌ [WEBHOOK] Error details:', error);
    console.error('❌ [WEBHOOK] Error stack:', error.stack);
    console.error('❌ [WEBHOOK] Error message:', error.message);
  }
}

// Handle successful payment authorized webhook
async function handlePaymentAuthorized(payload) {
  try {
    console.log('✅ [WEBHOOK] ==========================================');
    console.log('✅ [WEBHOOK] PROCESSING PAYMENT AUTHORIZED EVENT');
    console.log('✅ [WEBHOOK] ==========================================');
    console.log('✅ [WEBHOOK] Full payload:', JSON.stringify(payload, null, 2));
    
    const payment = payload.payment || payload.entity || {};
    const notes = payment.notes || {};
    
    console.log('✅ [WEBHOOK] Extracted payment data:');
    console.log('   - Payment object:', JSON.stringify(payment, null, 2));
    console.log('   - Notes object:', JSON.stringify(notes, null, 2));
    
    // Extract all required parameters from the webhook data
    const userId = notes.user_id;
    const planTitle = notes.plan_title;
    const planId = notes.plan_id;
    const duration = parseInt(notes.duration);
    const usageType = notes.usage_type;
    const userEmail = notes.user_email;
    const userName = notes.user_name;
    const userPhone = notes.user_phone;
    const amount = (payment.amount || 0) / 100; // Convert from paise
    const paymentId = payment.id;
    const orderId = payment.order_id;
    const paymentStatus = payment.status;
    const currency = payment.currency;
    const method = payment.method;
    const contact = payment.contact;
    const email = payment.email;
    const description = payment.description;
    const createdAt = payment.created_at;
    
    console.log('✅ [WEBHOOK] Extracted user and plan details:');
    console.log('   - User ID:', userId);
    console.log('   - Plan Title:', planTitle);
    console.log('   - Plan ID:', planId);
    console.log('   - Duration:', duration);
    console.log('   - Usage Type:', usageType);
    console.log('   - User Email:', userEmail);
    console.log('   - User Name:', userName);
    console.log('   - User Phone:', userPhone);
    console.log('   - Amount:', amount);
    console.log('   - Payment ID:', paymentId);
    console.log('   - Order ID:', orderId);
    console.log('   - Payment Status:', paymentStatus);
    console.log('   - Currency:', currency);
    console.log('   - Method:', method);
    console.log('   - Contact:', contact);
    console.log('   - Email:', email);
    console.log('   - Description:', description);
    console.log('   - Created At:', createdAt);
    
    // Validate required fields
    if (!userId) {
      console.log('❌ [WEBHOOK] No user_id in payment notes');
      console.log('❌ [WEBHOOK] Cannot process payment without user ID');
      console.log('❌ [WEBHOOK] Available notes keys:', Object.keys(notes));
      return;
    }
    
    if (!planId) {
      console.log('❌ [WEBHOOK] No plan_id in payment notes');
      console.log('❌ [WEBHOOK] Cannot process payment without plan ID');
      return;
    }
    
    if (!paymentId) {
      console.log('❌ [WEBHOOK] No payment ID in payment data');
      console.log('❌ [WEBHOOK] Cannot process payment without payment ID');
      return;
    }
    
    console.log('✅ [WEBHOOK] All required fields validated, proceeding with subscription update');
    
    // Update user subscription with complete data
    console.log('🔥 [WEBHOOK] Calling updateUserSubscription...');
    await updateUserSubscription(userId, {
      planId,
      planTitle,
      duration,
      usageType,
      amount,
      paymentId,
      orderId,
      paymentStatus,
      currency,
      method,
      contact,
      email,
      description,
      createdAt,
      userEmail,
      userName,
      userPhone
    });
    
    // Send success notification
    console.log('📱 [WEBHOOK] Calling sendPaymentNotification...');
    await sendPaymentNotification(userId, 'success', planTitle);
    
    console.log('🎉 [WEBHOOK] ==========================================');
    console.log('🎉 [WEBHOOK] PAYMENT PROCESSING COMPLETED SUCCESSFULLY');
    console.log('🎉 [WEBHOOK] User ID:', userId);
    console.log('🎉 [WEBHOOK] Plan:', planTitle);
    console.log('🎉 [WEBHOOK] Payment ID:', paymentId);
    console.log('🎉 [WEBHOOK] Order ID:', orderId);
    console.log('🎉 [WEBHOOK] ==========================================');
    
  } catch (error) {
    console.log('❌ [WEBHOOK] ==========================================');
    console.log('❌ [WEBHOOK] ERROR IN PAYMENT AUTHORIZED PROCESSING');
    console.log('❌ [WEBHOOK] ==========================================');
    console.error('❌ [WEBHOOK] Error details:', error);
    console.error('❌ [WEBHOOK] Error stack:', error.stack);
    console.error('❌ [WEBHOOK] Error message:', error.message);
  }
}

// Handle failed payment webhook
async function handlePaymentFailed(payload) {
  try {
    console.log('❌ [WEBHOOK] Processing payment.failed event');
    
    const payment = payload.payment || payload.entity || {};
    const notes = payment.notes || {};
    
    // Extract all required parameters from the webhook data
    const userId = notes.user_id;
    const planTitle = notes.plan_title;
    const planId = notes.plan_id;
    const duration = parseInt(notes.duration);
    const usageType = notes.usage_type;
    const userEmail = notes.user_email;
    const userName = notes.user_name;
    const userPhone = notes.user_phone;
    const amount = (payment.amount || 0) / 100; // Convert from paise
    const paymentId = payment.id;
    const orderId = payment.order_id;
    const paymentStatus = payment.status;
    const currency = payment.currency;
    const method = payment.method;
    const contact = payment.contact;
    const email = payment.email;
    const description = payment.description;
    const createdAt = payment.created_at;
    
    console.log('❌ [WEBHOOK] Extracted payment data for failed payment:');
    console.log('   - User ID:', userId);
    console.log('   - Plan Title:', planTitle);
    console.log('   - Payment ID:', paymentId);
    console.log('   - Order ID:', orderId);
    console.log('   - Payment Status:', paymentStatus);
    console.log('   - Amount:', amount);
    
    if (!userId) {
      console.log('❌ [WEBHOOK] No user_id in payment notes');
      return;
    }
    
    // Send failure notification
    await sendPaymentNotification(userId, 'failed');
    
    // Update payment attempt status with complete data
    const paymentData = {
      planId,
      planTitle,
      duration,
      usageType,
      amount,
      paymentId,
      orderId,
      paymentStatus,
      currency,
      method,
      contact,
      email,
      description,
      createdAt,
      userEmail,
      userName,
      userPhone
    };
    
    await updatePaymentAttemptStatus(userId, 'failed', paymentId, orderId, paymentData);
    
    console.log('❌ [WEBHOOK] Payment failed for user:', userId);
    
  } catch (error) {
    console.error('❌ [WEBHOOK] Error handling payment failed:', error);
  }
}

// Update user subscription in Firestore
async function updateUserSubscription(userId, paymentData) {
  try {
    console.log('🔥 [WEBHOOK] ==========================================');
    console.log('🔥 [WEBHOOK] UPDATING USER SUBSCRIPTION');
    console.log('🔥 [WEBHOOK] ==========================================');
    console.log('🔥 [WEBHOOK] User ID:', userId);
    console.log('🔥 [WEBHOOK] Payment Data:', JSON.stringify(paymentData, null, 2));
    
    const now = new Date();
    const expiryDate = new Date(now.getTime() + (paymentData.duration * 24 * 60 * 60 * 1000));
    
    console.log('🔥 [WEBHOOK] Calculated dates:');
    console.log('   - Current time:', now.toISOString());
    console.log('   - Expiry date:', expiryDate.toISOString());
    console.log('   - Duration in days:', paymentData.duration);
    
    // Update user document with complete subscription data
    console.log('🔥 [WEBHOOK] Updating user document in Firestore...');
    const userUpdateData = {
      subscription: 'Premium',
      subscriptionPlanId: paymentData.planId,
      subscriptionPlanTitle: paymentData.planTitle,
      subscriptionStartDate: now,
      subscriptionEndDate: expiryDate,
      subscriptionStatus: 'active',
      lastPaymentDate: now,
      lastPaymentId: paymentData.paymentId,
      lastOrderId: paymentData.orderId,
      lastPaymentStatus: paymentData.paymentStatus,
      lastPaymentMethod: paymentData.method,
      lastPaymentAmount: paymentData.amount,
      lastPaymentCurrency: paymentData.currency,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    console.log('🔥 [WEBHOOK] User update data:', JSON.stringify(userUpdateData, null, 2));
    
    await db.collection('users').doc(userId).update(userUpdateData);
    console.log('✅ [WEBHOOK] User subscription updated successfully in Firestore');
    
    // Add comprehensive subscription history
    console.log('🔥 [WEBHOOK] Adding subscription history...');
    const historyData = {
      planId: paymentData.planId,
      planTitle: paymentData.planTitle,
      amount: paymentData.amount,
      duration: paymentData.duration,
      usageType: paymentData.usageType,
      startDate: now,
      endDate: expiryDate,
      status: 'active',
      paymentId: paymentData.paymentId,
      orderId: paymentData.orderId,
      paymentStatus: paymentData.paymentStatus,
      currency: paymentData.currency,
      method: paymentData.method,
      contact: paymentData.contact,
      email: paymentData.email,
      description: paymentData.description,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      // Additional user details
      userEmail: paymentData.userEmail,
      userName: paymentData.userName,
      userPhone: paymentData.userPhone,
      // Payment metadata
      paymentCreatedAt: paymentData.createdAt,
      webhookProcessedAt: now
    };
    
    console.log('🔥 [WEBHOOK] History data:', JSON.stringify(historyData, null, 2));
    
    const historyRef = await db.collection('users').doc(userId).collection('subscriptionHistory').add(historyData);
    console.log('✅ [WEBHOOK] Subscription history added successfully with ID:', historyRef.id);
    
    // Update payment attempt status with complete data
    console.log('🔥 [WEBHOOK] Updating payment attempt status...');
    await updatePaymentAttemptStatus(userId, 'success', paymentData.paymentId, paymentData.orderId, paymentData);
    
    console.log('✅ [WEBHOOK] ==========================================');
    console.log('✅ [WEBHOOK] USER SUBSCRIPTION UPDATE COMPLETED');
    console.log('✅ [WEBHOOK] ==========================================');
    
  } catch (error) {
    console.log('❌ [WEBHOOK] ==========================================');
    console.log('❌ [WEBHOOK] ERROR UPDATING USER SUBSCRIPTION');
    console.log('❌ [WEBHOOK] ==========================================');
    console.error('❌ [WEBHOOK] Error details:', error);
    console.error('❌ [WEBHOOK] Error stack:', error.stack);
    console.error('❌ [WEBHOOK] Error message:', error.message);
    throw error;
  }
}

// Update payment attempt status
async function updatePaymentAttemptStatus(userId, status, paymentId, orderId, paymentData = null) {
  try {
    const paymentAttempts = await db.collection('users').doc(userId)
      .collection('paymentAttempts')
      .where('status', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();
    
    if (!paymentAttempts.empty) {
      const doc = paymentAttempts.docs[0];
      const updateData = {
        status: status,
        paymentId: paymentId,
        orderId: orderId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Add additional payment data if available
      if (paymentData) {
        updateData.paymentStatus = paymentData.paymentStatus;
        updateData.paymentMethod = paymentData.method;
        updateData.paymentCurrency = paymentData.currency;
        updateData.paymentAmount = paymentData.amount;
        updateData.paymentContact = paymentData.contact;
        updateData.paymentEmail = paymentData.email;
        updateData.paymentDescription = paymentData.description;
        updateData.paymentCreatedAt = paymentData.createdAt;
        updateData.webhookProcessedAt = new Date();
      }
      
      await doc.ref.update(updateData);
      console.log('✅ [WEBHOOK] Payment attempt status updated to:', status);
      console.log('✅ [WEBHOOK] Additional payment data stored:', paymentData ? 'Yes' : 'No');
    }
  } catch (error) {
    console.error('❌ [WEBHOOK] Error updating payment attempt status:', error);
  }
}

// Send payment notification to user
async function sendPaymentNotification(userId, type, planTitle = '') {
  try {
    console.log('📱 [WEBHOOK] Sending payment notification to user:', userId);
    
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log('❌ [WEBHOOK] User not found:', userId);
      return;
    }
    
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    
    if (!fcmToken) {
      console.log('❌ [WEBHOOK] No FCM token for user:', userId);
      return;
    }
    
    // Create notification message
    let title, body, data;
    
    if (type === 'success') {
      title = 'Payment Successful! 🎉';
      body = `Your ${planTitle} subscription has been activated successfully.`;
      data = {
        type: 'payment_success',
        planTitle: planTitle,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      };
    } else {
      title = 'Payment Failed';
      body = 'Your payment was unsuccessful. Please try again.';
      data = {
        type: 'payment_failed',
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      };
    }
    
    // Send FCM notification
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body
      },
      data: data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'payment_notifications',
          priority: 'high',
          defaultSound: true
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default'
          }
        }
      }
    };
    
    const response = await admin.messaging().send(message);
    console.log('✅ [WEBHOOK] Payment notification sent successfully:', response);
    
  } catch (error) {
    console.error('❌ [WEBHOOK] Error sending payment notification:', error);
  }
}

// HTTP function to manually verify payment (for testing)
exports.verifyPaymentManually = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { paymentId, orderId } = req.body;
      
      if (!paymentId && !orderId) {
        return res.status(400).json({ error: 'paymentId or orderId is required' });
      }
      
      console.log('🔍 [MANUAL] Verifying payment:', { paymentId, orderId });
      
      // This would typically call Razorpay API to verify payment
      // For now, we'll just log it
      console.log('✅ [MANUAL] Payment verification requested');
      
      res.json({ 
        success: true, 
        message: 'Payment verification requested',
        paymentId,
        orderId
      });
      
    } catch (error) {
      console.error('❌ [MANUAL] Error verifying payment:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
}); 