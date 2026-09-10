import 'package:drift/drift.dart';

import '../core/utils/dates.dart';
import '../data/database/database.dart';
import '../data/database/seed.dart';
import 'finance.dart';

/// Aksi domain yang melibatkan beberapa tabel sekaligus.
class MoneyActions {
  MoneyActions(this.db);

  final AppDatabase db;

  Future<int?> _systemCategory(String name) async => (await db.findSystemCategory(name))?.id;

  // ---------------------------------------------------------------------------
  // Transaksi berulang
  // ---------------------------------------------------------------------------

  /// Catat semua transaksi berulang (auto-post) yang sudah jatuh tempo.
  Future<int> processDueRecurrings({DateTime? now}) async {
    final current = now ?? DateTime.now();
    var posted = 0;
    final list = await db.getActiveRecurrings();
    for (final r in list) {
      if (!r.autoPost) continue;
      var next = r.nextDate;
      var guard = 0;
      var active = true;
      while (!next.isAfter(current) && guard++ < 400) {
        if (r.endDate != null && next.isAfter(r.endDate!)) {
          active = false;
          break;
        }
        await _postRecurring(r, next);
        posted++;
        next = nextOccurrence(next, r.frequency, r.interval);
      }
      if (r.endDate != null && next.isAfter(r.endDate!)) active = false;
      if (next != r.nextDate || !active) {
        await db.saveRecurring(RecurringsCompanion(id: Value(r.id), nextDate: Value(next), active: Value(active)));
      }
    }
    return posted;
  }

  Future<void> _postRecurring(Recurring r, DateTime date) => db.saveTransaction(TransactionsCompanion.insert(
        type: r.type,
        amount: r.amount,
        accountId: r.accountId,
        toAccountId: Value(r.toAccountId),
        categoryId: Value(r.categoryId),
        date: date,
        note: Value(r.note.isEmpty ? r.name : r.note),
        recurringId: Value(r.id),
      ));

  /// Catat manual satu kejadian lalu majukan jadwal.
  Future<void> postRecurringNow(Recurring r) async {
    await _postRecurring(r, DateTime.now());
    final next = nextOccurrence(r.nextDate, r.frequency, r.interval);
    await db.saveRecurring(RecurringsCompanion(id: Value(r.id), nextDate: Value(next)));
  }

  Future<void> skipRecurring(Recurring r) => db.saveRecurring(
        RecurringsCompanion(id: Value(r.id), nextDate: Value(nextOccurrence(r.nextDate, r.frequency, r.interval))),
      );

  // ---------------------------------------------------------------------------
  // Cicilan
  // ---------------------------------------------------------------------------

  Future<void> payInstallment(Installment i, {required int accountId, DateTime? date, double? amount}) async {
    final catId = i.categoryId ??
        (await (db.select(db.categories)..where((c) => c.name.equals('Cicilan'))).getSingleOrNull())?.id;
    await db.transaction(() async {
      await db.saveTransaction(TransactionsCompanion.insert(
        type: 'expense',
        amount: amount ?? i.monthlyAmount,
        accountId: accountId,
        categoryId: Value(catId),
        date: date ?? DateTime.now(),
        note: Value('${i.name} (${i.paidCount + 1}/${i.tenor})'),
        installmentId: Value(i.id),
      ));
      final paid = i.paidCount + 1;
      await db.saveInstallment(InstallmentsCompanion(
        id: Value(i.id),
        paidCount: Value(paid),
        active: Value(paid < i.tenor),
      ));
    });
  }

  // ---------------------------------------------------------------------------
  // Utang & piutang
  // ---------------------------------------------------------------------------

  Future<int> createDebt({
    required String person,
    required String direction,
    required double amount,
    required String currency,
    required DateTime date,
    DateTime? dueDate,
    String note = '',
    int? accountId,
  }) async {
    final catId = await _systemCategory(kSystemDebtCategory);
    return db.transaction(() async {
      final id = await db.into(db.debts).insert(DebtsCompanion.insert(
            person: person,
            direction: direction,
            amount: amount,
            currency: Value(currency),
            date: date,
            dueDate: Value(dueDate),
            note: Value(note),
            accountId: Value(accountId),
          ));
      if (accountId != null) {
        await db.saveTransaction(TransactionsCompanion.insert(
          // Meminjamkan = uang keluar; meminjam = uang masuk.
          type: direction == 'lend' ? 'expense' : 'income',
          amount: amount,
          accountId: accountId,
          categoryId: Value(catId),
          date: date,
          note: Value(direction == 'lend' ? 'Pinjamkan ke $person' : 'Pinjam dari $person'),
          debtId: Value(id),
          excludeFromStats: const Value(true),
        ));
      }
      return id;
    });
  }

  Future<void> addDebtPayment(Debt d, {required double amount, required DateTime date, int? accountId, String note = ''}) async {
    final catId = await _systemCategory(kSystemDebtCategory);
    await db.transaction(() async {
      int? txId;
      if (accountId != null) {
        txId = await db.saveTransaction(TransactionsCompanion.insert(
          type: d.direction == 'lend' ? 'income' : 'expense',
          amount: amount,
          accountId: accountId,
          categoryId: Value(catId),
          date: date,
          note: Value(d.direction == 'lend' ? 'Pelunasan dari ${d.person}' : 'Bayar utang ke ${d.person}'),
          debtId: Value(d.id),
          excludeFromStats: const Value(true),
        ));
      }
      await db.into(db.debtPayments).insert(DebtPaymentsCompanion.insert(
            debtId: d.id,
            amount: amount,
            date: date,
            accountId: Value(accountId),
            transactionId: Value(txId),
            note: Value(note),
          ));
      final paid = await db
          .customSelect('SELECT COALESCE(SUM(amount),0) AS s FROM debt_payments WHERE debt_id = ?',
              variables: [Variable.withInt(d.id)])
          .map((r) => r.read<double>('s'))
          .getSingle();
      if (paid >= d.amount - 0.0001) {
        await (db.update(db.debts)..where((x) => x.id.equals(d.id))).write(const DebtsCompanion(settled: Value(true)));
      }
    });
  }

  Future<void> setDebtSettled(int id, bool settled) =>
      (db.update(db.debts)..where((x) => x.id.equals(id))).write(DebtsCompanion(settled: Value(settled)));

  // ---------------------------------------------------------------------------
  // Target tabungan
  // ---------------------------------------------------------------------------

  Future<void> addGoalEntry(Goal g, {required double amount, required DateTime date, int? accountId, String note = ''}) async {
    final catId = await _systemCategory(kSystemGoalCategory);
    await db.transaction(() async {
      int? txId;
      if (accountId != null) {
        txId = await db.saveTransaction(TransactionsCompanion.insert(
          type: amount >= 0 ? 'expense' : 'income',
          amount: amount.abs(),
          accountId: accountId,
          categoryId: Value(catId),
          date: date,
          note: Value(amount >= 0 ? 'Setor ke ${g.name}' : 'Tarik dari ${g.name}'),
          goalId: Value(g.id),
          excludeFromStats: const Value(true),
        ));
      }
      await db.into(db.goalEntries).insert(GoalEntriesCompanion.insert(
            goalId: g.id,
            amount: amount,
            date: date,
            note: Value(note),
            transactionId: Value(txId),
          ));
      final saved = (await db.getGoalSaved())[g.id] ?? 0;
      final done = saved >= g.targetAmount;
      if (done != (g.completedAt != null)) {
        await db.saveGoal(GoalsCompanion(id: Value(g.id), completedAt: Value(done ? DateTime.now() : null)));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Penyesuaian saldo & split bill
  // ---------------------------------------------------------------------------

  Future<void> adjustBalance(Account a, {required double currentBalance, required double actualBalance}) async {
    final diff = actualBalance - currentBalance;
    if (diff.abs() < 0.0001) return;
    final catId = await _systemCategory(kSystemAdjustCategory);
    await db.saveTransaction(TransactionsCompanion.insert(
      type: diff > 0 ? 'income' : 'expense',
      amount: diff.abs(),
      accountId: a.id,
      categoryId: Value(catId),
      date: DateTime.now(),
      note: const Value('Penyesuaian saldo'),
      excludeFromStats: const Value(true),
    ));
  }

  /// Bagi tagihan: catat bagian sendiri sebagai pengeluaran, sisanya jadi piutang.
  Future<void> splitBill({
    required String title,
    required double total,
    required int accountId,
    required String currency,
    int? categoryId,
    required double myShare,
    required Map<String, double> others,
    DateTime? date,
    DateTime? dueDate,
  }) async {
    final when = date ?? DateTime.now();
    final debtCat = await _systemCategory(kSystemDebtCategory);
    await db.transaction(() async {
      await db.saveTransaction(TransactionsCompanion.insert(
        type: 'expense',
        amount: myShare,
        accountId: accountId,
        categoryId: Value(categoryId),
        date: when,
        note: Value('$title (bagian saya)'),
      ));
      for (final e in others.entries) {
        if (e.value <= 0) continue;
        final debtId = await db.into(db.debts).insert(DebtsCompanion.insert(
              person: e.key,
              direction: 'lend',
              amount: e.value,
              currency: Value(currency),
              date: when,
              dueDate: Value(dueDate),
              note: Value('Split bill: $title'),
              accountId: Value(accountId),
            ));
        await db.saveTransaction(TransactionsCompanion.insert(
          type: 'expense',
          amount: e.value,
          accountId: accountId,
          categoryId: Value(debtCat),
          date: when,
          note: Value('$title — talangan ${e.key}'),
          debtId: Value(debtId),
          excludeFromStats: const Value(true),
        ));
      }
    });
  }

  Future<int> duplicateTransaction(TxEntry t) async {
    final tags = await db.getTagIdsFor(t.id);
    return db.saveTransaction(
      TransactionsCompanion.insert(
        type: t.type,
        amount: t.amount,
        accountId: t.accountId,
        toAccountId: Value(t.toAccountId),
        toAmount: Value(t.toAmount),
        fee: Value(t.fee),
        categoryId: Value(t.categoryId),
        date: DateTime.now(),
        note: Value(t.note),
        payee: Value(t.payee),
        excludeFromStats: Value(t.excludeFromStats),
      ),
      tagIds: tags,
    );
  }

  Future<void> recordPreset(Preset p, {DateTime? date}) => db.saveTransaction(TransactionsCompanion.insert(
        type: p.type,
        amount: p.amount,
        accountId: p.accountId,
        categoryId: Value(p.categoryId),
        date: date ?? DateTime.now(),
        note: Value(p.note.isEmpty ? p.name : p.note),
      ));

  /// Budget yang baru melewati ambang peringatan akibat transaksi [t].
  Future<List<(Budget, double)>> budgetsCrossed(TxEntry t, Finance f, {required int monthStartDay}) async {
    if (t.type != 'expense' || t.excludeFromStats) return const [];
    final result = <(Budget, double)>[];
    for (final b in await db.getBudgets()) {
      final range = periodRange(b.period, t.date, monthStartDay: monthStartDay);
      final txs = await db.getTransactions(from: range.start, to: range.end, type: 'expense');
      final spent = f.budgetSpent(b, txs, range);
      final before = spent - f.budgetSpent(b, [t], range);
      final threshold = b.amount * b.alertPercent / 100;
      if (before < threshold && spent >= threshold) result.add((b, spent / b.amount));
      if (before < b.amount && spent >= b.amount && b.alertPercent < 100) result.add((b, spent / b.amount));
    }
    return result;
  }
}
