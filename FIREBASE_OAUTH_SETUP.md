# 🔧 Firebase OAuth Setup untuk Error 10 (DEVELOPER_ERROR)

## 📋 Status Saat Ini

✅ **Kode sudah fixed:**
- Changed dari `clientId` → `serverClientId`
- Added full scopes untuk Google API
- Improved error handling

❌ **Yang masih perlu:**
- Firebase belum memiliki OAuth Client untuk Android

---

## 🚀 STEP-BY-STEP FIX (WAJIB DILAKUKAN)

### **LANGKAH 1: Dapatkan SHA-1 Certificate**

Buka PowerShell dan jalankan:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Lihat output SHA1, contoh:**
```
Certificate Fingerprints:
     SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
```

**✅ CATAT SHA1 INI!** (Akan digunakan di Firebase)

---

### **LANGKAH 2: Akses Firebase Console**

1. Buka: [https://console.firebase.google.com](https://console.firebase.google.com)
2. Pilih project: **asetq-2026**
3. Di sidebar kiri, klik **⚙️ Project Settings** (gear icon)

---

### **LANGKAH 3: Tambah OAuth Client untuk Android**

**Opsi A: Via Project Settings (RECOMMENDED)**

1. Di Project Settings, pilih tab **⚙️ Service Accounts**
2. Scroll ke bawah, lihat section **"Android OAuth Client"**
3. Klik **"Add App"** jika belum ada Android app

**Opsi B: Via Google Cloud Console (Backup)**

Jika tidak ada di Firebase Console:

1. Buka: [https://console.cloud.google.com](https://console.cloud.google.com)
2. Pilih project: **asetq-2026**
3. Klik menu: **APIs & Services** → **Credentials**
4. Klik **Create Credentials** → **OAuth 2.0 Client IDs**
5. Pilih **Android**
6. Isi form:
   - **Package name**: `com.asetq_apps`
   - **SHA-1 certificate fingerprint**: (paste SHA1 dari LANGKAH 1)
7. Klik **Create**

---

### **LANGKAH 4: Verify di Firebase Console**

Kembali ke Firebase Console:

1. Buka: [https://console.firebase.google.com](https://console.firebase.google.com)
2. Pilih project **asetq-2026**
3. Klik menu **Project Settings** (⚙️)
4. Scroll ke section **"Your apps"**
5. Cari app **com.asetq_apps**
6. Klik pada app tersebut
7. Di section **"SHA certificate fingerprints"**, pastikan SHA-1 sudah ada

---

### **LANGKAH 5: Download google-services.json Baru**

1. Di Project Settings → Your apps
2. Pilih app **com.asetq_apps**
3. Klik **Download google-services.json**
4. **Replace** file lama di: `android/app/google-services.json`

**Verify file berisi:**
```json
{
  "client": [
    {
      "oauth_client": [
        {
          "client_id": "xxx.apps.googleusercontent.com",
          "client_type": 3,
          "android_info": {
            "package_name": "com.asetq_apps",
            "certificate_hash": "abcdef123456"
          }
        }
      ]
    }
  ]
}
```

Jika tidak ada `oauth_client`, berarti setup di Google Cloud Console belum berhasil!

---

### **LANGKAH 6: Clean & Rebuild**

```powershell
cd g:\05. PANCAR\webview_asetq

# Hapus semua cache
flutter clean
rm -r android/build -Force
rm -r build -Force

# Get dependencies baru
flutter pub get

# Build & run dengan verbose
flutter run -v
```

---

## ✅ Verification Checklist

- [ ] SHA-1 certificate sudah dicopy dari keytool
- [ ] OAuth Client sudah dibuat di Google Cloud Console
- [ ] Firebase Console menampilkan Android OAuth Client
- [ ] google-services.json sudah di-download (verify ada `oauth_client`)
- [ ] google-services.json sudah di-replace di `android/app/`
- [ ] `flutter clean` sudah dijalankan
- [ ] App sudah di-rebuild

---

## 🎯 Expected Success Signs

Setelah fix, logcat harus menampilkan:

```
✅ GoogleSignIn initialized with serverClientId
🔵 Starting Google Sign-In...
✅ Google Sign-In successful: user@gmail.com
🔑 Auth info obtained, sending to backend...
```

**BUKAN:**
```
❌ Error during sign-in: PlatformException(sign_in_failed, 
com.google.android.gms.common.api.ApiException: 10: , null, null)
```

---

## 🔍 Troubleshooting

### Issue: "Still getting Error 10"

**Penyebab #1: google-services.json tidak di-download ulang**
- ✅ Solution: Download lagi dari Firebase Console

**Penyebab #2: SHA-1 di Firebase tidak match dengan development key**
- ✅ Solution: Verify SHA-1 di keytool sama dengan di Firebase

**Penyebab #3: OAuth Client belum dibuat di Google Cloud**
- ✅ Solution: Buat di Google Cloud Console → APIs & Services → Credentials

### Issue: "OAuth Client tidak muncul di Firebase Console"

**Kemungkinan:**
- OAuth Client dibuat di Google Cloud tapi belum link ke Firebase
- Firebase project tidak link ke Google Cloud project yang benar

**Solution:**
- Di Firebase Project Settings → Integrations → Google Cloud Console
- Pastikan link ke project **asetq-2026**

---

## 📞 Jika Masih Stuck

Provide ke saya:

1. **Screenshot Firebase Console** (Project Settings → Your apps → com.asetq_apps)
2. **Contents google-services.json** (khususnya bagian `oauth_client`)
3. **Full error log dari logcat** saat klik Google Sign-In button
4. **Output dari keytool command** (SHA1 value)

---

**Next Steps:** 
Setelah selesai step-by-step ini, coba `flutter run -v` lagi dan lihat apakah error 10 sudah hilang!

Kalau masih error, share screenshot/log dengan saya.

---

**Last Updated:** 16 Januari 2026
