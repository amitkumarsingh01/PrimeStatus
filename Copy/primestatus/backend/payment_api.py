from flask import Flask, request, jsonify
from flask_cors import CORS
import razorpay
import json
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Razorpay configuration
RAZORPAY_KEY_ID = os.getenv('RAZORPAY_KEY_ID', 'rzp_test_YOUR_KEY_ID')
RAZORPAY_KEY_SECRET = os.getenv('RAZORPAY_KEY_SECRET', 'YOUR_KEY_SECRET')

# Initialize Razorpay client
client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

@app.route('/api/payments/create-order', methods=['POST'])
def create_payment_order():
    try:
        data = request.get_json()
        
        # Extract data from request
        amount = data.get('amount')  # Amount in paise
        currency = data.get('currency', 'INR')
        receipt = data.get('receipt')
        notes = data.get('notes', {})
        prefill = data.get('prefill', {})
        
        # Create Razorpay order
        order_data = {
            'amount': amount,
            'currency': currency,
            'receipt': receipt,
            'notes': notes
        }
        
        order = client.order.create(data=order_data)
        
        # Create payment link
        payment_link_data = {
            'amount': amount,
            'currency': currency,
            'order_id': order['id'],
            'prefill': prefill,
            'notes': notes,
            'callback_url': 'https://your-app.com/payment/callback',  # Replace with your callback URL
            'cancel_url': 'https://your-app.com/payment/cancel',      # Replace with your cancel URL
        }
        
        payment_link = client.payment_link.create(data=payment_link_data)
        
        return jsonify({
            'success': True,
            'order_id': order['id'],
            'payment_url': payment_link['short_url'],
            'payment_link_id': payment_link['id']
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400

@app.route('/api/payments/verify', methods=['POST'])
def verify_payment():
    try:
        data = request.get_json()
        
        # Extract payment verification data
        payment_id = data.get('payment_id')
        order_id = data.get('order_id')
        signature = data.get('signature')
        
        # Verify payment signature
        params_dict = {
            'razorpay_payment_id': payment_id,
            'razorpay_order_id': order_id,
            'razorpay_signature': signature
        }
        
        client.utility.verify_payment_signature(params_dict)
        
        return jsonify({
            'success': True,
            'message': 'Payment verified successfully'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400

@app.route('/api/payments/webhook', methods=['POST'])
def payment_webhook():
    try:
        # Get webhook data
        webhook_data = request.get_json()
        webhook_signature = request.headers.get('X-Razorpay-Signature')
        
        # Verify webhook signature
        client.utility.verify_webhook_signature(
            request.data.decode(),
            webhook_signature,
            'YOUR_WEBHOOK_SECRET'  # Replace with your webhook secret
        )
        
        # Process webhook event
        event = webhook_data.get('event')
        payload = webhook_data.get('payload', {})
        
        if event == 'payment.captured':
            payment = payload.get('payment', {})
            order = payload.get('order', {})
            
            # Update your database with payment success
            # You can send this data to your mobile app via Firebase
            print(f"Payment successful: {payment['id']} for order: {order['id']}")
            
        elif event == 'payment.failed':
            payment = payload.get('payment', {})
            print(f"Payment failed: {payment['id']}")
        
        return jsonify({'success': True})
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000) 