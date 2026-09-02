#!/bin/bash

echo "🔍 Checking for processes on ports..."
echo ""

# Check port 8080
echo "Port 8080 (Main App):"
lsof -ti:8080 2>/dev/null && echo "  ⚠️  IN USE" || echo "  ✅ FREE"

# Check port 8081
echo "Port 8081 (Admin Dashboard):"
lsof -ti:8081 2>/dev/null && echo "  ⚠️  IN USE" || echo "  ✅ FREE"

# Check port 9000
echo "Port 9000 (Vendor Dashboard):"
lsof -ti:9000 2>/dev/null && echo "  ⚠️  IN USE" || echo "  ✅ FREE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Kill process on 8081
if lsof -ti:8081 >/dev/null 2>&1; then
    echo "🔪 Killing process on port 8081..."
    lsof -ti:8081 | xargs kill -9
    echo "✅ Port 8081 freed!"
else
    echo "✅ Port 8081 is already free"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Kill process on 9000
if lsof -ti:9000 >/dev/null 2>&1; then
    echo "🔪 Killing process on port 9000..."
    lsof -ti:9000 | xargs kill -9
    echo "✅ Port 9000 freed!"
else
    echo "✅ Port 9000 is already free"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Kill process on 8080
if lsof -ti:8080 >/dev/null 2>&1; then
    echo "🔪 Killing process on port 8080..."
    lsof -ti:8080 | xargs kill -9
    echo "✅ Port 8080 freed!"
else
    echo "✅ Port 8080 is already free"
fi

echo ""
echo "✅ All ports freed! You can now run your apps."
echo ""
echo "To run vendor dashboard:"
echo "  cd vendor_dashboard"
echo "  flutter run -d chrome --web-port=9000"
echo ""
