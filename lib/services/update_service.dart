import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateDownloadError { noApk, network, server }

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.error);
  final UpdateDownloadError error;

  @override
  String toString() => 'UpdateDownloadException($error)';
}

/// Informasi rilis terbaru dari GitHub Releases.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.title,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
    this.apkName,
    this.apkSize = 0,
    this.publishedAt,
  });

  final String version;
  final String tag;
  final String title;
  final String notes;
  final String pageUrl;
  final String? apkUrl;
  final String? apkName;
  final int apkSize;
  final DateTime? publishedAt;

  Map<String, Object?> toJson() => {
        'version': version,
        'tag': tag,
        'title': title,
        'notes': notes,
        'pageUrl': pageUrl,
        'apkUrl': apkUrl,
        'apkName': apkName,
        'apkSize': apkSize,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  static AppRelease fromJson(Map<String, dynamic> j) => AppRelease(
        version: j['version'] as String,
        tag: j['tag'] as String,
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        pageUrl: j['pageUrl'] as String,
        apkUrl: j['apkUrl'] as String?,
        apkName: j['apkName'] as String?,
        apkSize: (j['apkSize'] as num?)?.toInt() ?? 0,
        publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
      );
}

/// Pembaruan aplikasi lewat GitHub Releases (APK di luar Play Store).
abstract final class UpdateService {
  static const repo = 'Irana06/monshika';
  static const releasesPage = 'https://github.com/$repo/releases/latest';
  static const _latestApi = 'https://api.github.com/repos/$repo/releases/latest';
  static const checkEvery = Duration(hours: 6);

  static const _kLastCheck = 'updateLastCheck';
  static const _kCached = 'updateLatestJson';
  static const _kDismissed = 'updateDismissedVersion';
  static const _kNotified = 'updateNotifiedVersion';

  static Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  /// > 0 jika [a] lebih baru dari [b].
  static int compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[.+\-]')).take(3).map((e) => int.tryParse(e) ?? 0).toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static Future<List<String>> _deviceAbis() async {
    if (!Platform.isAndroid) return const [];
    try {
      return (await DeviceInfoPlugin().androidInfo).supportedAbis;
    } catch (_) {
      return const [];
    }
  }

  static Future<AppRelease?> fetchLatest() async {
    final res = await http
        .get(Uri.parse(_latestApi), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = j['tag_name'] as String? ?? '';
    if (tag.isEmpty || j['draft'] == true || j['prerelease'] == true) return null;

    final apks = ((j['assets'] as List?) ?? const [])
        .cast<Map>()
        .map((a) => a.cast<String, dynamic>())
        .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
        .toList();
    Map<String, dynamic>? pick;
    for (final abi in await _deviceAbis()) {
      pick = apks.firstWhereOrNull((a) => (a['name'] as String).contains(abi));
      if (pick != null) break;
    }
    pick ??= apks.firstWhereOrNull((a) => (a['name'] as String).contains('arm64')) ?? apks.firstOrNull;

    return AppRelease(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      tag: tag,
      title: j['name'] as String? ?? tag,
      notes: j['body'] as String? ?? '',
      pageUrl: j['html_url'] as String? ?? releasesPage,
      apkUrl: pick?['browser_download_url'] as String?,
      apkName: pick?['name'] as String?,
      apkSize: (pick?['size'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse(j['published_at'] as String? ?? ''),
    );
  }

  /// Rilis yang lebih baru dari versi terpasang, atau null.
  /// Tanpa [force], hasil di-cache selama [checkEvery].
  static Future<AppRelease?> check({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastCheck);
    final fresh = last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < checkEvery;

    AppRelease? latest;
    if (!force && fresh) {
      final cached = prefs.getString(_kCached);
      if (cached != null) latest = AppRelease.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } else {
      latest = await fetchLatest();
      await prefs.setInt(_kLastCheck, DateTime.now().millisecondsSinceEpoch);
      if (latest != null) await prefs.setString(_kCached, jsonEncode(latest.toJson()));
    }
    if (latest == null) return null;
    return compareVersions(latest.version, await currentVersion()) > 0 ? latest : null;
  }

  static Future<bool> isDismissed(String version) async =>
      (await SharedPreferences.getInstance()).getString(_kDismissed) == version;

  static Future<void> dismiss(String version) async =>
      (await SharedPreferences.getInstance()).setString(_kDismissed, version);

  static Future<bool> wasNotified(String version) async =>
      (await SharedPreferences.getInstance()).getString(_kNotified) == version;

  static Future<void> markNotified(String version) async =>
      (await SharedPreferences.getInstance()).setString(_kNotified, version);

  static const _maxAttempts = 6;
  static const _stallTimeout = Duration(seconds: 30);

  /// Unduh APK ke cache aplikasi. [onProgress] menerima 0..1.
  ///
  /// Koneksi HP sering putus di tengah jalan, jadi unduhan ditulis ke file
  /// `.part` dan dilanjutkan dengan header Range. Kalau putus, dicoba lagi
  /// beberapa kali dari posisi terakhir. Bila tetap gagal, file `.part` disimpan
  /// sehingga ketukan Perbarui berikutnya melanjutkan, bukan mulai dari nol.
  static Future<File> download(AppRelease r, void Function(double progress) onProgress) async {
    final url = r.apkUrl;
    if (url == null) throw const UpdateDownloadException(UpdateDownloadError.noApk);
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${r.apkName ?? 'monshika-${r.version}.apk'}');
    final part = File('${file.path}.part');
    final expected = r.apkSize;

    if (expected > 0 && await file.exists() && await file.length() == expected) {
      onProgress(1);
      return file;
    }

    var attempt = 0;
    while (true) {
      final client = http.Client();
      try {
        var have = await part.exists() ? await part.length() : 0;
        if (expected > 0 && have > expected) {
          await part.delete();
          have = 0;
        }
        if (expected > 0 && have == expected) break;

        final request = http.Request('GET', Uri.parse(url));
        if (have > 0) request.headers['Range'] = 'bytes=$have-';
        final response = await client.send(request).timeout(_stallTimeout);

        final IOSink sink;
        var received = have;
        if (response.statusCode == 206) {
          sink = part.openWrite(mode: FileMode.append);
        } else if (response.statusCode == 200) {
          received = 0;
          sink = part.openWrite();
        } else if (response.statusCode == 416 && have > 0) {
          // Server bilang tidak ada sisa data: anggap selesai bila ukurannya cocok, kalau tidak ulang dari nol.
          if (expected <= 0 || have == expected) break;
          await part.delete();
          throw const SocketException('range mismatch');
        } else if (response.statusCode >= 500) {
          throw SocketException('HTTP ${response.statusCode}');
        } else {
          throw const UpdateDownloadException(UpdateDownloadError.server);
        }

        final total = expected > 0 ? expected : received + (response.contentLength ?? 0);
        try {
          await for (final chunk in response.stream.timeout(_stallTimeout)) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) onProgress((received / total).clamp(0, 1).toDouble());
          }
        } finally {
          await sink.close();
        }
        if (expected > 0 && received != expected) throw const SocketException('incomplete download');
        break;
      } on UpdateDownloadException {
        rethrow;
      } catch (_) {
        if (++attempt >= _maxAttempts) throw const UpdateDownloadException(UpdateDownloadError.network);
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      } finally {
        client.close();
      }
    }

    if (await file.exists()) await file.delete();
    return part.rename(file.path);
  }

  /// Buka installer Android. Mengembalikan pesan error, atau null bila berhasil.
  static Future<String?> install(File apk) async {
    final result = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    return result.type == ResultType.done ? null : result.message;
  }

  static Future<void> openInBrowser([AppRelease? r]) =>
      launchUrl(Uri.parse(r?.pageUrl ?? releasesPage), mode: LaunchMode.externalApplication);

  /// Ubah markdown catatan rilis menjadi teks sederhana.
  static String plainNotes(String markdown) => markdown
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('|'))
      .map((l) => l
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceFirst(RegExp(r'^>\s*'), '')
          .replaceAll('**', '')
          .replaceAll('`', ''))
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
