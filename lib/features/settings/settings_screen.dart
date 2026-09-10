import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
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

  @override
  void initState() {
    super.initState();
    SecurityService.instance.canUseBiometric().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  SettingsNotifier get _n => ref.read(settingsProvider.notifier);

  Future<void> _reschedule() => rescheduleNotifications(ref.read(databaseProvider), ref.read(settingsProvider));

  Widget _section(String jp, String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, jp: jp),
          WaCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final muted = AppTheme.sans(size: 12, color: WaColors.washiMuted);
    const weekdays = {DateTime.monday: 'Senin', DateTime.saturday: 'Sabtu', DateTime.sunday: 'Minggu'};

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan · 設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const UpdateBanner(),
          _section('新', 'Pembaruan', [const UpdateTile()]),
          _section('人', 'Profil', [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Nama panggilan'),
              subtitle: Text(s.userName.isEmpty ? 'Belum diisi' : s.userName, style: muted),
              onTap: () async {
                final ctrl = TextEditingController(text: s.userName);
                final v = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Nama panggilan'),
                    content: TextField(controller: ctrl, autofocus: true),
                    actions: [FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Simpan'))],
                  ),
                );
                if (v != null) await _n.setUserName(v);
              },
            ),
          ]),
          _section('基', 'Umum', [
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('Mata uang & kurs'),
              subtitle: Text('${s.baseCurrency} · ${currencyInfo(s.baseCurrency).name}', style: muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Awal periode bulanan'),
              subtitle: Text(
                s.monthStartDay == 1 ? 'Kalender biasa (tanggal 1 – akhir bulan)' : 'Mulai tanggal ${s.monthStartDay} setiap bulan',
                style: muted,
              ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () async {
                final ctrl = TextEditingController(text: s.monthStartDay == 1 ? '' : '${s.monthStartDay}');
                final result = await showDialog<int>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Awal periode bulanan'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Isi tanggal gajian kalau ingin budget & laporan dihitung mulai tanggal itu. '
                          'Kosongkan untuk kalender biasa.',
                          style: muted,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: ctrl,
                          autofocus: true,
                          maxLength: 2,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'mis. 25 (1–31)', counterText: ''),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(ctx, 1), child: const Text('Kalender biasa')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, (int.tryParse(ctrl.text.trim()) ?? 1).clamp(1, 31)),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );
                if (result != null) await _n.setMonthStartDay(result);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('Awal minggu'),
              trailing: DropdownButton<int>(
                value: s.firstWeekday,
                items: [for (final e in weekdays.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => _n.setFirstWeekday(v ?? DateTime.monday),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Kategori'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          ]),
          _section('彩', 'Tampilan & Nuansa', [
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Sembunyikan saldo'),
              value: s.hideBalance,
              onChanged: _n.setHideBalance,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.approval_outlined),
              title: const Text('Animasi cap hanko'),
              subtitle: Text('Stempel 済 saat transaksi tersimpan', style: muted),
              value: s.hankoAnimation,
              onChanged: _n.setHankoAnimation,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.local_florist_outlined),
              title: const Text('Motif musiman'),
              subtitle: Text('🌸 春 · 🎐 夏 · 🍁 秋 · ❄️ 冬', style: muted),
              value: s.seasonalMotif,
              onChanged: _n.setSeasonalMotif,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.menu_book_outlined),
              title: const Text('Mode Kakeibo'),
              subtitle: Text('Pengingat rencana & refleksi bulanan di beranda', style: muted),
              value: s.kakeiboMode,
              onChanged: _n.setKakeiboMode,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Getar (haptic)'),
              value: s.haptics,
              onChanged: _n.setHaptics,
            ),
          ]),
          _section('鍵', 'Keamanan', [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Kunci dengan PIN'),
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
                title: const Text('Ganti PIN'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen())),
              ),
              if (_bioAvailable)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Buka dengan sidik jari / wajah'),
                  value: s.biometric,
                  onChanged: (v) async {
                    if (v && !await SecurityService.instance.authenticateBiometric()) return;
                    await _n.setBiometric(v);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Kunci otomatis setelah'),
                trailing: DropdownButton<int>(
                  value: s.lockDelaySeconds,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Langsung')),
                    DropdownMenuItem(value: 30, child: Text('30 detik')),
                    DropdownMenuItem(value: 60, child: Text('1 menit')),
                    DropdownMenuItem(value: 300, child: Text('5 menit')),
                  ],
                  onChanged: (v) => _n.setLockDelay(v ?? 30),
                ),
              ),
            ],
          ]),
          _section('知', 'Notifikasi', [
            SwitchListTile(
              secondary: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Pengingat mencatat harian'),
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
                title: const Text('Jam pengingat'),
                trailing: Text(
                  '${s.reminderHour.toString().padLeft(2, '0')}:${s.reminderMinute.toString().padLeft(2, '0')}',
                  style: AppTheme.serif(size: 17, weight: FontWeight.w700),
                ),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute));
                  if (t == null) return;
                  await _n.setReminderTime(t.hour, t.minute);
                  await _reschedule();
                },
              ),
            SwitchListTile(
              secondary: const Icon(Icons.receipt_long_outlined),
              title: const Text('Pengingat tagihan & jatuh tempo'),
              value: s.billReminders,
              onChanged: (v) async {
                if (v) await NotificationService.instance.requestPermission();
                await _n.setBillReminders(v);
                await _reschedule();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.warning_amber_outlined),
              title: const Text('Peringatan budget'),
              value: s.budgetAlerts,
              onChanged: _n.setBudgetAlerts,
            ),
          ]),
          _section('窓', 'Widget & Data', [
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Widget beranda'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsGuideScreen())),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.hide_source),
              title: const Text('Sembunyikan nominal di widget'),
              value: s.hideOnWidget,
              onChanged: (v) async {
                await _n.setHideOnWidget(v);
                await HomeWidgetSync.refresh(ref.read(databaseProvider));
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Backup, export & import'),
              subtitle: Text(s.driveEmail ?? 'Google Drive belum terhubung', style: muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
          ]),
          _section('印', 'Tentang', [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Monshika'),
              subtitle: Text('Versi 1.0.0 · oleh Shicomp', style: muted),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Monshika',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Shicomp',
                applicationIcon: const KanjiBadge(glyph: '鹿', color: WaColors.beni, size: 48),
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Monshika (紋鹿) — "rusa berlambang". Aplikasi pengelola uang bernuansa Jepang: '
                    'data tersimpan di HP-mu sendiri, dengan backup opsional ke Google Drive milikmu.',
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
