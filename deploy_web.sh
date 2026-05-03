#!/bin/bash

# Firebase Hosting Deployment Script for Flutter Web
# This script builds and deploys your Flutter web app to Firebase Hosting

set -e  # Exit on error

echo "========================================="
echo "🚀 Flutter Web + Firebase Hosting Deploy"
echo "========================================="
echo ""

# Step 1: Clean previous builds
echo "🧹 Step 1: Cleaning previous builds..."
flutter clean
echo "✅ Clean complete"
echo ""

# Step 2: Get dependencies
echo "📦 Step 2: Getting dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Step 3: Build Flutter Web
echo "🔨 Step 3: Building Flutter Web app..."
flutter build web --release
echo "✅ Web build complete"
echo ""

# Step 4: Verify build output
echo "🔍 Step 4: Verifying build output..."
if [ -d "build/web" ]; then
    echo "✅ Build directory exists: build/web"
    echo "📊 Build size: $(du -sh build/web | cut -f1)"
else
    echo "❌ Error: build/web directory not found!"
    exit 1
fi
echo ""

# Step 5: Check Firebase CLI
echo "🔍 Step 5: Checking Firebase CLI..."
if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI installed: $(firebase --version)"
else
    echo "❌ Firebase CLI not installed!"
    echo "📦 Install it with: npm install -g firebase-tools"
    exit 1
fi
echo ""

# Step 6: Check Firebase authentication
echo "🔐 Step 6: Checking Firebase authentication..."
if firebase projects:list &> /dev/null; then
    echo "✅ Firebase authenticated"
else
    echo "❌ Not authenticated with Firebase!"
    echo "🔑 Run: firebase login"
    exit 1
fi
echo ""

# Step 7: Deploy to Firebase Hosting
echo "🚀 Step 7: Deploying to Firebase Hosting..."
echo "🌐 Site: https://multiverses-8d207.web.app"
echo ""
firebase deploy --only hosting

echo ""
echo "========================================="
echo "✅ Deployment Complete!"
echo "========================================="
echo "🌐 Your app is live at: https://multiverses-8d207.web.app"
echo "🌐 Alternative URL: https://multiverses-8d207.firebaseapp.com"
echo ""
echo "📝 Next Steps:"
echo "1. Add domain to Firebase Console → Authentication → Authorized domains"
echo "2. Enable Email Link sign-in in Firebase Console"
echo "3. Test email link authentication"
echo ""
echo "📖 See EMAIL_LINK_DEPLOYMENT_GUIDE.md for complete setup"
echo "========================================="
