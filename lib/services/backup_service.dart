import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/database.dart';

class BackupPasswordRequired implements Exception {
  const BackupPasswordRequired();
}

class BackupWrongPassword implements Exception {
  const BackupWrongPassword();
}

class BackupInvalid implements Exception {
  const BackupInvalid([this.message = 'File backup tidak valid']);
  final String message;

  @override
  String toString() => message;
}

class BackupInfo {
  const BackupInfo({required this.createdAt, required this.transactions, required this.accounts});
  final DateTime createdAt;
  final int transactions;
  final int accounts;
}

/// Format file `.msk`:
///   `MSK1P` + gzip(json)                                   (tanpa sandi)
///   `MSK1E` + salt(16) + nonce(12) + mac(16) + aesgcm(gzip(json))
class BackupService {
  static const _plain = 'MSK1P';
  static const _enc = 'MSK1E';
  static const extension = 'msk';

  static const _settingKeys = [
    'userName', 'baseCurrency', 'monthStartDay', 'firstWeekday', 'hideOnWidget', 'dailyReminder',
    'reminderHour', 'reminderMinute', 'budgetAlerts', 'billReminders', 'hankoAnimation', 'seasonalMotif',
    'kakeiboMode', 'haptics', 'defaultAccountId',
  ];

  static final _algo = AesGcm.with256bits();

  static Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> create(AppDatabase db, {String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, Object?>{for (final k in _settingKeys) k: prefs.get(k)};
    final payload = {
      'app': 'monshika',
      'format': 1,
      'schema': db.schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'db': await db.exportAll(),
    };
    final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
    final out = BytesBuilder();
    if (password == null || password.isEmpty) {
      out.add(ascii.encode(_plain));
      out.add(compressed);
      return out.toBytes();
    }
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final nonce = _algo.newNonce();
    final key = await _deriveKey(password, salt);
    final box = await _algo.encrypt(compressed, secretKey: key, nonce: nonce);
    out
      ..add(ascii.encode(_enc))
      ..add(salt)
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return out.toBytes();
  }

  static bool isEncrypted(Uint8List bytes) =>
      bytes.length > 5 && ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == _enc;

  static Future<Map<String, dynamic>> read(Uint8List bytes, {String? password}) async {
    if (bytes.length < 6) throw const BackupInvalid();
    final header = ascii.decode(bytes.sublist(0, 5), allowInvalid: true);
    List<int> compressed;
    if (header == _plain) {
      compressed = bytes.sublist(5);
    } else if (header == _enc) {
      if (password == null || password.isEmpty) throw const BackupPasswordRequired();
      final salt = bytes.sublist(5, 21);
      final nonce = bytes.sublist(21, 33);
      final mac = bytes.sublist(33, 49);
      final cipher = bytes.sublist(49);
      final key = await _deriveKey(password, salt);
      try {
        compressed = await _algo.decrypt(SecretBox(cipher, nonce: nonce, mac: Mac(mac)), secretKey: key);
      } on SecretBoxAuthenticationError {
        throw const BackupWrongPassword();
      }
    } else {
      throw const BackupInvalid();
    }
    final json = jsonDecode(utf8.decode(gzip.decode(compressed))) as Map<String, dynamic>;
    if (json['app'] != 'monshika') throw const BackupInvalid('Bukan file backup Monshika');
    return json;
  }

  static BackupInfo info(Map<String, dynamic> json) {
    final data = (json['db'] as Map).cast<String, dynamic>();
    return BackupInfo(
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      transactions: (data['transactions'] as List?)?.length ?? 0,
      accounts: (data['accounts'] as List?)?.length ?? 0,
    );
  }

  static Future<void> restore(AppDatabase db, Map<String, dynamic> json) async {
    await db.importAll((json['db'] as Map).cast<String, dynamic>());
    final prefs = await SharedPreferences.getInstance();
    final settings = (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final e in settings.entries) {
      final v = e.value;
      switch (v) {
        case bool b:
          await prefs.setBool(e.key, b);
        case int i:
          await prefs.setInt(e.key, i);
        case double d:
          await prefs.setDouble(e.key, d);
        case String s:
          await prefs.setString(e.key, s);
      }
    }
    await prefs.setBool('onboardingDone', true);
  }

  static String fileName([DateTime? at]) {
    final d = at ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'monshika-${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}.$extension';
  }
}
