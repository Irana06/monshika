import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../../services/finance.dart';
import '../transactions/transaction_tile.dart';

class BudgetStatus {
  const BudgetStatus({required this.range, required this.limit, required this.spent, required this.carried});

  final DateRange range;
  final double limit;
  final double spent;
  final double carried;

  double get left => limit - spent;
  double get ratio => limit <= 0 ? 0 : spent / limit;

  int get daysLeft => math.max(1, range.end.difference(dateOnly(DateTime.now())).inDays);

  double get perDayLeft => math.max(0, left) / daysLeft;

  double get projection {
    final elapsed = math.max(1, dateOnly(DateTime.now()).difference(range.start).inDays + 1);
    return spent / elapsed * range.days;
  }
}

BudgetStatus budgetStatus(Budget b, Finance f, List<TxEntry> txs, AppSettings s, {int offset = 0}) {
  var range = periodRange(b.period, DateTime.now(), monthStartDay: s.monthStartDay, firstWeekday: s.firstWeekday);
  if (offset != 0) range = range.shift(offset, b.period);
  final spent = f.budgetSpent(b, txs, range);
  var carried = 0.0;
  if (b.rollover) {
    final prev = range.shift(-1, b.period);
    if (!prev.start.isBefore(DateTime(b.createdAt.year, b.createdAt.month, 1))) {
      carried = math.max(0, b.amount - f.budgetSpent(b, txs, prev));
    }
  }
  return BudgetStatus(range: range, limit: b.amount + carried, spent: spent, carried: carried);
}

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final f = ref.watch(financeProvider);
    final s = ref.watch(settingsProvider);
    final txs = ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[];

    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('予算', 'Budget'))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-budget',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: budgets.isEmpty
          ? EmptyState(
              kanji: '算',
              title: t.t('Belum ada budget', 'No budgets yet'),
              subtitle: t.t('Pasang batas belanja per kategori, mingguan, bulanan, atau tahunan.', 'Set spending limits by category, per week, month, or year.'),
              action: t.t('Buat budget', 'Create a budget'),
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetFormScreen())),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: budgets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final b = budgets[i];
                final st = budgetStatus(b, f, txs, s);
                String m(double v, {bool c = false}) => formatMoney(v, b.currency, compact: c, hidden: s.hideBalance);
                return Opacity(
                  opacity: b.active ? 1 : 0.5,
                  child: WaCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetDetailScreen(budgetId: b.id))),
                    child: Row(
                      children: [
                        EnsoRing(
                          progress: st.ratio,
                          size: 70,
                          child: GlyphIcon(b.icon, color: Color(b.color), size: 23),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(b.name, style: AppTheme.serif(size: 16, weight: FontWeight.w600))),
                                Text('${(st.ratio * 100).round()}%',
                                    style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: st.ratio >= 1 ? WaColors.expense : WaColors.accent)),
                              ]),
                              Text('${t.periodLabel(b.period)} · ${fmtRange(st.range)}', style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                              const SizedBox(height: 8),
                              Text('${m(st.spent)} / ${m(st.limit)}', style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                              Text(
                                st.left >= 0
                                    ? t.t('Sisa ${m(st.left, c: true)} · ${m(st.perDayLeft, c: true)}/hari', '${m(st.left, c: true)} left · ${m(st.perDayLeft, c: true)}/day')
                                    : t.t('Lebih ${m(-st.left, c: true)}', '${m(-st.left, c: true)} over'),
                                style: AppTheme.sans(size: 12, color: st.left >= 0 ? WaColors.washiMuted : WaColors.expense),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetId});

  final int budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final b = (ref.watch(budgetsProvider).value ?? const <Budget>[]).where((x) => x.id == budgetId).firstOrNull;
    if (b == null) return Scaffold(body: Center(child: Text(t.t('Budget tidak ditemukan', 'Budget not found'))));
    final f = ref.watch(financeProvider);
    final s = ref.watch(settingsProvider);
    final cats = ref.watch(categoryMapProvider);
    final txs = ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[];
    final st = budgetStatus(b, f, txs, s);
    final ids = b.categoryIds.isEmpty ? null : f.withChildren(b.categoryIds.split(',').map(int.tryParse).whereType<int>());
    final inPeriod = txs
        .where((x) => x.type == 'expense' && !x.excludeFromStats && st.range.contains(x.date) && (ids == null || ids.contains(x.categoryId)))
        .toList();
    final history = [for (var i = 5; i >= 0; i--) budgetStatus(b, f, txs, s, offset: -i)];
    final maxH = [...history.map((h) => h.spent), ...history.map((h) => h.limit), 1.0].reduce(math.max);
    String m(double v, {bool c = false}) => formatMoney(v, b.currency, compact: c, hidden: s.hideBalance);

    return Scaffold(
      appBar: AppBar(
        title: Text(b.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetFormScreen(existing: b))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: EnsoRing(
              progress: st.ratio,
              size: 180,
              stroke: 13,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GlyphIcon(b.icon, color: Color(b.color), size: 32),
                Text('${(st.ratio * 100).round()}%', style: AppTheme.serif(size: 26, weight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(fmtRange(st.range), style: AppTheme.sans(color: WaColors.washiMuted))),
          const SizedBox(height: 16),
          WaCard(
            child: Column(
              children: [
                _row(t.t('Batas', 'Limit'), m(st.limit)),
                if (st.carried > 0) _row(t.t('   termasuk sisa periode lalu', '   includes last period leftover'), m(st.carried)),
                _row(t.t('Terpakai', 'Spent'), m(st.spent)),
                _row(st.left >= 0 ? t.t('Sisa', 'Left') : t.t('Kelebihan', 'Over by'), m(st.left.abs()), color: st.left >= 0 ? WaColors.income : WaColors.expense),
                _row(t.t('Jatah per hari (${st.daysLeft} hari lagi)', 'Per day (${st.daysLeft} days left)'), m(st.perDayLeft)),
                _row(t.t('Perkiraan di akhir periode', 'Projected by end of period'), m(st.projection),
                    color: st.projection > st.limit ? WaColors.expense : WaColors.washi),
                _row(
                  t.categories,
                  b.categoryIds.isEmpty
                      ? t.t('Semua pengeluaran', 'All spending')
                      : b.categoryIds.split(',').map((e) => cats[int.tryParse(e)]?.name).whereType<String>().join(', '),
                ),
              ],
            ),
          ),
          SectionHeader(title: t.t('6 periode terakhir', 'Last 6 periods'), jp: '歴'),
          WaCard(
            child: Column(
              children: [
                for (final h in history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(
                        width: 70,
                        child: Text(b.period == 'monthly' ? monthShort(h.range.start) : fmtDateShort(h.range.start),
                            style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                      ),
                      Expanded(child: InkBar(value: h.spent / maxH, height: 8, color: h.spent > h.limit ? WaColors.expense : WaColors.accent)),
                      const SizedBox(width: 8),
                      SizedBox(width: 70, child: Text(m(h.spent, c: true), textAlign: TextAlign.end, style: AppTheme.sans(size: 12))),
                    ]),
                  ),
              ],
            ),
          ),
          SectionHeader(title: t.t('Transaksi periode ini', 'This period'), jp: '記'),
          if (inPeriod.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(t.t('Belum ada pengeluaran', 'No spending yet'))))
          else
            WaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [for (final x in inPeriod) TransactionTile(tx: x, showDate: true)]),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTheme.sans(size: 13, color: WaColors.washiMuted))),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: color))),
        ]),
      );
}

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key, this.existing});

  final Budget? existing;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(text: widget.existing?.amount.toStringAsFixed(0) ?? '');
  late String _currency = widget.existing?.currency ?? ref.read(settingsProvider).baseCurrency;
  late String _period = widget.existing?.period ?? 'monthly';
  late final Set<int> _cats = {...?widget.existing?.categoryIds.split(',').map(int.tryParse).whereType<int>()};
  late bool _rollover = widget.existing?.rollover ?? false;
  late double _alert = (widget.existing?.alertPercent ?? 80).toDouble();
  late String _icon = widget.existing?.icon ?? '算';
  late int _color = widget.existing?.color ?? WaColors.yamabuki.toARGB32();
  late bool _active = widget.existing?.active ?? true;

  Future<void> _save() async {
    final t = S.of(context);
    final amount = parseAmount(_amount.text);
    if (_name.text.trim().isEmpty || amount == null || amount <= 0) {
      return showSnack(context, t.t('Nama dan nominal budget belum diisi', 'Fill in the budget name and amount'));
    }
    await ref.read(databaseProvider).saveBudget(BudgetsCompanion(
          id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
          name: Value(_name.text.trim()),
          amount: Value(amount),
          currency: Value(_currency),
          period: Value(_period),
          categoryIds: Value(_cats.join(',')),
          rollover: Value(_rollover),
          alertPercent: Value(_alert.round()),
          icon: Value(_icon),
          color: Value(_color),
          active: Value(_active),
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final roots = (ref.watch(categoriesProvider).value ?? const <TxCategory>[])
        .where((c) => c.type == 'expense' && c.parentId == null && !c.isSystem)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? t.t('Budget baru', 'New budget') : t.t('Ubah budget', 'Edit budget')),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDialog(context,
                    title: t.t('Hapus budget ini?', 'Delete this budget?'),
                    message: t.t('Transaksinya tetap aman, tidak ikut terhapus.', "Your transactions won't be touched."))) {
                  return;
                }
                await ref.read(databaseProvider).deleteBudget(widget.existing!.id);
                if (context.mounted) Navigator.of(context)..pop()..maybePop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            GestureDetector(
              onTap: () async {
                final k = await pickKanji(context, current: _icon, color: Color(_color));
                if (k != null) setState(() => _icon = k);
              },
              child: KanjiBadge(glyph: _icon, color: Color(_color), size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _name, decoration: InputDecoration(hintText: t.t('Nama budget, contoh: Makan bulanan', 'Budget name, e.g. Monthly food')))),
          ]),
          const SizedBox(height: 16),
          LabeledField(
            label: t.t('Batas', 'Limit'),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(prefixText: '${currencyInfo(_currency).symbol} '),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final c = await pickCurrency(context, current: _currency);
                  if (c != null) setState(() => _currency = c);
                },
                child: Text(_currency),
              ),
            ]),
          ),
          LabeledField(
            label: t.t('Periode', 'Period'),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final p in const ['weekly', 'monthly', 'yearly']) ButtonSegment(value: p, label: Text(t.periodLabel(p)))],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.first),
            ),
          ),
          LabeledField(
            label: t.t('Kategori (biarkan kosong untuk semua pengeluaran)', 'Categories (leave empty for all spending)'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in roots)
                  FilterChip(
                    avatar: GlyphIcon(c.icon, color: Color(c.color), size: 15),
                    label: Text(c.name),
                    selected: _cats.contains(c.id),
                    onSelected: (v) => setState(() => v ? _cats.add(c.id) : _cats.remove(c.id)),
                  ),
              ],
            ),
          ),
          LabeledField(
            label: t.t('Kasih peringatan saat terpakai ${_alert.round()}%', 'Warn me at ${_alert.round()}% used'),
            child: Slider(value: _alert, min: 50, max: 100, divisions: 10, onChanged: (v) => setState(() => _alert = v)),
          ),
          LabeledField(label: t.color, child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.t('Bawa sisa ke periode berikutnya', 'Carry leftover to next period')),
            subtitle: Text(t.t('Sisa budget yang tidak terpakai ditambahkan ke periode berikutnya', 'Unused budget gets added to the next period'),
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            value: _rollover,
            onChanged: (v) => setState(() => _rollover = v),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t.active), value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
