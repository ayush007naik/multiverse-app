#!/bin/bash

echo "🔥 Deploying Firestore Rules..."
echo ""

cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

echo "📍 Current directory: $(pwd)"
echo ""

firebase deploy --only firestore:rules

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🚀 Now run admin dashboard:"
echo "   cd /Users/ayushnaik/AndroidStudioProjects/multiversesss/admin_dashboard"
echo "   flutter pub get"
echo "   flutter run -d chrome"
echo ""
