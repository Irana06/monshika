import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/dates.dart';
import '../data/database/database.dart';
import '../services/finance.dart';
import 'providers.dart';

final financeProvider = Provider<Finance>((ref) => Finance(
      accounts: ref.watch(accountMapProvider),
      balances: ref.watch(balancesProvider).value ?? const {},
      categories: ref.watch(categoryMapProvider),
      rates: ref.watch(ratesProvider),
      baseCurrency: ref.watch(settingsProvider.select((s) => s.baseCurrency)),
    ));

final upcomingBillsProvider = Provider.family<List<UpcomingBill>, int>((ref, days) {
  return upcomingBills(
    recurrings: ref.watch(recurringsProvider).value ?? const [],
    installments: ref.watch(installmentsProvider).value ?? const [],
    debts: ref.watch(debtsProvider).value ?? const [],
    debtPaid: ref.watch(debtPaidProvider).value ?? const {},
    accounts: ref.watch(accountMapProvider),
    until: dateOnly(DateTime.now()).add(Duration(days: days + 1)),
    includeIncome: true,
  );
});

final kakeiboMonthProvider = StreamProvider.family<KakeiboMonth?, String>(
  (ref, month) => ref.watch(databaseProvider).watchKakeibo(month),
);

final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(recentTransactionsProvider);
  final days = await ref
      .watch(databaseProvider)
      .getTransactionDays(since: DateTime.now().subtract(const Duration(days: 400)));
  return computeStreak(days);
});

final safeToSpendProvider = Provider<SafeToSpend?>((ref) {
  final txs = ref.watch(thisMonthTransactionsProvider).value;
  if (txs == null) return null;
  final range = ref.watch(thisMonthRangeProvider);
  final f = ref.watch(financeProvider);
  final kakeibo = ref.watch(kakeiboMonthProvider(fmtMonthKey(range.start))).value;
  final bills = upcomingBills(
    recurrings: ref.watch(recurringsProvider).value ?? const [],
    installments: ref.watch(installmentsProvider).value ?? const [],
    debts: ref.watch(debtsProvider).value ?? const [],
    debtPaid: ref.watch(debtPaidProvider).value ?? const {},
    accounts: ref.watch(accountMapProvider),
    until: range.end,
  );
  return f.safeToSpend(
    periodTxs: txs,
    range: range,
    upcomingBills: bills.fold(0.0, (s, b) => s + f.toBase(b.amount, b.currency)),
    plannedIncome: kakeibo?.plannedIncome ?? 0,
    savingsTarget: kakeibo?.savingsTarget ?? 0,
  );
});

/// Transaksi 13 bulan terakhir (untuk tren & kekayaan bersih).
final yearTransactionsProvider = StreamProvider<List<TxEntry>>((ref) {
  final from = DateTime(DateTime.now().year - 1, DateTime.now().month - 1, 1);
  return ref.watch(databaseProvider).watchTransactions(from: from);
});
