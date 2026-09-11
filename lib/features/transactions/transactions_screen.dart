import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/finance.dart';
import 'transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.initialFilter, this.title});

  final TxFilter? initialFilter;
  final String? title;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TxFilter _filter;
  int _monthOffset = 0;
  bool _allTime = false;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? const TxFilter();
    _allTime = widget.initialFilter != null && widget.initialFilter!.from == null;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateRange _range() {
    final s = ref.read(settingsProvider);
    final base = monthRange(DateTime.now(), startDay: s.monthStartDay);
    return _monthOffset == 0 ? base : base.shift(_monthOffset, 'monthly');
  }

  TxFilter get _effective {
    if (_allTime || _filter.search.isNotEmpty) {
      return TxFilter(
        type: _filter.type,
        accountIds: _filter.accountIds,
        categoryIds: _filter.categoryIds,
        tagIds: _filter.tagIds,
        search: _filter.search,
        minAmount: _filter.minAmount,
        maxAmount: _filter.maxAmount,
        from: _filter.from,
        to: _filter.to,
      );
    }
    final r = _range();
    return _filter.copyWith(from: r.start, to: r.end);
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<TxFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result.copyWith(search: _filter.search));
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    ref.watch(settingsProvider.select((s) => s.monthStartDay));
    final settings = ref.watch(settingsProvider);
    final txsAsync = ref.watch(transactionsProvider(_effective));
    final f = Finance(
      accounts: ref.watch(accountMapProvider),
      balances: const {},
      categories: ref.watch(categoryMapProvider),
      rates: ref.watch(ratesProvider),
      baseCurrency: settings.baseCurrency,
    );
    final isRoot = widget.initialFilter == null;
    String m(double v) => formatMoney(v, settings.baseCurrency, compact: true, hidden: settings.hideBalance);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isRoot,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(hintText: t.t('Cari catatan atau penerima', 'Search notes or payees'), filled: false, border: InputBorder.none),
                onChanged: (v) => setState(() => _filter = _filter.copyWith(search: v)),
              )
            : Text(widget.title ?? t.withJp('記録', t.t('Transaksi', 'Activity'))),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _filter = _filter.copyWith(search: '');
              }
            }),
          ),
          IconButton(
            icon: Badge(isLabelVisible: _filter.isFiltered && _filter.search.isEmpty, child: const Icon(Icons.tune)),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filter.search.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _allTime ? null : () => setState(() => _monthOffset--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _monthOffset = 0;
                        _allTime = false;
                      }),
                      child: Text(
                        _allTime ? t.t('Semua waktu', 'All time') : fmtRange(_range()),
                        textAlign: TextAlign.center,
                        style: AppTheme.serif(size: 16, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _allTime ? null : () => setState(() => _monthOffset++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _allTime = !_allTime),
                    child: Text(_allTime ? t.t('Per bulan', 'By month') : t.all),
                  ),
                ],
              ),
            ),
          Expanded(
            child: txsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (txs) {
                if (txs.isEmpty) {
                  return EmptyState(
                    kanji: '無',
                    title: t.t('Belum ada transaksi', 'No transactions yet'),
                    subtitle: _filter.isFiltered
                        ? t.t('Tidak ada yang cocok dengan filter.', 'Nothing matches your filter.')
                        : t.t('Ketuk tombol + untuk mulai mencatat.', 'Tap + to add one.'),
                  );
                }
                final s = f.summarize(txs);
                final groups = groupBy(txs, (TxEntry x) => dateOnly(x.date));
                final days = groups.keys.toList();
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: WaCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              _Stat(t.t('Masuk', 'In'), m(s.income), WaColors.income),
                              _Stat(t.t('Keluar', 'Out'), m(s.expense), WaColors.expense),
                              _Stat(t.t('Selisih', 'Net'), m(s.income - s.expense), WaColors.washi),
                              _Stat(t.t('Jumlah', 'Count'), '${txs.length}', WaColors.washiMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: days.length,
                      itemBuilder: (_, i) {
                        final day = days[i];
                        final list = groups[day]!;
                        final ds = f.summarize(list);
                        return Column(
                          children: [
                            DayHeader(
                              date: day,
                              income: ds.income,
                              expense: ds.expense,
                              currency: settings.baseCurrency,
                              hidden: settings.hideBalance,
                            ),
                            for (final x in list) _DismissibleTx(tx: x),
                          ],
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(label, style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
            const SizedBox(height: 2),
            FittedBox(child: Text(value, style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: color))),
          ],
        ),
      );
}

class _DismissibleTx extends ConsumerWidget {
  const _DismissibleTx({required this.tx});

  final TxEntry tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    return Dismissible(
      key: ValueKey('tx-${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: WaColors.expense.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline, color: WaColors.expense),
      ),
      confirmDismiss: (_) async => tx.debtId == null && tx.goalId == null
          ? true
          : confirmDialog(
              context,
              title: t.t('Hapus transaksi ini?', 'Delete this transaction?'),
              message: t.t('Transaksi ini terhubung ke utang atau target. Catatan pembayarannya juga ikut terhapus.',
                  "This one is linked to a debt or goal. Its payment record will be deleted too."),
            ),
      onDismissed: (_) async {
        final db = ref.read(databaseProvider);
        final tags = await db.getTagIdsFor(tx.id);
        await db.deleteTransaction(tx.id);
        if (!context.mounted) return;
        showSnack(context, t.t('Transaksi dihapus', 'Transaction deleted'), actionLabel: t.t('Batalkan', 'Undo'), onAction: () {
          db.saveTransaction(tx.toCompanion(true), tagIds: tags);
        });
      },
      child: TransactionTile(tx: tx),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final TxFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _type = widget.initial.type;
  late final Set<int> _accounts = {...widget.initial.accountIds};
  late final Set<int> _categories = {...widget.initial.categoryIds};
  late final Set<int> _tags = {...widget.initial.tagIds};
  late final _min = TextEditingController(text: widget.initial.minAmount?.toStringAsFixed(0) ?? '');
  late final _max = TextEditingController(text: widget.initial.maxAmount?.toStringAsFixed(0) ?? '');

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final cats = (ref.watch(categoriesProvider).value ?? const <TxCategory>[])
        .where((c) => c.parentId == null && (_type == null || c.type == _type) && !c.archived && !c.isSystem)
        .toList();
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTheme.sans(size: 13, color: WaColors.washiMuted, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ]),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (ctx, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text('Filter', style: AppTheme.serif(size: 20, weight: FontWeight.w600)),
                const SizedBox(height: 16),
                section(
                  t.t('Jenis', 'Type'),
                  Wrap(spacing: 8, children: [
                    for (final type in const [null, 'expense', 'income', 'transfer'])
                      ChoiceChip(
                        label: Text(type == null ? t.all : t.typeLabel(type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ]),
                ),
                section(
                  t.wallet,
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final a in accounts)
                      FilterChip(
                        label: Text(a.name),
                        selected: _accounts.contains(a.id),
                        onSelected: (v) => setState(() => v ? _accounts.add(a.id) : _accounts.remove(a.id)),
                      ),
                  ]),
                ),
                if (_type != 'transfer')
                  section(
                    t.category,
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in cats)
                        FilterChip(
                          avatar: GlyphIcon(c.icon, color: Color(c.color), size: 15),
                          label: Text(c.name),
                          selected: _categories.contains(c.id),
                          onSelected: (v) => setState(() => v ? _categories.add(c.id) : _categories.remove(c.id)),
                        ),
                    ]),
                  ),
                if (tags.isNotEmpty)
                  section(
                    'Tag',
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final tag in tags)
                        FilterChip(
                          label: Text('#${tag.name}'),
                          selected: _tags.contains(tag.id),
                          onSelected: (v) => setState(() => v ? _tags.add(tag.id) : _tags.remove(tag.id)),
                        ),
                    ]),
                  ),
                section(
                  t.t('Nominal', 'Amount'),
                  Row(children: [
                    Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: t.t('Paling kecil', 'Min')))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(t.t('sampai', 'to'))),
                    Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: t.t('Paling besar', 'Max')))),
                  ]),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, const TxFilter()),
                    child: Text(t.t('Reset', 'Reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TxFilter(
                        type: _type,
                        accountIds: _accounts,
                        categoryIds: _categories,
                        tagIds: _tags,
                        minAmount: parseAmount(_min.text),
                        maxAmount: parseAmount(_max.text),
                      ),
                    ),
                    child: Text(t.t('Terapkan', 'Apply')),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
