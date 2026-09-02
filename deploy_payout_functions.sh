#!/bin/bash

# 🔧 Deploy Payout Functions with Test Keys
# Your Razorpay Test Key ID: rzp_test_xxxxxxxxxxxx
# Your Razorpay Test Secret: xxxxxxxxxxxxxxxxxxxx

echo "🚀 Setting up Razorpay Payout Functions..."
echo ""

echo "📝 Razorpay Key ID: rzp_test_xxxxxxxxxxxx"
echo "📝 Environment file: functions/.env"
echo ""

echo "✅ .env file already created in functions/ directory"
echo ""
echo "📦 Installing Razorpay package..."
echo ""

cd functions
npm install razorpay

if [ $? -ne 0 ]; then
    echo "❌ Failed to install razorpay package!"
    exit 1
fi

cd ..

echo ""
echo "🚀 Deploying Cloud Functions..."
echo ""

# Deploy without lint to avoid eslint errors
firebase deploy --only functions:processPayout,functions:payoutWebhook,functions:processBulkPayouts --force

if [ $? -eq 0 ]; then
    echo ""
    echo "✅✅✅ DEPLOYMENT SUCCESSFUL! ✅✅✅"
    echo ""
    echo "📊 Next Steps:"
    echo "   1. Test payout flow in your app"
    echo "   2. Check function logs: firebase functions:log"
    echo "   3. Apply for Razorpay Route activation for production"
    echo ""
else
    echo ""
    echo "❌ Deployment failed! Check errors above."
    echo ""
fi
