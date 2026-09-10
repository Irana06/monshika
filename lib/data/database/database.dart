import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Tags,
    TransactionTags,
    Budgets,
    Goals,
    GoalEntries,
    Debts,
    DebtPayments,
    Recurrings,
    Installments,
    Presets,
    ExchangeRates,
    KakeiboMonths,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  static const dbName = 'monshika';

  static QueryExecutor _open() => driftDatabase(name: dbName);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        beforeOpen: (details) async {
          // Aplikasi utama, dialog quick-add, dan widget beranda membuka
          // database dari engine Flutter yang berbeda, jadi pakai WAL.
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA busy_timeout=5000');
          await customStatement('PRAGMA foreign_keys=OFF');
        },
      );

  /// Paksa semua stream query dibaca ulang (mis. setelah widget menulis data).
  void refreshAllStreams() {
    notifyUpdates({
      for (final t in allTables) TableUpdate.onTable(t),
    });
  }

  // ---------------------------------------------------------------------------
  // Accounts
  // ---------------------------------------------------------------------------

  Stream<List<Account>> watchAccounts({bool includeArchived = false}) {
    final q = select(accounts)
      ..orderBy([(a) => OrderingTerm(expression: a.sortOrder), (a) => OrderingTerm(expression: a.id)]);
    if (!includeArchived) q.where((a) => a.archived.equals(false));
    return q.watch();
  }

  Future<List<Account>> getAccounts({bool includeArchived = false}) {
    final q = select(accounts)..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]);
    if (!includeArchived) q.where((a) => a.archived.equals(false));
    return q.get();
  }

  static const _balanceSql = '''
SELECT a.id AS id,
  a.initial_balance
  + COALESCE((SELECT SUM(CASE
        WHEN t.type = 'income' THEN t.amount
        WHEN t.type = 'expense' THEN -t.amount
        WHEN t.type = 'transfer' THEN -(t.amount + t.fee)
        ELSE 0 END)
      FROM transactions t WHERE t.account_id = a.id), 0)
  + COALESCE((SELECT SUM(COALESCE(t.to_amount, t.amount))
      FROM transactions t WHERE t.type = 'transfer' AND t.to_account_id = a.id), 0)
  AS balance
FROM accounts a
''';

  Stream<Map<int, double>> watchBalances() {
    return customSelect(_balanceSql, readsFrom: {accounts, transactions}).watch().map(
          (rows) => {for (final r in rows) r.read<int>('id'): r.read<double>('balance')},
        );
  }

  Future<Map<int, double>> getBalances() async {
    final rows = await customSelect(_balanceSql, readsFrom: {accounts, transactions}).get();
    return {for (final r in rows) r.read<int>('id'): r.read<double>('balance')};
  }

  Future<int> saveAccount(AccountsCompanion data) async {
    if (data.id.present) {
      await (update(accounts)..where((a) => a.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(accounts).insert(data);
  }

  Future<void> deleteAccount(int id) => transaction(() async {
        final txIds = await (selectOnly(transactions)
              ..addColumns([transactions.id])
              ..where(transactions.accountId.equals(id) | transactions.toAccountId.equals(id)))
            .map((r) => r.read(transactions.id)!)
            .get();
        await (delete(transactionTags)..where((t) => t.transactionId.isIn(txIds))).go();
        await (delete(transactions)..where((t) => t.id.isIn(txIds))).go();
        await (delete(presets)..where((p) => p.accountId.equals(id))).go();
        await (delete(recurrings)..where((r) => r.accountId.equals(id))).go();
        await (delete(accounts)..where((a) => a.id.equals(id))).go();
      });

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Stream<List<TxCategory>> watchCategories() => (select(categories)
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder), (c) => OrderingTerm(expression: c.id)]))
      .watch();

  Future<List<TxCategory>> getCategories() => (select(categories)
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder), (c) => OrderingTerm(expression: c.id)]))
      .get();

  Future<int> saveCategory(CategoriesCompanion data) async {
    if (data.id.present) {
      await (update(categories)..where((c) => c.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(categories).insert(data);
  }

  /// Hapus kategori; transaksinya dipindah ke [moveTo] (atau tanpa kategori).
  Future<void> deleteCategory(int id, {int? moveTo}) => transaction(() async {
        await (update(transactions)..where((t) => t.categoryId.equals(id)))
            .write(TransactionsCompanion(categoryId: Value(moveTo)));
        await (update(categories)..where((c) => c.parentId.equals(id)))
            .write(const CategoriesCompanion(parentId: Value(null)));
        await (delete(categories)..where((c) => c.id.equals(id))).go();
      });

  Future<TxCategory?> findSystemCategory(String name) =>
      (select(categories)..where((c) => c.isSystem.equals(true) & c.name.equals(name))).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$TransactionsTable, TxEntry> _txQuery({
    DateTime? from,
    DateTime? to,
    String? type,
    Set<int>? accountIds,
    Set<int>? categoryIds,
    String? search,
    double? minAmount,
    double? maxAmount,
    int? limit,
  }) {
    final q = select(transactions);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      if (from != null) e = e & t.date.isBiggerOrEqualValue(from);
      if (to != null) e = e & t.date.isSmallerThanValue(to);
      if (type != null) e = e & t.type.equals(type);
      if (accountIds != null && accountIds.isNotEmpty) {
        e = e & (t.accountId.isIn(accountIds) | t.toAccountId.isIn(accountIds));
      }
      if (categoryIds != null && categoryIds.isNotEmpty) e = e & t.categoryId.isIn(categoryIds);
      if (search != null && search.trim().isNotEmpty) {
        final s = '%${search.trim()}%';
        e = e & (t.note.like(s) | t.payee.like(s));
      }
      if (minAmount != null) e = e & t.amount.isBiggerOrEqualValue(minAmount);
      if (maxAmount != null) e = e & t.amount.isSmallerOrEqualValue(maxAmount);
      return e;
    });
    q.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
    ]);
    if (limit != null) q.limit(limit);
    return q;
  }

  Stream<List<TxEntry>> watchTransactions({
    DateTime? from,
    DateTime? to,
    String? type,
    Set<int>? accountIds,
    Set<int>? categoryIds,
    String? search,
    double? minAmount,
    double? maxAmount,
    int? limit,
  }) =>
      _txQuery(
        from: from,
        to: to,
        type: type,
        accountIds: accountIds,
        categoryIds: categoryIds,
        search: search,
        minAmount: minAmount,
        maxAmount: maxAmount,
        limit: limit,
      ).watch();

  Future<List<TxEntry>> getTransactions({DateTime? from, DateTime? to, String? type, int? limit}) =>
      _txQuery(from: from, to: to, type: type, limit: limit).get();

  Future<TxEntry?> getTransaction(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> saveTransaction(TransactionsCompanion data, {List<int>? tagIds}) => transaction(() async {
        int id;
        if (data.id.present) {
          id = data.id.value;
          await (update(transactions)..where((t) => t.id.equals(id)))
              .write(data.copyWith(updatedAt: Value(DateTime.now())));
        } else {
          id = await into(transactions).insert(data);
        }
        if (tagIds != null) {
          await (delete(transactionTags)..where((t) => t.transactionId.equals(id))).go();
          for (final tagId in tagIds) {
            await into(transactionTags).insert(TxTag(transactionId: id, tagId: tagId));
          }
        }
        return id;
      });

  Future<void> deleteTransaction(int id) => transaction(() async {
        await (delete(transactionTags)..where((t) => t.transactionId.equals(id))).go();
        await (delete(goalEntries)..where((g) => g.transactionId.equals(id))).go();
        await (delete(debtPayments)..where((d) => d.transactionId.equals(id))).go();
        await (delete(transactions)..where((t) => t.id.equals(id))).go();
      });

  /// Tanggal-tanggal (unik, lokal) yang punya transaksi — untuk streak.
  Future<List<DateTime>> getTransactionDays({required DateTime since}) async {
    final rows = await (selectOnly(transactions)
          ..addColumns([transactions.date])
          ..where(transactions.date.isBiggerOrEqualValue(since)))
        .map((r) => r.read(transactions.date)!)
        .get();
    return rows.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  Stream<List<Tag>> watchTags() => (select(tags)..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Stream<Map<int, List<int>>> watchTransactionTagMap() => select(transactionTags).watch().map((rows) {
        final map = <int, List<int>>{};
        for (final r in rows) {
          map.putIfAbsent(r.transactionId, () => []).add(r.tagId);
        }
        return map;
      });

  Future<List<int>> getTagIdsFor(int txId) =>
      (select(transactionTags)..where((t) => t.transactionId.equals(txId))).map((r) => r.tagId).get();

  Future<int> saveTag(TagsCompanion data) async {
    if (data.id.present) {
      await (update(tags)..where((t) => t.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(tags).insert(data);
  }

  Future<void> deleteTag(int id) => transaction(() async {
        await (delete(transactionTags)..where((t) => t.tagId.equals(id))).go();
        await (delete(tags)..where((t) => t.id.equals(id))).go();
      });

  // ---------------------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------------------

  Stream<List<Budget>> watchBudgets() =>
      (select(budgets)..orderBy([(b) => OrderingTerm(expression: b.id)])).watch();

  Future<List<Budget>> getBudgets() => (select(budgets)..where((b) => b.active.equals(true))).get();

  Future<int> saveBudget(BudgetsCompanion data) async {
    if (data.id.present) {
      await (update(budgets)..where((b) => b.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(budgets).insert(data);
  }

  Future<void> deleteBudget(int id) => (delete(budgets)..where((b) => b.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Goals
  // ---------------------------------------------------------------------------

  Stream<List<Goal>> watchGoals() => (select(goals)
        ..orderBy([
          (g) => OrderingTerm(expression: g.pinned, mode: OrderingMode.desc),
          (g) => OrderingTerm(expression: g.id),
        ]))
      .watch();

  Future<List<Goal>> getGoals() => (select(goals)..where((g) => g.archived.equals(false))).get();

  Stream<Map<int, double>> watchGoalSaved() => customSelect(
        'SELECT goal_id AS id, SUM(amount) AS total FROM goal_entries GROUP BY goal_id',
        readsFrom: {goalEntries},
      ).watch().map((rows) => {for (final r in rows) r.read<int>('id'): r.read<double>('total')});

  Future<Map<int, double>> getGoalSaved() async {
    final rows = await customSelect(
      'SELECT goal_id AS id, SUM(amount) AS total FROM goal_entries GROUP BY goal_id',
      readsFrom: {goalEntries},
    ).get();
    return {for (final r in rows) r.read<int>('id'): r.read<double>('total')};
  }

  Stream<List<GoalEntry>> watchGoalEntries(int goalId) => (select(goalEntries)
        ..where((g) => g.goalId.equals(goalId))
        ..orderBy([(g) => OrderingTerm(expression: g.date, mode: OrderingMode.desc)]))
      .watch();

  Future<int> saveGoal(GoalsCompanion data) async {
    if (data.id.present) {
      await (update(goals)..where((g) => g.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(goals).insert(data);
  }

  Future<void> deleteGoal(int id) => transaction(() async {
        await (delete(goalEntries)..where((g) => g.goalId.equals(id))).go();
        await (delete(goals)..where((g) => g.id.equals(id))).go();
      });

  // ---------------------------------------------------------------------------
  // Debts
  // ---------------------------------------------------------------------------

  Stream<List<Debt>> watchDebts() => (select(debts)
        ..orderBy([
          (d) => OrderingTerm(expression: d.settled),
          (d) => OrderingTerm(expression: d.date, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<List<Debt>> getOpenDebts() => (select(debts)..where((d) => d.settled.equals(false))).get();

  Stream<Map<int, double>> watchDebtPaid() => customSelect(
        'SELECT debt_id AS id, SUM(amount) AS total FROM debt_payments GROUP BY debt_id',
        readsFrom: {debtPayments},
      ).watch().map((rows) => {for (final r in rows) r.read<int>('id'): r.read<double>('total')});

  Stream<List<DebtPayment>> watchDebtPayments(int debtId) => (select(debtPayments)
        ..where((d) => d.debtId.equals(debtId))
        ..orderBy([(d) => OrderingTerm(expression: d.date, mode: OrderingMode.desc)]))
      .watch();

  Future<void> deleteDebt(int id) => transaction(() async {
        final txIds = await (select(transactions)..where((t) => t.debtId.equals(id))).map((t) => t.id).get();
        await (delete(transactionTags)..where((t) => t.transactionId.isIn(txIds))).go();
        await (delete(transactions)..where((t) => t.debtId.equals(id))).go();
        await (delete(debtPayments)..where((d) => d.debtId.equals(id))).go();
        await (delete(debts)..where((d) => d.id.equals(id))).go();
      });

  // ---------------------------------------------------------------------------
  // Recurring & installments
  // ---------------------------------------------------------------------------

  Stream<List<Recurring>> watchRecurrings() =>
      (select(recurrings)..orderBy([(r) => OrderingTerm(expression: r.nextDate)])).watch();

  Future<List<Recurring>> getActiveRecurrings() =>
      (select(recurrings)..where((r) => r.active.equals(true))).get();

  Future<int> saveRecurring(RecurringsCompanion data) async {
    if (data.id.present) {
      await (update(recurrings)..where((r) => r.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(recurrings).insert(data);
  }

  Future<void> deleteRecurring(int id) => (delete(recurrings)..where((r) => r.id.equals(id))).go();

  Stream<List<Installment>> watchInstallments() =>
      (select(installments)..orderBy([(i) => OrderingTerm(expression: i.active, mode: OrderingMode.desc)])).watch();

  Future<List<Installment>> getActiveInstallments() =>
      (select(installments)..where((i) => i.active.equals(true))).get();

  Future<int> saveInstallment(InstallmentsCompanion data) async {
    if (data.id.present) {
      await (update(installments)..where((i) => i.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(installments).insert(data);
  }

  Future<void> deleteInstallment(int id) => (delete(installments)..where((i) => i.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  Stream<List<Preset>> watchPresets() =>
      (select(presets)..orderBy([(p) => OrderingTerm(expression: p.sortOrder), (p) => OrderingTerm(expression: p.id)]))
          .watch();

  Future<List<Preset>> getPresets() =>
      (select(presets)..orderBy([(p) => OrderingTerm(expression: p.sortOrder), (p) => OrderingTerm(expression: p.id)]))
          .get();

  Future<int> savePreset(PresetsCompanion data) async {
    if (data.id.present) {
      await (update(presets)..where((p) => p.id.equals(data.id.value))).write(data);
      return data.id.value;
    }
    return into(presets).insert(data);
  }

  Future<void> deletePreset(int id) => (delete(presets)..where((p) => p.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Exchange rates
  // ---------------------------------------------------------------------------

  Stream<List<ExchangeRate>> watchRates() => select(exchangeRates).watch();

  Future<List<ExchangeRate>> getRates() => select(exchangeRates).get();

  Future<void> upsertRates(Map<String, double> perUsd, {bool keepManual = true}) => transaction(() async {
        final manualCodes = keepManual
            ? (await (select(exchangeRates)..where((r) => r.manual.equals(true))).map((r) => r.code).get()).toSet()
            : <String>{};
        final now = DateTime.now();
        await batch((b) {
          for (final e in perUsd.entries) {
            if (manualCodes.contains(e.key)) continue;
            b.insert(
              exchangeRates,
              ExchangeRate(code: e.key, perUsd: e.value, manual: false, updatedAt: now),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      });

  Future<void> setManualRate(String code, double? perUsd) async {
    if (perUsd == null) {
      await (update(exchangeRates)..where((r) => r.code.equals(code)))
          .write(const ExchangeRatesCompanion(manual: Value(false)));
      return;
    }
    await into(exchangeRates).insertOnConflictUpdate(
      ExchangeRate(code: code, perUsd: perUsd, manual: true, updatedAt: DateTime.now()),
    );
  }

  // ---------------------------------------------------------------------------
  // Kakeibo
  // ---------------------------------------------------------------------------

  Stream<KakeiboMonth?> watchKakeibo(String month) =>
      (select(kakeiboMonths)..where((k) => k.month.equals(month))).watchSingleOrNull();

  Future<void> saveKakeibo(KakeiboMonthsCompanion data) =>
      into(kakeiboMonths).insertOnConflictUpdate(data.copyWith(updatedAt: Value(DateTime.now())));

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  Future<Map<String, List<Map<String, dynamic>>>> exportAll() async {
    Future<List<Map<String, dynamic>>> dump<T extends Table, D extends DataClass>(TableInfo<T, D> table) async =>
        (await select(table).get()).map((row) => row.toJson()).toList();

    return {
      'accounts': await dump(accounts),
      'categories': await dump(categories),
      'transactions': await dump(transactions),
      'tags': await dump(tags),
      'transactionTags': await dump(transactionTags),
      'budgets': await dump(budgets),
      'goals': await dump(goals),
      'goalEntries': await dump(goalEntries),
      'debts': await dump(debts),
      'debtPayments': await dump(debtPayments),
      'recurrings': await dump(recurrings),
      'installments': await dump(installments),
      'presets': await dump(presets),
      'exchangeRates': await dump(exchangeRates),
      'kakeiboMonths': await dump(kakeiboMonths),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) => transaction(() async {
        for (final table in allTables.toList().reversed) {
          await delete(table).go();
        }
        List<Map<String, dynamic>> rows(String key) =>
            ((data[key] as List?) ?? const []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();

        await batch((b) {
          b.insertAll(accounts, rows('accounts').map(Account.fromJson));
          b.insertAll(categories, rows('categories').map(TxCategory.fromJson));
          b.insertAll(transactions, rows('transactions').map(TxEntry.fromJson));
          b.insertAll(tags, rows('tags').map(Tag.fromJson));
          b.insertAll(transactionTags, rows('transactionTags').map(TxTag.fromJson));
          b.insertAll(budgets, rows('budgets').map(Budget.fromJson));
          b.insertAll(goals, rows('goals').map(Goal.fromJson));
          b.insertAll(goalEntries, rows('goalEntries').map(GoalEntry.fromJson));
          b.insertAll(debts, rows('debts').map(Debt.fromJson));
          b.insertAll(debtPayments, rows('debtPayments').map(DebtPayment.fromJson));
          b.insertAll(recurrings, rows('recurrings').map(Recurring.fromJson));
          b.insertAll(installments, rows('installments').map(Installment.fromJson));
          b.insertAll(presets, rows('presets').map(Preset.fromJson));
          b.insertAll(exchangeRates, rows('exchangeRates').map(ExchangeRate.fromJson));
          b.insertAll(kakeiboMonths, rows('kakeiboMonths').map(KakeiboMonth.fromJson));
        });
      });

  Future<void> wipeAll({bool reseed = true}) => transaction(() async {
        for (final table in allTables.toList().reversed) {
          await delete(table).go();
        }
        if (reseed) await seedDefaults(this);
      });
}
