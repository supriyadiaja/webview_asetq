# 🔄 Google Sign-In Flow Diagram & Troubleshooting

## ✅ Correct Flow (What We Want)

```
┌─────────────────────────────────────────────┐
│   User Clicks "Sign in with Google"         │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Flutter App (main.dart)                   │
│   _handleGoogleSignIn() triggered           │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Google SignIn Dialog Appears              │
│   ✅ GoogleSignIn initialized with:         │
│   - serverClientId (NOT clientId)           │
│   - Full OAuth scopes                       │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Google Checks:                            │
│   ✅ Package name: com.asetq_apps           │
│   ✅ SHA-1 matches in Firebase              │
│   ✅ OAuth Client exists in Google Cloud    │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   ✅ User selects Google account             │
│   ✅ Permissions granted                    │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Backend receives login                    │
│   Sets localStorage with user data          │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   ✅ Login Successful!                      │
│   User navigated to home page               │
└─────────────────────────────────────────────┘
```

---

## ❌ Current Flow (Error 10)

```
┌─────────────────────────────────────────────┐
│   User Clicks "Sign in with Google"         │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Flutter App (main.dart)                   │
│   _handleGoogleSignIn() triggered           │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Google SignIn Dialog Appears              │
│   ⚠️  Warning: clientId used, should use    │
│      serverClientId                         │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Google Checks:                            │
│   ✅ Package name: com.asetq_apps           │
│   ✅ SHA-1 matches in Firebase              │
│   ❌ OAuth Client NOT found in Google Cloud │
│      (or not properly configured)           │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   ❌ ERROR 10 (DEVELOPER_ERROR)              │
│   "OAuth configuration mismatch"            │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│   Sign-In Dialog closes                     │
│   PlatformException thrown                  │
│   User sees: "Login gagal"                  │
└─────────────────────────────────────────────┘
```

---

## 🔧 Where the Fix Happens

### ✅ Code Level (Already Done)
```
lib/main.dart
├─ _initializeGoogleSignIn()
│  └─ Changed: clientId → serverClientId
├─ scopes updated
└─ error handling improved
```

### ❌ Backend Level (Still Needed)
```
Google Cloud Console
├─ OAuth 2.0 Client IDs
│  ├─ Android
│  │  ├─ Package: com.asetq_apps
│  │  ├─ SHA-1: [FROM KEYTOOL]
│  │  └─ ✅ Create this!
│  └─ Web
│      ├─ Client ID: 884256332175-...
│      └─ (already exists)

Firebase Console
├─ google-services.json
│  └─ Contains OAuth client reference
└─ ✅ Must be downloaded after creating OAuth client
```

---

## 📍 The 3 Key Pieces That Must Match

```
PIECE #1: Development Machine
┌────────────────────────────────────┐
│  Android Debug Keystore            │
│  SHA-1: AB:CD:EF:12:34:56...       │
│  (keytool output)                  │
└────────────────────────────────────┘
        │
        │ MUST MATCH
        ▼
PIECE #2: Google Cloud Console
┌────────────────────────────────────┐
│  OAuth Client (Android)            │
│  Package: com.asetq_apps           │
│  SHA-1: AB:CD:EF:12:34:56...       │
│  ✅ Created manually in console    │
└────────────────────────────────────┘
        │
        │ REFERENCES
        ▼
PIECE #3: Firebase
┌────────────────────────────────────┐
│  google-services.json              │
│  {                                 │
│    "oauth_client": [               │
│      {                             │
│        "client_id": "...",          │
│        "android_info": {           │
│          "package_name": "...",    │
│          "certificate_hash": "..." │
│        }                           │
│      }                             │
│    ]                               │
│  }                                 │
└────────────────────────────────────┘
```

**Jika salah satu tidak match = ERROR 10**

---

## 🎯 Step-by-Step with Verification

```
STEP 1: Get SHA-1
┌──────────────────────────────┐
│ $ keytool -list -v ...       │
│ SHA1: [COPY THIS]            │
└──────────────────────────────┘

STEP 2: Create OAuth Client
┌──────────────────────────────┐
│ Google Cloud Console         │
│ Create Credentials           │
│ OAuth 2.0 → Android          │
│ Package: com.asetq_apps      │
│ SHA-1: [PASTE FROM STEP 1]   │
│ ✅ CREATE                    │
└──────────────────────────────┘

STEP 3: Verify in Firebase
┌──────────────────────────────┐
│ Firebase Console             │
│ Project Settings             │
│ Your apps → com.asetq_apps   │
│ ✅ SHA-1 listed              │
└──────────────────────────────┘

STEP 4: Download JSON
┌──────────────────────────────┐
│ Firebase Console             │
│ Download google-services.json│
│ ✅ Contains oauth_client     │
└──────────────────────────────┘

STEP 5: Replace File
┌──────────────────────────────┐
│ android/app/                 │
│ Replace google-services.json │
│ ✅ Done                      │
└──────────────────────────────┘

STEP 6: Rebuild
┌──────────────────────────────┐
│ $ flutter clean              │
│ $ flutter run -v             │
│ ✅ Test Sign-In              │
└──────────────────────────────┘
```

---

## 🔍 What Each Error Code Means

| Code | Name | Meaning | Cause |
|------|------|---------|-------|
| **10** | **DEVELOPER_ERROR** | **OAuth config mismatch** | **OAuth Client not created in Google Cloud** |
| 11 | LICENSE_CHECKER_ERROR | License not found | App signature issue |
| 12 | NETWORK_ERROR | Network problem | No internet |
| 13 | INTERNAL_ERROR | Internal Google error | Temporary issue, try again |
| 14 | SERVICE_INVALID | Service invalid | Google Services version issue |

---

## 🧪 Testing Checklist

```
Before Testing:
□ SHA-1 from keytool
□ OAuth Client created in Google Cloud
□ google-services.json downloaded & replaced
□ flutter clean executed
□ App rebuilt

During Testing:
□ Click "Sign in with Google" button
□ Google dialog appears
□ No "Error 10" message
□ Select Google account
□ Permissions dialog appears
□ Accept permissions
□ Dialog closes
□ App shows "Login Successful"

Success Signs:
□ localStorage contains user_id
□ localStorage contains access_token
□ Page navigates to /home
□ Logcat shows ✅ messages (not ❌)

Failure Signs:
□ Sign-In dialog closes
□ Error message shows
□ Logcat shows Error 10
□ App returns to login screen
```

---

## 💡 Pro Tips

**Tip 1: Clear Google Account**
```powershell
adb shell pm clear com.google.android.gms
```
Restart app after this.

**Tip 2: Check Signing Certificate**
```powershell
# Verify app signing
jarsigner -verify -verbose build/app/outputs/apk/debug/app-debug.apk
```

**Tip 3: Logcat Filter**
```powershell
adb logcat | findstr "flutter|google|sign|ApiException"
```

**Tip 4: Double-Check SHA-1**
```powershell
# Verify SHA-1 from installed APK
$cert = (keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android)
$cert | findstr "SHA1"
```

---

**Reference:** 16 Januari 2026

