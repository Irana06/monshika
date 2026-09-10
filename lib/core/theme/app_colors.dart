import 'package:flutter/material.dart';

/// Palet "Yoru" — warna tradisional Jepang (和色) dalam nuansa malam.
abstract final class WaColors {
  // Dasar
  static const sumi = Color(0xFF0F0F14); // 墨 latar
  static const keshizumi = Color(0xFF17171E); // 消炭 kartu
  static const surfaceHigh = Color(0xFF1F1F28);
  static const border = Color(0xFF2A2A35);
  static const washi = Color(0xFFEDE6D6); // 和紙 teks
  static const washiMuted = Color(0xFF9A948A);
  static const washiFaint = Color(0xFF5E5A55);

  // Semantik
  static const expense = Color(0xFFE0605A); // 紅 beni (lebih terang untuk mode gelap)
  static const income = Color(0xFF9CC48F); // 抹茶 matcha
  static const transfer = Color(0xFF9C86C2); // 藤 fuji
  static const accent = Color(0xFFC9A45C); // 金 kin
  static const secondary = Color(0xFF5B7DB1); // 藍 ai

  // Palet kategori
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

  static Color forType(String type) => switch (type) {
        'income' => income,
        'expense' => expense,
        _ => transfer,
      };
}
