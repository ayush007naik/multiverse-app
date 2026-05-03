#!/bin/bash
# Fix Xcode project.pbxproj parse error
# This fixes the corrupted shellScript line in the project file

PROJECT_FILE="/Users/ayushnaik/AndroidStudioProjects/multiversesss/ios/Runner.xcodeproj/project.pbxproj"

echo "🔧 Fixing Xcode project.pbxproj parse error..."

# Backup the original file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"
echo "✅ Backup created: project.pbxproj.backup"

# Fix line 261 - Replace the corrupted shellScript line
# The issue is unescaped quotes in the shellScript value
sed -i '' '261s|.*|			shellScript = "export PATH=\\\"\\$PATH:/Users/ayushnaik/flutter/bin\\\"\\nset -e\\n/bin/sh \\\"\\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh\\\" build";|' "$PROJECT_FILE"

echo "✅ Fixed shellScript line (line 261)"

# Verify the fix
echo ""
echo "📋 Verifying fix..."
if grep -q 'shellScript = "export PATH=' "$PROJECT_FILE"; then
    echo "✅ Fix applied successfully!"
    echo ""
    echo "📝 New line 261:"
    sed -n '261p' "$PROJECT_FILE"
else
    echo "❌ Fix verification failed"
    exit 1
fi

echo ""
echo "🎉 Xcode project file fixed!"
echo ""
echo "📝 Next steps:"
echo "1. Try building again: flutter build ios --no-codesign"
echo "2. OR run: flutter run -d ios"
echo ""
echo "💡 If issues persist:"
echo "  - Open in Xcode: open ios/Runner.xcworkspace"
echo "  - Product → Clean Build Folder (Shift+Cmd+K)"
echo "  - Product → Build (Cmd+B)"
