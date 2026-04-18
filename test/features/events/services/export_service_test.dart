import 'dart:convert';

import 'package:daymark/core/pin_security_service.dart';
import 'package:daymark/features/events/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePinSecurityService extends PinSecurityService {
  _FakePinSecurityService() : super(settingsBox: null);

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
  });
}
