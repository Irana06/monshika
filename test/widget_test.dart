import 'package:flutter_test/flutter_test.dart';
import 'package:monshika/core/utils/dates.dart';
import 'package:monshika/core/utils/money.dart';
import 'package:monshika/core/utils/smart_parser.dart';
import 'package:monshika/data/database/database.dart';
import 'package:monshika/features/transactions/calc_pad.dart';
import 'package:monshika/services/finance.dart';

TxCategory _cat(int id, String name, String type) =>
    TxCategory(id: id, name: name, type: type, icon: '他', color: 0, isSystem: false, archived: false, sortOrder: 0);

Account _acc(int id, String name, String type) => Account(
      id: id,
      name: name,
      type: type,
      currency: 'IDR',
      initialBalance: 0,
      color: 0,
      icon: '財',
      note: '',
      includeInTotal: true,
      archived: false,
      sortOrder: 0,
      createdAt: DateTime(2026),
    );

TxEntry _tx(
  String type,
  double amount,
  DateTime date, {
  int accountId = 1,
  int? recurringId,
  int? installmentId,
  int? debtId,
  bool excludeFromStats = false,
}) =>
    TxEntry(
      id: 0,
      type: type,
      amount: amount,
      accountId: accountId,
      fee: 0,
      date: date,
      note: '',
      payee: '',
      recurringId: recurringId,
      debtId: debtId,
      installmentId: installmentId,
      excludeFromStats: excludeFromStats,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  final categories = [
    _cat(1, 'Kopi & Jajan', 'expense'),
    _cat(2, 'Ojek Online', 'expense'),
    _cat(3, 'Gaji', 'income'),
  ];
  final accounts = [_acc(1, 'Tunai', 'cash'), _acc(2, 'OVO', 'ewallet')];

  group('parseQuickInput', () {
    test('suffix rb dan kata kunci kategori', () {
      final p = parseQuickInput('kopi 25rb', categories: categories, accounts: accounts);
      expect(p.amount, 25000);
      expect(p.type, 'expense');
      expect(p.categoryId, 1);
    });

    test('pemisah ribuan dan nama dompet', () {
      final p = parseQuickInput('gojek 18.500 ovo', categories: categories, accounts: accounts);
      expect(p.amount, 18500);
      expect(p.categoryId, 2);
      expect(p.accountId, 2);
    });

    test('tanda plus dan juta = pemasukan', () {
      final p = parseQuickInput('+8jt gaji', categories: categories, accounts: accounts);
      expect(p.amount, 8000000);
      expect(p.type, 'income');
      expect(p.categoryId, 3);
    });
  });

  group('CalcController', () {
    test('prioritas operator', () {
      final c = CalcController();
      for (final k in ['2', '0', '0', '0', '0', '+', '5', '0', '0', '0', '*', '2']) {
        c.input(k);
      }
      expect(c.value, 30000);
    });
  });

  group('money & dates', () {
    test('parseAmount format Indonesia', () {
      expect(parseAmount('25.000'), 25000);
      expect(parseAmount('1.250.000,50'), 1250000.5);
    });

    test('convert via kurs per USD', () {
      expect(convert(10, 'USD', 'IDR', {'USD': 1, 'IDR': 16000}), 160000);
    });

    test('monthRange dengan tanggal gajian', () {
      final r = monthRange(DateTime(2026, 9, 10), startDay: 25);
      expect(r.start, DateTime(2026, 8, 25));
      expect(r.end, DateTime(2026, 9, 25));
    });
  });

  group('safeToSpend', () {
    final range = DateRange(DateTime(2026, 9, 1), DateTime(2026, 10, 1));
    final today = DateTime(2026, 9, 10);

    Finance finance({Map<int, double> balances = const {}, List<Account>? accs}) => Finance(
          accounts: {for (final a in accs ?? accounts) a.id: a},
          balances: balances,
          categories: {for (final c in categories) c.id: c},
          rates: const {'IDR': 16000, 'USD': 1},
          baseCurrency: 'IDR',
        );

    test('rencana periode dari pemasukan, terpisah dari sisa harian', () {
      final s = finance().safeToSpend(
        periodTxs: [
          _tx('income', 8000000, DateTime(2026, 9, 1)),
          _tx('expense', 2250000, DateTime(2026, 9, 5)),
          _tx('expense', 150000, today),
        ],
        range: range,
        upcomingBills: 1200000,
        now: today,
      );
      expect(s.basis, 'income');
      expect(s.hasPlan, isTrue);
      // 8.000.000 - 1.200.000 tagihan = 6.800.000 untuk 30 hari.
      expect(s.periodPool, 6800000);
      expect(s.periodDays, 30);
      expect(s.periodPerDay, closeTo(226666.67, 0.01));
      expect(s.periodSpent, 2400000);
      expect(s.periodLeft, 4400000);
      // Lapis realisasi: sisa dibagi 21 hari yang tersisa.
      expect(s.remainingDays, 21);
      expect(s.todaySpent, 150000);
      expect(s.perDay, closeTo(4550000 / 21, 0.01));
      // Dua lapis itu harus konsisten satu sama lain.
      expect(s.pool, closeTo(s.periodLeft + s.todaySpent, 0.01));
    });

    test('tagihan yang sudah dibayar tidak dihitung dua kali', () {
      final s = finance().safeToSpend(
        periodTxs: [
          _tx('income', 5000000, DateTime(2026, 9, 1)),
          _tx('expense', 500000, DateTime(2026, 9, 3), recurringId: 7),
          _tx('expense', 300000, DateTime(2026, 9, 4)),
        ],
        range: range,
        upcomingBills: 1000000,
        now: today,
      );
      expect(s.paidBills, 500000);
      // 5.000.000 - 1.000.000 belum dibayar - 500.000 sudah dibayar.
      expect(s.periodPool, 3500000);
      // Belanja bebas saja, tagihannya tidak ikut.
      expect(s.periodSpent, 300000);
    });

    test('target nabung Kakeibo mengurangi jatah', () {
      final s = finance().safeToSpend(
        periodTxs: [_tx('income', 6000000, DateTime(2026, 9, 1))],
        range: range,
        upcomingBills: 0,
        savingsTarget: 1500000,
        now: today,
      );
      expect(s.periodPool, 4500000);
      expect(s.periodPerDay, 150000);
    });

    test('tanpa pemasukan, pakai saldo dan dompet tabungan tidak ikut', () {
      final withSavings = [...accounts, _acc(3, 'Tabungan', 'savings')];
      final s = finance(
        accs: withSavings,
        balances: {1: 1000000, 2: 500000, 3: 20000000},
      ).safeToSpend(
        periodTxs: const [],
        range: range,
        upcomingBills: 0,
        now: today,
      );
      expect(s.basis, 'balance');
      expect(s.hasPlan, isFalse);
      // Hanya tunai dan e-wallet, 20 juta di tabungan tidak dianggap jatah belanja.
      expect(s.pool, 1500000);
      expect(s.periodPool, 0);
    });
  });
}
