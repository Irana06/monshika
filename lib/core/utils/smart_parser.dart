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
  // Indonesia
  'gaji', 'gajian', 'bonus', 'thr', 'terima', 'diterima', 'dapat', 'masuk', 'jual', 'refund', 'cashback',
  'pemasukan', 'dividen', 'bunga', 'komisi', 'honor', 'transferan',
  // English
  'salary', 'paycheck', 'income', 'received', 'earned', 'sold', 'dividend', 'interest', 'commission', 'payout',
};

/// Nama kategori bawaan (Indonesia, Inggris) per kunci.
const _categoryNames = <String, (String, String)>{
  'coffee': ('Kopi & jajan', 'Coffee & snacks'),
  'food': ('Makan & minum', 'Food & drinks'),
  'eatout': ('Makan di luar', 'Eating out'),
  'groceries': ('Belanja harian', 'Groceries'),
  'ride': ('Ojek online', 'Ride hailing'),
  'fuel': ('Bensin', 'Fuel'),
  'parking': ('Parkir & tol', 'Parking & tolls'),
  'transport': ('Transportasi', 'Transport'),
  'electricity': ('Listrik', 'Electricity'),
  'internet': ('Internet', 'Internet'),
  'phone': ('Pulsa & kuota', 'Phone & data'),
  'water': ('Air', 'Water'),
  'housing': ('Tempat tinggal', 'Housing'),
  'health': ('Kesehatan', 'Health'),
  'education': ('Pendidikan', 'Education'),
  'fun': ('Hiburan', 'Entertainment'),
  'shopping': ('Belanja & fashion', 'Shopping'),
  'subs': ('Langganan', 'Subscriptions'),
  'selfcare': ('Perawatan diri', 'Self care'),
  'sports': ('Olahraga', 'Sports'),
  'gifts': ('Hadiah & donasi', 'Gifts & charity'),
  'travel': ('Liburan', 'Travel'),
  'taxes': ('Pajak & biaya', 'Taxes & fees'),
  'installment': ('Cicilan', 'Installments'),
  'salary': ('Gaji', 'Salary'),
  'bonus': ('Bonus & THR', 'Bonus'),
  'freelance': ('Freelance', 'Freelance'),
  'invest': ('Investasi', 'Investments'),
  'sales': ('Penjualan', 'Sales'),
  'cashback': ('Cashback & refund', 'Cashback & refunds'),
};

/// Kata kunci ke kunci kategori.
const _keywordCategory = <String, String>{
  // Kopi & jajan
  'kopi': 'coffee', 'coffee': 'coffee', 'jajan': 'coffee', 'snack': 'coffee', 'snacks': 'coffee', 'boba': 'coffee',
  'teh': 'coffee', 'tea': 'coffee', 'latte': 'coffee', 'starbucks': 'coffee',
  // Makan
  'makan': 'food', 'sarapan': 'food', 'nasi': 'food', 'bakso': 'food', 'mie': 'food', 'warteg': 'food',
  'lunch': 'food', 'dinner': 'food', 'breakfast': 'food', 'food': 'food', 'meal': 'food',
  'resto': 'eatout', 'restoran': 'eatout', 'restaurant': 'eatout', 'cafe': 'eatout', 'gofood': 'eatout',
  'grabfood': 'eatout', 'shopeefood': 'eatout',
  // Belanja harian
  'indomaret': 'groceries', 'alfamart': 'groceries', 'sayur': 'groceries', 'beras': 'groceries', 'pasar': 'groceries',
  'supermarket': 'groceries', 'galon': 'groceries', 'sabun': 'groceries', 'groceries': 'groceries', 'grocery': 'groceries',
  // Transport
  'gojek': 'ride', 'grab': 'ride', 'ojol': 'ride', 'maxim': 'ride', 'ojek': 'ride', 'uber': 'ride', 'taxi': 'ride',
  'bensin': 'fuel', 'pertalite': 'fuel', 'pertamax': 'fuel', 'solar': 'fuel', 'fuel': 'fuel', 'gas': 'fuel',
  'parkir': 'parking', 'tol': 'parking', 'etoll': 'parking', 'parking': 'parking', 'toll': 'parking',
  'krl': 'transport', 'mrt': 'transport', 'transjakarta': 'transport', 'kereta': 'transport', 'bus': 'transport',
  'train': 'transport', 'tiket': 'transport', 'servis': 'transport', 'bengkel': 'transport',
  // Tagihan
  'listrik': 'electricity', 'pln': 'electricity', 'token': 'electricity', 'electricity': 'electricity',
  'internet': 'internet', 'wifi': 'internet', 'indihome': 'internet', 'biznet': 'internet',
  'pulsa': 'phone', 'kuota': 'phone', 'paket': 'phone', 'data': 'phone',
  'pdam': 'water', 'water': 'water',
  'kos': 'housing', 'kost': 'housing', 'sewa': 'housing', 'kontrakan': 'housing', 'rent': 'housing',
  // Lainnya
  'obat': 'health', 'dokter': 'health', 'apotek': 'health', 'bpjs': 'health', 'vitamin': 'health',
  'doctor': 'health', 'pharmacy': 'health', 'medicine': 'health',
  'buku': 'education', 'kursus': 'education', 'kuliah': 'education', 'spp': 'education', 'udemy': 'education',
  'book': 'education', 'course': 'education', 'tuition': 'education',
  'nonton': 'fun', 'bioskop': 'fun', 'game': 'fun', 'steam': 'fun', 'konser': 'fun', 'karaoke': 'fun',
  'topup': 'fun', 'movie': 'fun', 'cinema': 'fun', 'concert': 'fun',
  'baju': 'shopping', 'sepatu': 'shopping', 'celana': 'shopping', 'shopee': 'shopping', 'tokopedia': 'shopping',
  'lazada': 'shopping', 'tiktok': 'shopping', 'clothes': 'shopping', 'shoes': 'shopping', 'amazon': 'shopping',
  'netflix': 'subs', 'spotify': 'subs', 'youtube': 'subs', 'disney': 'subs', 'icloud': 'subs', 'chatgpt': 'subs',
  'claude': 'subs', 'langganan': 'subs', 'subscription': 'subs',
  'potong': 'selfcare', 'salon': 'selfcare', 'skincare': 'selfcare', 'barbershop': 'selfcare', 'haircut': 'selfcare',
  'gym': 'sports', 'futsal': 'sports', 'badminton': 'sports', 'renang': 'sports', 'swimming': 'sports',
  'sedekah': 'gifts', 'donasi': 'gifts', 'zakat': 'gifts', 'kado': 'gifts', 'infaq': 'gifts', 'kondangan': 'gifts',
  'gift': 'gifts', 'donation': 'gifts', 'charity': 'gifts',
  'hotel': 'travel', 'liburan': 'travel', 'travel': 'travel', 'pesawat': 'travel', 'flight': 'travel',
  'pajak': 'taxes', 'admin': 'taxes', 'tax': 'taxes', 'fee': 'taxes',
  'cicilan': 'installment', 'angsuran': 'installment', 'kredit': 'installment', 'installment': 'installment',
  // Pemasukan
  'gaji': 'salary', 'gajian': 'salary', 'salary': 'salary', 'paycheck': 'salary',
  'bonus': 'bonus', 'thr': 'bonus',
  'freelance': 'freelance', 'project': 'freelance', 'proyek': 'freelance', 'honor': 'freelance',
  'dividen': 'invest', 'bunga': 'invest', 'dividend': 'invest', 'interest': 'invest',
  'jual': 'sales', 'sold': 'sales',
  'cashback': 'cashback', 'refund': 'cashback',
};

final _amountRe = RegExp(
  r'(^|\s)([+\-])?\s*(?:rp\.?\s*|\$\s*)?(\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*(rb|ribu|k|jt|juta|m|mio|miliar|t)?(?=\s|$)',
  caseSensitive: false,
);

/// Parser teks bebas untuk catat cepat, contoh:
/// `kopi 25rb`, `gojek 18.500 ovo`, `+8jt gaji`, `coffee 5 cash`.
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
      final key = _keywordCategory[w];
      final names = key == null ? null : _categoryNames[key];
      if (names == null) continue;
      final found = typed.where((c) {
        final n = c.name.toLowerCase();
        return n == names.$1.toLowerCase() || n == names.$2.toLowerCase();
      });
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
