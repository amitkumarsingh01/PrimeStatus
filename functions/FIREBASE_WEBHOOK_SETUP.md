# Firebase Functions Webhook Setup Guide

This guide explains how to set up the Razorpay webhook using Firebase Functions instead of a separate server.

## 🚀 Quick Setup

### 1. Configure Webhook Secret
```bash
cd functions
chmod +x setup-webhook.sh
./setup-webhook.sh YOUR_RAZORPAY_WEBHOOK_SECRET
```

### 2. Deploy Functions
```bash
firebase deploy --only functions
```

### 3. Update Payment Service
Replace the webhook URL in `payment_service.dart` with your actual Firebase Functions URL.

## 🔧 Detailed Setup Steps

### Step 1: Get Your Project ID
```bash
firebase projects:list
```
Note your project ID (e.g., `my-app-12345`)

### Step 2: Configure Webhook Secret
```bash
cd functions
./setup-webhook.sh YOUR_WEBHOOK_SECRET
```

### Step 3: Deploy Functions
```bash
firebase deploy --only functions
```

### Step 4: Update Payment Service URL
In `Copy/primestatus/lib/services/payment_service.dart`, replace:
```dart
'callback_url': 'https://us-central1-your-project-id.cloudfunctions.net/razorpayWebhook',
```
With your actual project ID:
```dart
'callback_url': 'https://us-central1-my-app-12345.cloudfunctions.net/razorpayWebhook',
```

### Step 5: Configure Razorpay Webhook
1. Go to Razorpay Dashboard → Settings → Webhooks
2. Add webhook URL: `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/razorpayWebhook`
3. Select events:
   - `payment.captured`
   - `payment.failed`
4. Save the webhook

## 📱 How It Works

### Payment Flow:
1. **User initiates payment** → App creates payment link with Firebase Functions webhook URL
2. **Payment opens in browser** → User completes payment
3. **Razorpay sends webhook** → Firebase Functions receives notification
4. **Functions update Firebase** → User subscription activated
5. **User gets FCM notification** → Payment success confirmed

### Benefits:
- ✅ **Integrated with Firebase** - No separate server needed
- ✅ **Automatic scaling** - Firebase handles traffic
- ✅ **Built-in security** - Firebase security rules
- ✅ **Easy monitoring** - Firebase console logs
- ✅ **Cost effective** - Pay only for usage

## 🔍 Testing

### Test Webhook Locally:
```bash
# Start Firebase emulator
firebase emulators:start --only functions

# Test webhook endpoint
curl -X POST http://localhost:5001/YOUR_PROJECT_ID/us-central1/razorpayWebhook \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Signature: test_signature" \
  -d '{"test": "data"}'
```

### Test Production Webhook:
```bash
curl -X POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/razorpayWebhook \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Signature: test_signature" \
  -d '{"test": "data"}'
```

## 📊 Monitoring

### Firebase Console:
1. Go to Firebase Console → Functions
2. Click on `razorpayWebhook` function
3. View logs and execution details

### Check Webhooks in Firestore:
- Collection: `webhooks`
- Documents: All received webhooks with processing status

### Check User Subscriptions:
- Collection: `users`
- Field: `subscriptionStatus` (should be 'active' after payment)

## 🛠️ Troubleshooting

### Common Issues:

1. **Webhook not received**
   - Check Firebase Functions logs
   - Verify webhook URL is correct
   - Ensure webhook secret is set

2. **Signature verification failed**
   - Check webhook secret configuration
   - Verify Razorpay webhook secret matches

3. **User subscription not updated**
   - Check Firestore rules
   - Verify user document exists
   - Check function logs for errors

4. **FCM notification not sent**
   - Check user has FCM token
   - Verify notification permissions
   - Check Firebase Messaging setup

### Debug Commands:
```bash
# Check function logs
firebase functions:log --only razorpayWebhook

# Check configuration
firebase functions:config:get

# Test function locally
firebase emulators:start --only functions
```

## 🔒 Security

### Webhook Verification:
- ✅ HMAC SHA256 signature verification
- ✅ Environment variable for webhook secret
- ✅ HTTPS required for production

### Firebase Security:
- ✅ Firestore security rules
- ✅ Function authentication
- ✅ CORS protection

## 📈 Production Checklist

- [ ] Deploy Firebase Functions
- [ ] Configure webhook secret
- [ ] Update payment service URL
- [ ] Configure Razorpay webhook
- [ ] Test payment flow
- [ ] Monitor function logs
- [ ] Set up error alerts
- [ ] Test with real payments

## 🎯 Functions Added

### New Functions:
1. **`razorpayWebhook`** - Main webhook handler
2. **`verifyPaymentManually`** - Manual payment verification (testing)

### Helper Functions:
- `verifyWebhookSignature()` - Verify Razorpay signature
- `handlePaymentCaptured()` - Process successful payments
- `handlePaymentFailed()` - Process failed payments
- `updateUserSubscription()` - Update user subscription
- `sendPaymentNotification()` - Send FCM notifications

## 📝 Environment Variables

### Required:
- `razorpay.webhook_secret` - Your Razorpay webhook secret

### Set via Firebase CLI:
```bash
firebase functions:config:set razorpay.webhook_secret="your_secret_here"
```

## 🎉 Benefits Over Separate Server

1. **No server management** - Firebase handles everything
2. **Automatic scaling** - Handles any traffic load
3. **Integrated monitoring** - Firebase console logs
4. **Cost effective** - Pay only for usage
5. **Easy deployment** - One command deployment
6. **Built-in security** - Firebase security features

The Firebase Functions approach is much more integrated and easier to manage! 🚀 