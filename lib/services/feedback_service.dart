// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';

/// Kirim masukan lewat WhatsApp, lengkap dengan keterangan teknis.
///
/// Aplikasi tidak pernah mengirim apa pun sendiri. Pesannya baru disusun saat
/// tombol ditekan, lalu dibuka di WhatsApp dalam keadaan belum terkirim, jadi
/// isinya bisa dibaca, diubah, atau dihapus dulu oleh pemakainya.
abstract final class FeedbackService {
  static const waNumber = '6282233365018';

  static const _kLog = 'errorLog';
  static const _maxEntries = 5;

  /// Pasang penangkap error. Catatannya hanya disimpan di HP.
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      _record('${details.exceptionAsString()}\n${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _record('$error\n$stack');
      return false;
    };
  }

  static Future<void> _record(String text) async {
    try {
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String().substring(0, 19);
      final entries = p.getStringList(_kLog) ?? <String>[];
      entries.insert(0, '[$now] ${text.trim()}');
      await p.setStringList(_kLog, entries.take(_maxEntries).toList());
    } catch (_) {
      // Mencatat error tidak boleh ikut menjatuhkan aplikasi.
    }
  }

  static Future<List<String>> readLog() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_kLog) ?? const <String>[];
  }

  static Future<void> clearLog() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLog);
  }

  static Future<bool> get hasLog async => (await readLog()).isNotEmpty;

  /// Ringkasan error terakhir, dipotong supaya pesan WhatsApp tidak kepanjangan.
  static Future<String?> lastErrorSummary() async {
    final log = await readLog();
    if (log.isEmpty) return null;
    final lines = log.first.split('\n').where((l) => l.trim().isNotEmpty).take(3);
    final text = lines.join('\n');
    return text.length > 300 ? '${text.substring(0, 300)}...' : text;
  }

  /// Blok keterangan teknis yang ikut di pesan.
  static Future<String> _context(S s) async {
    final info = await PackageInfo.fromPlatform();
    final buf = StringBuffer()
      ..writeln('Versi   : ${info.version} (${info.buildNumber})');

    try {
      if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        buf.writeln('HP      : ${a.manufacturer} ${a.model} · Android ${a.version.release}');
      } else if (Platform.isIOS) {
        final i = await DeviceInfoPlugin().iosInfo;
        buf.writeln('HP      : ${i.name} · iOS ${i.systemVersion}');
      }
    } catch (_) {
      // Perangkat tidak terbaca, bagian ini dilewati saja.
    }

    final p = await SharedPreferences.getInstance();
    final mode = p.getString('themeMode') ?? 'system';
    buf.writeln('Tampilan: $mode · Bahasa: ${s.code}');

    final err = await lastErrorSummary();
    if (err != null) {
      buf
        ..writeln('Error terakhir:')
        ..writeln(err);
    }

    return buf.toString().trimRight();
  }

  /// Susun pesannya, lalu buka WhatsApp. Mengembalikan false kalau gagal dibuka.
  static Future<bool> openWhatsApp(S s) async {
    final body = StringBuffer()
      ..writeln(s.t('Masukan Monshika', 'Monshika feedback'))
      ..writeln()
      ..writeln(s.t('Jenis: Bug / Usul / Lainnya', 'Kind: Bug / Idea / Other'))
      ..writeln()
      ..writeln(s.t('Ceritakan di sini:', 'Tell me here:'))
      ..writeln()
      ..writeln()
      ..writeln(s.t('— — — jangan dihapus — — —', '— — — please keep — — —'))
      ..write(await _context(s));

    final uri = Uri.parse('https://wa.me/$waNumber?text=${Uri.encodeComponent(body.toString())}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
