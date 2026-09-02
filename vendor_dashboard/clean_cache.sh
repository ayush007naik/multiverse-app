#!/bin/bash

echo "🔧 Fixing Dart Analyzer Cache Errors..."
echo ""

# Navigate to vendor_dashboard
cd "$(dirname "$0")"

echo "📦 Step 1: Cleaning Flutter build..."
flutter clean

echo ""
echo "📦 Step 2: Getting dependencies..."
flutter pub get

echo ""
echo "📦 Step 3: Cleaning Dart cache..."
rm -rf .dart_tool
rm -rf build

echo ""
echo "📦 Step 4: Rebuilding..."
flutter pub get

echo ""
echo "✅ Cache cleared! Now run:"
echo "   flutter run -d chrome --web-port=9000"
echo ""
echo "The false errors should be gone now!"
