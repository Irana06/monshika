import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/database.dart';

/// Kurs mata uang, emas & kripto.
///
/// - Coinbase: diperbarui terus-menerus (fiat + kripto), tanpa API key.
/// - fawazahmed0 currency-api: 200+ mata uang termasuk logam (XAU/XAG), harian.
/// Hasil keduanya digabung; Coinbase diprioritaskan karena lebih real-time.
class RatesService {
  static const _fawazPrimary = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json';
  static const _fawazFallback = 'https://latest.currency-api.pages.dev/v1/currencies/usd.min.json';
  static const _coinbase = 'https://api.coinbase.com/v2/exchange-rates?currency=USD';

  static const refreshEvery = Duration(minutes: 30);

  static Future<Map<String, double>> fetch({http.Client? client}) async {
    final c = client ?? http.Client();
    final result = <String, double>{};
    try {
      for (final url in [_fawazPrimary, _fawazFallback]) {
        try {
          final res = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
          if (res.statusCode != 200) continue;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final usd = (json['usd'] as Map).cast<String, dynamic>();
          usd.forEach((k, v) {
            final d = (v as num?)?.toDouble();
            if (d != null && d > 0) result[k.toUpperCase()] = d;
          });
          break;
        } catch (_) {}
      }
      try {
        final res = await c.get(Uri.parse(_coinbase)).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final rates = ((json['data'] as Map)['rates'] as Map).cast<String, dynamic>();
          rates.forEach((k, v) {
            final d = double.tryParse(v.toString());
            if (d != null && d > 0) result[k.toUpperCase()] = d;
          });
        }
      } catch (_) {}
    } finally {
      if (client == null) c.close();
    }
    result['USD'] = 1;
    return result;
  }

  /// Perbarui kurs bila sudah kedaluwarsa (atau [force]). Mengembalikan true bila berhasil.
  static Future<bool> refresh(AppDatabase db, {bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('ratesUpdatedAt');
    if (!force && last != null) {
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last));
      if (age < refreshEvery) return true;
    }
    final rates = await fetch();
    if (rates.length < 5) return false;
    await db.upsertRates(rates);
    await prefs.setInt('ratesUpdatedAt', DateTime.now().millisecondsSinceEpoch);
    return true;
  }
}
