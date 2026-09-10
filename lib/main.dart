import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'features/quick_add/quick_add_app.dart';
import 'providers/providers.dart';

Future<ProviderScope> _bootstrap(Widget child) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  Intl.defaultLocale = 'id_ID';
  final prefs = await SharedPreferences.getInstance();
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

/// Entrypoint terpisah untuk dialog quick-add yang dibuka dari widget beranda
/// (QuickAddActivity di Android) — tampil transparan di atas home screen.
@pragma('vm:entry-point')
Future<void> quickAddMain() async {
  runApp(await _bootstrap(const QuickAddApp()));
}
