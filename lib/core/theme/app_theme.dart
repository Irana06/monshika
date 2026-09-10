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

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: WaColors.accent,
      onPrimary: WaColors.sumi,
      secondary: WaColors.secondary,
      onSecondary: WaColors.washi,
      tertiary: WaColors.beni,
      onTertiary: WaColors.washi,
      error: WaColors.expense,
      onError: WaColors.sumi,
      surface: WaColors.sumi,
      onSurface: WaColors.washi,
      surfaceContainerLowest: WaColors.sumi,
      surfaceContainerLow: WaColors.keshizumi,
      surfaceContainer: WaColors.keshizumi,
      surfaceContainerHigh: WaColors.surfaceHigh,
      surfaceContainerHighest: WaColors.border,
      onSurfaceVariant: WaColors.washiMuted,
      outline: WaColors.border,
      outlineVariant: WaColors.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
    final body = GoogleFonts.zenKakuGothicNewTextTheme(base.textTheme).apply(
      bodyColor: WaColors.washi,
      displayColor: WaColors.washi,
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

    return base.copyWith(
      scaffoldBackgroundColor: WaColors.sumi,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: WaColors.sumi,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: serif(size: 20, weight: FontWeight.w600),
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: WaColors.sumi,
        ),
      ),
      cardTheme: CardThemeData(
        color: WaColors.keshizumi,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: WaColors.border)),
      ),
      dividerTheme: const DividerThemeData(color: WaColors.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WaColors.keshizumi,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WaColors.border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WaColors.border)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: WaColors.accent)),
        labelStyle: const TextStyle(color: WaColors.washiMuted),
        hintStyle: const TextStyle(color: WaColors.washiFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WaColors.accent,
          foregroundColor: WaColors.sumi,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: sans(size: 15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WaColors.washi,
          minimumSize: const Size(48, 50),
          side: const BorderSide(color: WaColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: WaColors.accent)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: WaColors.beni,
        foregroundColor: WaColors.washi,
        shape: CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: WaColors.keshizumi,
        selectedColor: WaColors.accent.withValues(alpha: 0.22),
        side: const BorderSide(color: WaColors.border),
        labelStyle: sans(size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WaColors.keshizumi,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WaColors.keshizumi,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: serif(size: 20, weight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WaColors.surfaceHigh,
        contentTextStyle: sans(size: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WaColors.keshizumi,
        surfaceTintColor: Colors.transparent,
        indicatorColor: WaColors.accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(sans(size: 11, weight: FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? WaColors.accent : WaColors.washiMuted),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide(color: WaColors.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? WaColors.accent.withValues(alpha: 0.2) : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? WaColors.accent : WaColors.washiMuted,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? WaColors.sumi : WaColors.washiMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? WaColors.accent : WaColors.surfaceHigh,
        ),
      ),
      listTileTheme: const ListTileThemeData(iconColor: WaColors.washiMuted, textColor: WaColors.washi),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: WaColors.accent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
