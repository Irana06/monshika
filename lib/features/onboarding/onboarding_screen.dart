import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/notification_service.dart';
import '../../services/rates_service.dart';
import '../backup/backup_screen.dart';

class _AccountDraft {
  _AccountDraft(this.type, this.enabled);
  final String type;
  final TextEditingController name = TextEditingController();
  final TextEditingController balance = TextEditingController();
  bool enabled;
  bool edited = false;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  final _name = TextEditingController();
  String _currency = 'IDR';
  bool _usePayday = false;
  final _payday = TextEditingController();
  bool _presets = true;
  bool _busy = false;

  final _accounts = [
    _AccountDraft('cash', true),
    _AccountDraft('bank', true),
    _AccountDraft('ewallet', false),
  ];

  int get _startDay => _usePayday ? (int.tryParse(_payday.text.trim()) ?? 1).clamp(1, 31) : 1;

  /// Isi nama dompet bawaan sesuai bahasa, kecuali yang sudah diubah pengguna.
  void _syncAccountNames(S s) {
    for (final a in _accounts) {
      final label = accountTypeLabel(s, a.type);
      if (!a.edited && a.name.text != label) a.name.text = label;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAccountNames(S.of(context));
  }

  void _next() {
    FocusScope.of(context).unfocus();
    _page.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final s = S.of(context);
    final db = ref.read(databaseProvider);
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.setUserName(_name.text.trim());
    await notifier.setBaseCurrency(_currency);
    await notifier.setMonthStartDay(_startDay);

    final colors = [WaColors.kin, WaColors.ai, WaColors.wakatake];
    int? firstId;
    int? walletId;
    var order = 0;
    for (final (i, a) in _accounts.indexed) {
      if (!a.enabled || a.name.text.trim().isEmpty) continue;
      final id = await db.saveAccount(AccountsCompanion.insert(
        name: a.name.text.trim(),
        type: a.type,
        currency: Value(_currency),
        initialBalance: Value(parseAmount(a.balance.text) ?? 0),
        color: colors[i].toARGB32(),
        icon: accountTypeGlyph(a.type),
        sortOrder: Value(order++),
      ));
      firstId ??= id;
      if (a.type == 'cash' || a.type == 'ewallet') walletId ??= id;
    }
    firstId ??= await db.saveAccount(AccountsCompanion.insert(
      name: accountTypeLabel(s, 'cash'),
      type: 'cash',
      currency: Value(_currency),
      color: WaColors.kin.toARGB32(),
      icon: '銭',
    ));
    await notifier.setDefaultAccount(walletId ?? firstId);

    if (_presets) {
      final cats = await db.getCategories();
      int? cat(String glyph) => cats.where((c) => c.icon == glyph && !c.isSystem).map((c) => c.id).firstOrNull;
      final small = _currency == 'IDR';
      final presets = [
        (s.t('Kopi', 'Coffee'), '☕', small ? 25000.0 : 5.0, '茶'),
        (s.t('Makan', 'Lunch'), '🍱', small ? 25000.0 : 10.0, '食'),
        (s.t('Ojol', 'Ride'), '🛵', small ? 15000.0 : 5.0, '走'),
        (s.t('Parkir', 'Parking'), '🅿️', small ? 5000.0 : 2.0, '駐'),
      ];
      for (final (i, p) in presets.indexed) {
        await db.savePreset(PresetsCompanion.insert(
          name: p.$1,
          icon: p.$2,
          type: 'expense',
          amount: p.$3,
          accountId: walletId ?? firstId,
          categoryId: Value(cat(p.$4)),
          sortOrder: Value(i),
        ));
      }
    }

    RatesService.refresh(db, force: true);
    await NotificationService.instance.requestPermission();
    await notifier.setOnboardingDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [_welcome(s), _profile(s), _accountsPage(s)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? WaColors.beni : WaColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  if (_index > 0)
                    TextButton(
                      onPressed: () => _page.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      child: Text(s.back),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : (_index < 2 ? _next : _finish),
                    child: Text(_index == 0 ? s.t('Mulai', 'Get started') : (_index < 2 ? s.next : s.done)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(S s) {
    final settings = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Stack(
      children: [
        if (s.jp)
          Positioned.fill(child: CustomPaint(painter: SeigaihaPainter(color: WaColors.washi.withValues(alpha: 0.03), radius: 30))),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 168, height: 168, filterQuality: FilterQuality.medium)
                  .animate()
                  .scale(begin: const Offset(0.8, 0.8), duration: 700.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 32),
              Text('Monshika', style: AppTheme.serif(size: 40, weight: FontWeight.w700, letterSpacing: 2))
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              if (s.jp) Text('お金を、心穏やかに。', style: AppTheme.serif(size: 18, color: WaColors.accent)).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 4),
              Text(s.t('Catat uang tanpa ribet.', 'Money tracking, minus the stress.'),
                      style: AppTheme.sans(size: 15, color: WaColors.washiMuted))
                  .animate()
                  .fadeIn(delay: 600.ms),
              const SizedBox(height: 28),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'id', label: Text('Indonesia')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {settings.language},
                showSelectedIcon: false,
                onSelectionChanged: (v) => n.setLanguage(v.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                value: settings.japaneseStyle,
                onChanged: n.setJapaneseStyle,
                title: Text(s.t('Nuansa Jepang', 'Japanese style'), style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
                subtitle: Text(s.t('Ikon kanji dan label Jepang. Bisa diganti nanti.', 'Kanji icons and Japanese labels. You can change this later.'),
                    style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen(fromOnboarding: true))),
                icon: const Icon(Icons.restore),
                label: Text(s.t('Punya backup? Pulihkan data', 'Have a backup? Restore it')),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profile(S s) {
    final info = currencyInfo(_currency);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (s.jp) Text('自己紹介', style: AppTheme.serif(size: 16, color: WaColors.accent)),
        Text(s.t('Kenalan dulu', 'About you'), style: AppTheme.serif(size: 28, weight: FontWeight.w700)),
        const SizedBox(height: 24),
        LabeledField(
          label: s.t('Nama panggilan', 'Nickname'),
          child: TextField(controller: _name, decoration: InputDecoration(hintText: s.t('Contoh: Irana', 'e.g. Sam'))),
        ),
        LabeledField(
          label: s.t('Mata uang utama', 'Main currency'),
          child: PickerTile(
            leading: Text(info.flag, style: const TextStyle(fontSize: 26)),
            title: '${info.code} · ${info.name(s)}',
            subtitle: s.t('Total dan laporan dihitung pakai mata uang ini', 'Totals and reports use this currency'),
            onTap: () async {
              final c = await pickCurrency(context, current: _currency);
              if (c != null) setState(() => _currency = c);
            },
          ),
        ),
        WaCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _usePayday,
                onChanged: (v) => setState(() => _usePayday = v),
                title: Text(s.t('Hitung bulan dari tanggal gajian', 'Start the month on payday'), style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                subtitle: Text(
                  s.t('Opsional. Kalau mati, periode bulanan ikut kalender biasa.', 'Optional. When off, months follow the normal calendar.'),
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                ),
              ),
              if (_usePayday) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextField(
                    controller: _payday,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    decoration: InputDecoration(labelText: s.t('Tanggal gajian', 'Payday'), hintText: s.t('Contoh: 25', 'e.g. 25')),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t(
                    'Gaji suka telat? Santai saja. Tanggal ini cuma dipakai untuk memotong periode budget dan laporan, bukan jadwal gaji masuk. Bisa diubah di Pengaturan.',
                    "Paychecks run late sometimes? That's fine. This date only splits budget and report periods, it doesn't track when you get paid. You can change it in Settings.",
                  ),
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountsPage(S s) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (s.jp) Text('財布', style: AppTheme.serif(size: 16, color: WaColors.accent)),
        Text(s.t('Dompet pertamamu', 'Your first wallets'), style: AppTheme.serif(size: 28, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.t('Isi saldo sekarang. Nanti masih bisa ditambah atau diubah.', 'Fill in what you have now. You can add or change these later.'),
            style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
        const SizedBox(height: 20),
        for (final a in _accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WaCard(
              borderColor: a.enabled ? WaColors.accent.withValues(alpha: 0.5) : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      KanjiBadge(glyph: accountTypeGlyph(a.type), color: a.enabled ? WaColors.accent : WaColors.washiFaint, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: a.name,
                          enabled: a.enabled,
                          onChanged: (_) => a.edited = true,
                          decoration: const InputDecoration(filled: false, border: InputBorder.none, isDense: true),
                          style: AppTheme.sans(size: 16, weight: FontWeight.w600),
                        ),
                      ),
                      Switch(value: a.enabled, onChanged: (v) => setState(() => a.enabled = v)),
                    ],
                  ),
                  if (a.enabled)
                    TextField(
                      controller: a.balance,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(hintText: s.t('Saldo awal', 'Starting balance'), prefixText: '${currencyInfo(_currency).symbol} '),
                    ),
                ],
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.currency_exchange, size: 18, color: WaColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.t(
                  'Punya saldo dolar di PayPal, yen, atau mata uang lain? Tambahkan nanti lewat Lainnya › Dompet lalu pilih mata uangnya. Kurs dihitung otomatis, atau isi sendiri sesuai kurs bank.',
                  'Got dollars on PayPal, yen, or another currency? Add it later from More › Wallets and pick the currency. Rates update on their own, or you can enter your bank rate.',
                ),
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _presets,
          onChanged: (v) => setState(() => _presets = v),
          title: Text(s.t('Buat tombol catat sekali tap', 'Add one-tap shortcuts')),
          subtitle: Text(
            s.t('Kopi, makan, ojol, dan parkir. Bisa dipakai juga dari widget.', 'Coffee, lunch, rides, and parking. Works from the widget too.'),
            style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
          ),
        ),
      ],
    );
  }
}
