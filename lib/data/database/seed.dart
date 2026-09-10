import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show Color;

import '../../core/theme/app_colors.dart';
import 'database.dart';

const kSystemDebtCategory = 'Utang & Piutang';
const kSystemAdjustCategory = 'Penyesuaian Saldo';
const kSystemGoalCategory = 'Tabungan Target';

class _Cat {
  const _Cat(this.name, this.icon, this.color, [this.pillar, this.children = const []]);
  final String name;
  final String icon;
  final Color color;
  final String? pillar;
  final List<_Cat> children;
}

const _expense = <_Cat>[
  _Cat('Makan & Minum', '食', WaColors.shu, 'needs', [
    _Cat('Kopi & Jajan', '茶', WaColors.cha, 'wants'),
    _Cat('Makan di Luar', '店', WaColors.kohaku, 'wants'),
  ]),
  _Cat('Belanja Harian', '買', WaColors.yamabuki, 'needs'),
  _Cat('Transportasi', '車', WaColors.asagi, 'needs', [
    _Cat('Bensin', '油', WaColors.kohaku, 'needs'),
    _Cat('Ojek Online', '走', WaColors.wakatake, 'needs'),
    _Cat('Parkir & Tol', '駐', WaColors.nezumi, 'needs'),
  ]),
  _Cat('Tempat Tinggal', '家', WaColors.cha, 'needs'),
  _Cat('Tagihan', '電', WaColors.ruri, 'needs', [
    _Cat('Listrik', '雷', WaColors.yamabuki, 'needs'),
    _Cat('Internet', '網', WaColors.ai, 'needs'),
    _Cat('Pulsa & Kuota', '話', WaColors.fuji, 'needs'),
    _Cat('Air', '水', WaColors.asagi, 'needs'),
  ]),
  _Cat('Kesehatan', '医', WaColors.matcha, 'needs'),
  _Cat('Pendidikan', '学', WaColors.ai, 'culture'),
  _Cat('Hiburan', '遊', WaColors.sakura, 'wants'),
  _Cat('Belanja & Fashion', '服', WaColors.fuji, 'wants'),
  _Cat('Langganan', '定', WaColors.ruri, 'wants'),
  _Cat('Keluarga', '族', WaColors.momiji, 'needs'),
  _Cat('Perawatan Diri', '美', WaColors.sakura, 'wants'),
  _Cat('Olahraga', '体', WaColors.wakatake, 'culture'),
  _Cat('Hadiah & Donasi', '贈', WaColors.beni, 'culture'),
  _Cat('Liburan', '旅', WaColors.asagi, 'wants'),
  _Cat('Pajak & Biaya', '税', WaColors.nezumi, 'needs'),
  _Cat('Cicilan', '返', WaColors.momiji, 'needs'),
  _Cat('Tak Terduga', '急', WaColors.beni, 'unexpected'),
  _Cat('Lainnya', '他', WaColors.nezumi, 'unexpected'),
];

const _income = <_Cat>[
  _Cat('Gaji', '給', WaColors.matcha),
  _Cat('Bonus & THR', '賞', WaColors.kin),
  _Cat('Freelance', '業', WaColors.wakatake),
  _Cat('Investasi', '株', WaColors.asagi),
  _Cat('Penjualan', '売', WaColors.yamabuki),
  _Cat('Hadiah', '贈', WaColors.sakura),
  _Cat('Cashback & Refund', '戻', WaColors.fuji),
  _Cat('Lainnya', '他', WaColors.nezumi),
];

Future<void> seedDefaults(AppDatabase db) async {
  var order = 0;
  Future<void> insertCats(List<_Cat> cats, String type, {int? parentId}) async {
    for (final c in cats) {
      final id = await db.into(db.categories).insert(CategoriesCompanion.insert(
            name: c.name,
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
    (kSystemDebtCategory, '借', WaColors.nezumi),
    (kSystemAdjustCategory, '調', WaColors.nezumi),
    (kSystemGoalCategory, '貯', WaColors.kin),
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

  await db.into(db.tags).insert(TagsCompanion.insert(name: 'penting', color: WaColors.beni.toARGB32()));
  await db.into(db.tags).insert(TagsCompanion.insert(name: 'kerja', color: WaColors.ai.toARGB32()));
  await db.into(db.tags).insert(TagsCompanion.insert(name: 'liburan', color: WaColors.asagi.toARGB32()));
}
