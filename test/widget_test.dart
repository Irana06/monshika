import 'package:flutter_test/flutter_test.dart';
import 'package:monshika/core/utils/dates.dart';
import 'package:monshika/core/utils/money.dart';
import 'package:monshika/core/utils/smart_parser.dart';
import 'package:monshika/data/database/database.dart';
import 'package:monshika/features/transactions/calc_pad.dart';

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
}
