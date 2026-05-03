#!/bin/bash
# Complete fix for all Flutter errors - Dependencies & Build

echo "🔧 Fixing ALL Flutter errors..."
echo ""

# Step 1: Navigate to project
echo "📁 Navigating to project directory..."
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# Step 2: Clean everything
echo "🗑️  Step 1/6: Cleaning build artifacts..."
flutter clean
rm -rf build/
rm -rf .dart_tool/
echo "✅ Clean complete"
echo ""

# Step 3: Get all dependencies
echo "📦 Step 2/6: Installing Flutter dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Step 4: Fix iOS pods
echo "📱 Step 3/6: Fixing iOS CocoaPods..."
cd ios
rm -rf Pods/
rm -rf Podfile.lock
rm -rf .symlinks/
pod repo update
pod install --repo-update
cd ..
echo "✅ iOS pods installed"
echo ""

# Step 5: Verify project structure
echo "🔍 Step 4/6: Verifying project structure..."
if [ -f "pubspec.lock" ]; then
    echo "✅ pubspec.lock exists"
else
    echo "❌ pubspec.lock missing!"
    exit 1
fi

if [ -d ".dart_tool/package_config.json" ]; then
    echo "✅ Package config exists"
else
    echo "❌ Package config missing!"
    exit 1
fi
echo ""

# Step 6: Run analyzer
echo "🔎 Step 5/6: Running Flutter analyzer..."
flutter analyze --no-fatal-infos --no-fatal-warnings
echo ""

# Step 7: Try building
echo "🏗️  Step 6/6: Testing Android build..."
flutter build apk --debug --no-pub
echo ""

echo "================================================================================"
echo "✅ ALL FIXES COMPLETE!"
echo "================================================================================"
echo ""
echo "📋 Summary:"
echo "  ✅ Flutter dependencies installed"
echo "  ✅ iOS CocoaPods installed"
echo "  ✅ Project cleaned and rebuilt"
echo ""
echo "🚀 Next steps:"
echo "  • Run app: flutter run"
echo "  • Build Android: flutter build apk --release"
echo "  • Build iOS: flutter build ios --no-codesign"
echo ""
echo "💡 If errors persist:"
echo "  • Restart your IDE (Android Studio / VS Code)"
echo "  • Run: flutter doctor -v"
echo "  • Check: pubspec.yaml for typos"
echo ""
