#!/bin/bash
# Fix iOS CocoaPods GoogleUtilities/Environment version conflict
# Run this script from your project root directory

echo "🔧 Fixing iOS CocoaPods version conflict..."

# Step 1: Clean iOS build files
echo "🗑️  Cleaning iOS build files..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf build/ios

# Step 2: Clean Flutter build cache
echo "🗑️  Cleaning Flutter build cache..."
flutter clean

# Step 3: Get dependencies (this will use the downgraded google_sign_in)
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Step 4: Navigate to iOS directory
echo "📱 Navigating to iOS directory..."
cd ios

# Step 5: Update CocoaPods repo
echo "🔄 Updating CocoaPods repo..."
pod repo update

# Step 6: Clean pod cache for problematic pods
echo "🧹 Cleaning pod cache..."
pod cache clean GoogleUtilities --all 2>/dev/null || true
pod cache clean AppCheckCore --all 2>/dev/null || true

# Step 7: Install pods with clean state
echo "📦 Installing pods with version resolution..."
pod install --repo-update --verbose

echo ""
echo "✅ iOS CocoaPods conflict should be resolved!"
echo ""
echo "📝 Next steps:"
echo "1. Open Xcode: open Runner.xcworkspace"
echo "2. Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)"
echo "3. Build again: Product → Build (Cmd+B)"
echo ""
echo "💡 If the issue persists, try:"
echo "  - brew upgrade cocoapods"
echo "  - pod cache clean --all"
echo "  - Check that google_sign_in is ^6.1.5 in pubspec.yaml"
