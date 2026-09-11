import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/app_services.dart';
import '../../services/home_widget_sync.dart';
import '../../services/notification_service.dart';
import '../../services/security_service.dart';
import '../backup/backup_screen.dart';
import '../categories/categories_screen.dart';
import '../currency/currency_screen.dart';
import '../lock/lock_screen.dart';
import '../update/update_ui.dart';
import '../widgets_guide/widgets_guide_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _bioAvailable = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    SecurityService.instance.canUseBiometric().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }).catchError((_) {});
  }

  SettingsNotifier get _n => ref.read(settingsProvider.notifier);

  Future<void> _reschedule() => rescheduleNotifications(ref.read(databaseProvider), ref.read(settingsProvider));

  Future<void> _refreshWidgets() async {
    if (isMobile) await HomeWidgetSync.refresh(ref.read(databaseProvider));
  }

  Widget _section(String jp, String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, jp: jp),
          WaCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final muted = AppTheme.sans(size: 12, color: WaColors.washiMuted);
    final weekdays = {
      DateTime.monday: t.t('Senin', 'Monday'),
      DateTime.saturday: t.t('Sabtu', 'Saturday'),
      DateTime.sunday: t.t('Minggu', 'Sunday'),
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('設定', t.t('Pengaturan', 'Settings')))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const UpdateBanner(),
          _section('言', t.t('Bahasa & gaya', 'Language & style'), [
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(t.t('Bahasa', 'Language')),
              trailing: DropdownButton<String>(
                value: s.language,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'id', child: Text('Bahasa Indonesia')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) async {
                  if (v == null || v == s.language) return;
                  await _n.setLanguage(v);
                  await _reschedule();
                  await _refreshWidgets();
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.temple_buddhist_outlined),
              title: Text(t.t('Nuansa Jepang', 'Japanese style')),
              subtitle: Text(
                t.t('Pakai ikon kanji dan label Jepang. Kalau dimatikan, semua pakai ikon dan teks biasa.',
                    'Use kanji icons and Japanese labels. Turn it off to use regular icons and text.'),
                style: muted,
              ),
              value: s.japaneseStyle,
              onChanged: (v) async {
                await _n.setJapaneseStyle(v);
                await _refreshWidgets();
              },
            ),
          ]),
          _section('新', t.t('Pembaruan', 'Updates'), [const UpdateTile()]),
          _section('人', t.t('Profil', 'Profile'), [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(t.t('Nama panggilan', 'Nickname')),
              subtitle: Text(s.userName.isEmpty ? t.t('Belum diisi', 'Not set') : s.userName, style: muted),
              onTap: () async {
                final ctrl = TextEditingController(text: s.userName);
                final v = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t.t('Nama panggilan', 'Nickname')),
                    content: TextField(controller: ctrl, autofocus: true),
                    actions: [FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(t.save))],
                  ),
                );
                if (v != null) await _n.setUserName(v);
              },
            ),
          ]),
          _section('基', t.t('Umum', 'General'), [
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(t.t('Mata uang & kurs', 'Currency & rates')),
              subtitle: Text('${s.baseCurrency} · ${currencyInfo(s.baseCurrency).name(t)}', style: muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: Text(t.t('Awal periode bulanan', 'Monthly period start')),
              subtitle: Text(
                s.monthStartDay == 1
                    ? t.t('Ikut kalender (tanggal 1 sampai akhir bulan)', 'Calendar month (1st to end of month)')
                    : t.t('Mulai tanggal ${s.monthStartDay} tiap bulan', 'Starts on day ${s.monthStartDay} each month'),
                style: muted,
              ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () async {
                final ctrl = TextEditingController(text: s.monthStartDay == 1 ? '' : '${s.monthStartDay}');
                final result = await showDialog<int>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t.t('Awal periode bulanan', 'Monthly period start')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('Isi tanggal gajian kalau mau budget dan laporan dihitung mulai tanggal itu. Biarkan kosong untuk ikut kalender.',
                              'Enter your payday if you want budgets and reports to start on that day. Leave it empty to follow the calendar.'),
                          style: muted,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: ctrl,
                          autofocus: true,
                          maxLength: 2,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: t.t('Contoh: 25', 'e.g. 25'), counterText: ''),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
                      TextButton(onPressed: () => Navigator.pop(ctx, 1), child: Text(t.t('Ikut kalender', 'Use calendar'))),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, (int.tryParse(ctrl.text.trim()) ?? 1).clamp(1, 31)),
                        child: Text(t.save),
                      ),
                    ],
                  ),
                );
                if (result != null) await _n.setMonthStartDay(result);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: Text(t.t('Minggu dimulai hari', 'Week starts on')),
              trailing: DropdownButton<int>(
                value: s.firstWeekday,
                underline: const SizedBox.shrink(),
                items: [for (final e in weekdays.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => _n.setFirstWeekday(v ?? DateTime.monday),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(t.categories),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          ]),
          _section('彩', t.t('Tampilan', 'Display'), [
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: Text(t.t('Sembunyikan saldo', 'Hide balances')),
              value: s.hideBalance,
              onChanged: _n.setHideBalance,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.approval_outlined),
              title: Text(t.t('Animasi cap saat menyimpan', 'Stamp animation on save')),
              value: s.hankoAnimation,
              onChanged: _n.setHankoAnimation,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.local_florist_outlined),
              title: Text(t.t('Hiasan musim', 'Seasonal touches')),
              subtitle: Text('🌸 🎐 🍁 ❄️', style: muted),
              value: s.seasonalMotif,
              onChanged: _n.setSeasonalMotif,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.menu_book_outlined),
              title: Text(t.t('Mode Kakeibo', 'Kakeibo mode')),
              subtitle: Text(t.t('Tampilkan rencana dan catatan akhir bulan di beranda', 'Show the monthly plan and review on Home'), style: muted),
              value: s.kakeiboMode,
              onChanged: _n.setKakeiboMode,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: Text(t.t('Getar', 'Vibration')),
              value: s.haptics,
              onChanged: _n.setHaptics,
            ),
          ]),
          _section('鍵', t.t('Keamanan', 'Security'), [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(t.t('Kunci pakai PIN', 'Lock with PIN')),
              value: s.lockEnabled,
              onChanged: (v) async {
                if (v) {
                  final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
                  if (ok == true) await _n.setLockEnabled(true);
                } else {
                  await SecurityService.instance.removePin();
                  await _n.setLockEnabled(false);
                  await _n.setBiometric(false);
                }
              },
            ),
            if (s.lockEnabled) ...[
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: Text(t.t('Ganti PIN', 'Change PIN')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen())),
              ),
              if (_bioAvailable)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(t.t('Buka pakai sidik jari atau wajah', 'Unlock with fingerprint or face')),
                  value: s.biometric,
                  onChanged: (v) async {
                    if (v && !await SecurityService.instance.authenticateBiometric()) return;
                    await _n.setBiometric(v);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(t.t('Kunci otomatis setelah', 'Auto lock after')),
                trailing: DropdownButton<int>(
                  value: s.lockDelaySeconds,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(t.t('Langsung', 'Right away'))),
                    DropdownMenuItem(value: 30, child: Text(t.t('30 detik', '30 seconds'))),
                    DropdownMenuItem(value: 60, child: Text(t.t('1 menit', '1 minute'))),
                    DropdownMenuItem(value: 300, child: Text(t.t('5 menit', '5 minutes'))),
                  ],
                  onChanged: (v) => _n.setLockDelay(v ?? 30),
                ),
              ),
            ],
          ]),
          _section('知', t.t('Notifikasi', 'Notifications'), [
            SwitchListTile(
              secondary: const Icon(Icons.edit_calendar_outlined),
              title: Text(t.t('Pengingat catat harian', 'Daily logging reminder')),
              value: s.dailyReminder,
              onChanged: (v) async {
                if (v) await NotificationService.instance.requestPermission();
                await _n.setDailyReminder(v);
                await _reschedule();
              },
            ),
            if (s.dailyReminder)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(t.t('Jam pengingat', 'Reminder time')),
                trailing: Text(
                  '${s.reminderHour.toString().padLeft(2, '0')}:${s.reminderMinute.toString().padLeft(2, '0')}',
                  style: AppTheme.serif(size: 17, weight: FontWeight.w700),
                ),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute));
                  if (time == null) return;
                  await _n.setReminderTime(time.hour, time.minute);
                  await _reschedule();
                },
              ),
            SwitchListTile(
              secondary: const Icon(Icons.receipt_long_outlined),
              title: Text(t.t('Pengingat tagihan', 'Bill reminders')),
              value: s.billReminders,
              onChanged: (v) async {
                if (v) await NotificationService.instance.requestPermission();
                await _n.setBillReminders(v);
                await _reschedule();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.warning_amber_outlined),
              title: Text(t.t('Peringatan budget', 'Budget alerts')),
              value: s.budgetAlerts,
              onChanged: _n.setBudgetAlerts,
            ),
          ]),
          _section('窓', t.t('Widget & data', 'Widgets & data'), [
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: Text(t.t('Widget layar utama', 'Home screen widgets')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsGuideScreen())),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.hide_source),
              title: Text(t.t('Sembunyikan nominal di widget', 'Hide amounts on widgets')),
              value: s.hideOnWidget,
              onChanged: (v) async {
                await _n.setHideOnWidget(v);
                await _refreshWidgets();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(t.t('Backup, ekspor & impor', 'Backup, export & import')),
              subtitle: Text(s.driveEmail ?? t.t('Google Drive belum terhubung', 'Google Drive not connected'), style: muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
          ]),
          _section('印', t.t('Tentang', 'About'), [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Monshika'),
              subtitle: Text(
                _version.isEmpty ? t.t('oleh Shicomp', 'by Shicomp') : t.t('Versi $_version, oleh Shicomp', 'Version $_version, by Shicomp'),
                style: muted,
              ),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Monshika',
                applicationVersion: _version,
                applicationLegalese: '© 2026 Shicomp',
                applicationIcon: Image.asset('assets/logo.png', width: 56, height: 56),
                children: [
                  const SizedBox(height: 12),
                  Text(
                    t.t(
                      'Monshika artinya rusa berlambang. Semua datamu disimpan di HP ini, dan bisa kamu backup ke Google Drive milikmu sendiri kalau mau.',
                      'Monshika means crested deer. Your data stays on this phone, and you can back it up to your own Google Drive if you like.',
                    ),
                    style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
