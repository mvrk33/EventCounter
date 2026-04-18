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

  final List<int> derivedKey = await pbkdf2.derive(
    passphraseBytes,
    nonce: saltBytes,
  );

  return base64Encode(derivedKey);
}

enum SecureStorageMode {
  localOnly,
  cloudEncrypted;

  String get label {
    switch (this) {
      case SecureStorageMode.localOnly:
        return 'Local only';
      case SecureStorageMode.cloudEncrypted:
        return 'Cloud encrypted';
    }
  }
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
  static const String _localBackupEncryptionKey =
      'security_local_backup_encryption_v1';
  static const String _cloudBackupEncryptionKey =
      'security_cloud_backup_encryption_v1';
  static const String _passphraseBackupEncryptionKey =
      'security_passphrase_backup_encryption_v1';
  static const String _passphraseBackupSaltKey =
      'security_passphrase_backup_salt_v1';

  // Backward-compatible alias used by older call sites.
  bool get hasPin => false;

  // Backward-compatible alias used by older call sites.
  SecureStorageMode get storageMode {
    return isCloudBackupEncryptionEnabled
        ? SecureStorageMode.cloudEncrypted
        : SecureStorageMode.localOnly;
  }

  bool get isLocalBackupEncryptionEnabled {
    return (_settingsBox?.get(_localBackupEncryptionKey) as bool?) ?? true;
  }

  bool get isCloudBackupEncryptionEnabled {
    return (_settingsBox?.get(_cloudBackupEncryptionKey) as bool?) ?? false;
  }

  bool get isPassphraseBackupEncryptionEnabled {
    return (_settingsBox?.get(_passphraseBackupEncryptionKey) as bool?) ?? false;
  }

  String? get passphraseBackupSalt {
    return (_settingsBox?.get(_passphraseBackupSaltKey) as String?);
  }

  Future<void> setLocalBackupEncryptionEnabled(bool enabled) async {
    if (_settingsBox == null) {
      return;
    }
    if (enabled) {
      await ensureEncryptionKey();
    }
    await _settingsBox.put(_localBackupEncryptionKey, enabled);
  }

  Future<void> setCloudBackupEncryptionEnabled(bool enabled) async {
    if (_settingsBox == null) {
      return;
    }
    if (enabled) {
      await ensureEncryptionKey();
    }
    await _settingsBox.put(_cloudBackupEncryptionKey, enabled);
  }

  Future<void> setPassphraseBackupEncryptionEnabled(
    bool enabled, {
    String? passphrase,
  }) async {
    if (_settingsBox == null) {
      return;
    }
    if (enabled && passphrase != null && passphrase.isNotEmpty) {
      await ensureEncryptionKey();
      final String salt = base64Encode(_randomBytes(16));
      await _settingsBox.put(_passphraseBackupSaltKey, salt);
      await _settingsBox.put(_passphraseBackupEncryptionKey, true);
    } else if (!enabled) {
      await _settingsBox.put(_passphraseBackupEncryptionKey, false);
      await _settingsBox.put(_passphraseBackupSaltKey, null);
    }
  }

  Future<void> ensureEncryptionKey() async {
    if (_settingsBox == null) {
      return;
    }
    if (_currentKeyBytes() != null) {
      return;
    }
    await _settingsBox.put(_keyKey, base64Encode(_randomBytes(32)));
  }

  // Backward-compatible alias used by older call sites.
  Future<void> setStorageMode(SecureStorageMode mode) async {
    await setCloudBackupEncryptionEnabled(
        mode == SecureStorageMode.cloudEncrypted);
  }

  // Backward-compatible no-op for replaced PIN UX.
  Future<void> setPin(String pin) async {
    await ensureEncryptionKey();
  }

  // Backward-compatible no-op for replaced PIN UX.
  Future<bool> verifyPin(String pin) async {
    return true;
  }

  // Backward-compatible no-op for replaced PIN UX.
  Future<void> clearPin() async {
    return;
  }

  Future<Map<String, String>?> encryptJson(Map<String, dynamic> json) async {
    await ensureEncryptionKey();
    final List<int>? key = _currentKeyBytes();
    if (key == null) {
      return null;
    }

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
    if (key == null) {
      return null;
    }

    try {
      final String nonceRaw = (payload['nonce'] ?? '').toString();
      final String cipherRaw = (payload['ciphertext'] ?? '').toString();
      final String macRaw = (payload['mac'] ?? '').toString();
      if (nonceRaw.isEmpty || cipherRaw.isEmpty || macRaw.isEmpty) {
        return null;
      }

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
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> encryptString(String clearText) async {
    await ensureEncryptionKey();
    final List<int>? key = _currentKeyBytes();
    if (key == null) {
      return null;
    }

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
    if (key == null) {
      return null;
    }

    try {
      final String nonceRaw = (payload['nonce'] ?? '').toString();
      final String cipherRaw = (payload['ciphertext'] ?? '').toString();
      final String macRaw = (payload['mac'] ?? '').toString();
      if (nonceRaw.isEmpty || cipherRaw.isEmpty || macRaw.isEmpty) {
        return null;
      }
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

  /// Encrypts a string using a passphrase-derived key (portable backup).
  /// Returns map with nonce, ciphertext, mac (same structure as device-key encryption).
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

  /// Decrypts a string encrypted with passphrase-derived key.
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
      if (nonceRaw.isEmpty || cipherRaw.isEmpty || macRaw.isEmpty) {
        return null;
      }

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
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return base64Decode(raw);
  }

  List<int> _randomBytes(int length) {
    final Random random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256),
        growable: false);
  }
}
