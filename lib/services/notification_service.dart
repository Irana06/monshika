import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/money.dart';
import 'finance.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _dailyId = 1;
  static const _billBase = 1000;
  static const _billMax = 60;
  static const _budgetBase = 5000;

  static const _channelReminder = AndroidNotificationDetails(
    'monshika_reminder',
    'Pengingat harian',
    channelDescription: 'Pengingat untuk mencatat keuangan setiap hari',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _channelBills = AndroidNotificationDetails(
    'monshika_bills',
    'Tagihan & jatuh tempo',
    channelDescription: 'Tagihan berulang, cicilan, dan utang yang akan jatuh tempo',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _channelBudget = AndroidNotificationDetails(
    'monshika_budget',
    'Peringatan budget',
    channelDescription: 'Pemberitahuan saat budget hampir atau sudah habis',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return true;
  }

  Future<void> scheduleDailyReminder({required bool enabled, required int hour, required int minute}) async {
    await init();
    await _plugin.cancel(id: _dailyId);
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: '今日の記録 · Catatan hari ini',
      body: 'Sudah catat pemasukan & pengeluaran hari ini? Jaga streak-mu 🔥',
      scheduledDate: at,
      notificationDetails: const NotificationDetails(android: _channelReminder, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleBills(List<UpcomingBill> bills, {required bool enabled, int remindDaysBefore = 1}) async {
    await init();
    for (var i = 0; i < _billMax; i++) {
      await _plugin.cancel(id: _billBase + i);
    }
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    var idx = 0;
    for (final b in bills) {
      if (idx >= _billMax) break;
      final day = b.date.subtract(Duration(days: remindDaysBefore));
      var at = tz.TZDateTime(tz.local, day.year, day.month, day.day, 9);
      if (!at.isAfter(now)) {
        final sameDay = tz.TZDateTime(tz.local, b.date.year, b.date.month, b.date.day, 8);
        if (!sameDay.isAfter(now)) continue;
        at = sameDay;
      }
      final when = remindDaysBefore == 0 || at.day == b.date.day ? 'hari ini' : 'besok';
      await _plugin.zonedSchedule(
        id: _billBase + idx++,
        title: '${b.isIncome ? '💰' : '🔔'} ${b.title}',
        body: '${formatMoney(b.amount, b.currency)} jatuh tempo $when.',
        scheduledDate: at,
        notificationDetails: const NotificationDetails(android: _channelBills, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showBudgetAlert({required int budgetId, required String name, required double ratio}) async {
    await init();
    final pct = (ratio * 100).round();
    await _plugin.show(
      id: _budgetBase + budgetId,
      title: ratio >= 1 ? '⛔ Budget "$name" terlampaui' : '⚠️ Budget "$name" sudah $pct%',
      body: ratio >= 1 ? 'Pengeluaran sudah melewati batas ($pct%). Rem dulu ya.' : 'Tinggal ${100 - pct}% lagi untuk periode ini.',
      notificationDetails: const NotificationDetails(android: _channelBudget, iOS: DarwinNotificationDetails()),
    );
  }

  Future<void> showSimple(int id, String title, String body) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _channelReminder, iOS: DarwinNotificationDetails()),
    );
  }
}
