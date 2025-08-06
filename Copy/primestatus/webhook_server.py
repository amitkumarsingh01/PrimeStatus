#!/usr/bin/env python3
"""
Razorpay Webhook Server
Receives payment webhooks from Razorpay and forwards them to Firebase
"""

import os
import json
import hmac
import hashlib
import requests
from flask import Flask, request, jsonify
from firebase_admin import initialize_app, firestore, credentials

# Initialize Flask app
app = Flask(__name__)

# Initialize Firebase
try:
    # Use service account key if available
    if os.path.exists('serviceAccountKey.json'):
        cred = credentials.Certificate('serviceAccountKey.json')
        firebase_app = initialize_app(cred)
    else:
        # Use default credentials (for production)
        firebase_app = initialize_app()
    
    db = firestore.client()
    print("✅ Firebase initialized successfully")
except Exception as e:
    print(f"❌ Firebase initialization failed: {e}")
    db = None

# Razorpay webhook secret (set this in environment variables)
WEBHOOK_SECRET = os.getenv('RAZORPAY_WEBHOOK_SECRET', 'your_webhook_secret_here')

def verify_webhook_signature(payload, signature):
    """Verify Razorpay webhook signature"""
    try:
        expected_signature = hmac.new(
            WEBHOOK_SECRET.encode('utf-8'),
            payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(expected_signature, signature)
    except Exception as e:
        print(f"❌ Webhook signature verification failed: {e}")
        return False

def send_to_firebase(webhook_data):
    """Send webhook data to Firebase"""
    try:
        if db is None:
            print("❌ Firebase not initialized")
            return False
        
        # Store webhook in Firestore
        webhook_ref = db.collection('webhooks').document()
        webhook_ref.set({
            'data': webhook_data,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'processed': False
        })
        
        print(f"✅ Webhook stored in Firebase: {webhook_ref.id}")
        return True
    except Exception as e:
        print(f"❌ Failed to send to Firebase: {e}")
        return False

def send_fcm_notification(user_id, title, body, data=None):
    """Send FCM notification to user"""
    try:
        # Get user's FCM token from Firestore
        user_doc = db.collection('users').document(user_id).get()
        if not user_doc.exists:
            print(f"❌ User {user_id} not found")
            return False
        
        user_data = user_doc.to_dict()
        fcm_token = user_data.get('fcmToken')
        
        if not fcm_token:
            print(f"❌ No FCM token for user {user_id}")
            return False
        
        # Send FCM notification (you'll need to implement this)
        # For now, just log it
        print(f"📱 FCM Notification to {user_id}:")
        print(f"   Title: {title}")
        print(f"   Body: {body}")
        print(f"   Data: {data}")
        
        return True
    except Exception as e:
        print(f"❌ FCM notification failed: {e}")
        return False

@app.route('/api/payment/callback', methods=['POST'])
def payment_webhook():
    """Handle Razorpay payment webhooks"""
    try:
        # Get webhook data
        webhook_data = request.get_json()
        signature = request.headers.get('X-Razorpay-Signature')
        
        if not webhook_data:
            print("❌ No webhook data received")
            return jsonify({'error': 'No data received'}), 400
        
        if not signature:
            print("❌ No signature received")
            return jsonify({'error': 'No signature'}), 400
        
        # Verify webhook signature
        payload = request.get_data(as_text=True)
        if not verify_webhook_signature(payload, signature):
            print("❌ Invalid webhook signature")
            return jsonify({'error': 'Invalid signature'}), 401
        
        print(f"🔔 [WEBHOOK] Received webhook: {json.dumps(webhook_data, indent=2)}")
        
        # Extract event details
        event = webhook_data.get('event')
        payload_data = webhook_data.get('payload', {})
        
        if event == 'payment.captured':
            await handle_payment_captured(payload_data)
        elif event == 'payment.failed':
            await handle_payment_failed(payload_data)
        else:
            print(f"ℹ️ Unhandled event: {event}")
        
        # Store webhook in Firebase
        send_to_firebase(webhook_data)
        
        return jsonify({'status': 'success'}), 200
        
    except Exception as e:
        print(f"❌ Webhook processing error: {e}")
        return jsonify({'error': str(e)}), 500

async def handle_payment_captured(payload):
    """Handle successful payment"""
    try:
        payment = payload.get('payment', payload.get('entity', {}))
        notes = payment.get('notes', {})
        
        user_id = notes.get('user_id')
        plan_title = notes.get('plan_title', 'Premium Plan')
        
        if user_id:
            print(f"✅ Payment successful for user: {user_id}")
            
            # Send success notification
            send_fcm_notification(
                user_id=user_id,
                title="Payment Successful! 🎉",
                body=f"Your {plan_title} subscription has been activated successfully.",
                data={
                    'type': 'payment_success',
                    'planTitle': plan_title
                }
            )
            
            # Update user subscription in Firestore
            update_user_subscription(user_id, payment, notes)
        else:
            print("❌ No user_id in payment notes")
            
    except Exception as e:
        print(f"❌ Error handling payment captured: {e}")

async def handle_payment_failed(payload):
    """Handle failed payment"""
    try:
        payment = payload.get('payment', payload.get('entity', {}))
        notes = payment.get('notes', {})
        
        user_id = notes.get('user_id')
        
        if user_id:
            print(f"❌ Payment failed for user: {user_id}")
            
            # Send failure notification
            send_fcm_notification(
                user_id=user_id,
                title="Payment Failed",
                body="Your payment was unsuccessful. Please try again.",
                data={'type': 'payment_failed'}
            )
        else:
            print("❌ No user_id in payment notes")
            
    except Exception as e:
        print(f"❌ Error handling payment failed: {e}")

def update_user_subscription(user_id, payment, notes):
    """Update user subscription in Firestore"""
    try:
        from datetime import datetime, timedelta
        
        plan_id = notes.get('plan_id', '')
        plan_title = notes.get('plan_title', 'Premium Plan')
        duration = int(notes.get('duration', 30))
        usage_type = notes.get('usage_type', 'Personal')
        amount = payment.get('amount', 0) / 100.0  # Convert from paise
        
        now = datetime.now()
        expiry_date = now + timedelta(days=duration)
        
        # Update user document
        user_ref = db.collection('users').document(user_id)
        user_ref.update({
            'subscription': 'Premium',
            'subscriptionPlanId': plan_id,
            'subscriptionPlanTitle': plan_title,
            'subscriptionStartDate': now,
            'subscriptionEndDate': expiry_date,
            'subscriptionStatus': 'active',
            'lastPaymentDate': now,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        })
        
        # Add subscription history
        user_ref.collection('subscriptionHistory').add({
            'planId': plan_id,
            'planTitle': plan_title,
            'amount': amount,
            'duration': duration,
            'usageType': usage_type,
            'startDate': now,
            'endDate': expiry_date,
            'status': 'active',
            'paymentId': payment.get('id'),
            'orderId': payment.get('order_id'),
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        
        print(f"✅ User {user_id} subscription updated successfully")
        
    except Exception as e:
        print(f"❌ Error updating user subscription: {e}")

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True) 