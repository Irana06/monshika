import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants/kanji_icons.dart';
import '../core/utils/dates.dart';
import '../core/utils/money.dart';
import '../data/database/database.dart';
import 'finance.dart';

const _typeLabel = {'income': 'Pemasukan', 'expense': 'Pengeluaran', 'transfer': 'Transfer'};

class ExportService {
  ExportService(this.db);

  final AppDatabase db;

  static const csvHeader = [
    'Tanggal', 'Jam', 'Tipe', 'Kategori', 'Sub-kategori', 'Dompet', 'Ke Dompet', 'Nominal', 'Mata Uang',
    'Nominal Tujuan', 'Biaya', 'Catatan', 'Penerima', 'Tag',
  ];

  Future<_Ctx> _ctx(DateRange range) async {
    final accounts = {for (final a in await db.getAccounts(includeArchived: true)) a.id: a};
    final categories = {for (final c in await db.getCategories()) c.id: c};
    final tags = {for (final t in await db.select(db.tags).get()) t.id: t};
    final tagLinks = await db.select(db.transactionTags).get();
    final tagMap = <int, List<String>>{};
    for (final l in tagLinks) {
      final t = tags[l.tagId];
      if (t != null) tagMap.putIfAbsent(l.transactionId, () => []).add(t.name);
    }
    final txs = await db.getTransactions(from: range.start, to: range.end);
    return _Ctx(accounts, categories, tagMap, txs.reversed.toList());
  }

  List<List<Object?>> _rows(_Ctx c) {
    return [
      csvHeader,
      for (final t in c.txs)
        () {
          final cat = t.categoryId == null ? null : c.categories[t.categoryId];
          final parent = cat?.parentId == null ? null : c.categories[cat!.parentId];
          return <Object?>[
            DateFormat('yyyy-MM-dd').format(t.date),
            DateFormat('HH:mm').format(t.date),
            _typeLabel[t.type] ?? t.type,
            parent?.name ?? cat?.name ?? '',
            parent != null ? cat?.name ?? '' : '',
            c.accounts[t.accountId]?.name ?? '',
            t.toAccountId == null ? '' : c.accounts[t.toAccountId]?.name ?? '',
            t.amount,
            c.accounts[t.accountId]?.currency ?? '',
            t.toAmount ?? '',
            t.fee == 0 ? '' : t.fee,
            t.note,
            t.payee,
            (c.tagMap[t.id] ?? const []).join('; '),
          ];
        }(),
    ];
  }

  Future<Uint8List> csvBytes(DateRange range) async {
    final c = await _ctx(range);
    final text = Csv(lineDelimiter: '\n').encode(_rows(c));
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
  }

  Future<Uint8List> excelBytes(DateRange range, {required String baseCurrency, required Map<String, double> rates}) async {
    final c = await _ctx(range);
    final book = xl.Excel.createExcel();
    const sheetName = 'Transaksi';
    book.rename(book.getDefaultSheet() ?? 'Sheet1', sheetName);
    for (final row in _rows(c)) {
      book.appendRow(sheetName, row.map<xl.CellValue?>((v) {
        if (v is double) return xl.DoubleCellValue(v);
        if (v is int) return xl.IntCellValue(v);
        return xl.TextCellValue(v?.toString() ?? '');
      }).toList());
    }

    final f = Finance(
      accounts: c.accounts,
      balances: await db.getBalances(),
      categories: c.categories,
      rates: rates,
      baseCurrency: baseCurrency,
    );
    const summary = 'Ringkasan';
    final s = f.summarize(c.txs);
    book.appendRow(summary, [xl.TextCellValue('Periode'), xl.TextCellValue(fmtRange(range))]);
    book.appendRow(summary, [xl.TextCellValue('Mata uang dasar'), xl.TextCellValue(baseCurrency)]);
    book.appendRow(summary, [xl.TextCellValue('Pemasukan'), xl.DoubleCellValue(s.income)]);
    book.appendRow(summary, [xl.TextCellValue('Pengeluaran'), xl.DoubleCellValue(s.expense)]);
    book.appendRow(summary, [xl.TextCellValue('Selisih'), xl.DoubleCellValue(s.income - s.expense)]);
    book.appendRow(summary, [xl.TextCellValue('')]);
    book.appendRow(summary, [xl.TextCellValue('Kategori pengeluaran'), xl.TextCellValue('Total')]);
    for (final e in f.breakdown(c.txs, 'expense')) {
      book.appendRow(summary, [
        xl.TextCellValue(e.key == null ? 'Tanpa kategori' : c.categories[e.key]?.name ?? '-'),
        xl.DoubleCellValue(e.value),
      ]);
    }
    book.appendRow(summary, [xl.TextCellValue('')]);
    book.appendRow(summary, [xl.TextCellValue('Dompet'), xl.TextCellValue('Saldo'), xl.TextCellValue('Mata uang')]);
    for (final a in c.accounts.values.where((a) => !a.archived)) {
      book.appendRow(summary, [
        xl.TextCellValue(a.name),
        xl.DoubleCellValue(f.accountBalance(a.id)),
        xl.TextCellValue(a.currency),
      ]);
    }
    return Uint8List.fromList(book.encode() ?? const []);
  }

  Future<Uint8List> pdfBytes(DateRange range, {required String baseCurrency, required Map<String, double> rates, String userName = ''}) async {
    final c = await _ctx(range);
    final f = Finance(
      accounts: c.accounts,
      balances: await db.getBalances(),
      categories: c.categories,
      rates: rates,
      baseCurrency: baseCurrency,
    );
    final s = f.summarize(c.txs);
    // Font bawaan PDF tidak punya glyph U+2212, jadi pakai minus ASCII.
    String money(double v, String code) => formatMoney(v, code).replaceAll('−', '-');

    const beni = PdfColor.fromInt(0xFFB5453A);
    const matcha = PdfColor.fromInt(0xFF5DA487);
    const ink = PdfColor.fromInt(0xFF1F1F28);
    const muted = PdfColor.fromInt(0xFF6B6760);

    pw.Widget stat(String label, String value, PdfColor color) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: muted)),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
            ]),
          ),
        );

    final doc = pw.Document(title: 'Laporan Monshika', author: userName.isEmpty ? 'Monshika' : userName);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: beni, width: 2))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('MONSHIKA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink, letterSpacing: 3)),
          pw.Text('Laporan Keuangan · ${fmtRange(range)}', style: const pw.TextStyle(fontSize: 10, color: muted)),
        ]),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Halaman ${ctx.pageNumber}/${ctx.pagesCount} · dibuat ${fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: muted)),
      ),
      build: (ctx) => [
        pw.SizedBox(height: 12),
        pw.Row(children: [
          stat('Pemasukan', money(s.income, baseCurrency), matcha),
          pw.SizedBox(width: 8),
          stat('Pengeluaran', money(s.expense, baseCurrency), beni),
          pw.SizedBox(width: 8),
          stat('Selisih', money(s.income - s.expense, baseCurrency), ink),
          pw.SizedBox(width: 8),
          stat('Kekayaan bersih', money(f.totalBalance, baseCurrency), ink),
        ]),
        pw.SizedBox(height: 18),
        pw.Text('Pengeluaran per kategori', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Kategori', 'Total', '%'],
          data: [
            for (final e in f.breakdown(c.txs, 'expense'))
              [
                e.key == null ? 'Tanpa kategori' : c.categories[e.key]?.name ?? '-',
                money(e.value, baseCurrency),
                s.expense == 0 ? '0%' : '${(e.value / s.expense * 100).toStringAsFixed(1)}%',
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: ink),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 18),
        pw.Text('Kakeibo — 4 pilar', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Pilar', 'Total'],
          data: [
            for (final e in f.pillarBreakdown(c.txs).entries) [kPillars[e.key]?.$1 ?? e.key, money(e.value, baseCurrency)],
          ],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: ink),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {1: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 18),
        pw.Text('Daftar transaksi (${c.txs.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Tanggal', 'Tipe', 'Kategori', 'Dompet', 'Catatan', 'Nominal'],
          data: [
            for (final t in c.txs)
              [
                DateFormat('dd/MM/yy HH:mm').format(t.date),
                _typeLabel[t.type] ?? t.type,
                t.type == 'transfer'
                    ? '-> ${c.accounts[t.toAccountId]?.name ?? ''}'
                    : (t.categoryId == null ? '' : c.categories[t.categoryId]?.name ?? ''),
                c.accounts[t.accountId]?.name ?? '',
                t.note,
                money(t.type == 'expense' ? -t.amount : t.amount, c.accounts[t.accountId]?.currency ?? baseCurrency),
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: ink),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {5: pw.Alignment.centerRight},
          columnWidths: {4: const pw.FlexColumnWidth(2)},
        ),
      ],
    ));
    return doc.save();
  }

  /// Import CSV dengan format sama seperti export. Mengembalikan jumlah baris masuk.
  Future<int> importCsv(Uint8List bytes, {required int fallbackAccountId}) async {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final rows = csv.decode(text);
    if (rows.length < 2) return 0;
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name.toLowerCase());

    final accounts = await db.getAccounts(includeArchived: true);
    final categories = await db.getCategories();
    final typeByLabel = {for (final e in _typeLabel.entries) e.value.toLowerCase(): e.key};

    var count = 0;
    await db.transaction(() async {
      for (final r in rows.skip(1)) {
        String cell(String name) {
          final i = col(name);
          return i < 0 || i >= r.length ? '' : r[i].toString().trim();
        }

        final date = DateTime.tryParse('${cell('Tanggal')} ${cell('Jam').isEmpty ? '00:00' : cell('Jam')}');
        final amount = parseAmount(cell('Nominal'))?.abs();
        if (date == null || amount == null || amount == 0) continue;
        final rawType = cell('Tipe').toLowerCase();
        final type = typeByLabel[rawType] ?? (['income', 'expense', 'transfer'].contains(rawType) ? rawType : 'expense');
        int? findAccount(String name) =>
            accounts.where((a) => a.name.toLowerCase() == name.toLowerCase()).map((a) => a.id).firstOrNull;
        final sub = cell('Sub-kategori');
        final catName = sub.isNotEmpty ? sub : cell('Kategori');
        final catId = categories
            .where((c) => c.name.toLowerCase() == catName.toLowerCase() && (type == 'transfer' || c.type == type))
            .map((c) => c.id)
            .firstOrNull;
        final toAcc = findAccount(cell('Ke Dompet'));
        if (type == 'transfer' && toAcc == null) continue;
        await db.saveTransaction(TransactionsCompanion.insert(
          type: type,
          amount: amount,
          accountId: findAccount(cell('Dompet')) ?? fallbackAccountId,
          toAccountId: Value(type == 'transfer' ? toAcc : null),
          toAmount: Value(parseAmount(cell('Nominal Tujuan'))),
          fee: Value(parseAmount(cell('Biaya')) ?? 0),
          categoryId: Value(type == 'transfer' ? null : catId),
          date: date,
          note: Value(cell('Catatan')),
          payee: Value(cell('Penerima')),
        ));
        count++;
      }
    });
    return count;
  }
}

class _Ctx {
  _Ctx(this.accounts, this.categories, this.tagMap, this.txs);
  final Map<int, Account> accounts;
  final Map<int, TxCategory> categories;
  final Map<int, List<String>> tagMap;
  final List<TxEntry> txs;
}
