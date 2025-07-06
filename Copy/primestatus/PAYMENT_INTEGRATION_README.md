# Razorpay Payment Integration Guide

This guide explains how to set up and use the Razorpay payment gateway integration in your Prime Status app.

## Features

- ✅ Payment gateway opens in external browser (no WebView)
- ✅ User-specific subscription plans based on usage type
- ✅ Payment tracking in Firestore
- ✅ Automatic subscription management
- ✅ Payment verification and webhook support

## Setup Instructions

### 1. Razorpay Account Setup

1. **Create Razorpay Account**
   - Go to [Razorpay Dashboard](https://dashboard.razorpay.com/)
   - Sign up for a new account
   - Complete KYC verification

2. **Get API Keys**
   - Go to Settings → API Keys
   - Copy your `Key ID` and `Key Secret`
   - For testing, use test keys (starts with `rzp_test_`)
   - For production, use live keys (starts with `rzp_live_`)

3. **Configure Webhooks** (Optional but recommended)
   - Go to Settings → Webhooks
   - Add webhook URL: `https://your-backend.com/api/payments/webhook`
   - Select events: `payment.captured`, `payment.failed`
   - Copy the webhook secret

### 2. Backend Setup

1. **Install Dependencies**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Environment Variables**
   Create a `.env` file in the backend directory:
   ```env
   RAZORPAY_KEY_ID=rzp_test_YOUR_KEY_ID
   RAZORPAY_KEY_SECRET=YOUR_KEY_SECRET
   WEBHOOK_SECRET=YOUR_WEBHOOK_SECRET
   ```

3. **Update Configuration**
   - Open `payment_api.py`
   - Replace `YOUR_WEBHOOK_SECRET` with your actual webhook secret
   - Update callback and cancel URLs to your app's URLs

4. **Run Backend**
   ```bash
   python payment_api.py
   ```

### 3. Mobile App Setup

1. **Update Payment Service**
   - Open `lib/services/payment_service.dart`
   - Replace placeholder values:
     ```dart
     static const String _razorpayKeyId = 'rzp_test_YOUR_KEY_ID';
     static const String _razorpayKeySecret = 'YOUR_KEY_SECRET';
     static const String _webhookSecret = 'YOUR_WEBHOOK_SECRET';
     static const String _backendUrl = 'https://your-backend.com/api/payments/create-order';
     ```

2. **Update Backend URL**
   - Replace `https://your-backend.com` with your actual backend URL
   - Make sure the backend is accessible from the mobile app

## How It Works

### 1. User Flow
1. User selects a subscription plan
2. App calls backend API to create Razorpay order
3. Backend creates order and payment link
4. App opens payment link in external browser
5. User completes payment in browser
6. Razorpay sends webhook to backend
7. Backend updates payment status in Firestore
8. App shows updated subscription status

### 2. Payment Processing
```dart
// When user taps "Select Plan"
await PaymentService.initiatePayment(
  planId: plan.id,
  planTitle: plan.title,
  amount: plan.price,
  duration: plan.duration,
  userUsageType: widget.userUsageType,
  userName: widget.userName,
  userEmail: widget.userEmail,
  userPhone: widget.userPhone,
);
```

### 3. Data Flow
1. **Order Creation**: App → Backend → Razorpay
2. **Payment Link**: Razorpay → Backend → App
3. **Browser Redirect**: App → External Browser
4. **Payment Processing**: Browser → Razorpay
5. **Webhook**: Razorpay → Backend
6. **Status Update**: Backend → Firestore

## Database Schema

### Payment Attempts Collection
```javascript
users/{userId}/paymentAttempts/{attemptId}
{
  planId: "string",
  planTitle: "string",
  amount: number,
  duration: number,
  usageType: "Personal|Business",
  paymentUrl: "string",
  status: "pending|success|failed",
  paymentId: "string",
  paymentDetails: {},
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### User Subscription
```javascript
users/{userId}
{
  subscription: "Free|Premium",
  subscriptionPlanId: "string",
  subscriptionPlanTitle: "string",
  subscriptionStartDate: timestamp,
  subscriptionEndDate: timestamp,
  subscriptionStatus: "active|inactive",
  lastPaymentDate: timestamp
}
```

### Subscription History
```javascript
users/{userId}/subscriptionHistory/{historyId}
{
  planId: "string",
  planTitle: "string",
  amount: number,
  duration: number,
  usageType: "Personal|Business",
  startDate: timestamp,
  endDate: timestamp,
  status: "active|expired",
  createdAt: timestamp
}
```

## Testing

### 1. Test Cards
Use these test cards for testing:
- **Success**: 4111 1111 1111 1111
- **Failure**: 4000 0000 0000 0002
- **CVV**: Any 3 digits
- **Expiry**: Any future date

### 2. Test UPI
- **Success**: success@razorpay
- **Failure**: failure@razorpay

### 3. Test Net Banking
- **Success**: HDFC Bank
- **Failure**: ICICI Bank

## Production Checklist

- [ ] Switch to live Razorpay keys
- [ ] Set up proper webhook URLs
- [ ] Configure SSL certificates
- [ ] Set up monitoring and logging
- [ ] Test payment flows thoroughly
- [ ] Set up error handling and retry logic
- [ ] Configure backup payment methods
- [ ] Set up customer support for payment issues

## Security Considerations

1. **Never expose API secrets in client code**
2. **Always verify payment signatures**
3. **Use HTTPS for all API calls**
4. **Implement proper error handling**
5. **Log payment events for audit**
6. **Set up fraud detection**
7. **Regular security audits**

## Troubleshooting

### Common Issues

1. **Payment Link Not Opening**
   - Check internet connectivity
   - Verify URL launcher permissions
   - Ensure backend is accessible

2. **Payment Not Processing**
   - Check Razorpay dashboard for errors
   - Verify API keys are correct
   - Check webhook configuration

3. **Subscription Not Updating**
   - Check Firestore permissions
   - Verify webhook is working
   - Check payment verification logic

### Debug Steps

1. **Enable Debug Logging**
   ```dart
   // Add to payment_service.dart
   print('Payment initiation: $orderData');
   ```

2. **Check Backend Logs**
   ```bash
   # Monitor backend logs
   tail -f backend.log
   ```

3. **Verify Webhook Delivery**
   - Check Razorpay dashboard → Webhooks
   - Look for delivery status and response codes

## Support

For issues related to:
- **Razorpay**: Contact Razorpay support
- **Backend**: Check Flask logs and error messages
- **Mobile App**: Check Flutter debug console
- **Firebase**: Check Firestore rules and permissions

## Additional Resources

- [Razorpay Documentation](https://razorpay.com/docs/)
- [Flutter URL Launcher](https://pub.dev/packages/url_launcher)
- [Firebase Firestore](https://firebase.google.com/docs/firestore)
- [Flask Documentation](https://flask.palletsprojects.com/) 