# Java 21 Upgrade - Quick Reference

## Configuration Files Updated

### 1. `android/app/build.gradle.kts`
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_21  // Changed from VERSION_17
    targetCompatibility = JavaVersion.VERSION_21  // Changed from VERSION_17
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_21.toString()  // Changed from VERSION_17
}
```

### 2. `android/gradle.properties`
```ini
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseG1GC
org.gradle.java.home=/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
android.useAndroidX=true
```

### 3. `android/local.properties`
```ini
java.home=/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
```

## Quick Build Commands

### Clean and rebuild:
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss
rm -rf build .gradle
flutter clean
flutter pub get
flutter build apk --debug
```

### Run on emulator/device:
```bash
flutter run
```

### Verify Java 21 is active:
```bash
/usr/local/opt/openjdk@21/bin/java -version
# Expected output: openjdk version "21.0.11"
```

## Expected Results

✅ **Before (with Java 8):**
```
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
```

✅ **After (with Java 21):**
- No obsolete warnings
- Cleaner build output
- Faster compilation

## Troubleshooting Checklist

- [ ] Java 21 installed via Homebrew
- [ ] `gradle.properties` points to Java 21 home
- [ ] `local.properties` has java.home set
- [ ] `app/build.gradle.kts` uses JavaVersion.VERSION_21
- [ ] Gradle cache cleared (`~/.gradle/caches`)
- [ ] Flutter clean executed
- [ ] No IDE/Android Studio caching issues

## Support

If build fails after upgrade:
1. Run: `flutter doctor -v` to verify setup
2. Check: `which java` shows Java 21
3. Rebuild: `flutter clean && flutter build apk --debug`
