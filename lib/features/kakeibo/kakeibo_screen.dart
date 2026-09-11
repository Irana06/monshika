import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';

/// Kakeibo: cara mencatat keuangan rumah tangga ala Jepang.
/// Buat rencana di awal bulan, kelompokkan pengeluaran ke 4 jenis, lalu evaluasi di akhir bulan.
class KakeiboScreen extends ConsumerStatefulWidget {
  const KakeiboScreen({super.key});

  @override
  ConsumerState<KakeiboScreen> createState() => _KakeiboScreenState();
}

class _KakeiboScreenState extends ConsumerState<KakeiboScreen> {
  int _offset = 0;
  String? _loadedFor;
  final _income = TextEditingController();
  final _fixed = TextEditingController();
  final _savings = TextEditingController();
  final _intention = TextEditingController();
  final _rSaved = TextEditingController();
  final _rSpent = TextEditingController();
  final _rImprove = TextEditingController();
  int? _mood;

  DateRange get _range {
    final s = ref.read(settingsProvider);
    final base = monthRange(DateTime.now(), startDay: s.monthStartDay);
    return _offset == 0 ? base : base.shift(_offset, 'monthly');
  }

  void _load(KakeiboMonth? k, String key) {
    if (_loadedFor == key) return;
    _loadedFor = key;
    String v(double? x) => x == null || x == 0 ? '' : x.toStringAsFixed(0);
    _income.text = v(k?.plannedIncome);
    _fixed.text = v(k?.fixedCosts);
    _savings.text = v(k?.savingsTarget);
    _intention.text = k?.intention ?? '';
    _rSaved.text = k?.reflectionSaved ?? '';
    _rSpent.text = k?.reflectionSpent ?? '';
    _rImprove.text = k?.reflectionImprove ?? '';
    _mood = k?.mood;
  }

  Future<void> _save(String key) async {
    final t = S.of(context);
    await ref.read(databaseProvider).saveKakeibo(KakeiboMonthsCompanion(
          month: Value(key),
          plannedIncome: Value(parseAmount(_income.text) ?? 0),
          fixedCosts: Value(parseAmount(_fixed.text) ?? 0),
          savingsTarget: Value(parseAmount(_savings.text) ?? 0),
          intention: Value(_intention.text.trim()),
          reflectionSaved: Value(_rSaved.text.trim()),
          reflectionSpent: Value(_rSpent.text.trim()),
          reflectionImprove: Value(_rImprove.text.trim()),
          mood: Value(_mood),
        ));
    if (mounted) await showHanko(context, glyph: '簿', label: t.t('Tersimpan', 'Saved'));
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final range = _range;
    final key = fmtMonthKey(range.start);
    final entry = ref.watch(kakeiboMonthProvider(key));
    if (entry.hasValue) _load(entry.value, key);
    final f = ref.watch(financeProvider);
    final txs = (ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[]).where((x) => range.contains(x.date)).toList();
    final sum = f.summarize(txs);
    final pillars = f.pillarBreakdown(txs);
    final cur = s.baseCurrency;

    final planned = parseAmount(_income.text) ?? 0;
    final fixed = parseAmount(_fixed.text) ?? 0;
    final target = parseAmount(_savings.text) ?? 0;
    final available = planned - fixed - target;
    final weeks = (range.days / 7).ceil();
    final actualSaved = sum.income - sum.expense;
    String m(double v) => formatMoney(v, cur, hidden: s.hideBalance);

    final savedHint = StringBuffer(t.t('Tercatat ${m(actualSaved)}', 'Recorded: ${m(actualSaved)}'));
    if (target > 0) {
      savedHint.write(actualSaved >= target
          ? t.t(', target ${m(target)} tercapai 🎉', ', goal of ${m(target)} reached 🎉')
          : t.t(', target ${m(target)} belum tercapai', ', goal of ${m(target)} not reached yet'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('家計簿', 'Kakeibo'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Row(children: [
            IconButton(onPressed: () => setState(() => _offset--), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Column(children: [
                if (t.jp) Text(kJpMonths[range.start.month - 1], style: AppTheme.serif(size: 13, color: WaColors.accent)),
                Text(fmtRange(range), style: AppTheme.serif(size: 17, weight: FontWeight.w600)),
              ]),
            ),
            IconButton(onPressed: () => setState(() => _offset++), icon: const Icon(Icons.chevron_right)),
          ]),
          SectionHeader(title: t.t('Rencana bulan ini', "This month's plan"), jp: '一'),
          WaCard(
            child: Column(children: [
              _money(t.t('Perkiraan pemasukan', 'Expected income'), _income, cur),
              _money(t.t('Biaya tetap (kos, tagihan, cicilan)', 'Fixed costs (rent, bills, installments)'), _fixed, cur),
              _money(t.t('Target menabung', 'Savings goal'), _savings, cur),
              const Divider(height: 24),
              Row(children: [
                Expanded(child: Text(t.t('Sisa untuk belanja', 'Left to spend'), style: AppTheme.sans(color: WaColors.washiMuted))),
                Text(m(available), style: AppTheme.serif(size: 18, weight: FontWeight.w700, color: available < 0 ? WaColors.expense : WaColors.income)),
              ]),
              Row(children: [
                Expanded(
                  child: Text(t.t('Kira-kira per minggu ($weeks minggu)', 'About per week ($weeks weeks)'),
                      style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                ),
                Text(m(available / weeks), style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _intention,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: t.t('Mau fokus apa bulan ini? Contoh: kurangi jajan kopi, nabung buat liburan',
                      'What do you want to focus on? e.g. fewer coffee runs, save for a trip'),
                ),
              ),
            ]),
          ),
          SectionHeader(title: t.t('Sejauh ini', 'So far'), jp: '二'),
          WaCard(
            child: Column(children: [
              _kv(t.t('Uang masuk', 'Money in'), m(sum.income), WaColors.income),
              _kv(t.t('Uang keluar', 'Money out'), m(sum.expense), WaColors.expense),
              if (available > 0) ...[
                const SizedBox(height: 8),
                InkBar(value: (sum.expense - fixed) / available, height: 8),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    t.t('${((sum.expense - fixed) / available * 100).clamp(0, 999).round()}% dari jatah belanja terpakai',
                        '${((sum.expense - fixed) / available * 100).clamp(0, 999).round()}% of your spending money used'),
                    style: AppTheme.sans(size: 11, color: WaColors.washiMuted),
                  ),
                ),
              ],
              const Divider(height: 24),
              for (final e in pillars.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    GlyphIcon(pillarGlyph(e.key), color: WaColors.accent, size: 19),
                    const SizedBox(width: 10),
                    Expanded(child: Text(pillarLabel(t, e.key))),
                    Text(m(e.value), style: AppTheme.sans(weight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          SectionHeader(title: t.t('Catatan akhir bulan', 'Month-end review'), jp: '三'),
          WaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _question(t.t('1. Berapa yang berhasil ditabung?', '1. How much did you save?'), savedHint.toString()),
              TextField(controller: _rSaved, maxLines: 2, decoration: InputDecoration(hintText: t.t('Cerita soal tabunganmu', 'A few words about your savings'))),
              const SizedBox(height: 14),
              _question(t.t('2. Uang paling banyak habis buat apa?', '2. Where did most of the money go?'), null),
              TextField(controller: _rSpent, maxLines: 2, decoration: InputDecoration(hintText: t.t('Mana yang sebenarnya tidak perlu?', "What didn't you really need?"))),
              const SizedBox(height: 14),
              _question(t.t('3. Apa yang mau diubah bulan depan?', '3. What will you change next month?'), null),
              TextField(controller: _rImprove, maxLines: 2, decoration: InputDecoration(hintText: t.t('Satu kebiasaan kecil saja cukup', 'One small habit is enough'))),
              const SizedBox(height: 14),
              _question(t.t('4. Gimana perasaanmu soal keuangan bulan ini?', '4. How do you feel about money this month?'), null),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (i, e) in const ['😣', '😕', '😐', '🙂', '😌'].indexed)
                    GestureDetector(
                      onTap: () => setState(() => _mood = i + 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _mood == i + 1 ? WaColors.accent.withValues(alpha: 0.2) : Colors.transparent,
                          border: Border.all(color: _mood == i + 1 ? WaColors.accent : Colors.transparent),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => _save(key), child: Text(t.save)),
        ],
      ),
    );
  }

  Widget _money(String label, TextEditingController c, String cur) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, prefixText: '${currencyInfo(cur).symbol} '),
        ),
      );

  Widget _kv(String k, String v, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: AppTheme.sans(color: WaColors.washiMuted))),
          Text(v, style: AppTheme.sans(weight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _question(String q, String? hint) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q, style: AppTheme.serif(size: 15, weight: FontWeight.w600)),
          if (hint != null) Text(hint, style: AppTheme.sans(size: 12, color: WaColors.accent)),
        ]),
      );
}
