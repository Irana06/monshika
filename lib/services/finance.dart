import 'dart:math' as math;

import '../core/utils/dates.dart';
import '../core/utils/money.dart';
import '../data/database/database.dart';
import '../l10n/strings.dart';

/// Kumpulan perhitungan murni (tanpa I/O) supaya bisa dipakai di aplikasi,
/// dialog quick-add, maupun isolate widget beranda.
class Finance {
  Finance({
    required this.accounts,
    required this.balances,
    required this.categories,
    required this.rates,
    required this.baseCurrency,
  });

  final Map<int, Account> accounts;
  final Map<int, double> balances;
  final Map<int, TxCategory> categories;
  final Map<String, double> rates;
  final String baseCurrency;

  /// Saldo yang benar-benar bebas dipakai. Tabungan sengaja tidak termasuk
  /// karena itu uang yang sudah disisihkan, bukan jatah belanja.
  static const liquidTypes = {'cash', 'bank', 'ewallet'};
  static const liabilityTypes = {'credit', 'paylater'};

  String currencyOf(int accountId) => accounts[accountId]?.currency ?? baseCurrency;

  double toBase(double amount, String currency) => convert(amount, currency, baseCurrency, rates);

  double txBase(TxEntry t) => toBase(t.amount, currencyOf(t.accountId));

  double accountBalance(int id) => balances[id] ?? accounts[id]?.initialBalance ?? 0;

  double get totalBalance => accounts.values
      .where((a) => a.includeInTotal && !a.archived)
      .fold(0.0, (s, a) => s + toBase(accountBalance(a.id), a.currency));

  double get liquidBalance => accounts.values
      .where((a) => a.includeInTotal && !a.archived && liquidTypes.contains(a.type))
      .fold(0.0, (s, a) => s + toBase(accountBalance(a.id), a.currency));

  double get assets => accounts.values
      .where((a) => !a.archived)
      .map((a) => toBase(accountBalance(a.id), a.currency))
      .where((v) => v > 0)
      .fold(0.0, (s, v) => s + v);

  double get liabilities => accounts.values
      .where((a) => !a.archived)
      .map((a) => toBase(accountBalance(a.id), a.currency))
      .where((v) => v < 0)
      .fold(0.0, (s, v) => s + v.abs());

  bool countsInStats(TxEntry t) => !t.excludeFromStats && t.type != 'transfer';

  ({double income, double expense}) summarize(Iterable<TxEntry> txs) {
    var income = 0.0, expense = 0.0;
    for (final t in txs) {
      if (!countsInStats(t)) continue;
      final v = txBase(t);
      if (t.type == 'income') income += v;
      if (t.type == 'expense') expense += v;
    }
    return (income: income, expense: expense);
  }

  /// Id kategori induk (level teratas) untuk pengelompokan.
  int? rootCategory(int? id) {
    var c = id == null ? null : categories[id];
    var guard = 0;
    while (c != null && c.parentId != null && guard++ < 5) {
      final p = categories[c.parentId];
      if (p == null) break;
      c = p;
    }
    return c?.id;
  }

  Set<int> withChildren(Iterable<int> ids) {
    final result = ids.toSet();
    for (final c in categories.values) {
      if (c.parentId != null && result.contains(c.parentId)) result.add(c.id);
    }
    return result;
  }

  /// Total per kategori (root) untuk tipe tertentu, diurutkan menurun.
  List<MapEntry<int?, double>> breakdown(Iterable<TxEntry> txs, String type, {bool byRoot = true}) {
    final map = <int?, double>{};
    for (final t in txs) {
      if (t.type != type || !countsInStats(t)) continue;
      final key = byRoot ? rootCategory(t.categoryId) : t.categoryId;
      map[key] = (map[key] ?? 0) + txBase(t);
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Map<String, double> pillarBreakdown(Iterable<TxEntry> txs) {
    final map = <String, double>{'needs': 0, 'wants': 0, 'culture': 0, 'unexpected': 0};
    for (final t in txs) {
      if (t.type != 'expense' || !countsInStats(t)) continue;
      final cat = t.categoryId == null ? null : categories[t.categoryId];
      final root = cat?.parentId != null ? categories[cat!.parentId] : null;
      final pillar = cat?.pillar ?? root?.pillar ?? 'unexpected';
      map[pillar] = (map[pillar] ?? 0) + txBase(t);
    }
    return map;
  }

  /// Total pengeluaran harian dalam rentang (index 0 = hari pertama).
  List<double> dailyTotals(Iterable<TxEntry> txs, DateRange range, String type) {
    final days = math.max(1, range.days);
    final list = List<double>.filled(days, 0);
    for (final t in txs) {
      if (t.type != type || !countsInStats(t) || !range.contains(t.date)) continue;
      final idx = dateOnly(t.date).difference(range.start).inDays;
      if (idx >= 0 && idx < days) list[idx] += txBase(t);
    }
    return list;
  }

  double budgetSpent(Budget b, Iterable<TxEntry> txs, DateRange range) {
    final ids = b.categoryIds.isEmpty
        ? null
        : withChildren(b.categoryIds.split(',').map(int.tryParse).whereType<int>());
    var total = 0.0;
    for (final t in txs) {
      if (t.type != 'expense' || t.excludeFromStats || !range.contains(t.date)) continue;
      if (ids != null && !ids.contains(t.categoryId)) continue;
      total += convert(t.amount, currencyOf(t.accountId), b.currency, rates);
    }
    return total;
  }

  /// Rencana dan sisa aman belanja untuk periode berjalan.
  ///
  /// Menghasilkan dua lapis angka:
  /// - **Rencana** ([SafeToSpend.periodPool] dan [SafeToSpend.periodPerDay]):
  ///   patokan tetap untuk seluruh periode, dihitung dari pemasukan dikurangi
  ///   target menabung dan semua tagihan periode ini (yang sudah dibayar maupun
  ///   yang belum). Angkanya tidak bergerak walau hari ini boros.
  /// - **Realisasi** ([SafeToSpend.perDay] dan [SafeToSpend.todayLeft]): sisa
  ///   yang dibagi rata ke hari yang tersisa, jadi ikut menyesuaikan tiap hari.
  ///
  /// [upcomingBills] adalah tagihan yang belum dibayar sampai akhir periode.
  /// Tagihan yang sudah dibayar dibaca dari [periodTxs] lewat relasinya ke
  /// transaksi berulang, cicilan, dan utang, supaya tidak terhitung dua kali.
  SafeToSpend safeToSpend({
    required Iterable<TxEntry> periodTxs,
    required DateRange range,
    required double upcomingBills,
    double plannedIncome = 0,
    double savingsTarget = 0,
    DateTime? now,
  }) {
    final today = dateOnly(now ?? DateTime.now());
    final remainingDays = math.max(1, range.end.difference(today).inDays);
    final s = summarize(periodTxs);

    var todaySpent = 0.0;
    var paidBills = 0.0;
    for (final t in periodTxs) {
      if (t.type != 'expense' || !countsInStats(t)) continue;
      final v = txBase(t);
      if (dateOnly(t.date) == today) todaySpent += v;
      if (t.recurringId != null || t.installmentId != null || t.debtId != null) paidBills += v;
    }

    final income = math.max(s.income, plannedIncome);
    final hasPlan = income > 0;

    final double pool;
    final String basis;
    if (hasPlan) {
      pool = income - savingsTarget - upcomingBills - (s.expense - todaySpent);
      basis = 'income';
    } else {
      pool = liquidBalance + todaySpent - upcomingBills - savingsTarget;
      basis = 'balance';
    }
    final perDay = pool / remainingDays;

    // Lapis rencana. Semua tagihan periode ini = yang belum dibayar + yang
    // sudah dibayar, jadi belanja bebasnya = pengeluaran di luar tagihan.
    final periodDays = math.max(1, range.days);
    final periodPool = hasPlan ? income - savingsTarget - upcomingBills - paidBills : 0.0;
    final periodSpent = math.max(0.0, s.expense - paidBills);

    return SafeToSpend(
      perDay: perDay,
      todaySpent: todaySpent,
      todayLeft: perDay - todaySpent,
      remainingDays: remainingDays,
      pool: pool,
      basis: basis,
      periodPool: periodPool,
      periodPerDay: periodPool / periodDays,
      periodSpent: periodSpent,
      periodDays: periodDays,
      paidBills: paidBills,
    );
  }
}

class SafeToSpend {
  const SafeToSpend({
    required this.perDay,
    required this.todaySpent,
    required this.todayLeft,
    required this.remainingDays,
    required this.pool,
    required this.basis,
    required this.periodPool,
    required this.periodPerDay,
    required this.periodSpent,
    required this.periodDays,
    required this.paidBills,
  });

  /// Jatah harian yang menyesuaikan sisa pool dan sisa hari.
  final double perDay;
  final double todaySpent;
  final double todayLeft;
  final int remainingDays;
  final double pool;

  /// `income` bila hitungannya berdasar pemasukan, `balance` bila berdasar saldo.
  final String basis;

  /// Total yang aman dipakai untuk seluruh periode, di luar tagihan dan tabungan.
  final double periodPool;

  /// Jatah harian tetap: [periodPool] dibagi jumlah hari dalam periode.
  final double periodPerDay;

  /// Belanja bebas yang sudah terpakai periode ini (tidak termasuk tagihan).
  final double periodSpent;

  final int periodDays;

  /// Tagihan periode ini yang sudah dibayar.
  final double paidBills;

  /// Rencana periode hanya bermakna kalau ada pemasukan yang jadi patokan.
  bool get hasPlan => basis == 'income';

  /// Sisa dari rencana periode. Konsisten dengan [pool]: `pool = periodLeft + todaySpent`.
  double get periodLeft => periodPool - periodSpent;

  double get periodUsedRatio => periodPool <= 0 ? 1 : (periodSpent / periodPool).clamp(0, 1).toDouble();

  double get usedRatio => perDay <= 0 ? 1 : (todaySpent / perDay).clamp(0, 1).toDouble();
}

/// Tagihan yang akan datang dari transaksi berulang, cicilan, dan utang.
class UpcomingBill {
  const UpcomingBill({
    required this.title,
    required this.date,
    required this.amount,
    required this.currency,
    required this.kind,
    required this.icon,
    required this.color,
    this.refId,
    this.isIncome = false,
  });

  final String title;
  final DateTime date;
  final double amount;
  final String currency;
  final String kind; // recurring | installment | debt
  final String icon;
  final int color;
  final int? refId;
  final bool isIncome;
}

DateTime nextOccurrence(DateTime from, String frequency, int interval) => switch (frequency) {
      'daily' => from.add(Duration(days: interval)),
      'weekly' => from.add(Duration(days: 7 * interval)),
      'yearly' => DateTime(from.year + interval, from.month, from.day, from.hour, from.minute),
      _ => addMonths(from, interval),
    };

DateTime installmentDueDate(Installment i, [DateTime? ref]) {
  final now = ref ?? DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  var due = DateTime(now.year, now.month, math.min(i.dueDay, lastDay));
  if (due.isBefore(dateOnly(now))) {
    final nextLast = DateTime(now.year, now.month + 2, 0).day;
    due = DateTime(now.year, now.month + 1, math.min(i.dueDay, nextLast));
  }
  return due;
}

List<UpcomingBill> upcomingBills({
  required List<Recurring> recurrings,
  required List<Installment> installments,
  required List<Debt> debts,
  required Map<int, double> debtPaid,
  required Map<int, Account> accounts,
  required DateTime until,
  bool includeIncome = false,
}) {
  final now = dateOnly(DateTime.now());
  final list = <UpcomingBill>[];
  for (final r in recurrings) {
    if (!r.active || (!includeIncome && r.type == 'income')) continue;
    var d = r.nextDate;
    var guard = 0;
    while (d.isBefore(until) && guard++ < 62) {
      if (r.endDate != null && d.isAfter(r.endDate!)) break;
      if (!d.isBefore(now)) {
        list.add(UpcomingBill(
          title: r.name,
          date: d,
          amount: r.amount,
          currency: accounts[r.accountId]?.currency ?? 'IDR',
          kind: 'recurring',
          icon: r.icon,
          color: r.color,
          refId: r.id,
          isIncome: r.type == 'income',
        ));
      }
      d = nextOccurrence(d, r.frequency, r.interval);
    }
  }
  for (final i in installments) {
    if (!i.active || i.paidCount >= i.tenor) continue;
    final due = installmentDueDate(i);
    if (due.isBefore(until)) {
      list.add(UpcomingBill(
        title: '${i.name} (${i.paidCount + 1}/${i.tenor})',
        date: due,
        amount: i.monthlyAmount,
        currency: i.accountId != null ? (accounts[i.accountId]?.currency ?? 'IDR') : 'IDR',
        kind: 'installment',
        icon: '返',
        color: 0xFFB5453A,
        refId: i.id,
      ));
    }
  }
  for (final d in debts) {
    if (d.settled || d.dueDate == null || !d.dueDate!.isBefore(until)) continue;
    if (!includeIncome && d.direction == 'lend') continue;
    final left = d.amount - (debtPaid[d.id] ?? 0);
    if (left <= 0) continue;
    list.add(UpcomingBill(
      title: d.direction == 'borrow'
          ? S.current.t('Bayar utang ke ${d.person}', 'Pay back ${d.person}')
          : S.current.t('Tagih ${d.person}', 'Collect from ${d.person}'),
      date: d.dueDate!,
      amount: left,
      currency: d.currency,
      kind: 'debt',
      icon: '借',
      color: 0xFF8C8C96,
      refId: d.id,
      isIncome: d.direction == 'lend',
    ));
  }
  list.sort((a, b) => a.date.compareTo(b.date));
  return list;
}

/// Jumlah hari berturut-turut (sampai hari ini/kemarin) yang ada catatannya.
int computeStreak(List<DateTime> days) {
  if (days.isEmpty) return 0;
  final set = days.map(dateOnly).toSet();
  var cursor = dateOnly(DateTime.now());
  if (!set.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var streak = 0;
  while (set.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
