import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/database/database.dart';
import 'backup_service.dart';
import 'drive_service.dart';
import 'home_widget_sync.dart';
import 'money_actions.dart';
import 'rates_service.dart';
import 'security_service.dart';

const kPeriodicTask = 'monshika-periodic';

/// Dipanggil saat tombol di widget beranda ditekan (tanpa membuka aplikasi).
/// URI: `monshika://preset?id=3` atau `monshika://refresh`.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final db = AppDatabase();
  try {
    String? lastAction;
    if (uri?.host == 'preset') {
      final id = int.tryParse(uri!.queryParameters['id'] ?? '');
      final preset = (await db.getPresets()).where((p) => p.id == id).firstOrNull;
      if (preset != null) {
        await MoneyActions(db).recordPreset(preset);
        lastAction = '✓ ${preset.name} tercatat';
      }
    }
    await HomeWidgetSync.refresh(db, lastAction: lastAction);
  } finally {
    await db.close();
  }
}

@pragma('vm:entry-point')
void workmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID');
    final db = AppDatabase();
    try {
      await MoneyActions(db).processDueRecurrings();
      await RatesService.refresh(db);
      await HomeWidgetSync.refresh(db);
      await runAutoBackupIfDue(db);
    } catch (e) {
      debugPrint('Background task error: $e');
    } finally {
      await db.close();
    }
    return true;
  });
}

Future<void> registerBackgroundTasks() async {
  await Workmanager().initialize(workmanagerDispatcher);
  await Workmanager().registerPeriodicTask(
    kPeriodicTask,
    kPeriodicTask,
    frequency: const Duration(hours: 1),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Backup otomatis ke Google Drive bila sudah waktunya.
Future<bool> runAutoBackupIfDue(AppDatabase db) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final mode = prefs.getString('autoBackup') ?? 'off';
  if (mode == 'off' || prefs.getString('driveEmail') == null) return false;
  final last = prefs.getInt('lastBackupAt');
  final interval = mode == 'weekly' ? const Duration(days: 7) : const Duration(days: 1);
  if (last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < interval) return false;
  try {
    final password = await SecurityService.instance.getBackupPassword();
    final bytes = await BackupService.create(db, password: password);
    await DriveService.instance.upload(bytes, BackupService.fileName());
    await prefs.setInt('lastBackupAt', DateTime.now().millisecondsSinceEpoch);
    return true;
  } catch (e) {
    debugPrint('Auto backup failed: $e');
    return false;
  }
}
