import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/providers.dart';
import '../../services/notification_service.dart';
import '../../services/rates_service.dart';
import '../backup/backup_screen.dart';

class _AccountDraft {
  _AccountDraft(this.type, this.name, this.enabled);
  final String type;
  final TextEditingController name;
  final TextEditingController balance = TextEditingController();
  bool enabled;
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
  int _startDay = 1;
  bool _presets = true;
  bool _busy = false;

  final _accounts = [
    _AccountDraft('cash', TextEditingController(text: 'Tunai'), true),
    _AccountDraft('bank', TextEditingController(text: 'Bank'), true),
    _AccountDraft('ewallet', TextEditingController(text: 'E-Wallet'), false),
  ];

  void _next() {
    FocusScope.of(context).unfocus();
    _page.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
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
        icon: kAccountTypes[a.type]!.$2,
        sortOrder: Value(order++),
      ));
      firstId ??= id;
      if (a.type == 'cash' || a.type == 'ewallet') walletId ??= id;
    }
    firstId ??= await db.saveAccount(AccountsCompanion.insert(
      name: 'Tunai',
      type: 'cash',
      currency: Value(_currency),
      color: WaColors.kin.toARGB32(),
      icon: '銭',
    ));
    await notifier.setDefaultAccount(walletId ?? firstId);

    if (_presets) {
      final cats = await db.getCategories();
      int? cat(String name) => cats.where((c) => c.name == name).map((c) => c.id).firstOrNull;
      final small = _currency == 'IDR';
      final presets = [
        ('Kopi', '☕', small ? 25000.0 : 5.0, 'Kopi & Jajan'),
        ('Makan', '🍱', small ? 25000.0 : 10.0, 'Makan & Minum'),
        ('Ojol', '🛵', small ? 15000.0 : 5.0, 'Ojek Online'),
        ('Parkir', '🅿️', small ? 5000.0 : 2.0, 'Parkir & Tol'),
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [_welcome(), _profile(), _accountsPage()],
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
                      child: const Text('Kembali'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : (_index < 2 ? _next : _finish),
                    child: Text(_index == 0 ? 'Mulai' : (_index < 2 ? 'Lanjut' : 'Selesai')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: SeigaihaPainter(color: WaColors.washi.withValues(alpha: 0.03), radius: 30))),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EnsoRing(
                progress: 1,
                size: 180,
                stroke: 12,
                color: WaColors.beni,
                trackColor: Colors.transparent,
                child: Text('鹿', style: AppTheme.serif(size: 72, weight: FontWeight.w700)),
              ).animate().scale(begin: const Offset(0.8, 0.8), duration: 700.ms, curve: Curves.easeOutBack).fadeIn(),
              const SizedBox(height: 32),
              Text('Monshika', style: AppTheme.serif(size: 40, weight: FontWeight.w700, letterSpacing: 2))
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text('お金を、心穏やかに。', style: AppTheme.serif(size: 18, color: WaColors.accent)).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 4),
              Text('Kelola uang dengan tenang.', style: AppTheme.sans(size: 15, color: WaColors.washiMuted)).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen(fromOnboarding: true))),
                icon: const Icon(Icons.restore),
                label: const Text('Sudah punya backup? Pulihkan data'),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profile() {
    final info = currencyInfo(_currency);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('自己紹介', style: AppTheme.serif(size: 16, color: WaColors.accent)),
        Text('Kenalan dulu', style: AppTheme.serif(size: 28, weight: FontWeight.w700)),
        const SizedBox(height: 24),
        LabeledField(label: 'Nama panggilan', child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'mis. Irana'))),
        LabeledField(
          label: 'Mata uang utama',
          child: PickerTile(
            leading: Text(info.flag, style: const TextStyle(fontSize: 26)),
            title: '${info.code} · ${info.name}',
            subtitle: 'Semua ringkasan dikonversi ke mata uang ini',
            onTap: () async {
              final c = await pickCurrency(context, current: _currency);
              if (c != null) setState(() => _currency = c);
            },
          ),
        ),
        LabeledField(
          label: 'Awal periode bulanan (tanggal gajian)',
          child: WaCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('Setiap tanggal $_startDay', style: AppTheme.sans(size: 15))),
                IconButton(onPressed: _startDay > 1 ? () => setState(() => _startDay--) : null, icon: const Icon(Icons.remove)),
                IconButton(onPressed: _startDay < 28 ? () => setState(() => _startDay++) : null, icon: const Icon(Icons.add)),
              ],
            ),
          ),
        ),
        Text(
          'Kalau gajian tanggal 25, pilih 25 supaya budget & laporan bulanan dihitung dari 25 ke 24 bulan berikutnya.',
          style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
        ),
      ],
    );
  }

  Widget _accountsPage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('財布', style: AppTheme.serif(size: 16, color: WaColors.accent)),
        Text('Dompet pertamamu', style: AppTheme.serif(size: 28, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Isi saldo saat ini. Nanti bisa ditambah atau diubah kapan saja.', style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
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
                      KanjiBadge(glyph: kAccountTypes[a.type]!.$2, color: a.enabled ? WaColors.accent : WaColors.washiFaint, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: a.name,
                          enabled: a.enabled,
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
                      decoration: InputDecoration(hintText: 'Saldo awal', prefixText: '${currencyInfo(_currency).symbol} '),
                    ),
                ],
              ),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _presets,
          onChanged: (v) => setState(() => _presets = v),
          title: const Text('Buat preset sekali tap'),
          subtitle: Text('Kopi, makan, ojol, parkir — bisa dipakai di widget beranda', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
        ),
      ],
    );
  }
}
