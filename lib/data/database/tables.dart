import 'package:drift/drift.dart';

/// Dompet / rekening: tunai, bank, e-wallet, kartu kredit, paylater, dll.
@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text()();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  RealColumn get creditLimit => real().nullable()();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Kategori pemasukan / pengeluaran, mendukung sub-kategori lewat [parentId].
@DataClassName('TxCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text()(); // income | expense
  IntColumn get parentId => integer().nullable()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  TextColumn get pillar => text().nullable()(); // needs | wants | culture | unexpected
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('TxEntry')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // income | expense | transfer
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().nullable()();
  RealColumn get toAmount => real().nullable()();
  RealColumn get fee => real().withDefault(const Constant(0))();
  IntColumn get categoryId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get payee => text().withDefault(const Constant(''))();
  TextColumn get receiptPath => text().nullable()();
  IntColumn get recurringId => integer().nullable()();
  IntColumn get debtId => integer().nullable()();
  IntColumn get installmentId => integer().nullable()();
  IntColumn get goalId => integer().nullable()();
  BoolColumn get excludeFromStats => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get color => integer()();
}

@DataClassName('TxTag')
class TransactionTags extends Table {
  IntColumn get transactionId => integer()();
  IntColumn get tagId => integer()();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  TextColumn get period => text().withDefault(const Constant('monthly'))(); // weekly | monthly | yearly
  /// Daftar id kategori dipisah koma. Kosong = semua pengeluaran.
  TextColumn get categoryIds => text().withDefault(const Constant(''))();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  IntColumn get alertPercent => integer().withDefault(const Constant(80))();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Goal')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GoalEntry')
class GoalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer()();
  RealColumn get amount => real()(); // positif = setor, negatif = tarik
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get transactionId => integer().nullable()();
}

@DataClassName('Debt')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text()();
  TextColumn get direction => text()(); // lend (piutang) | borrow (utang)
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get accountId => integer().nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DebtPayment')
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  IntColumn get accountId => integer().nullable()();
  IntColumn get transactionId => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// Transaksi berulang & langganan.
@DataClassName('Recurring')
class Recurrings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  IntColumn get accountId => integer()();
  IntColumn get toAccountId => integer().nullable()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get frequency => text()(); // daily | weekly | monthly | yearly
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get autoPost => boolean().withDefault(const Constant(true))();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(1))();
  BoolColumn get isSubscription => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
}

/// Cicilan kartu kredit / paylater / KPR / kendaraan.
@DataClassName('Installment')
class Installments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get accountId => integer().nullable()();
  IntColumn get categoryId => integer().nullable()();
  RealColumn get principal => real()();
  RealColumn get monthlyAmount => real()();
  IntColumn get tenor => integer()();
  IntColumn get paidCount => integer().withDefault(const Constant(0))();
  RealColumn get interestRate => real().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get dueDay => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Template transaksi sekali-tap (dipakai di aplikasi & widget beranda).
@DataClassName('Preset')
class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  IntColumn get accountId => integer()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get showInWidget => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Kurs terhadap USD (1 USD = [perUsd] unit mata uang).
@DataClassName('ExchangeRate')
class ExchangeRates extends Table {
  TextColumn get code => text()();
  RealColumn get perUsd => real()();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Catatan Kakeibo per bulan (format key: yyyy-MM).
@DataClassName('KakeiboMonth')
class KakeiboMonths extends Table {
  TextColumn get month => text()();
  RealColumn get plannedIncome => real().withDefault(const Constant(0))();
  RealColumn get fixedCosts => real().withDefault(const Constant(0))();
  RealColumn get savingsTarget => real().withDefault(const Constant(0))();
  TextColumn get intention => text().withDefault(const Constant(''))();
  TextColumn get reflectionSaved => text().withDefault(const Constant(''))();
  TextColumn get reflectionSpent => text().withDefault(const Constant(''))();
  TextColumn get reflectionImprove => text().withDefault(const Constant(''))();
  IntColumn get mood => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {month};
}
