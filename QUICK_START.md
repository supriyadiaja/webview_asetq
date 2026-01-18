# ⚡ QUICK START - Fix dalam 15 Menit

**Estimasi waktu:** 15-20 menit total

---

## 🎯 TL;DR (Too Long; Didn't Read)

✅ **Saya sudah perbaiki:**
- Google Sign-In code (serverClientId)
- Pull-to-Refresh logic
- Build configuration

❌ **Yang masih perlu Anda lakukan:**
- Buat OAuth Client di Google Cloud
- Download google-services.json baru
- Replace file & rebuild

---

## ⚡ LANGKAH CEPAT (Copy-Paste)

### Step 1: Terminal 1 - Get SHA-1 (Copy hasil ini)

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Lihat output, CATAT nilai SHA1** (format: `AB:CD:EF:...`)

---

### Step 2: Browser - Create OAuth

Buka: https://console.cloud.google.com/apis/credentials

1. Top dropdown: select **asetq-2026**
2. **Create Credentials** → **OAuth 2.0 Client IDs** → **Android**
3. Fill:
   - Package name: `com.asetq_apps`
   - SHA-1: (paste dari Step 1)
4. **Create**

---

### Step 3: Browser - Download JSON

Buka: https://console.firebase.google.com/project/asetq-2026

1. ⚙️ **Project Settings**
2. Scroll: **Your apps** → **com.asetq_apps**
3. Click **Download google-services.json**
4. Delete old file: `android/app/google-services.json`
5. Copy downloaded file ke: `android/app/google-services.json`

---

### Step 4: Terminal 2 - Rebuild

```powershell
cd "g:\05. PANCAR\webview_asetq"
flutter pub get
flutter run -v
```

**Selesai!** 🎉

---

## ✅ VERIFICATION

Setelah selesai, lihat logcat:

✅ **Success sign:**
```
✅ GoogleSignIn initialized with serverClientId
🔵 Starting Google Sign-In...
✅ Google Sign-In successful: [email]
```

❌ **Jika masih Error 10:**
- SHA-1 tidak match (verify kesamaan character)
- google-services.json belum replace (check file di android/app/)
- Coba `flutter clean` lalu `flutter run -v` lagi

---

## 📱 Testing in App

1. Tunggu page load selesai
2. Klik **"Sign in with Google"** button
3. Pilih akun Google
4. Accept permissions
5. Harus masuk ke home (tidak ada error)

---

## 🔄 Pull-to-Refresh Test

1. Tunggu page load selesai
2. Swipe down dari atas screen
3. Spinner muncul
4. Page reload
5. Spinner hilang = **WORKING** ✅

---

## 💡 Pro Tips

**Tip 1: Stuck di Step 2?**
- Pastikan project **asetq-2026** dipilih di Google Cloud
- Harus login dengan akun yang memiliki Firebase project

**Tip 2: Stuck di Step 3?**
- Download file baru (bukan cache lama)
- Verify file ada di `android/app/google-services.json`
- Check: file contains `oauth_client` entry

**Tip 3: Still Error 10 after all steps?**
- Try: `flutter clean` → `flutter run -v`
- Check: SHA-1 adalah EXACTLY sama
- Check: No typo di package name `com.asetq_apps`

---

## ⏱️ TIME BREAKDOWN

- Step 1 (Get SHA-1): **2 min**
- Step 2 (OAuth): **5 min**
- Step 3 (JSON): **3 min**
- Step 4 (Rebuild): **5 min**
- **TOTAL: ~15 minutes**

---

## 📞 BUTUH BANTUAN?

Jika stuck, buka file ini:
- `NEXT_ACTIONS.md` - Detailed version
- `FIREBASE_OAUTH_SETUP.md` - Super detailed
- `DEBUGGING_GUIDE.md` - Troubleshooting

---

## ✨ SETELAH SELESAI

Anda akan mendapat:
- ✅ Google Sign-In working
- ✅ Pull-to-Refresh working  
- ✅ App ready untuk production
- ✅ No more Error 10

---

**Ready? Start dengan Step 1 sekarang!** 🚀

