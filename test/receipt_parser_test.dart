import 'package:flutter_test/flutter_test.dart';
import 'package:monshika/services/receipt_parser.dart';

const accounts = [ReceiptAccount(1, 'ShopeePay'), ReceiptAccount(2, 'BSI'), ReceiptAccount(3, 'GoPay'), ReceiptAccount(4, 'Dompet')];
final now = DateTime(2026, 11, 18, 21, 0);

List<List<String>> rows(String s) => [
      for (final l in s.trim().split('\n'))
        if (l.trim().isNotEmpty) l.split('|').map((e) => e.trim()).toList(),
    ];

void main() {
  test('nominal rupiah dengan berbagai format', () {
    expect(parseRupiah('25.000'), 25000);
    expect(parseRupiah('25.000,00'), 25000);
    expect(parseRupiah('1,500,000.00'), 1500000);
    expect(parseRupiah('1.500'), 1500);
    expect(parseRupiah('12.500,50'), 12500.5);
    expect(parseRupiah('50'), 50);
  });

  test('QRIS ShopeePay: pengeluaran ke merchant', () {
    final d = parseReceipt(rows('''
Pembayaran Berhasil
Rp25.000
Merchant | WARUNG GEPREK MBAK SRI
Metode Pembayaran | ShopeePay
Waktu Transaksi | 18 Nov 2026, 12:41
No. Transaksi | 1234567890123
Sisa Saldo | Rp1.234.567
'''), accounts: accounts, now: now);
    expect(d.type, 'expense');
    expect(d.amount, 25000);
    expect(d.payee, 'WARUNG GEPREK MBAK SRI');
    expect(d.fromAccountId, 1);
    expect(d.date, DateTime(2026, 11, 18, 12, 41));
  });

  test('ShopeePay ke BSI sendiri: transfer dengan biaya admin', () {
    final d = parseReceipt(rows('''
Transfer Berhasil
Rp501.000
Bank Tujuan | Bank Syariah Indonesia (BSI)
Nama Penerima | YUSHIKA
No. Rekening | 7123456789
Nominal | Rp500.000
Biaya Admin | Rp1.000
Total | Rp501.000
Sumber Dana | ShopeePay
18/11/2026 09:15
'''), accounts: accounts, now: now);
    expect(d.type, 'transfer');
    expect(d.amount, 500000);
    expect(d.fee, 1000);
    expect(d.toAccountId, 2);
    expect(d.fromAccountId, 1);
    expect(d.date, DateTime(2026, 11, 18, 9, 15));
  });

  test('BSI ke GoPay: label dan nilai di baris terpisah', () {
    final d = parseReceipt(rows('''
Transaksi Berhasil
Dari Rekening
BSI 7xxxxxx890
Ke
GOPAY CUSTOMER - 0812xxxx3456
Jumlah | Rp150.000,00
Tanggal | 17 November 2026 20:05:11
'''), accounts: accounts, now: now);
    expect(d.type, 'transfer');
    expect(d.amount, 150000);
    expect(d.fromAccountId, 2);
    expect(d.toAccountId, 3);
    expect(d.date, DateTime(2026, 11, 17, 20, 5));
  });

  test('uang masuk ke ShopeePay', () {
    final d = parseReceipt(rows('''
Dana Masuk
ShopeePay
Rp75.000
Dari | BUDI SANTOSO
18 Nov 2026 08.30 WIB
'''), accounts: accounts, now: now);
    expect(d.type, 'income');
    expect(d.amount, 75000);
    expect(d.payee, 'BUDI SANTOSO');
    expect(d.fromAccountId, 1);
    expect(d.date, DateTime(2026, 11, 18, 8, 30));
  });

  test('pengeluaran: total sudah termasuk biaya', () {
    final d = parseReceipt(rows('''
Pembayaran Berhasil
Nama Toko | Kopi Kenangan
Harga | Rp30.000
Biaya Layanan | Rp1.000
Total Bayar | Rp31.000
'''), accounts: accounts, now: now);
    expect(d.type, 'expense');
    expect(d.amount, 31000);
    expect(d.fee, 0);
    expect(d.payee, 'Kopi Kenangan');
  });

  test('tanggal masa depan atau terlalu lama diabaikan, teks kosong aman', () {
    final d = parseReceipt(rows('Rp10.000\n01/01/2031'), now: now);
    expect(d.amount, 10000);
    expect(d.date, isNull);
    expect(parseReceipt(const [], now: now).isEmpty, isTrue);
  });

  test('potongan OCR sejajar digabung jadi satu baris', () {
    final r = groupRows(const [
      OcrLine('Rp25.000', left: 600, top: 102, right: 800, bottom: 140),
      OcrLine('Total', left: 40, top: 100, right: 160, bottom: 138),
      OcrLine('Merchant', left: 40, top: 160, right: 200, bottom: 198),
      OcrLine('Toko A', left: 600, top: 162, right: 760, bottom: 200),
    ]);
    expect(r, [
      ['Total', 'Rp25.000'],
      ['Merchant', 'Toko A'],
    ]);
  });
}
