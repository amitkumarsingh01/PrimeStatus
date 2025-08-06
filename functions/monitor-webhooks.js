const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function monitorWebhooks() {
  console.log('🔍 [MONITOR] Checking webhook activity...');
  
  try {
    // Check recent webhooks in Firestore
    const webhooksSnapshot = await db.collection('webhooks')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    
    console.log(`📊 [MONITOR] Found ${webhooksSnapshot.size} webhook entries`);
    
    if (webhooksSnapshot.empty) {
      console.log('❌ [MONITOR] No webhooks found in Firestore');
      console.log('💡 [MONITOR] This means Razorpay is not sending webhooks');
      console.log('💡 [MONITOR] Check your Razorpay Dashboard webhook configuration');
    } else {
      console.log('✅ [MONITOR] Recent webhooks:');
      webhooksSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`   - ID: ${doc.id}`);
        console.log(`   - Event: ${data.event || 'unknown'}`);
        console.log(`   - Processed: ${data.processed || false}`);
        console.log(`   - Timestamp: ${data.timestamp?.toDate() || 'N/A'}`);
        console.log('   ---');
      });
    }
    
    // Check recent payment attempts
    const usersSnapshot = await db.collection('users').limit(5).get();
    console.log(`👥 [MONITOR] Checking recent users for payment attempts...`);
    
    for (const userDoc of usersSnapshot.docs) {
      const paymentAttemptsSnapshot = await userDoc.ref
        .collection('paymentAttempts')
        .orderBy('createdAt', 'desc')
        .limit(3)
        .get();
      
      if (!paymentAttemptsSnapshot.empty) {
        console.log(`💰 [MONITOR] User ${userDoc.id} has ${paymentAttemptsSnapshot.size} payment attempts`);
        paymentAttemptsSnapshot.forEach(doc => {
          const data = doc.data();
          console.log(`   - Status: ${data.status}`);
          console.log(`   - Plan: ${data.planTitle}`);
          console.log(`   - Amount: ₹${data.amount}`);
          console.log(`   - Created: ${data.createdAt?.toDate() || 'N/A'}`);
        });
      }
    }
    
  } catch (error) {
    console.error('❌ [MONITOR] Error monitoring webhooks:', error);
  }
}

// Run monitoring
monitorWebhooks(); 