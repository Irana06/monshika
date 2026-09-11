import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Ikon kategori/dompet disimpan sebagai glyph (kanji atau emoji).
/// Saat gaya Jepang mati, glyph kanji ditampilkan sebagai ikon Material.
class KanjiIcon {
  const KanjiIcon(this.glyph, this.id, this.en, this.icon);
  final String glyph;
  final String id;
  final String en;
  final IconData icon;

  String meaning(S s) => s.en ? en : id;
}

const kKanjiIcons = <KanjiIcon>[
  KanjiIcon('食', 'makan', 'food', Icons.restaurant),
  KanjiIcon('茶', 'kopi & jajan', 'coffee & snacks', Icons.local_cafe),
  KanjiIcon('酒', 'minuman', 'drinks', Icons.local_bar),
  KanjiIcon('店', 'restoran', 'restaurant', Icons.storefront),
  KanjiIcon('買', 'belanja harian', 'groceries', Icons.shopping_basket),
  KanjiIcon('服', 'pakaian', 'clothes', Icons.checkroom),
  KanjiIcon('靴', 'sepatu', 'shoes', Icons.directions_run),
  KanjiIcon('車', 'kendaraan', 'car', Icons.directions_car),
  KanjiIcon('走', 'ojek online', 'ride hailing', Icons.two_wheeler),
  KanjiIcon('油', 'bensin', 'fuel', Icons.local_gas_station),
  KanjiIcon('駐', 'parkir & tol', 'parking & tolls', Icons.local_parking),
  KanjiIcon('電', 'tagihan', 'bills', Icons.receipt_long),
  KanjiIcon('雷', 'listrik', 'electricity', Icons.bolt),
  KanjiIcon('水', 'air', 'water', Icons.water_drop),
  KanjiIcon('網', 'internet', 'internet', Icons.wifi),
  KanjiIcon('話', 'pulsa & kuota', 'phone & data', Icons.smartphone),
  KanjiIcon('家', 'rumah', 'home', Icons.home),
  KanjiIcon('族', 'keluarga', 'family', Icons.family_restroom),
  KanjiIcon('子', 'anak', 'kids', Icons.child_care),
  KanjiIcon('犬', 'hewan', 'pets', Icons.pets),
  KanjiIcon('医', 'kesehatan', 'health', Icons.local_hospital),
  KanjiIcon('薬', 'obat', 'medicine', Icons.medication),
  KanjiIcon('学', 'pendidikan', 'education', Icons.school),
  KanjiIcon('本', 'buku', 'books', Icons.menu_book),
  KanjiIcon('遊', 'hiburan', 'entertainment', Icons.sports_esports),
  KanjiIcon('映', 'film', 'movies', Icons.movie),
  KanjiIcon('音', 'musik', 'music', Icons.music_note),
  KanjiIcon('旅', 'liburan', 'travel', Icons.flight),
  KanjiIcon('美', 'perawatan diri', 'self care', Icons.spa),
  KanjiIcon('体', 'olahraga', 'sports', Icons.fitness_center),
  KanjiIcon('贈', 'hadiah', 'gifts', Icons.card_giftcard),
  KanjiIcon('祈', 'donasi & ibadah', 'charity', Icons.volunteer_activism),
  KanjiIcon('定', 'langganan', 'subscriptions', Icons.subscriptions),
  KanjiIcon('税', 'pajak & biaya', 'taxes & fees', Icons.account_balance),
  KanjiIcon('返', 'cicilan', 'installments', Icons.credit_score),
  KanjiIcon('借', 'utang', 'debt', Icons.handshake),
  KanjiIcon('急', 'tak terduga', 'unexpected', Icons.warning_amber),
  KanjiIcon('給', 'gaji', 'salary', Icons.work),
  KanjiIcon('賞', 'bonus', 'bonus', Icons.emoji_events),
  KanjiIcon('業', 'usaha', 'business', Icons.laptop_mac),
  KanjiIcon('株', 'investasi', 'investing', Icons.trending_up),
  KanjiIcon('売', 'penjualan', 'sales', Icons.sell),
  KanjiIcon('戻', 'cashback', 'cashback', Icons.replay),
  KanjiIcon('金', 'uang', 'money', Icons.payments),
  KanjiIcon('銭', 'tunai', 'cash', Icons.payments),
  KanjiIcon('財', 'dompet', 'wallet', Icons.account_balance_wallet),
  KanjiIcon('銀', 'bank', 'bank', Icons.account_balance),
  KanjiIcon('札', 'kartu', 'card', Icons.credit_card),
  KanjiIcon('携', 'e-wallet', 'e-wallet', Icons.phone_android),
  KanjiIcon('貯', 'tabungan', 'savings', Icons.savings),
  KanjiIcon('宝', 'aset', 'assets', Icons.diamond),
  KanjiIcon('夢', 'impian', 'dream', Icons.star),
  KanjiIcon('星', 'favorit', 'favorite', Icons.star_border),
  KanjiIcon('桜', 'bunga', 'flowers', Icons.local_florist),
  KanjiIcon('山', 'gunung', 'outdoors', Icons.landscape),
  KanjiIcon('海', 'pantai', 'beach', Icons.beach_access),
  KanjiIcon('月', 'malam', 'night', Icons.nightlight),
  KanjiIcon('火', 'gas & api', 'gas', Icons.local_fire_department),
  KanjiIcon('鹿', 'rusa', 'deer', Icons.cruelty_free),
  KanjiIcon('他', 'lainnya', 'other', Icons.more_horiz),
];

/// Glyph lain yang dipakai di UI (menu, header, status) → ikon biasa.
const Map<String, IconData> _extraGlyphIcons = {
  '調': Icons.tune,
  '算': Icons.pie_chart,
  '簿': Icons.menu_book,
  '類': Icons.category,
  '替': Icons.currency_exchange,
  '窓': Icons.widgets,
  '蔵': Icons.cloud,
  '設': Icons.settings,
  '割': Icons.call_split,
  '暦': Icons.event_repeat,
  '新': Icons.system_update,
  '鍵': Icons.lock,
  '済': Icons.check,
  '入': Icons.south_west,
  '出': Icons.north_east,
  '移': Icons.swap_horiz,
  '私': Icons.person,
  '友': Icons.group,
  '貸': Icons.call_made,
  '図': Icons.bar_chart,
  '予': Icons.event,
  '速': Icons.bolt,
  '記': Icons.receipt_long,
  '析': Icons.insights,
  '生': Icons.home,
  '欲': Icons.favorite,
  '文': Icons.auto_stories,
  '無': Icons.inbox,
  '始': Icons.flag,
  '空': Icons.inbox,
  '歴': Icons.history,
  '復': Icons.restore,
  '？': Icons.help_outline,
};

final Map<String, IconData> _glyphIcons = {
  for (final k in kKanjiIcons) k.glyph: k.icon,
  ..._extraGlyphIcons,
};

/// Ikon Material untuk sebuah glyph kanji, atau null bila glyph bukan kanji
/// yang dikenal (mis. emoji buatan pengguna).
IconData? iconForGlyph(String glyph) => _glyphIcons[glyph];

// -----------------------------------------------------------------------------
// Jenis dompet
// -----------------------------------------------------------------------------

const kAccountTypeKeys = ['cash', 'bank', 'ewallet', 'credit', 'paylater', 'savings', 'investment', 'other'];

String accountTypeGlyph(String type) => switch (type) {
      'cash' => '銭',
      'bank' => '銀',
      'ewallet' => '携',
      'credit' => '札',
      'paylater' => '借',
      'savings' => '貯',
      'investment' => '株',
      _ => '財',
    };

String accountTypeLabel(S s, String type) => switch (type) {
      'cash' => s.t('Tunai', 'Cash'),
      'bank' => s.t('Bank', 'Bank'),
      'ewallet' => s.t('E-wallet', 'E-wallet'),
      'credit' => s.t('Kartu kredit', 'Credit card'),
      'paylater' => s.t('Paylater', 'Pay later'),
      'savings' => s.t('Tabungan', 'Savings'),
      'investment' => s.t('Investasi', 'Investment'),
      _ => s.t('Lainnya', 'Other'),
    };

// -----------------------------------------------------------------------------
// Pilar Kakeibo
// -----------------------------------------------------------------------------

const kPillarKeys = ['needs', 'wants', 'culture', 'unexpected'];

String pillarGlyph(String key) => switch (key) {
      'needs' => '生',
      'wants' => '欲',
      'culture' => '文',
      _ => '急',
    };

String pillarLabel(S s, String key) => switch (key) {
      'needs' => s.t('Kebutuhan', 'Needs'),
      'wants' => s.t('Keinginan', 'Wants'),
      'culture' => s.t('Pengembangan diri', 'Growth'),
      _ => s.t('Tak terduga', 'Unexpected'),
    };

String pillarDesc(S s, String key) => switch (key) {
      'needs' => s.t('Makan, tempat tinggal, tagihan, transport.', 'Food, rent, bills, transport.'),
      'wants' => s.t('Jajan, hiburan, belanja yang tidak wajib.', 'Treats, fun, and non-essential shopping.'),
      'culture' => s.t('Buku, kursus, olahraga, donasi.', 'Books, courses, sports, charity.'),
      _ => s.t('Pengeluaran darurat atau di luar rencana.', 'Emergencies and unplanned costs.'),
    };
