import 'package:intl/intl.dart';

import '../../l10n/strings.dart';

class CurrencyInfo {
  const CurrencyInfo(this.code, this.nameId, this.nameEn, this.symbol, {this.decimals = 2, this.flag = '💱', this.crypto = false});

  final String code;
  final String nameId;
  final String nameEn;
  final String symbol;
  final int decimals;
  final String flag;
  final bool crypto;

  String name([S? s]) => (s ?? S.current).en ? nameEn : nameId;
}

/// Kode pseudo untuk emas dalam gram (dihitung dari XAU / troy ounce).
const kGoldGram = 'XAUG';
const kTroyOunceGram = 31.1034768;

const kCurrencies = <CurrencyInfo>[
  CurrencyInfo('IDR', 'Rupiah', 'Indonesian Rupiah', 'Rp', decimals: 0, flag: '🇮🇩'),
  CurrencyInfo('USD', 'Dolar Amerika', 'US Dollar', r'$', flag: '🇺🇸'),
  CurrencyInfo('JPY', 'Yen Jepang', 'Japanese Yen', '¥', decimals: 0, flag: '🇯🇵'),
  CurrencyInfo('EUR', 'Euro', 'Euro', '€', flag: '🇪🇺'),
  CurrencyInfo('SGD', 'Dolar Singapura', 'Singapore Dollar', r'S$', flag: '🇸🇬'),
  CurrencyInfo('MYR', 'Ringgit Malaysia', 'Malaysian Ringgit', 'RM', flag: '🇲🇾'),
  CurrencyInfo('SAR', 'Riyal Saudi', 'Saudi Riyal', 'SR', flag: '🇸🇦'),
  CurrencyInfo('AUD', 'Dolar Australia', 'Australian Dollar', r'A$', flag: '🇦🇺'),
  CurrencyInfo('GBP', 'Pound Inggris', 'British Pound', '£', flag: '🇬🇧'),
  CurrencyInfo('CNY', 'Yuan Tiongkok', 'Chinese Yuan', 'CN¥', flag: '🇨🇳'),
  CurrencyInfo('KRW', 'Won Korea', 'Korean Won', '₩', decimals: 0, flag: '🇰🇷'),
  CurrencyInfo('THB', 'Baht Thailand', 'Thai Baht', '฿', flag: '🇹🇭'),
  CurrencyInfo('HKD', 'Dolar Hong Kong', 'Hong Kong Dollar', r'HK$', flag: '🇭🇰'),
  CurrencyInfo('TWD', 'Dolar Taiwan', 'Taiwan Dollar', r'NT$', decimals: 0, flag: '🇹🇼'),
  CurrencyInfo('PHP', 'Peso Filipina', 'Philippine Peso', '₱', flag: '🇵🇭'),
  CurrencyInfo('VND', 'Dong Vietnam', 'Vietnamese Dong', '₫', decimals: 0, flag: '🇻🇳'),
  CurrencyInfo('INR', 'Rupee India', 'Indian Rupee', '₹', flag: '🇮🇳'),
  CurrencyInfo('AED', 'Dirham UEA', 'UAE Dirham', 'AED', flag: '🇦🇪'),
  CurrencyInfo('CHF', 'Franc Swiss', 'Swiss Franc', 'CHF', flag: '🇨🇭'),
  CurrencyInfo('CAD', 'Dolar Kanada', 'Canadian Dollar', r'C$', flag: '🇨🇦'),
  CurrencyInfo('NZD', 'Dolar Selandia Baru', 'New Zealand Dollar', r'NZ$', flag: '🇳🇿'),
  CurrencyInfo('TRY', 'Lira Turki', 'Turkish Lira', '₺', flag: '🇹🇷'),
  CurrencyInfo(kGoldGram, 'Emas (gram)', 'Gold (gram)', 'gr', decimals: 3, flag: '🥇'),
  CurrencyInfo('XAG', 'Perak (troy oz)', 'Silver (troy oz)', 'oz', decimals: 3, flag: '🥈'),
  CurrencyInfo('BTC', 'Bitcoin', 'Bitcoin', '₿', decimals: 8, flag: '🟠', crypto: true),
  CurrencyInfo('ETH', 'Ethereum', 'Ethereum', 'Ξ', decimals: 6, flag: '🔷', crypto: true),
  CurrencyInfo('USDT', 'Tether', 'Tether', 'USDT', decimals: 2, flag: '🟢', crypto: true),
  CurrencyInfo('BNB', 'BNB', 'BNB', 'BNB', decimals: 5, flag: '🟡', crypto: true),
  CurrencyInfo('SOL', 'Solana', 'Solana', 'SOL', decimals: 4, flag: '🟣', crypto: true),
];

CurrencyInfo currencyInfo(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => CurrencyInfo(code, code, code, code));

final _cache = <String, NumberFormat>{};

String get _numberLocale => S.current.en ? 'en_US' : 'id_ID';

NumberFormat _formatter(String code) => _cache.putIfAbsent('$_numberLocale|$code', () {
      final info = currencyInfo(code);
      final pattern = info.decimals == 0 ? '#,##0' : '#,##0.${'#' * info.decimals}';
      return NumberFormat(pattern, _numberLocale);
    });

/// Format nominal, contoh: `Rp 25.000`, `¥ 1.200`, `$ 12.5`.
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
    number = NumberFormat.compact(locale: _numberLocale).format(abs);
  } else {
    number = _formatter(code).format(abs);
  }
  final sign = amount < 0 ? '-' : (showSign && amount > 0 ? '+' : '');
  return symbol ? '$sign${info.symbol} $number' : '$sign$number';
}

/// Parsing string angka format Indonesia ("25.000,50") atau Inggris ("25,000.50").
double? parseAmount(String input) {
  var s = input.trim().replaceAll(RegExp(r'[^0-9.,\-]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',') && s.contains('.')) {
    // Pemisah yang muncul terakhir dianggap desimal.
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    s = RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s) ? s.replaceAll(',', '') : s.replaceAll(',', '.');
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
