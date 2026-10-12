// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static TextStyle serif({double? size, FontWeight? weight, Color? color, double? height, double? letterSpacing}) =>
      GoogleFonts.shipporiMincho(
        fontSize: size,
        fontWeight: weight,
        color: color ?? WaColors.washi,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle sans({double? size, FontWeight? weight, Color? color, double? height}) =>
      GoogleFonts.zenKakuGothicNew(fontSize: size, fontWeight: weight, color: color ?? WaColors.washi, height: height);

  /// Tema untuk palet yang sedang aktif di [WaColors.current].
  ///
  /// Pemanggilnya menyetel [WaColors.current] lebih dulu, jadi satu fungsi ini
  /// melayani mode terang maupun gelap.
  static ThemeData build() {
    final p = WaColors.current;
    final dark = !p.isLight;

    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: dark ? p.sumi : const Color(0xFFFFFCF9),
      secondary: p.secondary,
      onSecondary: dark ? p.washi : const Color(0xFFFFFCF9),
      tertiary: WaColors.beni,
      onTertiary: const Color(0xFFFFFCF9),
      error: p.expense,
      onError: dark ? p.sumi : const Color(0xFFFFFCF9),
      surface: p.sumi,
      onSurface: p.washi,
      surfaceContainerLowest: p.sumi,
      surfaceContainerLow: p.keshizumi,
      surfaceContainer: p.keshizumi,
      surfaceContainerHigh: p.surfaceHigh,
      surfaceContainerHighest: p.border,
      onSurfaceVariant: p.washiMuted,
      outline: p.border,
      outlineVariant: p.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: p.brightness);
    final body = GoogleFonts.zenKakuGothicNewTextTheme(base.textTheme).apply(
      bodyColor: p.washi,
      displayColor: p.washi,
    );
    final text = body.copyWith(
      displayLarge: serif(size: 48, weight: FontWeight.w600),
      displayMedium: serif(size: 38, weight: FontWeight.w600),
      displaySmall: serif(size: 30, weight: FontWeight.w600),
      headlineLarge: serif(size: 28, weight: FontWeight.w600),
      headlineMedium: serif(size: 24, weight: FontWeight.w600),
      headlineSmall: serif(size: 20, weight: FontWeight.w600),
      titleLarge: serif(size: 19, weight: FontWeight.w600),
    );

    final radius = BorderRadius.circular(16);
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return base.copyWith(
      scaffoldBackgroundColor: p.sumi,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: p.sumi,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: serif(size: 20, weight: FontWeight.w600),
        systemOverlayStyle: overlay.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: p.sumi,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.keshizumi,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.keshizumi,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.accent)),
        labelStyle: TextStyle(color: p.washiMuted),
        hintStyle: TextStyle(color: p.washiFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: dark ? p.sumi : const Color(0xFFFFFCF9),
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: sans(size: 15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.washi,
          minimumSize: const Size(48, 50),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.accent)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: dark ? p.sumi : const Color(0xFFFFFCF9),
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.keshizumi,
        selectedColor: p.accent.withValues(alpha: 0.22),
        side: BorderSide(color: p.border),
        labelStyle: sans(size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.keshizumi,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.keshizumi,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: serif(size: 20, weight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: sans(size: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.keshizumi,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(sans(size: 11, weight: FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.accent : p.washiMuted),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent.withValues(alpha: 0.2) : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : p.washiMuted,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (dark ? p.sumi : const Color(0xFFFFFCF9)) : p.washiMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHigh,
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: p.washiMuted, textColor: p.washi),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
