#!/bin/bash

echo "🔧 Fixing Vendor Dashboard..."

# Navigate to vendor_dashboard
cd "$(dirname "$0")"

echo "📦 Step 1: Cleaning build..."
flutter clean

echo "📦 Step 2: Getting dependencies..."
flutter pub get

echo "📦 Step 3: Analyzing code..."
flutter analyze

echo ""
echo "✅ Fix complete!"
echo ""
echo "🎯 To run the vendor dashboard:"
echo "   flutter run -d chrome --web-port=9000"
echo ""
echo "🌐 Vendor Dashboard will be available at: http://localhost:9000"
