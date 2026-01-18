# 🎯 Quick Reference: Google Sign-In Error 10 Fix

## ❌ Problem
```
E/flutter: ❌ Error during sign-in: PlatformException(sign_in_failed, 
com.google.android.gms.common.api.ApiException: 10: , null, null)

W/google_sign_in: clientId is not supported on Android and is interpreted 
as serverClientId. Use serverClientId instead to suppress this warning.
```

## ✅ What Was Fixed in Code
- Changed `GoogleSignIn(clientId: ...)` → `GoogleSignIn(serverClientId: ...)`
- Added full OAuth scopes
- Improved error handling

## 🔴 What Still Needs to Be Done (CRITICAL)

Firebase belum memiliki OAuth Client ID untuk package `com.asetq_apps`.

### Quick Checklist:

- [ ] Run `keytool` command → Get SHA-1
- [ ] Open Google Cloud Console
- [ ] Create OAuth 2.0 Client ID for Android
- [ ] Input SHA-1 + package name
- [ ] Download google-services.json
- [ ] Replace file di android/app/
- [ ] flutter clean + flutter run

## 📍 Exact Links to Visit

1. **Google Cloud Console (Create OAuth):**
   - https://console.cloud.google.com/apis/credentials
   - Select project: asetq-2026
   - Create Credentials → OAuth 2.0 Client IDs → Android

2. **Firebase Console (Download JSON):**
   - https://console.firebase.google.com
   - Project: asetq-2026
   - Project Settings → Your apps

3. **Firebase + Google Cloud Link Check:**
   - https://console.firebase.google.com/project/asetq-2026/settings/integrations/googlecloud

---

## 💡 Key Point

**Error 10 = DEVELOPER_ERROR = OAuth Config Mismatch**

Ini terjadi karena:
- ✅ App sudah installed
- ✅ Code sudah fixed
- ❌ Firebase/Google Cloud belum tahu tentang Android OAuth Client

Solution = Add Android OAuth Client ke Google Cloud Console

---

## 🎬 Video Reference (Optional)

Search: "Google Sign-In Flutter Android Error 10 firebase"

Key steps:
1. Get SHA-1 from keytool
2. Create Android OAuth Client in Google Cloud
3. Download google-services.json
4. Replace & rebuild

---

**Status:** 🟡 Code fixed, waiting for Firebase setup

