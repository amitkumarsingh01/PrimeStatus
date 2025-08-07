# Payment API Documentation

## Overview
This document shows the exact parameters being sent from the Flutter app to Firebase Functions and the responses received.

## Firebase Functions Base URL
```
https://us-central1-prime-status-1db09.cloudfunctions.net
```

---

## 1. Initiate Payment API

### Endpoint
```
POST /initiatePayment
```

### Request Parameters (Flutter → Firebase Function)
```json
{
  "userId": "htu0gJF57SW98PHbsvLb8zpL5fn2",
  "planId": "premium_monthly_001",
  "planTitle": "Premium Monthly Plan",
  "amount": 99.0,
  "duration": 30,
  "usageType": "Personal",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "userPhone": "9876543210"
}
```

### Response (Firebase Function → Flutter)
```json
{
  "success": true,
  "payment_url": "https://rzp.io/i/abc123def456",
  "payment_id": "plink_abc123def456"
}
```

### Error Response
```json
{
  "success": false,
  "error": "Payment link creation failed: Invalid amount"
}
```

---

## 2. Check Payment Status API

### Endpoint
```
POST /checkPaymentStatus
```

### Request Parameters (Flutter → Firebase Function)
```json
{
  "paymentId": "plink_abc123def456"
}
```

### Response (Firebase Function → Flutter)
```json
{
  "success": true,
  "status": "paid"
}
```

### Possible Status Values
- `"paid"` - Payment completed successfully
- `"created"` - Payment link created but not paid
- `"cancelled"` - Payment was cancelled by user
- `"failed"` - Payment failed

### Error Response
```json
{
  "success": false,
  "error": "Payment not found"
}
```

---

## 3. Update User Subscription API

### Endpoint
```
POST /updateUserSubscription
```

### Request Parameters (Flutter → Firebase Function)
```json
{
  "userId": "htu0gJF57SW98PHbsvLb8zpL5fn2",
  "planId": "premium_monthly_001",
  "planTitle": "Premium Monthly Plan",
  "amount": 99.0,
  "duration": 30,
  "usageType": "Personal"
}
```

### Response (Firebase Function → Flutter)
```json
{
  "success": true
}
```

### Error Response
```json
{
  "success": false,
  "error": "Missing required fields"
}
```

---

## Complete Payment Flow Example

### Step 1: User clicks "Select Plan"
```dart
// Flutter app calls:
await PaymentService.initiatePayment(
  planId: 'premium_monthly_001',
  planTitle: 'Premium Monthly Plan',
  amount: 99.0,
  duration: 30,
  userUsageType: 'Personal',
  userName: 'John Doe',
  userEmail: 'john@example.com',
  userPhone: '9876543210',
);
```

### Step 2: Firebase Function creates Razorpay payment link
```javascript
// Firebase Function receives:
{
  "userId": "htu0gJF57SW98PHbsvLb8zpL5fn2",
  "planId": "premium_monthly_001",
  "planTitle": "Premium Monthly Plan",
  "amount": 99.0,
  "duration": 30,
  "usageType": "Personal",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "userPhone": "9876543210"
}

// Firebase Function responds:
{
  "success": true,
  "payment_url": "https://rzp.io/i/abc123def456",
  "payment_id": "plink_abc123def456"
}
```

### Step 3: App opens payment URL and starts polling
```dart
// Every 10 seconds, Flutter app calls:
await PaymentService.verifyPaymentManually('plink_abc123def456');
```

### Step 4: Check payment status
```javascript
// Firebase Function receives:
{
  "paymentId": "plink_abc123def456"
}

// Firebase Function responds:
{
  "success": true,
  "status": "paid"
}
```

### Step 5: Update subscription when paid
```javascript
// Firebase Function receives:
{
  "userId": "htu0gJF57SW98PHbsvLb8zpL5fn2",
  "planId": "premium_monthly_001",
  "planTitle": "Premium Monthly Plan",
  "amount": 99.0,
  "duration": 30,
  "usageType": "Personal"
}

// Firebase Function responds:
{
  "success": true
}
```

---

## Console Logs Example

When you run the payment flow, you'll see these logs in the Flutter console:

```
📤 [PAYMENT] Sending request to Firebase Function:
   URL: https://us-central1-prime-status-1db09.cloudfunctions.net/initiatePayment
   Method: POST
   Headers: {"Content-Type": "application/json"}
   Body: {"userId":"htu0gJF57SW98PHbsvLb8zpL5fn2","planId":"premium_monthly_001","planTitle":"Premium Monthly Plan","amount":99.0,"duration":30,"usageType":"Personal","userName":"John Doe","userEmail":"john@example.com","userPhone":"9876543210"}

📥 [PAYMENT] Received response from Firebase Function:
   Status Code: 200
   Response Body: {"success":true,"payment_url":"https://rzp.io/i/abc123def456","payment_id":"plink_abc123def456"}

📤 [PAYMENT] Checking payment status:
   URL: https://us-central1-prime-status-1db09.cloudfunctions.net/checkPaymentStatus
   Method: POST
   Body: {"paymentId":"plink_abc123def456"}

📥 [PAYMENT] Payment status response:
   Status Code: 200
   Response Body: {"success":true,"status":"paid"}

📤 [PAYMENT] Updating user subscription:
   URL: https://us-central1-prime-status-1db09.cloudfunctions.net/updateUserSubscription
   Method: POST
   Body: {"userId":"htu0gJF57SW98PHbsvLb8zpL5fn2","planId":"premium_monthly_001","planTitle":"Premium Monthly Plan","amount":99.0,"duration":30,"usageType":"Personal"}

📥 [PAYMENT] Subscription update response:
   Status Code: 200
   Response Body: {"success":true}
```

---

## Testing

Use the `PaymentTestScreen` to test all API calls:

```dart
// Navigate to test screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => PaymentTestScreen()),
);
```

This will show you real-time API calls and responses in the app. 