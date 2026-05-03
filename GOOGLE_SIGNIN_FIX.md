Google Sign-In HTTP 400 checklist

Local app configuration verified in this workspace:
- Android package: `com.ayush.multiverse.multiverses`
- Firebase project id: `multiverses-8d207`
- Debug SHA-1: `3E:1C:18:37:92:0D:50:2F:F2:10:29:DC:A1:A1:67:02:53:34:5D:F3`
- `android/app/google-services.json` currently contains the same package and SHA-1.

Firebase Console checks required:
1. Open Firebase Console -> Project Settings -> Your Android app.
2. Ensure package name is exactly `com.ayush.multiverse.multiverses`.
3. Ensure SHA certificate fingerprints include:
   - `3E:1C:18:37:92:0D:50:2F:F2:10:29:DC:A1:A1:67:02:53:34:5D:F3`
4. Open Authentication -> Sign-in method.
5. Enable `Google`.
6. Download the latest `google-services.json`.
7. Replace `android/app/google-services.json` with the downloaded file.

Rebuild after Firebase config changes:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

Useful local verification commands:
```bash
keytool -list -v -alias androiddebugkey -keystore "$HOME/.android/debug.keystore" -storepass android -keypass android
```
