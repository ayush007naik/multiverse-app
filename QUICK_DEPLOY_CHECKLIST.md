# 🚀 Quick Deployment Checklist

## Pre-Deployment

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Login to Firebase
```bash
firebase login
```

### 3. Verify Project
```bash
firebase projects:list
# Should show: multiverses-8d207
```

---

## Deploy Web App

### Option 1: One-Command Deploy (Recommended)
```bash
./deploy_web.sh
```

### Option 2: Manual Deploy
```bash
# Build
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Verify Deployment
```bash
# Open in browser
open https://multiverses-8d207.web.app
```

**✅ Expected:** Your Flutter app loads (no "Site Not Found")

---

## Firebase Console Setup

### 1. Add Authorized Domains
Go to: **Authentication** → **Settings** → **Authorized domains**

Add:
- ✅ `multiverses-8d207.web.app`
- ✅ `multiverses-8d207.firebaseapp.com`
- ✅ `localhost`
- ✅ `127.0.0.1`

### 2. Enable Email Link Sign-In
Go to: **Authentication** → **Sign-in method** → **Email/Password**

Enable:
- ✅ Email/Password
- ✅ Email link (passwordless sign-in)

### 3. Add SHA-1 (For Android Testing)
```bash
cd android && ./gradlew signingReport
```

Copy SHA-1 to: **Project Settings** → **Your Android app** → **SHA certificate fingerprints**

---

## Test Email Link Authentication

### 1. Run Mobile App
```bash
flutter run
```

### 2. Send Login Link
- Switch to Email tab
- Enter email
- Click "Send Login Link"

### 3. Check Email
- Open email inbox
- Click login link

### 4. Expected Result
- App opens automatically
- User logs in
- Redirected to dashboard

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Site Not Found" | Run `flutter build web --release` then `firebase deploy --only hosting` |
| "Domain not authorized" | Add domain to Firebase Console → Authentication → Authorized domains |
| Link doesn't open app | Check intent filter in AndroidManifest.xml |
| Email not received | Check spam folder, verify email enabled in Firebase |

---

## Quick Commands

```bash
# Build web
flutter build web --release

# Deploy
firebase deploy --only hosting

# Test locally
flutter run -d chrome

# View logs
flutter run | grep "PasswordlessAuth"

# Test deep link (Android)
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://multiverses-8d207.web.app/login" \
  com.ayush.multiverse.multiverses
```

---

## Files Created

- ✅ `firebase.json` - Hosting configuration
- ✅ `.firebaserc` - Project configuration
- ✅ `deploy_web.sh` - Deployment script
- ✅ Android intent filter - Already added
- ✅ Flutter code - Already configured

---

## ✅ Done When

- [x] Web app accessible at https://multiverses-8d207.web.app
- [x] Email link sends successfully
- [x] Email link opens app
- [x] User auto-logs in
- [x] No errors in console

**🎉 You're ready!**
