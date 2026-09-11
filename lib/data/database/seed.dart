import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/strings.dart';
import 'database.dart';

/// Kategori sistem dikenali dari glyph-nya, bukan dari nama, supaya tetap
/// ditemukan apa pun bahasa yang dipakai.
const kSystemDebtGlyph = '借';
const kSystemAdjustGlyph = '調';
const kSystemGoalGlyph = '貯';

class _Cat {
  const _Cat(this.id, this.en, this.icon, this.color, [this.pillar, this.children = const []]);
  final String id;
  final String en;
  final String icon;
  final Color color;
  final String? pillar;
  final List<_Cat> children;
}

const _expense = <_Cat>[
  _Cat('Makan & minum', 'Food & drinks', '食', WaColors.shu, 'needs', [
    _Cat('Kopi & jajan', 'Coffee & snacks', '茶', WaColors.cha, 'wants'),
    _Cat('Makan di luar', 'Eating out', '店', WaColors.kohaku, 'wants'),
  ]),
  _Cat('Belanja harian', 'Groceries', '買', WaColors.yamabuki, 'needs'),
  _Cat('Transportasi', 'Transport', '車', WaColors.asagi, 'needs', [
    _Cat('Bensin', 'Fuel', '油', WaColors.kohaku, 'needs'),
    _Cat('Ojek online', 'Ride hailing', '走', WaColors.wakatake, 'needs'),
    _Cat('Parkir & tol', 'Parking & tolls', '駐', WaColors.nezumi, 'needs'),
  ]),
  _Cat('Tempat tinggal', 'Housing', '家', WaColors.cha, 'needs'),
  _Cat('Tagihan', 'Bills', '電', WaColors.ruri, 'needs', [
    _Cat('Listrik', 'Electricity', '雷', WaColors.yamabuki, 'needs'),
    _Cat('Internet', 'Internet', '網', WaColors.ai, 'needs'),
    _Cat('Pulsa & kuota', 'Phone & data', '話', WaColors.fuji, 'needs'),
    _Cat('Air', 'Water', '水', WaColors.asagi, 'needs'),
  ]),
  _Cat('Kesehatan', 'Health', '医', WaColors.matcha, 'needs'),
  _Cat('Pendidikan', 'Education', '学', WaColors.ai, 'culture'),
  _Cat('Hiburan', 'Entertainment', '遊', WaColors.sakura, 'wants'),
  _Cat('Belanja & fashion', 'Shopping', '服', WaColors.fuji, 'wants'),
  _Cat('Langganan', 'Subscriptions', '定', WaColors.ruri, 'wants'),
  _Cat('Keluarga', 'Family', '族', WaColors.momiji, 'needs'),
  _Cat('Perawatan diri', 'Self care', '美', WaColors.sakura, 'wants'),
  _Cat('Olahraga', 'Sports', '体', WaColors.wakatake, 'culture'),
  _Cat('Hadiah & donasi', 'Gifts & charity', '贈', WaColors.beni, 'culture'),
  _Cat('Liburan', 'Travel', '旅', WaColors.asagi, 'wants'),
  _Cat('Pajak & biaya', 'Taxes & fees', '税', WaColors.nezumi, 'needs'),
  _Cat('Cicilan', 'Installments', '返', WaColors.momiji, 'needs'),
  _Cat('Tak terduga', 'Unexpected', '急', WaColors.beni, 'unexpected'),
  _Cat('Lainnya', 'Other', '他', WaColors.nezumi, 'unexpected'),
];

const _income = <_Cat>[
  _Cat('Gaji', 'Salary', '給', WaColors.matcha),
  _Cat('Bonus & THR', 'Bonus', '賞', WaColors.kin),
  _Cat('Freelance', 'Freelance', '業', WaColors.wakatake),
  _Cat('Investasi', 'Investments', '株', WaColors.asagi),
  _Cat('Penjualan', 'Sales', '売', WaColors.yamabuki),
  _Cat('Hadiah', 'Gifts', '贈', WaColors.sakura),
  _Cat('Cashback & refund', 'Cashback & refunds', '戻', WaColors.fuji),
  _Cat('Lainnya', 'Other', '他', WaColors.nezumi),
];

Future<void> seedDefaults(AppDatabase db) async {
  final prefs = await SharedPreferences.getInstance();
  final s = S.fromPrefs(prefs);

  var order = 0;
  Future<void> insertCats(List<_Cat> cats, String type, {int? parentId}) async {
    for (final c in cats) {
      final id = await db.into(db.categories).insert(CategoriesCompanion.insert(
            name: s.t(c.id, c.en),
            type: type,
            icon: c.icon,
            color: c.color.toARGB32(),
            pillar: Value(c.pillar),
            parentId: Value(parentId),
            sortOrder: Value(order++),
          ));
      if (c.children.isNotEmpty) await insertCats(c.children, type, parentId: id);
    }
  }

  await insertCats(_expense, 'expense');
  await insertCats(_income, 'income');

  for (final sys in [
    (s.t('Utang & piutang', 'Debts'), kSystemDebtGlyph, WaColors.nezumi),
    (s.t('Penyesuaian saldo', 'Balance adjustment'), kSystemAdjustGlyph, WaColors.nezumi),
    (s.t('Setoran target', 'Goal savings'), kSystemGoalGlyph, WaColors.kin),
  ]) {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: sys.$1,
          type: 'expense',
          icon: sys.$2,
          color: sys.$3.toARGB32(),
          isSystem: const Value(true),
          sortOrder: Value(order++),
        ));
  }

  await db.into(db.tags).insert(TagsCompanion.insert(name: s.t('penting', 'important'), color: WaColors.beni.toARGB32()));
  await db.into(db.tags).insert(TagsCompanion.insert(name: s.t('kerja', 'work'), color: WaColors.ai.toARGB32()));
  await db.into(db.tags).insert(TagsCompanion.insert(name: s.t('liburan', 'holiday'), color: WaColors.asagi.toARGB32()));
}
