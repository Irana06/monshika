// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

/// Membaca teks hasil OCR dari screenshot bukti bayar (bank, e-wallet, QRIS)
/// dan menebak isi transaksinya. Murni Dart supaya bisa dites tanpa HP.
///
/// Hasilnya tebakan, bukan kepastian: form transaksi selalu menampilkannya
/// untuk dicek dulu, tidak pernah langsung disimpan.
library;

class OcrLine {
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  final String text;
  final double left, top, right, bottom;

  double get centerY => (top + bottom) / 2;
  double get height => (bottom - top).abs();
}

class ReceiptAccount {
  const ReceiptAccount(this.id, this.name);
  final int id;
  final String name;
}

class ReceiptDraft {
  const ReceiptDraft({
    this.amount,
    this.fee = 0,
    this.payee,
    this.date,
    this.type = 'expense',
    this.fromAccountId,
    this.toAccountId,
  });

  final double? amount;
  final double fee;
  final String? payee;
  final DateTime? date;
  final String type;
  final int? fromAccountId;
  final int? toAccountId;

  bool get isEmpty => amount == null && payee == null && date == null;

  @override
  String toString() =>
      'ReceiptDraft(amount: $amount, fee: $fee, payee: $payee, date: $date, type: $type, from: $fromAccountId, to: $toAccountId)';
}

/// Susun potongan teks OCR menjadi baris visual. ML Kit sering memisahkan
/// kolom label ("Total") dan kolom nilai ("Rp25.000") ke blok berbeda, jadi
/// potongan yang sejajar secara vertikal digabung lagi, urut dari kiri.
List<List<String>> groupRows(List<OcrLine> lines) {
  final sorted = [...lines.where((l) => l.text.trim().isNotEmpty)]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrLine>>[];
  for (final l in sorted) {
    final last = rows.isEmpty ? null : rows.last;
    if (last != null) {
      final ref = last.first;
      final tol = (ref.height < l.height ? ref.height : l.height) * 0.5;
      if ((l.centerY - ref.centerY).abs() <= tol) {
        last.add(l);
        continue;
      }
    }
    rows.add([l]);
  }
  return [
    for (final r in rows) [for (final l in (r..sort((a, b) => a.left.compareTo(b.left)))) l.text.trim()],
  ];
}

ReceiptDraft parseReceiptText(String text, {List<ReceiptAccount> accounts = const [], DateTime? now}) =>
    parseReceipt([for (final l in text.split('\n')) if (l.trim().isNotEmpty) [l.trim()]], accounts: accounts, now: now);

ReceiptDraft parseReceipt(List<List<String>> rows, {List<ReceiptAccount> accounts = const [], DateTime? now}) {
  now ??= DateTime.now();
  final rowTexts = [for (final r in rows) r.join('  ')];
  final all = _norm(rowTexts.join('\n'));

  final amounts = _findAmounts(rows);
  final type = _guessType(all);
  final payee = _findPayee(rows, incoming: type == 'income');
  final date = _findDate(rowTexts, now);

  // Akun: cari nama akun pengguna (dan alias mereknya) di teks.
  int? matchIn(String text) {
    final t = _norm(text);
    for (final a in accounts) {
      if (_keysFor(a.name).any((k) => _containsWord(t, k))) return a.id;
    }
    return null;
  }

  final mentioned = <int>[];
  for (final a in accounts) {
    if (_keysFor(a.name).any((k) => _containsWord(all, k))) mentioned.add(a.id);
  }

  int? toAccount;
  int? fromAccount;
  for (var i = 0; i < rowTexts.length; i++) {
    final row = _norm(rowTexts[i]);
    final next = i + 1 < rowTexts.length ? rowTexts[i + 1] : '';
    if (toAccount == null && type != 'income' && _toHints.any(row.contains)) {
      toAccount = matchIn(rowTexts[i]) ?? (_labelOnly(row) ? matchIn(next) : null);
    }
    if (fromAccount == null && _fromHints.any(row.contains)) {
      fromAccount = matchIn(rowTexts[i]) ?? (_labelOnly(row) ? matchIn(next) : null);
    }
  }
  if (toAccount == null && payee != null && type != 'income') toAccount = matchIn(payee);
  if (fromAccount == toAccount) fromAccount = null;
  final hintedFrom = fromAccount;
  if (fromAccount == null) {
    for (final id in mentioned) {
      if (id != toAccount) {
        fromAccount = id;
        break;
      }
    }
  }

  // Transfer ke akun sendiri: tujuannya salah satu akun di Monshika.
  final isTransfer = toAccount != null && type != 'income';
  final finalType = isTransfer ? 'transfer' : type;

  double? amount;
  var fee = amounts.fee;
  if (finalType == 'transfer') {
    amount = amounts.nominal ?? (amounts.total != null ? amounts.total! - fee : amounts.plain);
  } else {
    // Untuk pengeluaran, yang keluar dari kantong adalah totalnya.
    amount = amounts.total ?? (amounts.nominal != null ? amounts.nominal! + fee : amounts.plain);
    fee = 0;
  }
  if (amount != null && amount <= 0) amount = null;

  return ReceiptDraft(
    amount: amount,
    fee: fee,
    payee: isTransfer ? null : payee,
    date: date,
    type: finalType,
    // Uang masuk: akun yang disebut di teks selain akun pengirim.
    fromAccountId: finalType == 'income' ? mentioned.where((id) => id != hintedFrom).firstOrNull : fromAccount,
    toAccountId: isTransfer ? toAccount : null,
  );
}

// ---------------------------------------------------------------------------
// Nominal
// ---------------------------------------------------------------------------

class _Amounts {
  double? total, nominal, plain;
  double fee = 0;
}

final _moneyRe = RegExp(r'(?:rp|idr)\s*\.?\s*:?\s*(\d[\d.,\s]*\d|\d)', caseSensitive: false);

double? parseRupiah(String raw) {
  var s = raw.replaceAll(RegExp(r'\s'), '');
  // Dua digit terakhir setelah pemisah = sen ("25.000,00" / "25,000.00").
  final cents = RegExp(r'[.,](\d{2})$').firstMatch(s);
  var frac = 0.0;
  if (cents != null && s.length > 3) {
    final head = s.substring(0, cents.start);
    // "1.50" (tanpa pemisah ribuan sebelumnya) bisa juga ribuan yang terpotong;
    // anggap sen hanya kalau bagian depannya tampak seperti angka utuh.
    if (RegExp(r'^\d{1,3}([.,]\d{3})*$').hasMatch(head) || RegExp(r'^\d+$').hasMatch(head)) {
      frac = int.parse(cents.group(1)!) / 100;
      s = head;
    }
  }
  final digits = s.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty || digits.length > 13) return null;
  return int.parse(digits) + frac;
}

const _totalWords = ['total bayar', 'total pembayaran', 'total transaksi', 'total tagihan', 'total'];
const _nominalWords = ['nominal', 'jumlah', 'amount', 'nilai transaksi', 'harga', 'pembayaran', 'transfer'];
const _feeWords = ['biaya admin', 'biaya layanan', 'biaya transfer', 'admin fee', 'biaya', 'admin', 'fee'];
const _statusWords = ['berhasil', 'sukses', 'success', 'selesai', 'completed', 'diproses'];
const _ignoreWords = ['saldo', 'balance', 'cashback', 'diskon', 'potongan', 'promo', 'koin', 'poin', 'hemat', 'voucher', 'limit'];

_Amounts _findAmounts(List<List<String>> rows) {
  final r = _Amounts();
  for (var i = 0; i < rows.length; i++) {
    final rowText = rows[i].join('  ');
    final m = _moneyRe.firstMatch(rowText);
    if (m == null) continue;
    final value = parseRupiah(m.group(1)!);
    if (value == null) continue;
    // Label bisa di baris yang sama atau tepat di atas nominal.
    var label = _norm(rowText.substring(0, m.start));
    final prev = i > 0 ? _norm(rows[i - 1].join(' ')) : '';
    // Baris di atasnya dipakai sebagai label, kecuali judul status ("Transfer Berhasil").
    if (label.replaceAll(RegExp(r'[^a-z]'), '').isEmpty && prev.isNotEmpty && !_moneyRe.hasMatch(prev) && !_statusWords.any(prev.contains)) {
      label = prev;
    }
    if (_ignoreWords.any(label.contains)) continue;
    if (_feeWords.any(label.contains) && !_totalWords.any(label.contains)) {
      if (r.fee == 0) r.fee = value;
      continue;
    }
    if (_totalWords.any(label.contains)) {
      r.total ??= value;
    } else if (_nominalWords.any(label.contains)) {
      r.nominal ??= value;
    } else {
      r.plain ??= value;
    }
  }
  if (r.fee > 0 && r.total != null && r.nominal == null && r.plain != null && r.plain! < r.total!) {
    r.nominal = r.plain;
  }
  return r;
}

// ---------------------------------------------------------------------------
// Jenis transaksi
// ---------------------------------------------------------------------------

const _incomeWords = [
  'dana masuk', 'uang masuk', 'transfer masuk', 'kamu menerima', 'anda menerima', 'telah menerima',
  'diterima dari', 'terima dana', 'received', 'incoming', 'pengembalian dana', 'refund',
];

String _guessType(String all) => _incomeWords.any(all.contains) ? 'income' : 'expense';

// ---------------------------------------------------------------------------
// Penerima / toko
// ---------------------------------------------------------------------------

const _payeeLabels = [
  'nama merchant', 'merchant', 'nama penerima', 'penerima', 'rekening tujuan', 'tujuan', 'dibayar ke',
  'bayar ke', 'transfer ke', 'kirim ke', 'kepada', 'nama toko', 'toko', 'recipient', 'to', 'ke',
];
const _senderLabels = ['nama pengirim', 'pengirim', 'dari', 'from', 'sender', 'sumber'];

String? _findPayee(List<List<String>> rows, {required bool incoming}) {
  final labels = incoming ? _senderLabels : _payeeLabels;
  for (final label in labels) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final first = _norm(row.first);
      String? value;
      if (row.length > 1 && _isLabel(first, label)) {
        value = row.sublist(1).join(' ');
      } else if (first.startsWith('$label:') || first.startsWith('$label :')) {
        value = row.first.substring(row.first.indexOf(':') + 1);
      } else if (row.length == 1 && _isLabel(first, label) && i + 1 < rows.length) {
        value = rows[i + 1].first;
      } else if (row.length == 1 && first.startsWith('$label ') && label.length > 2) {
        // "Transfer ke Budi" dalam satu potongan.
        value = row.first.substring(label.length).trim();
      }
      final cleaned = _cleanName(value);
      if (cleaned != null) return cleaned;
    }
  }
  return null;
}

bool _isLabel(String text, String label) {
  final t = text.replaceAll(RegExp(r'[:\s]+$'), '');
  return t == label;
}

String? _cleanName(String? v) {
  if (v == null) return null;
  var s = v.replaceAll(RegExp(r'^[\s:\-]+'), '').trim();
  if (s.isEmpty) return null;
  if (_moneyRe.hasMatch(s)) return null;
  // Nomor rekening / HP / ID transaksi saja bukan nama.
  if (RegExp(r'^[\d\s\-*+x.]+$', caseSensitive: false).hasMatch(s)) return null;
  // Buang nomor rekening yang menempel: "BUDI SANTOSO - 1234567890".
  s = s.replaceAll(RegExp(r'[\s\-|•·]*[\d*x]{6,}.*$', caseSensitive: false), '').trim();
  if (s.length < 2) return null;
  if (s.length > 40) s = s.substring(0, 40).trim();
  return s;
}

// ---------------------------------------------------------------------------
// Tanggal
// ---------------------------------------------------------------------------

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mei': 5, 'may': 5, 'jun': 6, 'jul': 7,
  'agu': 8, 'agt': 8, 'aug': 8, 'ags': 8, 'sep': 9, 'okt': 10, 'oct': 10, 'nov': 11, 'des': 12, 'dec': 12,
};

DateTime? _findDate(List<String> rows, DateTime now) {
  final named = RegExp(r'\b(\d{1,2})\s+([a-z]{3})[a-z]*\.?,?\s+(\d{4})', caseSensitive: false);
  final slash = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');
  final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    DateTime? d;
    int? end;
    final mn = named.firstMatch(row);
    if (mn != null) {
      final mon = _months[mn.group(2)!.toLowerCase()];
      if (mon != null) {
        d = _safeDate(int.parse(mn.group(3)!), mon, int.parse(mn.group(1)!));
        end = mn.end;
      }
    }
    if (d == null) {
      final mi = iso.firstMatch(row);
      if (mi != null) {
        d = _safeDate(int.parse(mi.group(1)!), int.parse(mi.group(2)!), int.parse(mi.group(3)!));
        end = mi.end;
      }
    }
    if (d == null) {
      final ms = slash.firstMatch(row);
      if (ms != null) {
        var y = int.parse(ms.group(3)!);
        if (y < 100) y += 2000;
        d = _safeDate(y, int.parse(ms.group(2)!), int.parse(ms.group(1)!));
        end = ms.end;
      }
    }
    if (d == null) continue;
    if (d.isAfter(now.add(const Duration(days: 1))) || now.difference(d).inDays > 400) continue;

    // Jam: di sisa baris yang sama, atau baris berikutnya.
    final rest = [row.substring(end!), if (i + 1 < rows.length) rows[i + 1]];
    for (final r in rest) {
      final t = RegExp(r'\b([01]?\d|2[0-3])[:.]([0-5]\d)(?:[:.][0-5]\d)?\b').firstMatch(r);
      if (t != null && (r.contains(':') || RegExp('wib|wita|wit', caseSensitive: false).hasMatch(r))) {
        return DateTime(d.year, d.month, d.day, int.parse(t.group(1)!), int.parse(t.group(2)!));
      }
    }
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay ? now : DateTime(d.year, d.month, d.day, 12);
  }
  return null;
}

DateTime? _safeDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m ? dt : null;
}

// ---------------------------------------------------------------------------
// Akun
// ---------------------------------------------------------------------------

const _toHints = ['tujuan', 'penerima', 'transfer ke', 'kirim ke', 'ke rekening', 'ke bank', 'top up ke', 'isi saldo'];
const _fromHints = ['sumber', 'rekening asal', 'dari rekening', 'metode pembayaran', 'bayar pakai', 'bayar dengan', 'dibayar dengan', 'debit dari', 'pengirim'];

bool _labelOnly(String row) => !RegExp(r'[a-z0-9]').hasMatch(row.replaceAll(RegExp(_toHints.followedBy(_fromHints).map(RegExp.escape).join('|')), '').replaceAll(RegExp(r'(nama|bank|rekening|akun)'), ''));

const _aliases = {
  'bsi': ['bsi', 'bank syariah indonesia'],
  'bca': ['bca', 'bank central asia', 'mybca'],
  'bri': ['bri', 'bank rakyat indonesia', 'brimo'],
  'bni': ['bni', 'bank negara indonesia', 'wondr'],
  'mandiri': ['mandiri', 'livin'],
  'shopeepay': ['shopeepay', 'shopee pay', 'spay'],
  'shopee': ['shopeepay', 'shopee pay', 'spay'],
  'gopay': ['gopay', 'go pay', 'gojek'],
  'dana': ['dana'],
  'ovo': ['ovo'],
  'jago': ['jago', 'bank jago'],
  'seabank': ['seabank', 'sea bank'],
  'linkaja': ['linkaja', 'link aja'],
};

Set<String> _keysFor(String accountName) {
  final n = _norm(accountName);
  final keys = <String>{if (n.length >= 3) n};
  final compact = n.replaceAll(' ', '');
  for (final e in _aliases.entries) {
    if (_containsWord(n, e.key) || compact.contains(e.key)) keys.addAll(e.value);
  }
  return keys;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

bool _containsWord(String haystack, String needle) =>
    RegExp('(^|[^a-z0-9])${RegExp.escape(needle)}(\$|[^a-z0-9])').hasMatch(haystack);
