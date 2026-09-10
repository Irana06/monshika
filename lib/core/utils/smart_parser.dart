import '../../data/database/database.dart';

class ParsedInput {
  const ParsedInput({this.amount, required this.type, this.categoryId, this.accountId, this.note = ''});

  final double? amount;
  final String type;
  final int? categoryId;
  final int? accountId;
  final String note;
}

const _incomeWords = {
  'gaji', 'gajian', 'bonus', 'thr', 'terima', 'diterima', 'dapat', 'masuk', 'jual', 'refund', 'cashback',
  'income', 'pemasukan', 'dividen', 'bunga', 'komisi', 'fee', 'honor', 'transferan',
};

/// Kata kunci → nama kategori bawaan.
const _keywordCategory = <String, String>{
  'kopi': 'Kopi & Jajan', 'coffee': 'Kopi & Jajan', 'jajan': 'Kopi & Jajan', 'snack': 'Kopi & Jajan',
  'boba': 'Kopi & Jajan', 'teh': 'Kopi & Jajan', 'es': 'Kopi & Jajan',
  'makan': 'Makan & Minum', 'sarapan': 'Makan & Minum', 'lunch': 'Makan & Minum', 'dinner': 'Makan & Minum',
  'nasi': 'Makan & Minum', 'bakso': 'Makan & Minum', 'mie': 'Makan & Minum', 'warteg': 'Makan & Minum',
  'resto': 'Makan di Luar', 'restoran': 'Makan di Luar', 'cafe': 'Makan di Luar', 'gofood': 'Makan di Luar',
  'grabfood': 'Makan di Luar', 'shopeefood': 'Makan di Luar',
  'indomaret': 'Belanja Harian', 'alfamart': 'Belanja Harian', 'sayur': 'Belanja Harian', 'beras': 'Belanja Harian',
  'pasar': 'Belanja Harian', 'supermarket': 'Belanja Harian', 'galon': 'Belanja Harian', 'sabun': 'Belanja Harian',
  'gojek': 'Ojek Online', 'grab': 'Ojek Online', 'ojol': 'Ojek Online', 'maxim': 'Ojek Online', 'ojek': 'Ojek Online',
  'bensin': 'Bensin', 'pertalite': 'Bensin', 'pertamax': 'Bensin', 'solar': 'Bensin',
  'parkir': 'Parkir & Tol', 'tol': 'Parkir & Tol', 'etoll': 'Parkir & Tol',
  'krl': 'Transportasi', 'mrt': 'Transportasi', 'transjakarta': 'Transportasi', 'kereta': 'Transportasi',
  'bus': 'Transportasi', 'pesawat': 'Liburan', 'tiket': 'Transportasi',
  'listrik': 'Listrik', 'pln': 'Listrik', 'token': 'Listrik',
  'internet': 'Internet', 'wifi': 'Internet', 'indihome': 'Internet', 'biznet': 'Internet',
  'pulsa': 'Pulsa & Kuota', 'kuota': 'Pulsa & Kuota', 'paket': 'Pulsa & Kuota',
  'pdam': 'Air',
  'kos': 'Tempat Tinggal', 'kost': 'Tempat Tinggal', 'sewa': 'Tempat Tinggal', 'kontrakan': 'Tempat Tinggal',
  'obat': 'Kesehatan', 'dokter': 'Kesehatan', 'apotek': 'Kesehatan', 'bpjs': 'Kesehatan', 'vitamin': 'Kesehatan',
  'buku': 'Pendidikan', 'kursus': 'Pendidikan', 'kuliah': 'Pendidikan', 'spp': 'Pendidikan', 'udemy': 'Pendidikan',
  'nonton': 'Hiburan', 'bioskop': 'Hiburan', 'game': 'Hiburan', 'steam': 'Hiburan', 'konser': 'Hiburan',
  'karaoke': 'Hiburan', 'topup': 'Hiburan',
  'baju': 'Belanja & Fashion', 'sepatu': 'Belanja & Fashion', 'celana': 'Belanja & Fashion',
  'shopee': 'Belanja & Fashion', 'tokopedia': 'Belanja & Fashion', 'lazada': 'Belanja & Fashion', 'tiktok': 'Belanja & Fashion',
  'netflix': 'Langganan', 'spotify': 'Langganan', 'youtube': 'Langganan', 'disney': 'Langganan',
  'icloud': 'Langganan', 'chatgpt': 'Langganan', 'claude': 'Langganan', 'langganan': 'Langganan',
  'potong': 'Perawatan Diri', 'salon': 'Perawatan Diri', 'skincare': 'Perawatan Diri', 'barbershop': 'Perawatan Diri',
  'gym': 'Olahraga', 'futsal': 'Olahraga', 'badminton': 'Olahraga', 'renang': 'Olahraga',
  'sedekah': 'Hadiah & Donasi', 'donasi': 'Hadiah & Donasi', 'zakat': 'Hadiah & Donasi', 'kado': 'Hadiah & Donasi',
  'infaq': 'Hadiah & Donasi', 'kondangan': 'Hadiah & Donasi',
  'hotel': 'Liburan', 'liburan': 'Liburan', 'travel': 'Liburan',
  'pajak': 'Pajak & Biaya', 'admin': 'Pajak & Biaya',
  'cicilan': 'Cicilan', 'angsuran': 'Cicilan', 'kredit': 'Cicilan',
  'servis': 'Transportasi', 'bengkel': 'Transportasi',
  'gaji': 'Gaji', 'gajian': 'Gaji', 'bonus': 'Bonus & THR', 'thr': 'Bonus & THR',
  'freelance': 'Freelance', 'project': 'Freelance', 'proyek': 'Freelance', 'honor': 'Freelance',
  'dividen': 'Investasi', 'bunga': 'Investasi', 'jual': 'Penjualan', 'cashback': 'Cashback & Refund',
  'refund': 'Cashback & Refund',
};

final _amountRe = RegExp(
  r'(^|\s)([+\-])?\s*(?:rp\.?\s*)?(\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*(rb|ribu|k|jt|juta|m|mio|miliar|t)?(?=\s|$)',
  caseSensitive: false,
);

/// Parser teks bebas untuk input cepat, contoh:
/// `kopi 25rb`, `gojek 18.500 ovo`, `+8jt gaji`, `bensin 50k cash`.
ParsedInput parseQuickInput(
  String input, {
  required List<TxCategory> categories,
  required List<Account> accounts,
  String? forcedType,
}) {
  final text = input.trim();
  double? amount;
  var sign = '';
  var rest = text;

  final match = _amountRe.firstMatch(text);
  if (match != null) {
    sign = match.group(2) ?? '';
    final raw = match.group(3)!;
    final suffix = (match.group(4) ?? '').toLowerCase();
    String normalized;
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(raw)) {
      normalized = raw.replaceAll(RegExp(r'[.,]'), '');
    } else {
      normalized = raw.replaceAll(',', '.');
    }
    final base = double.tryParse(normalized);
    if (base != null) {
      final mult = switch (suffix) {
        'rb' || 'ribu' || 'k' => 1e3,
        'jt' || 'juta' || 'm' || 'mio' => 1e6,
        'miliar' => 1e9,
        't' => 1e12,
        _ => 1.0,
      };
      amount = base * mult;
    }
    rest = text.replaceRange(match.start, match.end, ' ');
  }

  final words = rest
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^a-z0-9&]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();

  var type = forcedType ?? 'expense';
  if (forcedType == null && (sign == '+' || words.any(_incomeWords.contains))) type = 'income';

  // Dompet: cocokkan kata dengan nama dompet.
  int? accountId;
  final usedWords = <String>{};
  for (final a in accounts) {
    final name = a.name.toLowerCase();
    for (final w in words) {
      if (w.length >= 2 && (name == w || name.split(RegExp(r'\s+')).contains(w))) {
        accountId = a.id;
        usedWords.add(w);
        break;
      }
    }
    if (accountId != null) break;
  }
  if (accountId == null && words.any((w) => w == 'cash' || w == 'tunai')) {
    final cash = accounts.where((a) => a.type == 'cash');
    if (cash.isNotEmpty) accountId = cash.first.id;
  }

  // Kategori: nama kategori langsung, lalu kamus kata kunci.
  final typed = categories.where((c) => c.type == type && !c.isSystem && !c.archived).toList();
  int? categoryId;
  for (final c in typed) {
    final cname = c.name.toLowerCase();
    if (words.any((w) => w.length >= 3 && cname.split(RegExp(r'[\s&]+')).contains(w))) {
      categoryId = c.id;
      break;
    }
  }
  if (categoryId == null) {
    for (final w in words) {
      final target = _keywordCategory[w];
      if (target == null) continue;
      final found = typed.where((c) => c.name == target);
      if (found.isNotEmpty) {
        categoryId = found.first.id;
        break;
      }
    }
  }

  final noteWords = rest.split(RegExp(r'\s+')).where((w) {
    final clean = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9&]'), '');
    return w.isNotEmpty && !usedWords.contains(clean);
  });
  final note = noteWords.join(' ').trim();

  return ParsedInput(
    amount: amount,
    type: type,
    categoryId: categoryId,
    accountId: accountId,
    note: note.isEmpty ? '' : note[0].toUpperCase() + note.substring(1),
  );
}
