import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();

  static final instance = SecurityService._();

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  static const _pinKey = 'monshika_pin_hash';
  static const _saltKey = 'monshika_pin_salt';

  Future<String> _hash(String pin, List<int> salt) async {
    final algo = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 60000, bits: 256);
    final key = await algo.deriveKeyFromPassword(password: pin, nonce: salt);
    return base64Encode(await key.extractBytes());
  }

  Future<bool> hasPin() async => (await _storage.read(key: _pinKey)) != null;

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _pinKey, value: await _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    final salt = await _storage.read(key: _saltKey);
    if (stored == null || salt == null) return false;
    return stored == await _hash(pin, base64Decode(salt));
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _saltKey);
  }

  static const _backupPasswordKey = 'monshika_backup_password';

  /// Sandi enkripsi file backup (disimpan terenkripsi oleh Keystore/Keychain).
  Future<String?> getBackupPassword() => _storage.read(key: _backupPasswordKey);

  Future<void> setBackupPassword(String? password) => password == null || password.isEmpty
      ? _storage.delete(key: _backupPasswordKey)
      : _storage.write(key: _backupPasswordKey, value: password);

  Future<bool> canUseBiometric() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka Monshika',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
