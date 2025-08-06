# Webhook Deployment Guide

This guide explains how to deploy the webhook server to handle Razorpay payment notifications.

## 🚀 Quick Deployment Options

### Option 1: Railway (Recommended - Free)
1. Go to [Railway.app](https://railway.app)
2. Connect your GitHub repository
3. Add environment variables:
   ```
   RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
   ```
4. Deploy automatically

### Option 2: Render (Free)
1. Go to [Render.com](https://render.com)
2. Create new Web Service
3. Connect your repository
4. Set build command: `pip install -r webhook_requirements.txt`
5. Set start command: `gunicorn webhook_server:app`
6. Add environment variables

### Option 3: Heroku (Paid)
1. Create Heroku app
2. Deploy using Heroku CLI
3. Set environment variables

## 🔧 Setup Steps

### 1. Configure Razorpay Webhook
1. Go to Razorpay Dashboard → Settings → Webhooks
2. Add webhook URL: `https://your-domain.com/api/payment/callback`
3. Select events:
   - `payment.captured`
   - `payment.failed`
4. Copy the webhook secret

### 2. Update Payment Service
Replace the webhook URL in `payment_service.dart`:
```dart
'callback_url': 'https://your-domain.com/api/payment/callback',
```

### 3. Environment Variables
Set these in your deployment platform:
```
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret_here
```

## 📱 How It Works

### Payment Flow with Webhooks:
1. **User initiates payment** → App creates payment link
2. **Payment opens in browser** → User completes payment
3. **Razorpay sends webhook** → Your server receives notification
4. **Server updates Firebase** → User subscription activated
5. **User gets notification** → Payment success confirmed

### Benefits:
- ✅ **Works when app is closed** - Webhooks are server-to-server
- ✅ **Real-time updates** - Instant payment confirmation
- ✅ **Reliable** - No polling needed
- ✅ **Push notifications** - User gets immediate feedback

## 🔍 Testing

### Test Webhook Locally:
```bash
# Install dependencies
pip install -r webhook_requirements.txt

# Run server
python webhook_server.py

# Test with ngrok
ngrok http 5000
```

### Test Webhook URL:
```
https://your-domain.com/health
```

## 📊 Monitoring

### Check Webhook Logs:
- Railway: Dashboard → Logs
- Render: Dashboard → Logs
- Heroku: `heroku logs --tail`

### Firebase Monitoring:
- Check `webhooks` collection for received webhooks
- Check `users` collection for updated subscriptions

## 🛠️ Troubleshooting

### Common Issues:

1. **Webhook not received**
   - Check webhook URL is accessible
   - Verify webhook secret is correct
   - Check server logs

2. **Firebase update failed**
   - Verify Firebase credentials
   - Check Firestore rules
   - Ensure user document exists

3. **Notification not sent**
   - Check user has FCM token
   - Verify Firebase Functions setup
   - Check notification permissions

### Debug Commands:
```bash
# Check webhook endpoint
curl -X POST https://your-domain.com/api/payment/callback \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Check health endpoint
curl https://your-domain.com/health
```

## 🔒 Security

### Webhook Verification:
- ✅ Signature verification enabled
- ✅ HTTPS required
- ✅ Environment variables for secrets

### Firebase Security:
- ✅ Service account authentication
- ✅ Firestore rules protection
- ✅ Secure API endpoints

## 📈 Production Checklist

- [ ] Deploy webhook server
- [ ] Configure Razorpay webhook URL
- [ ] Set environment variables
- [ ] Test payment flow
- [ ] Monitor webhook logs
- [ ] Set up error alerts
- [ ] Configure backup webhook URL
- [ ] Test with real payments

## 🎯 Next Steps

1. **Deploy webhook server** using one of the options above
2. **Update webhook URL** in your payment service
3. **Test payment flow** with test cards
4. **Monitor logs** for any issues
5. **Go live** with real payments

The webhook solution will solve the disconnection issue and provide reliable payment verification! 🎉 