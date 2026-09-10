# Monshika · 紋鹿

> お金を、心穏やかに。 — *Kelola uang dengan tenang.*

Monshika adalah aplikasi pengelola keuangan pribadi bernuansa Jepang dengan tema gelap.
Semua data tersimpan **lokal di HP**, dengan backup terenkripsi opsional ke **Google Drive milikmu sendiri**.
Dilengkapi **8 widget beranda**: catat pemasukan/pengeluaran langsung dari home screen tanpa membuka aplikasi.

Dibuat oleh **Shicomp**.

---

## Fitur

### Pencatatan
- **Multi-dompet**: tunai, bank, e-wallet, kartu kredit (dengan limit), paylater, tabungan, investasi
- **Transaksi**: pemasukan, pengeluaran, transfer antar dompet (beda mata uang + biaya admin)
- **Kalkulator** di form nominal (`20000 + 5000 × 2`)
- **Catat cepat berbasis teks**: `kopi 25rb`, `gojek 18.500 ovo`, `+8jt gaji`. Nominal, kategori, dan dompet dikenali otomatis
- **Preset sekali tap** (dipakai juga di widget)
- Kategori & sub-kategori berikon **kanji**, **tag**, catatan, penerima, **foto struk**
- **Split bill** (割り勘): bagianmu jadi pengeluaran, bagian teman otomatis jadi piutang
- Animasi cap **hanko** (判子) setiap transaksi tersimpan

### Perencanaan
- **Budget** mingguan/bulanan/tahunan per kategori, dengan rollover, ambang peringatan, dan proyeksi
- **Target tabungan** berbentuk **omamori** (お守り), plus rekomendasi setoran per bulan/minggu
- **Utang & piutang** dengan pembayaran bertahap dan jatuh tempo
- **Transaksi berulang & langganan**: dicatat otomatis atau lewat konfirmasi, lengkap dengan total biaya langganan per bulan
- **Cicilan** (kartu kredit, paylater, KPR) dengan kalkulator bunga flat
- **Kakeibo** (家計簿): rencana awal bulan, 4 pilar pengeluaran, dan refleksi akhir bulan
- **Sisa aman per hari**: berapa yang aman dibelanjakan hari ini

### Analisis
- Ringkasan & perbandingan 6 periode, rasio menabung, rata-rata harian
- Donut per kategori (bisa ditelusuri), tren kumulatif vs periode lalu, pola per hari dalam seminggu
- **Kalender heatmap** pengeluaran
- **Kekayaan bersih** 12 bulan & komposisi aset
- Streak mencatat (連続)

### Mata uang
- Multi-mata uang per dompet, dengan konversi otomatis ke mata uang utama
- **Kurs realtime** dari Coinbase dan [currency-api](https://github.com/fawazahmed0/exchange-api): 200+ mata uang, **emas (gram)**, perak, dan kripto
- Kurs manual (mis. kurs money changer)

### Data & keamanan
- Database **SQLite** lokal (Drift), bisa dipakai offline
- **Backup Google Drive** ke `appDataFolder` (scope `drive.appdata`, tidak bisa membaca file lain), bisa otomatis harian/mingguan
- Enkripsi backup **AES-256-GCM** dengan sandi (PBKDF2)
- Export **CSV / Excel / PDF**, import CSV
- Kunci **PIN** & **sidik jari/wajah**, mode sembunyikan saldo
- Notifikasi: pengingat harian, tagihan jatuh tempo, peringatan budget

## Widget beranda (Android)

| Widget | Ukuran | Fungsi |
|---|---|---|
| Catat Cepat | 2×1 | − / 速 / + membuka dialog transparan di atas beranda |
| Ringkasan | 4×2 | Total saldo, arus kas bulan ini, sisa aman, tombol cepat |
| Sisa Aman | 2×2 | Jatah belanja yang tersisa hari ini |
| Grafik | 4×2 | Grafik 7 hari + kategori terbesar |
| Preset | 4×1 | Sekali tap langsung tercatat di latar belakang |
| Budget | 4×2 | 3 budget dengan pemakaian tertinggi |
| Tagihan | 4×2 | Tagihan, cicilan & jatuh tempo 14 hari |
| Target | 2×2 | Progres target tabungan yang disematkan |

Widget iOS (WidgetKit) tersedia di [`ios/MonshikaWidget`](ios/MonshikaWidget). Lihat [docs/IOS_WIDGET_SETUP.md](docs/IOS_WIDGET_SETUP.md).

## Tech stack

Flutter · Riverpod 3 · Drift (SQLite) · fl_chart · home_widget · workmanager · google_sign_in + Drive API v3 · flutter_local_notifications · local_auth · cryptography · pdf / excel / csv

## Struktur

```
lib/
  core/        tema (palet 和色), util uang & tanggal, parser input cepat, UI kit (ensō, seigaiha, hanko)
  data/        skema & query database (Drift)
  providers/   state Riverpod
  services/    kurs, backup, Google Drive, export, notifikasi, widget, background task
  features/    layar-layar aplikasi
android/app/src/main/kotlin/.../widgets   widget beranda native
```

## Menjalankan

```bash
flutter pub get
dart run build_runner build
flutter run
```

### Google Drive (opsional)

Isi Client ID OAuth tipe **Web application** saat build:

```bash
flutter build apk --release --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
```

Di Google Cloud Console (project `monshika`): aktifkan **Google Drive API**, lalu buat OAuth client **Android** (package `com.shicomp.monshika` + SHA-1 keystore) dan client **Web application**.

### Build release

Buat `android/key.properties` (tidak di-commit):

```properties
storePassword=...
keyPassword=...
keyAlias=monshika
storeFile=E:/path/ke/monshika-release.jks
```

```bash
flutter build apk --release
```

---

© 2026 Shicomp
