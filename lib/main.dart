// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'data/database/database.dart';
import 'features/quick_add/quick_add_app.dart';
import 'l10n/strings.dart';
import 'providers/providers.dart';
import 'services/feedback_service.dart';

Future<ProviderScope> _bootstrap(Widget child) async {
  WidgetsFlutterBinding.ensureInitialized();
  FeedbackService.install();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  S.current = S.fromPrefs(prefs);
  WaColors.current = AppSettings.paletteFromPrefs(prefs);
  Intl.defaultLocale = S.current.dateLocale;
  final db = AppDatabase();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
    child: child,
  );
}

Future<void> main() async {
  runApp(await _bootstrap(const MonshikaApp()));
}

/// Entrypoint terpisah untuk dialog catat cepat yang dibuka dari widget beranda
/// (QuickAddActivity di Android), tampil transparan di atas home screen.
@pragma('vm:entry-point')
Future<void> quickAddMain() async {
  runApp(await _bootstrap(const QuickAddApp()));
}
