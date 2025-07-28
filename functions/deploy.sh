#!/bin/bash

# Deploy Firebase Cloud Functions (Node.js)
echo "Deploying Firebase Cloud Functions..."

# Make sure you're in the functions directory
cd "$(dirname "$0")"

# Install dependencies
echo "Installing dependencies..."
npm install

# Deploy the functions
echo "Deploying functions..."
firebase deploy --only functions

echo "Deployment complete!"
echo ""
echo "Available functions:"
echo "- sendNotificationToAll (Firestore trigger)"
echo "- subscribeUserToTopic (Callable function)"
echo "- unsubscribeUserFromTopic (Callable function)"
echo "- sendTestNotification (HTTP function)"
echo "- getNotificationStats (HTTP function)"
echo "- createUser (HTTP function)"
echo "- getUsers (HTTP function)"
echo "- healthCheck (HTTP function)" 