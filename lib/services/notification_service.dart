import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/money.dart';
import '../l10n/strings.dart';
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
  static const _updateId = 9000;

  S get _s => S.current;

  AndroidNotificationDetails get _channelReminder => AndroidNotificationDetails(
        'monshika_reminder',
        _s.t('Pengingat harian', 'Daily reminder'),
        channelDescription: _s.t('Pengingat untuk mencatat keuangan', 'A nudge to log your spending'),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

  AndroidNotificationDetails get _channelBills => AndroidNotificationDetails(
        'monshika_bills',
        _s.t('Tagihan & jatuh tempo', 'Bills & due dates'),
        channelDescription: _s.t('Tagihan rutin, cicilan, dan utang yang akan jatuh tempo', 'Upcoming bills, installments, and debts'),
        importance: Importance.high,
        priority: Priority.high,
      );

  AndroidNotificationDetails get _channelBudget => AndroidNotificationDetails(
        'monshika_budget',
        _s.t('Peringatan budget', 'Budget alerts'),
        channelDescription: _s.t('Saat budget hampir atau sudah habis', 'When a budget is almost or fully used'),
        importance: Importance.high,
        priority: Priority.high,
      );

  AndroidNotificationDetails get _channelUpdate => AndroidNotificationDetails(
        'monshika_update',
        _s.t('Pembaruan aplikasi', 'App updates'),
        channelDescription: _s.t('Saat versi baru Monshika tersedia', 'When a new version of Monshika is out'),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
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
      title: _s.t('Sudah catat hari ini?', 'Logged today yet?'),
      body: _s.t('Luangkan semenit untuk mencatat pemasukan dan pengeluaran hari ini.', 'Take a minute to log what came in and went out today.'),
      scheduledDate: at,
      notificationDetails: NotificationDetails(android: _channelReminder, iOS: const DarwinNotificationDetails()),
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
      final isToday = remindDaysBefore == 0 || at.day == b.date.day;
      final amount = formatMoney(b.amount, b.currency);
      await _plugin.zonedSchedule(
        id: _billBase + idx++,
        title: b.title,
        body: isToday
            ? _s.t('$amount jatuh tempo hari ini.', '$amount is due today.')
            : _s.t('$amount jatuh tempo besok.', '$amount is due tomorrow.'),
        scheduledDate: at,
        notificationDetails: NotificationDetails(android: _channelBills, iOS: const DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showBudgetAlert({required int budgetId, required String name, required double ratio}) async {
    await init();
    final pct = (ratio * 100).round();
    await _plugin.show(
      id: _budgetBase + budgetId,
      title: ratio >= 1
          ? _s.t('Budget $name sudah terlewati', 'Budget $name is over')
          : _s.t('Budget $name sudah terpakai $pct%', 'Budget $name is $pct% used'),
      body: ratio >= 1
          ? _s.t('Pengeluaran sudah $pct% dari batas.', 'Spending is at $pct% of the limit.')
          : _s.t('Sisa ${100 - pct}% untuk periode ini.', '${100 - pct}% left for this period.'),
      notificationDetails: NotificationDetails(android: _channelBudget, iOS: const DarwinNotificationDetails()),
    );
  }

  Future<void> showUpdateAvailable(String version) async {
    await init();
    await _plugin.show(
      id: _updateId,
      title: _s.t('Monshika $version sudah tersedia', 'Monshika $version is available'),
      body: _s.t('Buka aplikasi untuk melihat perubahan dan memperbarui.', 'Open the app to see what changed and update.'),
      notificationDetails: NotificationDetails(android: _channelUpdate, iOS: const DarwinNotificationDetails()),
    );
  }

  Future<void> showSimple(int id, String title, String body) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _channelReminder, iOS: const DarwinNotificationDetails()),
    );
  }
}
