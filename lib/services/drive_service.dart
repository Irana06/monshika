import 'dart:async';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../config/google_config.dart';

class DriveBackupFile {
  const DriveBackupFile({required this.id, required this.name, required this.size, required this.createdAt});
  final String id;
  final String name;
  final int size;
  final DateTime createdAt;
}

class DriveNotConfigured implements Exception {
  @override
  String toString() => 'Google Client ID belum dikonfigurasi (lihat lib/config/google_config.dart).';
}

/// Backup ke folder tersembunyi khusus aplikasi di Google Drive (appDataFolder).
/// Scope `drive.appdata` bersifat non-sensitif: aplikasi tidak bisa melihat
/// file lain di Drive pengguna.
class DriveService {
  DriveService._();

  static final instance = DriveService._();

  static const scopes = [drive.DriveApi.driveAppdataScope];
  static const keepLatest = 15;

  final _signIn = GoogleSignIn.instance;
  Future<void>? _init;
  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;

  Future<void> _ensureInit() {
    if (!GoogleConfig.isConfigured) throw DriveNotConfigured();
    return _init ??= _signIn.initialize(
      clientId: GoogleConfig.iosClientId.isEmpty ? null : GoogleConfig.iosClientId,
      serverClientId: GoogleConfig.webClientId,
    );
  }

  /// Login interaktif + minta izin Drive. Harus dipanggil dari aksi pengguna.
  Future<GoogleSignInAccount> signIn() async {
    await _ensureInit();
    final acc = await _signIn.authenticate(scopeHint: scopes);
    await acc.authorizationClient.authorizeScopes(scopes);
    _account = acc;
    return acc;
  }

  /// Coba login diam-diam (tanpa UI). Null bila tidak bisa.
  Future<GoogleSignInAccount?> silentSignIn() async {
    if (_account != null) return _account;
    try {
      await _ensureInit();
      final future = _signIn.attemptLightweightAuthentication();
      if (future == null) return null;
      _account = await future.timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
    return _account;
  }

  Future<void> signOut() async {
    try {
      await _ensureInit();
      await _signIn.disconnect();
    } catch (_) {}
    _account = null;
  }

  Future<drive.DriveApi> _api({bool interactive = false}) async {
    var acc = await silentSignIn();
    if (acc == null && interactive) acc = await signIn();
    if (acc == null) throw StateError('Belum login Google');
    var authz = await acc.authorizationClient.authorizationForScopes(scopes);
    if (authz == null && interactive) authz = await acc.authorizationClient.authorizeScopes(scopes);
    if (authz == null) throw StateError('Izin Google Drive belum diberikan');
    return drive.DriveApi(authz.authClient(scopes: scopes));
  }

  Future<DriveBackupFile> upload(Uint8List bytes, String name, {bool interactive = false}) async {
    final api = await _api(interactive: interactive);
    final meta = drive.File()
      ..name = name
      ..parents = ['appDataFolder']
      ..mimeType = 'application/octet-stream';
    final created = await api.files.create(
      meta,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      $fields: 'id,name,size,createdTime',
    );
    unawaited(_prune(api));
    return DriveBackupFile(
      id: created.id!,
      name: created.name ?? name,
      size: int.tryParse(created.size ?? '') ?? bytes.length,
      createdAt: created.createdTime ?? DateTime.now(),
    );
  }

  Future<List<DriveBackupFile>> list({bool interactive = false}) async {
    final api = await _api(interactive: interactive);
    return _list(api);
  }

  Future<List<DriveBackupFile>> _list(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
      pageSize: 100,
      $fields: 'files(id,name,size,createdTime)',
    );
    return (res.files ?? const [])
        .map((f) => DriveBackupFile(
              id: f.id!,
              name: f.name ?? '-',
              size: int.tryParse(f.size ?? '') ?? 0,
              createdAt: f.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0),
            ))
        .toList();
  }

  Future<void> _prune(drive.DriveApi api) async {
    try {
      final files = await _list(api);
      for (final f in files.skip(keepLatest)) {
        await api.files.delete(f.id);
      }
    } catch (_) {}
  }

  Future<Uint8List> download(String id, {bool interactive = false}) async {
    final api = await _api(interactive: interactive);
    final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  Future<void> delete(String id) async {
    final api = await _api(interactive: true);
    await api.files.delete(id);
  }
}
