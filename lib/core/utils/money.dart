import 'package:intl/intl.dart';

class CurrencyInfo {
  const CurrencyInfo(this.code, this.name, this.symbol, {this.decimals = 2, this.flag = '💱', this.crypto = false});

  final String code;
  final String name;
  final String symbol;
  final int decimals;
  final String flag;
  final bool crypto;
}

/// Kode pseudo untuk emas dalam gram (dihitung dari XAU / troy ounce).
const kGoldGram = 'XAUG';
const kTroyOunceGram = 31.1034768;

const kCurrencies = <CurrencyInfo>[
  CurrencyInfo('IDR', 'Rupiah Indonesia', 'Rp', decimals: 0, flag: '🇮🇩'),
  CurrencyInfo('USD', 'Dolar Amerika', r'$', flag: '🇺🇸'),
  CurrencyInfo('JPY', 'Yen Jepang', '¥', decimals: 0, flag: '🇯🇵'),
  CurrencyInfo('EUR', 'Euro', '€', flag: '🇪🇺'),
  CurrencyInfo('SGD', 'Dolar Singapura', r'S$', flag: '🇸🇬'),
  CurrencyInfo('MYR', 'Ringgit Malaysia', 'RM', flag: '🇲🇾'),
  CurrencyInfo('SAR', 'Riyal Saudi', 'SR', flag: '🇸🇦'),
  CurrencyInfo('AUD', 'Dolar Australia', r'A$', flag: '🇦🇺'),
  CurrencyInfo('GBP', 'Pound Inggris', '£', flag: '🇬🇧'),
  CurrencyInfo('CNY', 'Yuan Tiongkok', 'CN¥', flag: '🇨🇳'),
  CurrencyInfo('KRW', 'Won Korea', '₩', decimals: 0, flag: '🇰🇷'),
  CurrencyInfo('THB', 'Baht Thailand', '฿', flag: '🇹🇭'),
  CurrencyInfo('HKD', 'Dolar Hong Kong', r'HK$', flag: '🇭🇰'),
  CurrencyInfo('TWD', 'Dolar Taiwan', r'NT$', decimals: 0, flag: '🇹🇼'),
  CurrencyInfo('PHP', 'Peso Filipina', '₱', flag: '🇵🇭'),
  CurrencyInfo('VND', 'Dong Vietnam', '₫', decimals: 0, flag: '🇻🇳'),
  CurrencyInfo('INR', 'Rupee India', '₹', flag: '🇮🇳'),
  CurrencyInfo('AED', 'Dirham UEA', 'AED', flag: '🇦🇪'),
  CurrencyInfo('CHF', 'Franc Swiss', 'CHF', flag: '🇨🇭'),
  CurrencyInfo('CAD', 'Dolar Kanada', r'C$', flag: '🇨🇦'),
  CurrencyInfo('NZD', 'Dolar Selandia Baru', r'NZ$', flag: '🇳🇿'),
  CurrencyInfo('TRY', 'Lira Turki', '₺', flag: '🇹🇷'),
  CurrencyInfo(kGoldGram, 'Emas (gram)', 'gr', decimals: 3, flag: '🥇'),
  CurrencyInfo('XAG', 'Perak (troy oz)', 'oz', decimals: 3, flag: '🥈'),
  CurrencyInfo('BTC', 'Bitcoin', '₿', decimals: 8, flag: '🟠', crypto: true),
  CurrencyInfo('ETH', 'Ethereum', 'Ξ', decimals: 6, flag: '🔷', crypto: true),
  CurrencyInfo('USDT', 'Tether', 'USDT', decimals: 2, flag: '🟢', crypto: true),
  CurrencyInfo('BNB', 'BNB', 'BNB', decimals: 5, flag: '🟡', crypto: true),
  CurrencyInfo('SOL', 'Solana', 'SOL', decimals: 4, flag: '🟣', crypto: true),
];

CurrencyInfo currencyInfo(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => CurrencyInfo(code, code, code));

final _cache = <String, NumberFormat>{};

NumberFormat _formatter(String code) => _cache.putIfAbsent(code, () {
      final info = currencyInfo(code);
      final pattern = info.decimals == 0 ? '#,##0' : '#,##0.${'#' * info.decimals}';
      return NumberFormat(pattern, 'id_ID');
    });

/// Format nominal, contoh: `Rp 25.000`, `¥ 1.200`, `$ 12,5`.
String formatMoney(
  double amount,
  String code, {
  bool compact = false,
  bool showSign = false,
  bool hidden = false,
  bool symbol = true,
}) {
  final info = currencyInfo(code);
  if (hidden) return '${symbol ? '${info.symbol} ' : ''}••••••';
  final abs = amount.abs();
  final String number;
  if (compact && abs >= 1000 && !info.crypto) {
    number = NumberFormat.compact(locale: 'id_ID').format(abs);
  } else {
    number = _formatter(code).format(abs);
  }
  final sign = amount < 0 ? '−' : (showSign && amount > 0 ? '+' : '');
  return symbol ? '$sign${info.symbol} $number' : '$sign$number';
}

/// Parsing string angka format Indonesia ("25.000,50" / "25000.5").
double? parseAmount(String input) {
  var s = input.trim().replaceAll(RegExp(r'[^0-9.,\-]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

/// Konversi antar mata uang memakai tabel kurs per USD.
double convert(double amount, String from, String to, Map<String, double> perUsd) {
  if (from == to) return amount;
  final f = perUsd[from];
  final t = perUsd[to];
  if (f == null || t == null || f == 0) return amount;
  return amount / f * t;
}
