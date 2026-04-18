import 'dart:convert';

import 'package:daymark/core/pin_security_service.dart';
import 'package:daymark/features/events/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePinSecurityService extends PinSecurityService {
  _FakePinSecurityService({
    bool mockPassphraseEnabled = false,
    String mockPassphraseSalt = 'fake_salt',
  })  : _mockPassphraseEnabled = mockPassphraseEnabled,
        _mockPassphraseSalt = mockPassphraseSalt,
        super(settingsBox: null);

  final bool _mockPassphraseEnabled;
  final String _mockPassphraseSalt;

  @override
  Future<Map<String, String>?> encryptString(String clearText) async {
    return <String, String>{
      'nonce': 'n',
      'ciphertext': clearText,
      'mac': 'm',
    };
  }

  @override
  Future<String?> decryptString(Map<String, dynamic> payload) async {
    return payload['ciphertext']?.toString();
  }

  @override
  bool get isPassphraseBackupEncryptionEnabled => _mockPassphraseEnabled;

  @override
  String? get passphraseBackupSalt => _mockPassphraseSalt;

  @override
  Future<Map<String, String>?> encryptStringWithPassphrase(
    String clearText,
    String passphrase, {
    required String salt,
  }) async {
    // Fake encryption that just returns the plaintext as ciphertext
    return <String, String>{
      'nonce': 'n_pass',
      'ciphertext': clearText,
      'mac': 'm_pass',
    };
  }

  @override
  Future<String?> decryptStringWithPassphrase(
    Map<String, dynamic> payload,
    String passphrase, {
    required String salt,
  }) async {
    // Fake decryption that returns ciphertext as plaintext if passphrase is correct
    if (passphrase == 'correct_pass') {
      return payload['ciphertext']?.toString();
    }
    return null; // Wrong passphrase
  }
}

void main() {
  group('ExportService backup parsing', () {
    const ExportService service = ExportService();

    Map<String, dynamic> sampleEventJson() {
      return <String, dynamic>{
        'id': 'e1',
        'title': 'Birthday',
        'date': '2026-04-20T00:00:00.000',
        'category': 'Personal',
        'color': 4280391411,
        'emoji': '🎂',
        'notes': 'Cake day',
        'mode': 'countdown',
        'countUnit': 'days',
        'isPinned': true,
        'reminderDays': <int>[1, 3],
        'createdAt': '2026-04-01T10:00:00.000',
        'updatedAt': '2026-04-10T10:00:00.000',
      };
    }

    test('parses plain JSON list backup', () async {
      final String raw = jsonEncode(<Map<String, dynamic>>[sampleEventJson()]);

      final parsed = await service.parseEventsFromBackupRaw(raw);

      expect(parsed, hasLength(1));
      expect(parsed.first.title, 'Birthday');
    });

    test('parses encrypted JSON wrapper backup', () async {
      final _FakePinSecurityService security = _FakePinSecurityService();
      final String clearPayload =
          jsonEncode(<Map<String, dynamic>>[sampleEventJson()]);
      final String raw = jsonEncode(<String, dynamic>{
        'encrypted': true,
        'version': 1,
        'payload': <String, String>{
          'nonce': 'n',
          'ciphertext': clearPayload,
          'mac': 'm',
        },
      });

      final parsed =
          await service.parseEventsFromBackupRaw(raw, security: security);

      expect(parsed, hasLength(1));
      expect(parsed.first.id, 'e1');
    });

    test('parses passphrase-encrypted JSON backup', () async {
      final _FakePinSecurityService security =
          _FakePinSecurityService(mockPassphraseEnabled: true);
      final String clearPayload =
          jsonEncode(<Map<String, dynamic>>[sampleEventJson()]);
      final String raw = jsonEncode(<String, dynamic>{
        'encrypted': true,
        'version': 2,
        'type': 'passphrase',
        'salt': 'fake_salt',
        'payload': <String, String>{
          'nonce': 'n_pass',
          'ciphertext': clearPayload,
          'mac': 'm_pass',
        },
      });

      final parsed = await service.parseEventsFromBackupRaw(
        raw,
        security: security,
        passphraseForRestore: 'correct_pass',
      );

      expect(parsed, hasLength(1));
      expect(parsed.first.id, 'e1');
    });

    test('rejects passphrase-encrypted backup with wrong passphrase', () async {
      final _FakePinSecurityService security =
          _FakePinSecurityService(mockPassphraseEnabled: true);
      final String clearPayload =
          jsonEncode(<Map<String, dynamic>>[sampleEventJson()]);
      final String raw = jsonEncode(<String, dynamic>{
        'encrypted': true,
        'version': 2,
        'type': 'passphrase',
        'salt': 'fake_salt',
        'payload': <String, String>{
          'nonce': 'n_pass',
          'ciphertext': clearPayload,
          'mac': 'm_pass',
        },
      });

      final parsed = await service.parseEventsFromBackupRaw(
        raw,
        security: security,
        passphraseForRestore: 'wrong_pass',
      );

      expect(parsed, isEmpty);
    });

    test('parses CSV backup', () async {
      final String csv =
          'id,title,date,category,color,emoji,notes,mode,countUnit,isPinned,reminderDays,createdAt,updatedAt\n'
          'e1,Birthday,2026-04-20T00:00:00.000,Personal,4280391411,🎂,Cake day,countdown,days,true,1|3,2026-04-01T10:00:00.000,2026-04-10T10:00:00.000\n';

      final parsed = await service.parseEventsFromBackupRaw(csv);

      expect(parsed, hasLength(1));
      expect(parsed.first.reminderDays, <int>[1, 3]);
      expect(parsed.first.isPinned, isTrue);
    });
  });

  group('PinSecurityService defaults', () {
    test('local backup encryption is enabled by default', () {
      final PinSecurityService security = PinSecurityService(settingsBox: null);

      expect(security.isLocalBackupEncryptionEnabled, isTrue);
    });

    test('passphrase backup encryption is disabled by default', () {
      final PinSecurityService security = PinSecurityService(settingsBox: null);

      expect(security.isPassphraseBackupEncryptionEnabled, isFalse);
    });
  });

  group('PinSecurityService passphrase encryption', () {
    test('encryptStringWithPassphrase and decryptStringWithPassphrase work',
        () async {
      final security = PinSecurityService(settingsBox: null);
      const String clearText = 'Hello, passphrase-protected backup!';
      const String passphrase = 'my_secure_passphrase';
      const String salt = 'my_unique_salt';

      final Map<String, String>? encrypted =
          await security.encryptStringWithPassphrase(
        clearText,
        passphrase,
        salt: salt,
      );

      expect(encrypted, isNotNull);
      expect(encrypted, containsPair('nonce', anything));
      expect(encrypted, containsPair('ciphertext', anything));
      expect(encrypted, containsPair('mac', anything));

      final String? decrypted = await security.decryptStringWithPassphrase(
        encrypted!,
        passphrase,
        salt: salt,
      );

      expect(decrypted, clearText);
    });

    test('decryptStringWithPassphrase fails with wrong passphrase', () async {
      final security = PinSecurityService(settingsBox: null);
      const String clearText = 'Secret data';
      const String passphrase = 'correct_passphrase';
      const String salt = 'salt123';

      final Map<String, String>? encrypted =
          await security.encryptStringWithPassphrase(
        clearText,
        passphrase,
        salt: salt,
      );

      final String? decrypted = await security.decryptStringWithPassphrase(
        encrypted!,
        'wrong_passphrase',
        salt: salt,
      );

      expect(decrypted, isNull);
    });
  });
}
