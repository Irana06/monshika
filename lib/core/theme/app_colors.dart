// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

import 'package:flutter/material.dart';

/// Satu set warna dasar untuk satu mode tampilan.
///
/// Warna kategori di [WaColors] tidak ikut berubah antar mode, karena nilainya
/// tersimpan di database bersama tiap kategori, dompet, dan budget.
class WaPalette {
  const WaPalette({
    required this.brightness,
    required this.sumi,
    required this.keshizumi,
    required this.surfaceHigh,
    required this.border,
    required this.washi,
    required this.washiMuted,
    required this.washiFaint,
    required this.expense,
    required this.income,
    required this.transfer,
    required this.accent,
    required this.secondary,
    required this.heroTop,
    required this.heroBottom,
  });

  final Brightness brightness;

  /// Latar layar.
  final Color sumi;

  /// Latar kartu.
  final Color keshizumi;

  /// Latar yang sedikit lebih menonjol dari kartu.
  final Color surfaceHigh;

  final Color border;

  /// Teks utama.
  final Color washi;
  final Color washiMuted;
  final Color washiFaint;

  final Color expense;
  final Color income;
  final Color transfer;
  final Color accent;
  final Color secondary;

  /// Gradien kartu total saldo di beranda.
  final Color heroTop;
  final Color heroBottom;

  bool get isLight => brightness == Brightness.light;
}

/// Mode gelap, nuansa kayu dan kertas tua.
const kWaDark = WaPalette(
  brightness: Brightness.dark,
  sumi: Color(0xFF1C1411),
  keshizumi: Color(0xFF261B16),
  surfaceHigh: Color(0xFF33251F),
  border: Color(0xFF3D2C25),
  washi: Color(0xFFF7DECA),
  washiMuted: Color(0xFFC9AE9F),
  washiFaint: Color(0xFFA08B7D),
  expense: Color(0xFFE0605A),
  income: Color(0xFF9CC48F),
  transfer: Color(0xFF9C86C2),
  accent: Color(0xFFE35A57),
  secondary: Color(0xFF7E9AC8),
  heroTop: Color(0xFF3A2A21),
  heroBottom: Color(0xFF1F1612),
);

/// Mode terang, nuansa washi. Merah dan hijaunya digelapkan supaya kontrasnya
/// tetap terbaca di atas kertas terang.
const kWaLight = WaPalette(
  brightness: Brightness.light,
  sumi: Color(0xFFFBF5EF),
  keshizumi: Color(0xFFFFFCF9),
  surfaceHigh: Color(0xFFF5E9DE),
  border: Color(0xFFEDDCCD),
  washi: Color(0xFF35231C),
  washiMuted: Color(0xFF76625A),
  washiFaint: Color(0xFF9A8378),
  expense: Color(0xFFC0392F),
  income: Color(0xFF4F7A43),
  transfer: Color(0xFF6B52A3),
  accent: Color(0xFFD53B3A),
  secondary: Color(0xFF39508C),
  heroTop: Color(0xFFF9E7D6),
  heroBottom: Color(0xFFFFFCF9),
);

/// Palet "Wa" (和色), warna tradisional Jepang.
///
/// Warna dasarnya mengikuti [current], yang diganti saat mode tampilan berubah.
/// Pemanggilannya tetap `WaColors.sumi` seperti biasa.
abstract final class WaColors {
  static WaPalette current = kWaDark;

  static bool get isLight => current.isLight;

  // Dasar
  static Color get sumi => current.sumi;
  static Color get keshizumi => current.keshizumi;
  static Color get surfaceHigh => current.surfaceHigh;
  static Color get border => current.border;
  static Color get washi => current.washi;
  static Color get washiMuted => current.washiMuted;
  static Color get washiFaint => current.washiFaint;

  // Semantik
  static Color get expense => current.expense;
  static Color get income => current.income;
  static Color get transfer => current.transfer;
  static Color get accent => current.accent;
  static Color get secondary => current.secondary;
  static Color get heroTop => current.heroTop;
  static Color get heroBottom => current.heroBottom;

  // Palet kategori. Tetap sama di kedua mode karena tersimpan di database.
  static const beni = Color(0xFFD9534A);
  static const shu = Color(0xFFE8743B);
  static const kohaku = Color(0xFFC98B3C);
  static const kin = Color(0xFFC9A45C);
  static const yamabuki = Color(0xFFE6B422);
  static const matcha = Color(0xFF8DB580);
  static const wakatake = Color(0xFF5DA487);
  static const asagi = Color(0xFF3E9BA8);
  static const ai = Color(0xFF3E5C8A);
  static const ruri = Color(0xFF4C6CB3);
  static const fuji = Color(0xFF9C86C2);
  static const sakura = Color(0xFFE8A6B5);
  static const momiji = Color(0xFFB5453A);
  static const nezumi = Color(0xFF8C8C96);
  static const cha = Color(0xFF8B6F4E);

  static const palette = <Color>[
    beni, shu, kohaku, kin, yamabuki, matcha, wakatake, asagi,
    ai, ruri, fuji, sakura, momiji, nezumi, cha,
  ];

  static const paletteNames = <String>[
    '紅 Beni', '朱 Shu', '琥珀 Kohaku', '金 Kin', '山吹 Yamabuki', '抹茶 Matcha', '若竹 Wakatake',
    '浅葱 Asagi', '藍 Ai', '瑠璃 Ruri', '藤 Fuji', '桜 Sakura', '紅葉 Momiji', '鼠 Nezumi', '茶 Cha',
  ];

  /// Warna kategori dibuat agak gelap di mode terang supaya tetap terbaca
  /// di atas latar kertas.
  static Color onSurface(Color c) {
    if (!isLight) return c;
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness * 0.74).clamp(0.0, 1.0)).toColor();
  }

  static Color forType(String type) => switch (type) {
        'income' => income,
        'expense' => expense,
        _ => transfer,
      };
}
