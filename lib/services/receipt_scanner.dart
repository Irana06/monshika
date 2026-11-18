// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'receipt_parser.dart';

/// Kenapa pembacaan gagal, supaya pesannya bisa jelas ke pengguna.
enum ScanFailure { unsupported, modelDownloading, unreadable }

class ScanResult {
  const ScanResult(this.draft, {this.failure});
  final ReceiptDraft draft;
  final ScanFailure? failure;
}

/// Jembatan ke MainActivity: gambar dari menu Bagikan dan pembaca teks ML Kit.
class ReceiptScanner {
  static const _ch = MethodChannel('monshika/receipt');
  static final _shared = StreamController<void>.broadcast();
  static bool _ready = false;

  /// Berbunyi saat ada gambar baru dibagikan ketika aplikasi sudah terbuka.
  static Stream<void> get onShared {
    if (!_ready) {
      _ready = true;
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'shared') _shared.add(null);
      });
    }
    return _shared.stream;
  }

  /// Ambil (dan habiskan) gambar yang menunggu dari menu Bagikan.
  static Future<String?> takeSharedImage() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _ch.invokeMethod<String>('takeSharedImage');
    } on MissingPluginException {
      return null;
    }
  }

  /// Simpan salinan gambar di folder struk aplikasi, untuk dilampirkan ke transaksi.
  static Future<String> keepAsReceipt(String path) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
    await dir.create(recursive: true);
    final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path);
    final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(path).copy(dest);
    return dest;
  }

  static Future<ScanResult> scan(String path, List<ReceiptAccount> accounts) async {
    if (!Platform.isAndroid) return const ScanResult(ReceiptDraft(), failure: ScanFailure.unsupported);
    try {
      final raw = await _ch.invokeListMethod<Map<Object?, Object?>>('recognize', {'path': path}) ?? const [];
      final lines = [
        for (final m in raw)
          OcrLine(
            '${m['text'] ?? ''}',
            left: (m['l'] as num? ?? 0).toDouble(),
            top: (m['t'] as num? ?? 0).toDouble(),
            right: (m['r'] as num? ?? 0).toDouble(),
            bottom: (m['b'] as num? ?? 0).toDouble(),
          ),
      ];
      final draft = parseReceipt(groupRows(lines), accounts: accounts);
      return ScanResult(draft, failure: draft.isEmpty ? ScanFailure.unreadable : null);
    } on PlatformException catch (e) {
      return ScanResult(const ReceiptDraft(), failure: e.code == 'model' ? ScanFailure.modelDownloading : ScanFailure.unreadable);
    } on MissingPluginException {
      return const ScanResult(ReceiptDraft(), failure: ScanFailure.unsupported);
    }
  }
}
