# Setup widget iOS

Target widget iOS harus ditambahkan lewat Xcode, jadi butuh Mac. Source-nya sudah tersedia di `ios/MonshikaWidget/MonshikaWidget.swift`.

## 1. App Group

1. Buka `ios/Runner.xcworkspace` di Xcode.
2. Pilih target **Runner**, buka tab *Signing & Capabilities*, klik **+ Capability**, lalu pilih **App Groups**.
3. Tambahkan `group.com.shicomp.monshika`.

Aplikasi Flutter sudah memanggil `HomeWidget.setAppGroupId('group.com.shicomp.monshika')`.

## 2. Widget Extension

1. Buka **File › New › Target**, pilih **Widget Extension**, dan beri nama `MonshikaWidget`. Matikan *Include Live Activity* dan *Include Configuration App Intent*.
2. Hapus file Swift yang dibuat otomatis, lalu tambahkan `ios/MonshikaWidget/MonshikaWidget.swift` ke target `MonshikaWidget`.
3. Pada target **MonshikaWidget**, tambahkan capability **App Groups** dengan grup yang sama.
4. Set *Deployment Target* extension ke iOS 16 atau lebih baru.

## 3. Deep link

Tambahkan URL scheme `monshika` ke `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>monshika</string>
    </array>
  </dict>
</array>
```

Tombol widget membuka `monshika://add?type=expense&homeWidget`. Link ini ditangani `HomeWidget.widgetClicked` di `lib/app.dart`, lalu membuka form transaksi.

## 4. Google Sign-In (Drive)

Buat OAuth client tipe **iOS** di project `monshika` (bundle id `com.shicomp.monshika`), lalu:

- build dengan `--dart-define=GOOGLE_IOS_CLIENT_ID=...` dan `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
- tambahkan *reversed client ID* (`com.googleusercontent.apps.xxxx`) ke `CFBundleURLSchemes`

## Catatan

- Di iOS, nama widget (`kind`) sama dengan nama kelas provider Android, sehingga `HomeWidget.updateWidget(iOSName: ...)` langsung memperbarui semuanya.
- Preset sekali tap di iOS butuh App Intents (iOS 17) dan `HomeWidgetBackgroundWorker`. Versi ini memakai deep link ke form transaksi.
