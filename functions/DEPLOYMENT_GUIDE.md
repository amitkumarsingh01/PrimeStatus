# Firebase Functions Deployment Guide

## Prerequisites
- Firebase CLI installed
- Firebase project set up
- Razorpay account with live keys

## Deployment Steps

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Deploy Functions
```bash
firebase deploy --only functions
```

### 3. Get Your Functions URL
After deployment, you'll get URLs like:
- `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/initiatePayment`
- `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/checkPaymentStatus`
- `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/updateUserSubscription`

### 4. Update Payment Service
In `Copy/primestatus/lib/services/payment_service.dart`, replace:
```dart
static const String _firebaseFunctionsUrl = 'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net';
```
With your actual project ID.

## Available Functions

### 1. initiatePayment
- **Method**: POST
- **Purpose**: Creates Razorpay payment link
- **Input**: userId, planId, planTitle, amount, duration, usageType, userName, userEmail, userPhone
- **Output**: payment_url, payment_id

### 2. checkPaymentStatus
- **Method**: POST
- **Purpose**: Checks payment status from Razorpay
- **Input**: paymentId
- **Output**: status (paid, created, cancelled, failed)

### 3. updateUserSubscription
- **Method**: POST
- **Purpose**: Updates user subscription in Firestore
- **Input**: userId, planId, planTitle, amount, duration, usageType
- **Output**: success status

## Testing

### Test Payment Flow
1. Call `initiatePayment` with test data
2. Open the returned payment URL
3. Complete test payment
4. Check status via `checkPaymentStatus`
5. Verify subscription update in Firestore

### Test Commands
```bash
# Test initiatePayment
curl -X POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/initiatePayment \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test_user_id",
    "planId": "test_plan",
    "planTitle": "Test Plan",
    "amount": 100,
    "duration": 30,
    "usageType": "Personal",
    "userName": "Test User",
    "userEmail": "test@example.com",
    "userPhone": "1234567890"
  }'

# Test checkPaymentStatus
curl -X POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/checkPaymentStatus \
  -H "Content-Type: application/json" \
  -d '{"paymentId": "plink_test_123"}'
```

## Monitoring

### Firebase Console
- Go to Firebase Console → Functions
- View logs and execution details
- Monitor function performance

### Firestore Collections
- `users/{userId}/paymentAttempts` - Payment attempts
- `users/{userId}/subscriptionHistory` - Subscription history
- `users/{userId}` - User subscription status

## Troubleshooting

### Common Issues
1. **CORS errors**: Functions include CORS headers
2. **Authentication errors**: Check Razorpay credentials
3. **Firestore errors**: Check security rules
4. **Payment link errors**: Verify Razorpay account status

### Debug Commands
```bash
# View function logs
firebase functions:log

# Test locally
firebase emulators:start --only functions
```

## Security Notes
- Razorpay credentials are hardcoded (for demo purposes)
- In production, use environment variables
- Implement proper authentication for functions
- Add rate limiting for production use 