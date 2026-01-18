# 🐛 Complete Debugging Guide untuk Google Sign-In & Pull-to-Refresh

## 📋 Quick Troubleshooting

### ❌ Error: `com.google.android.gms.common.api.ApiException: 10`

**What is Error 10?**
```
Error Code: 10 = DEVELOPER_ERROR
Meaning: OAuth configuration mismatch
```

**Fixes (in order):**

#### Fix 1️⃣: Verify SHA-1 Certificate ✅

```powershell
# Run in PowerShell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Output should show:
```
Alias name: androiddebugkey
Creation date: Dec 19, 2024
...
Certificate fingerprints:
         SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

✅ **Catat SHA1 value ini!**

#### Fix 2️⃣: Add SHA-1 to Firebase ✅

```
Firebase Console 
  → Project Settings 
  → App Registration 
  → com.asetq_apps (Android) 
  → Add Fingerprint 
  → Paste SHA1 
  → Save
```

#### Fix 3️⃣: Download New google-services.json ✅

```
Firebase Console
  → Project Settings
  → Download google-services.json
  → Replace file at: android/app/google-services.json
```

**Verify new file includes:**
```json
"oauth_client": [
  {
    "client_id": "xxx.apps.googleusercontent.com",
    "client_type": 3,
    "android_info": {
      "package_name": "com.asetq_apps",
      "certificate_hash": "xxxxx"
    }
  }
]
```

#### Fix 4️⃣: Clean & Rebuild ✅

```powershell
cd g:\05. PANCAR\webview_asetq

# Clean completely
flutter clean
rm -r android/build -Force
rm -r build -Force

# Get dependencies
flutter pub get

# Build & run
flutter run -v
```

---

## 📊 Verify Each Component

### ✅ Step 1: Check Package Name Match

```dart
// main.dart line 103
static const String androidClientId = 
  '884256332175-ainljh42sjc4uad0l1i6qmmahpadrlns.apps.googleusercontent.com';
```

**Must match:**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest ...>
  <!-- Implicit package from app/build.gradle -->
  applicationId "com.asetq_apps"
</manifest>
```

```gradle
// android/app/build.gradle
defaultConfig {
    applicationId "com.asetq_apps"  ← Must match!
}
```

### ✅ Step 2: Verify Firebase Config

```json
// android/app/google-services.json
"client": [
  {
    "client_info": {
      "mobilesdk_app_id": "1:967780507762:android:69786da8df0de23008a2eb",
      "android_client_info": {
        "package_name": "com.asetq_apps"  ← Must match!
      }
    },
```

### ✅ Step 3: Check google_sign_in Initialization

```dart
// main.dart line 114
void _initializeGoogleSignIn() {
  _googleSignIn = GoogleSignIn(
    clientId: androidClientId,  // ← Web Client ID
    scopes: ['email', 'profile'],
  );
}
```

---

## 🔍 Debug Logs to Look For

### ✅ Successful Sign-In Log Pattern:

```
I flutter: 🔵 Starting Google Sign-In...
I flutter: ✅ Google Sign-In successful: user@gmail.com
I flutter: 🔑 Auth info obtained, sending to backend...
I flutter: Login Successful!
```

### ❌ Failed Sign-In Log Pattern:

```
I flutter: 🔵 Starting Google Sign-In...
I flutter: ❌ Error during sign-in: PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
```

### 📝 How to Capture Full Logs:

```powershell
# Terminal 1: Run app dengan verbose logging
flutter run -v 2>&1 | Tee-Object -FilePath flutter_log.txt

# Terminal 2: Monitor logcat real-time
adb logcat | findstr "flutter|google|sign"
```

---

## 🧪 Manual Test Sequence

### Test 1: Direct Google SignIn Call
```dart
// In StatefulWidget, call directly:
await _handleGoogleSignIn();
```

**Check:**
- [ ] Dialog muncul
- [ ] Dapat memilih akun Gmail
- [ ] Permissions granted
- [ ] No error thrown

### Test 2: From WebView Button
```javascript
// In web app, call:
FlutterGoogleAuth.postMessage('trigger_google_login');
```

**Check:**
- [ ] JS Channel properly connected
- [ ] Flutter method received
- [ ] Sign-In dialog triggered

### Test 3: Backend Integration
```dart
// After sign-in, verify backend call:
await _loginToBackend(userInfo);
```

**Check logcat:**
```
POST https://aset.pncr-tech.com/api/auth-google.php
Status: 200
Response: {"status":"success","user_id":"123",...}
```

---

## 🔧 Advanced Debugging

### Enable Google Play Services Debug:

Create file: `android/build.gradle`

```gradle
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

### Monitor Network Calls:

```bash
# In Android Studio
Tools → Profiler → Network

# Check:
# 1. /auth-google.php POST request
# 2. Response headers & body
# 3. Status code should be 200
```

### Check Signing Certificate in APK:

```powershell
# Extract and verify signing cert from built APK
$apkPath = "build/app/outputs/apk/debug/app-debug.apk"

# List certificate info
jarsigner -verify -verbose $apkPath

# Should show:
# Verified by "Android Debug Certificate"
```

---

## 📋 Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Error 10 | SHA-1 mismatch | Verify SHA-1, add to Firebase |
| Error 10 | Wrong package name | Check `applicationId` in build.gradle |
| Error 10 | google-services.json outdated | Download new JSON from Firebase |
| Sign-In dialog stuck | Network issue | Check device network connectivity |
| Backend 401/403 | Invalid session | Check if user_id properly saved to localStorage |
| Pull-to-refresh not work | Timing issue | Check if page fully loaded before refresh |

---

## 🎯 Final Verification

After applying all fixes:

```powershell
# 1. Clean everything
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build & run with logs
flutter run -v

# 4. Check logs
# Should see: ✅ Google Sign-In successful
# Should see: ✅ Page reloaded successfully (for pull-refresh)

# 5. Test in app
# - Try signing in
# - Try pull-to-refresh
# - Check device logs: adb logcat | findstr flutter
```

---

## 📞 Getting Help

If still not working, provide:

1. **Full error message** from logcat
2. **Output from keytool command**
3. **Screenshot of Firebase console** (SHA-1 section)
4. **Contents of google-services.json** (redact sensitive data)
5. **Flutter doctor output**: `flutter doctor -v`
6. **Full log file**: `flutter run -v > log.txt 2>&1`

---

**Last Updated:** 16 Januari 2026
**Tested on:** Flutter 3.10.4, Android SDK 36
