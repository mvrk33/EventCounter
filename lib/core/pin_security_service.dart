import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hive_boxes.dart';

/// Derives encryption key from a passphrase using PBKDF2.
/// Returns the base64-encoded derived key (32 bytes).
Future<String> deriveKeyFromPassphrase(
  String passphrase, {
  required String salt,
  int iterations = 100000,
}) async {
  final List<int> passphraseBytes = utf8.encode(passphrase);
  final List<int> saltBytes = utf8.encode(salt);

  final Pbkdf2 pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac(Sha256()),
    iterations: iterations,
    bits: 256,
  );

  final SecretKey derivedKey = await pbkdf2.deriveKey(
    secretKey: SecretKey(passphraseBytes),
    nonce: saltBytes,
  );

  return base64Encode(await derivedKey.extractBytes());
}

final Provider<PinSecurityService> pinSecurityServiceProvider =
    Provider<PinSecurityService>((Ref ref) {
  return PinSecurityService(
    settingsBox: Hive.isBoxOpen(HiveBoxes.settings)
        ? Hive.box<dynamic>(HiveBoxes.settings)
        : null,
  );
});

class PinSecurityService {
  PinSecurityService({required Box<dynamic>? settingsBox})
      : _settingsBox = settingsBox;

  final Box<dynamic>? _settingsBox;
  final Cipher _cipher = AesGcm.with256bits();

  static const String _keyKey = 'security_key_b64_v1';
  static const String _appLockKey = 'security_app_lock_enabled_v1';

  // Encryption is always on — these getters kept for backward compat with
  // export_service.dart and sync_service.dart which check them.
  bool get isLocalBackupEncryptionEnabled => true;
  bool get isCloudBackupEncryptionEnabled => true;

  // App lock via system biometrics / device credential.
  bool get isAppLockEnabled {
    return (_settingsBox?.get(_appLockKey) as bool?) ?? false;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    if (_settingsBox == null) return;
    await _settingsBox.put(_appLockKey, enabled);
  }

  Future<void> ensureEncryptionKey() async {
    if (_settingsBox == null) return;
    if (_currentKeyBytes() != null) return;
    await _settingsBox.put(_keyKey, base64Encode(_randomBytes(32)));
  }

  Future<Map<String, String>?> encryptJson(Map<String, dynamic> json) async {
    await ensureEncryptionKey();
    final List<int>? key = _currentKeyBytes();
    if (key == null) return null;

    final List<int> nonce = _randomBytes(12);
    final SecretBox box = await _cipher.encrypt(
      utf8.encode(jsonEncode(json)),
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    return <String, String>{
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>?> decryptJson(
      Map<String, dynamic> payload) async {
    final List<int>? key = _currentKeyBytes();
    if (key == null) return null;

    try {
      final String nonceRaw = (payload['nonce'] ?? '').toString();
      final String cipherRaw = (payload['ciphertext'] ?? '').toString();
      final String macRaw = (payload['mac'] ?? '').toString();
      if (nonceRaw.isEmpty || cipherRaw.isEmpty || macRaw.isEmpty) return null;

      final SecretBox box = SecretBox(
        base64Decode(cipherRaw),
        nonce: base64Decode(nonceRaw),
        mac: Mac(base64Decode(macRaw)),
      );
      final List<int> clear = await _cipher.decrypt(
        box,
        secretKey: SecretKey(key),
      );
      final dynamic decoded = jsonDecode(utf8.decode(clear));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> encryptString(String clearText) async {
    await ensureEncryptionKey();
    final List<int>? key = _currentKeyBytes();
    if (key == null) return null;

    final List<int> nonce = _randomBytes(12);
    final SecretBox box = await _cipher.encrypt(
      utf8.encode(clearText),
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    return <String, String>{
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<String?> decryptString(Map<String, dynamic> payload) async {
    final List<int>? key = _currentKeyBytes();
    if (key == null) return null;

    try {
      final String nonceRaw = (payload['nonce'] ?? '').toString();
      final String cipherRaw = (payload['ciphertext'] ?? '').toString();
      final String macRaw = (payload['mac'] ?? '').toString();
      if (nonceRaw.isEmpty || cipherRaw.isEmpty || macRaw.isEmpty) return null;
      final SecretBox box = SecretBox(
        base64Decode(cipherRaw),
        nonce: base64Decode(nonceRaw),
        mac: Mac(base64Decode(macRaw)),
      );
      final List<int> clear = await _cipher.decrypt(
        box,
        secretKey: SecretKey(key),
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  // Kept for import backward-compat with old passphrase-encrypted backups.
  bool get isPassphraseBackupEncryptionEnabled => false;
  String? get passphraseBackupSalt => null;

  Future<Map<String, String>?> encryptStringWithPassphrase(
    String clearText,
    String passphrase, {
    required String salt,
  }) async {
    final String derivedKeyB64 =
        await deriveKeyFromPassphrase(passphrase, salt: salt);
    final List<int> keyBytes = base64Decode(derivedKeyB64);

    final List<int> nonce = _randomBytes(12);
    final SecretBox box = await _cipher.encrypt(
      utf8.encode(clearText),
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );

    return <String, String>{
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<String?> decryptStringWithPassphrase(
    Map<String, dynamic> payload,
    String passphrase, {
    required String salt,
  }) async {
    try {
      final String derivedKeyB64 =
          await deriveKeyFromPassphrase(passphrase, salt: salt);
      final List<int> keyBytes = base64Decode(derivedKeyB64);

      final String nonceRaw = (payload['nonce'] ?? '').toString();
      final String cipherRaw = (payload['ciphertext'] ?? '').toString();
      final String macRaw = (payload['mac'] ?? '').toString();
      if (nonceRaw.isEmpty || cipherRaw.isEmpty || macRaw.isEmpty) return null;

      final SecretBox box = SecretBox(
        base64Decode(cipherRaw),
        nonce: base64Decode(nonceRaw),
        mac: Mac(base64Decode(macRaw)),
      );
      final List<int> clear = await _cipher.decrypt(
        box,
        secretKey: SecretKey(keyBytes),
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  List<int>? _currentKeyBytes() {
    final String? raw = _settingsBox?.get(_keyKey) as String?;
    if (raw == null || raw.isEmpty) return null;
    return base64Decode(raw);
  }

  List<int> _randomBytes(int length) {
    final Random random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256),
        growable: false);
  }
}
