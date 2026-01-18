# 🎬 NEXT ACTIONS - Google Sign-In Fix

**Current Status:** ✅ Code Fixed | 🔄 Waiting for Firebase Setup

---

## 📌 WHAT YOU NEED TO DO RIGHT NOW

### Action #1: Get Your SHA-1 Certificate (5 minutes)

**Open PowerShell and run:**

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Find this in the output:**
```
Certificate Fingerprints:
     SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
```

✅ **Copy the SHA1 value** (the part after SHA1: )

---

### Action #2: Create Android OAuth Client in Google Cloud (10 minutes)

**Go to:** https://console.cloud.google.com/apis/credentials

1. Make sure **asetq-2026** project is selected (top dropdown)
2. Click **Create Credentials** → **OAuth 2.0 Client IDs**
3. Choose **Android**
4. Fill the form:
   - **Package name:** `com.asetq_apps`
   - **SHA-1 certificate fingerprint:** (paste your SHA1 from Action #1)
5. Click **Create**

✅ **You should see a confirmation message**

---

### Action #3: Download Updated google-services.json (5 minutes)

**Go to:** https://console.firebase.google.com/project/asetq-2026

1. Click **Project Settings** (⚙️ icon)
2. Scroll down to **Your apps** section
3. Find and click **com.asetq_apps** app
4. Click **Download google-services.json** button
5. This downloads the updated JSON file

✅ **Now replace the old file:**
- Delete old file: `android/app/google-services.json`
- Copy downloaded file to: `android/app/google-services.json`

---

### Action #4: Rebuild and Test (5 minutes)

**Open PowerShell in project directory:**

```powershell
cd "g:\05. PANCAR\webview_asetq"

# Build again (clean already done before)
flutter pub get
flutter run -v
```

**Then in the app:**
1. Wait for page to fully load
2. Click **"Sign in with Google"** button
3. Select your Google account
4. Accept permissions

✅ **Expected result:**
- Sign-In dialog opens
- No error (previously showed "Error 10")
- Redirects to home page

❌ **If still shows Error 10:**
- Check if google-services.json was replaced
- Check if SHA-1 is exactly correct (case-sensitive!)
- Check if file saved to correct location

---

## 🎯 Total Time Required

| Task | Time |
|------|------|
| Get SHA-1 | 2 min |
| Create OAuth | 5 min |
| Download JSON | 2 min |
| Replace file | 1 min |
| Rebuild | 5 min |
| Test | 2 min |
| **TOTAL** | **~17 minutes** |

---

## 📋 Verification Before Each Step

**Before creating OAuth Client:**
- [ ] I have copied the SHA1 value
- [ ] SHA1 format is correct (with colons: AB:CD:EF...)

**Before downloading JSON:**
- [ ] OAuth Client created successfully
- [ ] Google Cloud shows no errors

**Before rebuilding:**
- [ ] google-services.json downloaded
- [ ] Old file replaced with new one
- [ ] File is in `android/app/google-services.json`

**Before testing:**
- [ ] `flutter pub get` completed
- [ ] App successfully built and installed
- [ ] Page fully loaded in WebView

---

## 💬 What to Tell Me If It Fails

If you still get Error 10 after all steps, send me:

1. **Screenshot of Firebase Console** (Your apps section)
2. **First 50 lines of google-services.json** (to verify oauth_client is there)
3. **Output from keytool command**
4. **Full logcat output** when trying to sign in:
   ```powershell
   flutter run -v 2>&1 | Tee-Object -FilePath log.txt
   # Then search for "google_sign_in" or "Error"
   ```

---

## 📚 Reference Files

If you need help, read these:
- 📄 `FIREBASE_OAUTH_SETUP.md` - Detailed step-by-step
- 📄 `FLOW_DIAGRAM.md` - Visual explanation
- 📄 `QUICK_FIX_CHECKLIST.md` - Quick reference
- 📄 `DEBUGGING_GUIDE.md` - If still having issues

---

## ✨ What Happens After This Works

Once OAuth is configured:
1. ✅ Google Sign-In will work
2. ✅ Pull-to-Refresh will work (already fixed in code)
3. ✅ App ready for production testing
4. ✅ Can proceed with other features

---

## 🚀 Ready?

Start with **Action #1** (Get SHA-1) and let me know when done!

Each action should take < 5 minutes.

After all 4 actions, test Google Sign-In and tell me the result!

---

**Good luck! 💪**

