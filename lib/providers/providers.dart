import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/dates.dart';
import '../core/utils/money.dart';
import '../data/database/database.dart';
import '../services/settings.dart';

export '../services/settings.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override in main'));

// -----------------------------------------------------------------------------
// Master data
// -----------------------------------------------------------------------------

final accountsProvider = StreamProvider<List<Account>>((ref) => ref.watch(databaseProvider).watchAccounts());

final allAccountsProvider =
    StreamProvider<List<Account>>((ref) => ref.watch(databaseProvider).watchAccounts(includeArchived: true));

final accountMapProvider = Provider<Map<int, Account>>((ref) {
  final list = ref.watch(allAccountsProvider).value ?? const [];
  return {for (final a in list) a.id: a};
});

final balancesProvider = StreamProvider<Map<int, double>>((ref) => ref.watch(databaseProvider).watchBalances());

final categoriesProvider = StreamProvider<List<TxCategory>>((ref) => ref.watch(databaseProvider).watchCategories());

final categoryMapProvider = Provider<Map<int, TxCategory>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in list) c.id: c};
});

final tagsProvider = StreamProvider<List<Tag>>((ref) => ref.watch(databaseProvider).watchTags());

final txTagMapProvider =
    StreamProvider<Map<int, List<int>>>((ref) => ref.watch(databaseProvider).watchTransactionTagMap());

final budgetsProvider = StreamProvider<List<Budget>>((ref) => ref.watch(databaseProvider).watchBudgets());

final goalsProvider = StreamProvider<List<Goal>>((ref) => ref.watch(databaseProvider).watchGoals());

final goalSavedProvider = StreamProvider<Map<int, double>>((ref) => ref.watch(databaseProvider).watchGoalSaved());

final debtsProvider = StreamProvider<List<Debt>>((ref) => ref.watch(databaseProvider).watchDebts());

final debtPaidProvider = StreamProvider<Map<int, double>>((ref) => ref.watch(databaseProvider).watchDebtPaid());

final recurringsProvider = StreamProvider<List<Recurring>>((ref) => ref.watch(databaseProvider).watchRecurrings());

final installmentsProvider =
    StreamProvider<List<Installment>>((ref) => ref.watch(databaseProvider).watchInstallments());

final presetsProvider = StreamProvider<List<Preset>>((ref) => ref.watch(databaseProvider).watchPresets());

final rateRowsProvider = StreamProvider<List<ExchangeRate>>((ref) => ref.watch(databaseProvider).watchRates());

/// Kurs per USD, termasuk emas per gram yang diturunkan dari XAU.
final ratesProvider = Provider<Map<String, double>>((ref) {
  final rows = ref.watch(rateRowsProvider).value ?? const [];
  return ratesFromRows(rows);
});

Map<String, double> ratesFromRows(List<ExchangeRate> rows) {
  final map = <String, double>{'USD': 1};
  for (final r in rows) {
    map[r.code] = r.perUsd;
  }
  if (!rows.any((r) => r.code == kGoldGram && r.manual) && map['XAU'] != null) {
    map[kGoldGram] = map['XAU']! * kTroyOunceGram;
  }
  return map;
}

// -----------------------------------------------------------------------------
// Transactions
// -----------------------------------------------------------------------------

class TxFilter {
  const TxFilter({
    this.from,
    this.to,
    this.type,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.tagIds = const {},
    this.search = '',
    this.minAmount,
    this.maxAmount,
    this.limit,
  });

  final DateTime? from;
  final DateTime? to;
  final String? type;
  final Set<int> accountIds;
  final Set<int> categoryIds;
  final Set<int> tagIds;
  final String search;
  final double? minAmount;
  final double? maxAmount;
  final int? limit;

  bool get isFiltered =>
      type != null ||
      accountIds.isNotEmpty ||
      categoryIds.isNotEmpty ||
      tagIds.isNotEmpty ||
      search.isNotEmpty ||
      minAmount != null ||
      maxAmount != null;

  TxFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? Function()? type,
    Set<int>? accountIds,
    Set<int>? categoryIds,
    Set<int>? tagIds,
    String? search,
    double? Function()? minAmount,
    double? Function()? maxAmount,
  }) =>
      TxFilter(
        from: from ?? this.from,
        to: to ?? this.to,
        type: type != null ? type() : this.type,
        accountIds: accountIds ?? this.accountIds,
        categoryIds: categoryIds ?? this.categoryIds,
        tagIds: tagIds ?? this.tagIds,
        search: search ?? this.search,
        minAmount: minAmount != null ? minAmount() : this.minAmount,
        maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
        limit: limit,
      );

  @override
  bool operator ==(Object other) =>
      other is TxFilter &&
      other.from == from &&
      other.to == to &&
      other.type == type &&
      _setEq(other.accountIds, accountIds) &&
      _setEq(other.categoryIds, categoryIds) &&
      _setEq(other.tagIds, tagIds) &&
      other.search == search &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.limit == limit;

  static bool _setEq(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
        from,
        to,
        type,
        Object.hashAllUnordered(accountIds),
        Object.hashAllUnordered(categoryIds),
        Object.hashAllUnordered(tagIds),
        search,
        minAmount,
        maxAmount,
        limit,
      );
}

final transactionsProvider = StreamProvider.family<List<TxEntry>, TxFilter>((ref, f) {
  final db = ref.watch(databaseProvider);
  // Kategori yang dipilih juga mencakup sub-kategorinya.
  Set<int>? catIds;
  if (f.categoryIds.isNotEmpty) {
    final cats = ref.watch(categoriesProvider).value ?? const [];
    catIds = {...f.categoryIds, ...cats.where((c) => f.categoryIds.contains(c.parentId)).map((c) => c.id)};
  }
  final stream = db.watchTransactions(
    from: f.from,
    to: f.to,
    type: f.type,
    accountIds: f.accountIds,
    categoryIds: catIds,
    search: f.search,
    minAmount: f.minAmount,
    maxAmount: f.maxAmount,
    limit: f.limit,
  );
  if (f.tagIds.isEmpty) return stream;
  final tagMap = ref.watch(txTagMapProvider).value ?? const {};
  return stream.map((list) => list.where((t) => (tagMap[t.id] ?? const []).any(f.tagIds.contains)).toList());
});

// -----------------------------------------------------------------------------
// Period selection (dipakai Beranda & Statistik)
// -----------------------------------------------------------------------------

final periodTypeProvider = NotifierProvider<PeriodTypeNotifier, String>(PeriodTypeNotifier.new);

class PeriodTypeNotifier extends Notifier<String> {
  @override
  String build() => 'monthly';

  void set(String v) => state = v;
}

final periodOffsetProvider = NotifierProvider<PeriodOffsetNotifier, int>(PeriodOffsetNotifier.new);

class PeriodOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void prev() => state--;
  void next() => state++;
  void reset() => state = 0;
}

final currentRangeProvider = Provider<DateRange>((ref) {
  final s = ref.watch(settingsProvider);
  final type = ref.watch(periodTypeProvider);
  final offset = ref.watch(periodOffsetProvider);
  final base = periodRange(type, DateTime.now(), monthStartDay: s.monthStartDay, firstWeekday: s.firstWeekday);
  return offset == 0 ? base : base.shift(offset, type);
});

final periodTransactionsProvider = StreamProvider<List<TxEntry>>((ref) {
  final r = ref.watch(currentRangeProvider);
  return ref.watch(databaseProvider).watchTransactions(from: r.start, to: r.end);
});

/// Bulan berjalan (mengikuti tanggal awal periode), dipakai dashboard & widget.
final thisMonthRangeProvider = Provider<DateRange>((ref) {
  final s = ref.watch(settingsProvider);
  return monthRange(DateTime.now(), startDay: s.monthStartDay);
});

final thisMonthTransactionsProvider = StreamProvider<List<TxEntry>>((ref) {
  final r = ref.watch(thisMonthRangeProvider);
  return ref.watch(databaseProvider).watchTransactions(from: r.start, to: r.end);
});

final recentTransactionsProvider =
    StreamProvider<List<TxEntry>>((ref) => ref.watch(databaseProvider).watchTransactions(limit: 8));
