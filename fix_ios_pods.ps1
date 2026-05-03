# Fix iOS CocoaPods GoogleUtilities/Environment version conflict
# Run this script from your project root directory in PowerShell

Write-Host "🔧 Fixing iOS CocoaPods version conflict..." -ForegroundColor Cyan

# Step 1: Clean iOS build files
Write-Host "🗑️  Cleaning iOS build files..." -ForegroundColor Yellow
Remove-Item -Recurse -Force -Path "ios/Pods" -ErrorAction SilentlyContinue
Remove-Item -Force -Path "ios/Podfile.lock" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "ios/.symlinks" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "build/ios" -ErrorAction SilentlyContinue

# Step 2: Clean Flutter build cache
Write-Host "🗑️  Cleaning Flutter build cache..." -ForegroundColor Yellow
flutter clean

# Step 3: Get dependencies
Write-Host "📦 Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

# Step 4: Navigate to iOS directory
Write-Host "📱 Navigating to iOS directory..." -ForegroundColor Yellow
Set-Location -Path "ios"

# Step 5: Update CocoaPods repo
Write-Host "🔄 Updating CocoaPods repo..." -ForegroundColor Yellow
pod repo update

# Step 6: Install pods with clean state
Write-Host "📦 Installing pods..." -ForegroundColor Yellow
pod install --repo-update

Write-Host ""
Write-Host "✅ iOS CocoaPods conflict resolved!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "1. Open Xcode: open Runner.xcworkspace"
Write-Host "2. Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)"
Write-Host "3. Build again: Product → Build (Cmd+B)"
Write-Host ""
Write-Host "💡 If the issue persists, try:" -ForegroundColor Yellow
Write-Host "  - sudo gem install cocoapods"
Write-Host "  - brew upgrade cocoapods"
Write-Host "  - pod cache clean --all"
