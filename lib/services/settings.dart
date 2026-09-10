import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.userName = '',
    this.baseCurrency = 'IDR',
    this.monthStartDay = 1,
    this.firstWeekday = DateTime.monday,
    this.hideBalance = false,
    this.hideOnWidget = false,
    this.lockEnabled = false,
    this.biometric = false,
    this.lockDelaySeconds = 30,
    this.onboardingDone = false,
    this.dailyReminder = true,
    this.reminderHour = 21,
    this.reminderMinute = 0,
    this.budgetAlerts = true,
    this.billReminders = true,
    this.hankoAnimation = true,
    this.seasonalMotif = true,
    this.kakeiboMode = true,
    this.haptics = true,
    this.autoBackup = 'off',
    this.driveEmail,
    this.lastBackupAt,
    this.defaultAccountId,
    this.ratesUpdatedAt,
  });

  final String userName;
  final String baseCurrency;
  final int monthStartDay;
  final int firstWeekday;
  final bool hideBalance;
  final bool hideOnWidget;
  final bool lockEnabled;
  final bool biometric;
  final int lockDelaySeconds;
  final bool onboardingDone;
  final bool dailyReminder;
  final int reminderHour;
  final int reminderMinute;
  final bool budgetAlerts;
  final bool billReminders;
  final bool hankoAnimation;
  final bool seasonalMotif;
  final bool kakeiboMode;
  final bool haptics;

  /// off | daily | weekly
  final String autoBackup;
  final String? driveEmail;
  final DateTime? lastBackupAt;
  final int? defaultAccountId;
  final DateTime? ratesUpdatedAt;

  static AppSettings fromPrefs(SharedPreferences p) {
    DateTime? dt(String k) {
      final v = p.getInt(k);
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
    }

    return AppSettings(
      userName: p.getString('userName') ?? '',
      baseCurrency: p.getString('baseCurrency') ?? 'IDR',
      monthStartDay: p.getInt('monthStartDay') ?? 1,
      firstWeekday: p.getInt('firstWeekday') ?? DateTime.monday,
      hideBalance: p.getBool('hideBalance') ?? false,
      hideOnWidget: p.getBool('hideOnWidget') ?? false,
      lockEnabled: p.getBool('lockEnabled') ?? false,
      biometric: p.getBool('biometric') ?? false,
      lockDelaySeconds: p.getInt('lockDelaySeconds') ?? 30,
      onboardingDone: p.getBool('onboardingDone') ?? false,
      dailyReminder: p.getBool('dailyReminder') ?? true,
      reminderHour: p.getInt('reminderHour') ?? 21,
      reminderMinute: p.getInt('reminderMinute') ?? 0,
      budgetAlerts: p.getBool('budgetAlerts') ?? true,
      billReminders: p.getBool('billReminders') ?? true,
      hankoAnimation: p.getBool('hankoAnimation') ?? true,
      seasonalMotif: p.getBool('seasonalMotif') ?? true,
      kakeiboMode: p.getBool('kakeiboMode') ?? true,
      haptics: p.getBool('haptics') ?? true,
      autoBackup: p.getString('autoBackup') ?? 'off',
      driveEmail: p.getString('driveEmail'),
      lastBackupAt: dt('lastBackupAt'),
      defaultAccountId: p.getInt('defaultAccountId'),
      ratesUpdatedAt: dt('ratesUpdatedAt'),
    );
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() => AppSettings.fromPrefs(ref.watch(sharedPrefsProvider));

  Future<void> _set(String key, Object? value) async {
    switch (value) {
      case null:
        await _p.remove(key);
      case bool v:
        await _p.setBool(key, v);
      case int v:
        await _p.setInt(key, v);
      case double v:
        await _p.setDouble(key, v);
      case String v:
        await _p.setString(key, v);
      case DateTime v:
        await _p.setInt(key, v.millisecondsSinceEpoch);
    }
    state = AppSettings.fromPrefs(_p);
  }

  Future<void> setUserName(String v) => _set('userName', v);
  Future<void> setBaseCurrency(String v) => _set('baseCurrency', v);
  Future<void> setMonthStartDay(int v) => _set('monthStartDay', v);
  Future<void> setFirstWeekday(int v) => _set('firstWeekday', v);
  Future<void> setHideBalance(bool v) => _set('hideBalance', v);
  Future<void> toggleHideBalance() => _set('hideBalance', !state.hideBalance);
  Future<void> setHideOnWidget(bool v) => _set('hideOnWidget', v);
  Future<void> setLockEnabled(bool v) => _set('lockEnabled', v);
  Future<void> setBiometric(bool v) => _set('biometric', v);
  Future<void> setLockDelay(int v) => _set('lockDelaySeconds', v);
  Future<void> setOnboardingDone(bool v) => _set('onboardingDone', v);
  Future<void> setDailyReminder(bool v) => _set('dailyReminder', v);
  Future<void> setReminderTime(int h, int m) async {
    await _p.setInt('reminderHour', h);
    await _set('reminderMinute', m);
  }

  Future<void> setBudgetAlerts(bool v) => _set('budgetAlerts', v);
  Future<void> setBillReminders(bool v) => _set('billReminders', v);
  Future<void> setHankoAnimation(bool v) => _set('hankoAnimation', v);
  Future<void> setSeasonalMotif(bool v) => _set('seasonalMotif', v);
  Future<void> setKakeiboMode(bool v) => _set('kakeiboMode', v);
  Future<void> setHaptics(bool v) => _set('haptics', v);
  Future<void> setAutoBackup(String v) => _set('autoBackup', v);
  Future<void> setDriveEmail(String? v) => _set('driveEmail', v);
  Future<void> setLastBackupAt(DateTime? v) => _set('lastBackupAt', v);
  Future<void> setDefaultAccount(int? v) => _set('defaultAccountId', v);
  Future<void> setRatesUpdatedAt(DateTime? v) => _set('ratesUpdatedAt', v);

  /// Muat ulang dari disk (mis. setelah isolate lain menulis).
  Future<void> reload() async {
    await _p.reload();
    state = AppSettings.fromPrefs(_p);
  }
}
