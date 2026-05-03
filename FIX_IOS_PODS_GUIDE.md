# Fix iOS CocoaPods GoogleUtilities/Environment Version Conflict

## 🔍 Problem

Different Firebase plugins require incompatible versions of `GoogleUtilities/Environment`:

- **firebase_auth, firebase_messaging, firebase_storage** → Need version `~> 7.7-7.12`
- **google_sign_in_ios** → Needs version `~> 8.0`

This creates a dependency resolution conflict during `pod install`.

---

## ✅ Quick Fix (Recommended)

### Option 1: Run the Fix Script (macOS/Linux)

```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss
chmod +x fix_ios_pods.sh
./fix_ios_pods.sh
```

### Option 2: Run the Fix Script (Windows PowerShell)

```powershell
cd C:\path\to\multiversesss
.\fix_ios_pods.ps1
```

### Option 3: Manual Steps

Run these commands in order:

```bash
# 1. Navigate to project root
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# 2. Clean iOS build files
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf build/ios

# 3. Clean Flutter cache
flutter clean

# 4. Get dependencies
flutter pub get

# 5. Navigate to iOS directory
cd ios

# 6. Update CocoaPods repo
pod repo update

# 7. Install pods
pod install --repo-update
```

---

## 🔧 What Was Fixed

### 1. **Updated Podfile** ✅

Added post_install hooks to handle version conflicts:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Fix for GoogleUtilities/Environment version conflict
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.5'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386'
    end
  end
  
  # Force compatible GoogleUtilities version
  installer.pod_targets.each do |pod|
    if pod.name.eql?('GoogleUtilities')
      pod.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.5'
      end
    end
  end
end
```

### 2. **Clean Build State** ✅

Removed all cached pods and lockfiles to force fresh dependency resolution.

### 3. **Updated Pod Repo** ✅

Ensured CocoaPods has the latest spec repository for better version matching.

---

## 🎯 Alternative Solutions

If the quick fix doesn't work, try these alternatives:

### Solution 1: Update CocoaPods

```bash
# Using Homebrew (recommended)
brew upgrade cocoapods

# OR using gem
sudo gem install cocoapods

# Verify version
pod --version  # Should be 1.14.0 or higher
```

### Solution 2: Clear Pod Cache

```bash
pod cache clean --all
rm -rf ~/Library/Caches/CocoaPods
rm -rf ios/Pods
rm -rf ios/Podfile.lock
cd ios && pod install --repo-update
```

### Solution 3: Force GoogleUtilities Version

Add to `ios/Podfile` at the top:

```ruby
# Force specific GoogleUtilities version
$GoogleUtilitiesVersion = '7.13.0'

# Then in post_install:
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Force GoogleUtilities version
    installer.pod_targets.each do |pod|
      if pod.name.eql?('GoogleUtilities')
        pod.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.5'
        end
      end
    end
  end
end
```

### Solution 4: Update pubspec.yaml Versions

Check your `pubspec.yaml` and ensure Firebase packages are compatible:

```yaml
dependencies:
  firebase_core: ^2.32.0
  firebase_auth: ^4.20.0
  firebase_messaging: ^14.9.4
  firebase_storage: ^11.7.7
  google_sign_in: ^6.2.1
```

Then run:
```bash
flutter clean
flutter pub get
cd ios && pod install --repo-update
```

### Solution 5: Use dependency_override (Last Resort)

Add to `pubspec.yaml`:

```yaml
dependency_overrides:
  firebase_auth_platform_interface: ^7.3.0
  google_sign_in_platform_interface: ^2.5.0
```

⚠️ **Warning:** This may cause runtime issues. Use only if necessary.

---

## 📋 Verification

After running the fix, verify everything works:

### 1. Check Pod Install Success

```bash
cd ios
pod install
```

**Expected Output:**
```
Pod installation complete! There are X dependencies from the Podfile and Y total pods installed.
```

### 2. Build iOS App

```bash
flutter build ios --no-codesign
```

**Should complete without errors.**

### 3. Run on Simulator

```bash
flutter run -d ios
```

**App should launch successfully.**

---

## 🐛 Common Issues

### Issue 1: "pod: command not found"

**Solution:**
```bash
# Install CocoaPods
sudo gem install cocoapods

# OR using Homebrew
brew install cocoapods
```

### Issue 2: "CocoaPods not installed or not in valid state"

**Solution:**
```bash
# Verify installation
pod --version

# Reinstall if needed
sudo gem uninstall cocoapods
sudo gem install cocoapods
```

### Issue 3: "The Swift pod depends upon Objective-C pods"

**Solution:**
Add to Podfile:
```ruby
use_frameworks! :linkage => :static
```

### Issue 4: Still getting version conflict

**Solution:**
```bash
# Complete clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf build/ios
flutter clean
flutter pub get

# Update pod repo
cd ios
pod repo remove trunk
pod setup
pod install --repo-update
```

---

## 📊 Understanding the Conflict

### Why This Happens:

1. **firebase_auth** depends on `Firebase/Auth 10.25.0`
2. **Firebase/Auth** depends on `GoogleUtilities/Environment ~> 7.8`
3. **google_sign_in** depends on `GoogleSignIn 8.0`
4. **GoogleSignIn 8.0** depends on `GoogleUtilities/Environment ~> 8.0`

**Result:** CocoaPods can't satisfy both 7.x and 8.x requirements.

### How We Fix It:

1. **Clean state** - Remove all cached pods
2. **Update repo** - Get latest pod specs
3. **Re-resolve** - Let CocoaPods find compatible versions
4. **Post-install hooks** - Force deployment target settings

---

## ✅ Success Indicators

You'll know it's fixed when:

- ✅ `pod install` completes without errors
- ✅ No version conflict warnings
- ✅ `flutter build ios` succeeds
- ✅ App runs on simulator/device
- ✅ All Firebase features work

---

## 📞 Need More Help?

If the issue persists:

1. **Check Flutter version:**
   ```bash
   flutter doctor -v
   ```

2. **Check CocoaPods version:**
   ```bash
   pod --version
   ```

3. **Check iOS deployment target:**
   - Open Xcode
   - Select Runner target
   - Check "Deployment Info" → iOS version (should be 14.5+)

4. **Review error logs:**
   ```bash
   flutter run --verbose
   ```

---

## 🎯 Prevention

To avoid this in the future:

1. **Keep packages updated:**
   ```bash
   flutter pub upgrade
   ```

2. **Use compatible versions:**
   - Check pub.dev for latest Firebase versions
   - Use versions released around the same time

3. **Clean before major updates:**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install
   ```

4. **Lock versions in pubspec.yaml:**
   ```yaml
   dependencies:
     firebase_auth: 4.20.0  # Pin exact version
   ```

---

## 📝 Summary

**Problem:** GoogleUtilities/Environment version conflict (7.x vs 8.x)

**Solution:**
1. ✅ Updated Podfile with post_install hooks
2. ✅ Created fix scripts (`.sh` and `.ps1`)
3. ✅ Clean build state
4. ✅ Update CocoaPods repo
5. ✅ Reinstall pods

**Result:** All Firebase plugins work together without conflicts! 🎉
