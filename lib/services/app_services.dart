import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/dates.dart';
import '../data/database/database.dart';
import 'background.dart';
import 'finance.dart';
import 'home_widget_sync.dart';
import 'money_actions.dart';
import 'notification_service.dart';
import 'rates_service.dart';
import 'settings.dart';

bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Tugas-tugas saat aplikasi dibuka / kembali ke depan.
Future<void> runStartupTasks(AppDatabase db, AppSettings settings, {bool first = false}) async {
  if (first && isMobile) {
    try {
      await HomeWidget.setAppGroupId(HomeWidgetSync.appGroupId);
      await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
    } catch (e) {
      debugPrint('home_widget init: $e');
    }
    try {
      await registerBackgroundTasks();
    } catch (e) {
      debugPrint('workmanager init: $e');
    }
  }
  try {
    await MoneyActions(db).processDueRecurrings();
  } catch (e) {
    debugPrint('recurring: $e');
  }
  unawaited(RatesService.refresh(db));
  if (isMobile) {
    unawaited(rescheduleNotifications(db, settings));
    unawaited(HomeWidgetSync.refresh(db));
    unawaited(runAutoBackupIfDue(db));
  }
}

Future<void> rescheduleNotifications(AppDatabase db, AppSettings s) async {
  try {
    final ns = NotificationService.instance;
    await ns.scheduleDailyReminder(enabled: s.dailyReminder, hour: s.reminderHour, minute: s.reminderMinute);
    final accounts = {for (final a in await db.getAccounts(includeArchived: true)) a.id: a};
    final rows = await db
        .customSelect('SELECT debt_id AS id, SUM(amount) AS total FROM debt_payments GROUP BY debt_id')
        .get();
    final bills = upcomingBills(
      recurrings: await db.getActiveRecurrings(),
      installments: await db.getActiveInstallments(),
      debts: await db.getOpenDebts(),
      debtPaid: {for (final r in rows) r.read<int>('id'): r.read<double>('total')},
      accounts: accounts,
      until: dateOnly(DateTime.now()).add(const Duration(days: 40)),
      includeIncome: true,
    );
    await ns.scheduleBills(bills, enabled: s.billReminders);
  } catch (e) {
    debugPrint('notifications: $e');
  }
}
