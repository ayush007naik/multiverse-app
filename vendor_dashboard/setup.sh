#!/bin/bash

echo "🚀 Setting up Vendor Dashboard..."

# Navigate to vendor_dashboard directory
cd "$(dirname "$0")"

echo "📦 Installing dependencies..."
flutter pub get

echo "✅ Setup complete!"
echo ""
echo "🎯 To run the vendor dashboard:"
echo "   flutter run -d chrome --web-port=9000"
echo ""
echo "🌐 Vendor Dashboard will be available at: http://localhost:9000"
