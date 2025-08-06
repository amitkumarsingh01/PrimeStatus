#!/bin/bash

# Setup script for Razorpay webhook configuration
echo "🔧 Setting up Razorpay webhook configuration..."

# Check if webhook secret is provided
if [ -z "$1" ]; then
    echo "❌ Error: Please provide your Razorpay webhook secret"
    echo "Usage: ./setup-webhook.sh YOUR_WEBHOOK_SECRET"
    echo ""
    echo "To get your webhook secret:"
    echo "1. Go to Razorpay Dashboard → Settings → Webhooks"
    echo "2. Copy the webhook secret"
    exit 1
fi

WEBHOOK_SECRET=$1

echo "🔐 Setting Razorpay webhook secret..."
firebase functions:config:set razorpay.webhook_secret="$WEBHOOK_SECRET"

echo "✅ Webhook secret configured successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Deploy your functions: firebase deploy --only functions"
echo "2. Update the webhook URL in your payment service with your actual project ID"
echo "3. Configure Razorpay webhook URL in dashboard"
echo ""
echo "🔗 Your webhook URL will be:"
echo "https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/razorpayWebhook"
echo ""
echo "📝 To get your project ID, run: firebase projects:list" 