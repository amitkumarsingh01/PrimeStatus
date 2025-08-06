const https = require('https');
const crypto = require('crypto');

// Your Razorpay webhook secret
const WEBHOOK_SECRET = 'primestatus2025';

const testWebhook = () => {
  const payload = {
    event: 'payment.captured',
    payload: {
      payment: {
        id: 'pay_test_123456',
        amount: 100,
        currency: 'INR',
        notes: {
          user_id: 'htu0gJF57SW98PHbsvLb8zpL5fn2', // Real user ID from your logs
          plan_title: 'Test Plan',
          duration: 30,
          usage_type: 'Personal'
        }
      }
    }
  };

  const data = JSON.stringify(payload);

  // ✅ Generate signature as Razorpay expects
  const signature = crypto
    .createHmac('sha256', WEBHOOK_SECRET)
    .update(data)
    .digest('hex');

  const options = {
    hostname: 'us-central1-prime-status-1db09.cloudfunctions.net',
    port: 443,
    path: '/razorpayWebhook',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Razorpay-Signature': signature,
      'Content-Length': Buffer.byteLength(data)
    }
  };

  const req = https.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Headers: ${JSON.stringify(res.headers)}`);
    
    let responseData = '';
    res.on('data', (chunk) => {
      responseData += chunk;
    });
    
    res.on('end', () => {
      console.log('Response:', responseData);
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
  });

  req.write(data);
  req.end();
};

console.log('🧪 Testing webhook endpoint with real user ID...');
testWebhook();
