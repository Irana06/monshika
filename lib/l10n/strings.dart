import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Teks aplikasi dalam dua bahasa + saklar gaya Jepang.
///
/// Pakai `S.of(context)` di widget, lalu `s.t('Simpan', 'Save')`.
/// Di luar widget (notifikasi, widget beranda, background) pakai
/// `S.fromPrefs(prefs)` atau `S.current`.
class S {
  const S({this.en = false, this.jp = false});

  /// Bahasa Inggris aktif.
  final bool en;

  /// Tampilan bernuansa Jepang (ikon kanji & label Jepang) aktif.
  final bool jp;

  String get code => en ? 'en' : 'id';
  String get dateLocale => en ? 'en_US' : 'id_ID';
  Locale get locale => Locale(code);

  /// Pilih teks sesuai bahasa.
  String t(String id, String en) => this.en ? en : id;

  /// Label Jepang tambahan, hanya saat gaya Jepang aktif.
  String? jpText(String text) => jp ? text : null;

  /// Gabungkan label Jepang di depan label biasa bila gaya Jepang aktif.
  String withJp(String jpLabel, String label) => jp ? '$jpLabel $label' : label;

  static S current = const S();

  static S of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SScope>()?.s ?? current;

  static String defaultLanguage() => PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'id';

  static S fromPrefs(SharedPreferences p) => S(
        en: (p.getString('language') ?? defaultLanguage()) == 'en',
        jp: p.getBool('japaneseStyle') ?? false,
      );

  // ---------------------------------------------------------------------------
  // Teks umum
  // ---------------------------------------------------------------------------

  String get save => t('Simpan', 'Save');
  String get saveChanges => t('Simpan perubahan', 'Save changes');
  String get cancel => t('Batal', 'Cancel');
  String get delete => t('Hapus', 'Delete');
  String get edit => t('Ubah', 'Edit');
  String get add => t('Tambah', 'Add');
  String get done => t('Selesai', 'Done');
  String get ok => t('Oke', 'OK');
  String get next => t('Lanjut', 'Next');
  String get back => t('Kembali', 'Back');
  String get close => t('Tutup', 'Close');
  String get all => t('Semua', 'All');
  String get manage => t('Kelola', 'Manage');
  String get seeAll => t('Lihat semua', 'See all');
  String get archive => t('Arsipkan', 'Archive');
  String get active => t('Aktif', 'Active');
  String get color => t('Warna', 'Color');
  String get icon => t('Ikon', 'Icon');
  String get name => t('Nama', 'Name');
  String get note => t('Catatan', 'Note');
  String get noteOptional => t('Catatan (opsional)', 'Note (optional)');
  String get amount => t('Nominal', 'Amount');
  String get date => t('Tanggal', 'Date');
  String get currency => t('Mata uang', 'Currency');
  String get wallet => t('Dompet', 'Wallet');
  String get wallets => t('Dompet', 'Wallets');
  String get category => t('Kategori', 'Category');
  String get categories => t('Kategori', 'Categories');
  String get income => t('Pemasukan', 'Income');
  String get expense => t('Pengeluaran', 'Expense');
  String get transfer => t('Transfer', 'Transfer');
  String get today => t('Hari ini', 'Today');
  String get yesterday => t('Kemarin', 'Yesterday');
  String get tomorrow => t('Besok', 'Tomorrow');
  String get noCategory => t('Tanpa kategori', 'No category');
  String get chooseWallet => t('Pilih dompet', 'Choose wallet');
  String get chooseCategory => t('Pilih kategori', 'Choose category');
  String get noData => t('Belum ada data', 'No data yet');
  String get failed => t('Gagal', 'Failed');

  String typeLabel(String type) => switch (type) {
        'income' => income,
        'expense' => expense,
        _ => transfer,
      };

  String everyN(int n, String unit) => en ? (n == 1 ? 'Every $unit' : 'Every $n ${unit}s') : 'Tiap ${n > 1 ? '$n ' : ''}$unit';

  String freqUnit(String frequency) => switch (frequency) {
        'daily' => t('hari', 'day'),
        'weekly' => t('minggu', 'week'),
        'yearly' => t('tahun', 'year'),
        _ => t('bulan', 'month'),
      };

  String periodLabel(String period) => switch (period) {
        'weekly' => t('Mingguan', 'Weekly'),
        'yearly' => t('Tahunan', 'Yearly'),
        _ => t('Bulanan', 'Monthly'),
      };
}

/// Menyediakan [S] ke seluruh pohon widget.
class SScope extends InheritedWidget {
  const SScope({super.key, required this.s, required super.child});

  final S s;

  @override
  bool updateShouldNotify(SScope oldWidget) => oldWidget.s.en != s.en || oldWidget.s.jp != s.jp;
}
