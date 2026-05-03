# Passwordless Email Authentication Setup Guide

## Overview
Your Flutter app now supports passwordless email authentication using Firebase Auth email links (magic links). Users can login by simply clicking a link sent to their email - no password required!

## Features Implemented
✅ Password field removed from login screen
✅ "Send Login Link" button added
✅ Email link authentication via Firebase Auth
✅ SharedPreferences for temporary email storage
✅ Deep linking support for link click handling
✅ Auto-login when user clicks email link
✅ Resend link functionality
✅ Beautiful UI with success state

## Firebase Console Configuration

### 1. Enable Email Link Sign-In
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Email/Password** provider
5. Enable **Email link (passwordless sign-in)** toggle
6. Save changes

### 2. Set Up Firebase Dynamic Links
1. In Firebase Console, go to **Engage** → **Dynamic Links**
2. Click **Get Started**
3. Create a Dynamic Links domain (e.g., `multiversesss.page.link`)
4. Configure the domain settings

### 3. Configure Authorized Domains
1. Go to **Authentication** → **Settings** → **Authorized domains**
2. Add your Dynamic Links domain: `multiversesss.page.link`
3. Add any custom domains you're using

## Android Configuration

### Add Intent Filter to AndroidManifest.xml
Open `android/app/src/main/AndroidManifest.xml` and add inside the `<activity>` tag:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:host="multiversesss.page.link"
        android:scheme="https" />
</intent-filter>
```

### Update actionCodeSettings
In `lib/screen/login_screen.dart`, update the `_sendPasswordlessEmailLink` method:

```dart
final actionCodeSettings = ActionCodeSettings(
  url: 'https://multiversesss.page.link/emailLogin',  // Your dynamic link
  handleCodeInApp: true,
  iOSBundleId: 'YOUR_IOS_BUNDLE_ID',  // e.g., com.example.multiversesss
  androidPackageName: 'YOUR_ANDROID_PACKAGE_NAME',  // e.g., com.example.multiversesss
  androidInstallApp: true,
  androidMinimumVersion: '1',
);
```

## iOS Configuration

### Update Info.plist
Open `ios/Runner/Info.plist` and add:

```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
```

### Update actionCodeSettings
Make sure to set the correct `iOSBundleId` in the actionCodeSettings.

## How It Works

### Login Flow
1. User enters email address
2. App sends login link via Firebase Auth
3. Email is temporarily stored in SharedPreferences
4. User receives email with magic link
5. User clicks link → App opens automatically
6. App detects the link and auto-completes sign-in
7. User is logged in and redirected to appropriate screen

### Code Flow
```
User enters email
    ↓
_sendPasswordlessEmailLink()
    ↓
Store email in SharedPreferences
    ↓
Firebase sends email link
    ↓
User clicks link in email
    ↓
App opens via deep link
    ↓
_handleEmailLinkSignIn() checks for pending email
    ↓
Completes sign-in with Firebase
    ↓
Navigates to user dashboard
```

## Testing

### Test Email Link Locally
1. Run the app: `flutter run`
2. Switch to Email login
3. Enter your email address
4. Click "Send Login Link"
5. Check your email inbox
6. Click the login link
7. App should open and auto-login

### Firebase Test Mode
For testing without actual email sending, you can use Firebase test email addresses in the Firebase Console.

## Security Considerations

✅ Email links expire after 1 hour (default Firebase setting)
✅ Links can only be used once
✅ Email is stored locally only until link is clicked
✅ Pending email is cleared after successful login
✅ Failed attempts clear invalid pending emails

## Customization

### Change Link Expiration
Firebase default is 1 hour. To customize, you'd need to use Firebase Admin SDK.

### Modify UI Colors
Update the colors in `_buildEmailLoginWidget()`:
- Primary color: `Color(0xFFFF5722)`
- Background: `Color(0xFF1E1E1E)`
- Text: `Color(0xFF888888)`

### Add Custom Domain
Replace `multiversesss.page.link` with your custom domain in:
- Firebase Console Dynamic Links
- actionCodeSettings URL
- AndroidManifest.xml intent filter

## Troubleshooting

### Email Not Received
1. Check spam folder
2. Verify email address is correct
3. Check Firebase Console for errors
4. Ensure Email/Password provider is enabled

### Link Doesn't Open App
1. Verify intent filter is correctly added
2. Check Dynamic Links domain is configured
3. Ensure app is installed on device
4. Test with `flutter run` on physical device

### "Invalid Link" Error
1. Link may have expired (1 hour limit)
2. Link already used (single use only)
3. Request a new link

## Next Steps

- [ ] Configure Firebase Dynamic Links domain
- [ ] Update AndroidManifest.xml with intent filter
- [ ] Update actionCodeSettings with your package names
- [ ] Test on physical device
- [ ] Add analytics for link tracking
- [ ] Customize email template in Firebase Console

## Support

For issues, check:
- Firebase Console logs
- Flutter debug console output
- Device logs for deep linking issues
