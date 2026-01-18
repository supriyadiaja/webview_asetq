# 🔧 Perbaikan Google Sign-In Error 10 (DEVELOPER_ERROR)

## ❌ Masalah yang Ditemukan:
1. **Error 10 di Google Sign-In** = DEVELOPER_ERROR, berarti Firebase belum memiliki OAuth Client untuk Android
2. **SHA-1 Certificate mismatch** antara konfigurasi lokal dan Firebase
3. **Pull-to-Refresh** tidak responsif karena timing issue

---

## ✅ SOLUSI LENGKAP

### **STEP 1: Dapatkan SHA-1 Certificate Fingerprint**

Jalankan command ini di PowerShell:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**CATAT SHA1 yang muncul**, contoh format:
```
XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

---

### **STEP 2: Update Firebase Console**

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Pilih project **asetq-2026**
3. Klik menu **Settings** (⚙️) → **Project Settings**
4. Pilih tab **Service Accounts**
5. Klik tombol **Generate New Private Key** (optional, untuk test later)
6. Kembali ke **Project Settings** → **App Registration**
7. Cari Android app **com.asetq_apps** → Klik edit
8. Scroll ke bagian **SHA certificate fingerprints**
9. Klik **Add fingerprint**
10. **Paste SHA-1 dari step 1** (gunakan format: `XX:XX:XX:XX:...`)
11. **Klik Save**

---

### **STEP 3: Generate New google-services.json**

Setelah menambah SHA-1:

1. Di Firebase Console, pergi ke **Project Settings** 
2. Download file `google-services.json` terbaru
3. **Replace** file lama di: `android/app/google-services.json`
4. File baru akan include **OAuth Client ID untuk Android**

---

### **STEP 4: Clean & Rebuild Flutter App**

```powershell
cd g:\05. PANCAR\webview_asetq

# ✅ Clean build
flutter clean

# ✅ Get dependencies
flutter pub get

# ✅ Build APK/Run app
flutter run -v
```

---

## 📝 File yang Sudah Diperbaiki:

### ✅ `lib/main.dart`
- ✅ Tambah `_initializeGoogleSignIn()` untuk set clientId dengan benar
- ✅ Improve `_handleGoogleSignIn()` dengan better error handling & debug logs
- ✅ Fix `_handleRefresh()` dengan await untuk page loading

### ✅ `android/app/build.gradle`
- ✅ Tambah explicit `signingConfigs` untuk debug & release
- ✅ Ensure signing config applied ke both buildTypes

---

## 🔍 Debugging: Cek Error Detail

Kalau masih error, jalankan dengan verbose logging:

```powershell
flutter run -v 2>&1 | tee flutter_log.txt
```

Carilah pattern:
- ❌ **`ApiException: 10`** = SHA-1 mismatch atau OAuth Client belum dibuat
- ❌ **`sign_in_failed`** = Network issue atau backend error
- ✅ **`sign_in successful`** = Bekerja!

---

## 📋 Checklist Verification

- [ ] SHA-1 dari debug.keystore sudah ditambah ke Firebase
- [ ] google-services.json sudah di-download ulang dan replace
- [ ] google-services.json sudah include `oauth_client` dengan Android client ID
- [ ] `flutter clean` sudah dijalankan
- [ ] App sudah di-rebuild
- [ ] Check logs untuk message "✅ Google Sign-In successful"

---

## 🎯 Expected Success Signs

Ketika berhasil, di logcat akan muncul:

```
✅ Google Sign-In successful: user@gmail.com
🔑 Auth info obtained, sending to backend...
Login Successful!
```

---

## ⚠️ Jika Masih Gagal

**Kemungkinan penyebab:**

1. **Typo di package name** - Harus EXACTLY `com.asetq_apps`
2. **Multiple SHA-1** - Ada lebih dari satu Android app di Firebase? Pastikan cek yang benar
3. **Timestamp issue** - Hapus app dari device, rebuild, re-install
4. **Backend issue** - Check if `https://aset.pncr-tech.com/api/auth-google.php` returns valid response

**Minta bantuan dengan include:**
- Output dari `keytool -list -v -keystore ...`
- Screenshot dari Firebase Console (SHA-1 fingerprints section)
- Full error log dari `flutter run -v`

---

**Update:** 16 Januari 2026 ✅
