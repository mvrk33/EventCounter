import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/pin_security_service.dart';
import '../models/event_model.dart';

class ExportService {
  const ExportService();

  static const List<String> _csvHeader = <String>[
    'id',
    'title',
    'date',
    'category',
    'color',
    'emoji',
    'notes',
    'mode',
    'countUnit',
    'isPinned',
    'reminderDays',
    'createdAt',
    'updatedAt',
  ];

  Future<File> exportEventsJson(
    List<EventModel> events, {
    PinSecurityService? security,
    String? passphraseForBackup,
  }) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/event_counter_events.json');
    final String payload = jsonEncode(
      events.map((EventModel e) => e.toJson()).toList(growable: false),
    );

    // Passphrase-based encryption (portable, cross-device)
    if (passphraseForBackup != null &&
        passphraseForBackup.isNotEmpty &&
        security != null &&
        security.isPassphraseBackupEncryptionEnabled) {
      final String? salt = security.passphraseBackupSalt;
      if (salt != null) {
        final Map<String, String>? encrypted =
            await security.encryptStringWithPassphrase(
          payload,
          passphraseForBackup,
          salt: salt,
        );
        if (encrypted != null) {
          final String wrapped = jsonEncode(<String, dynamic>{
            'encrypted': true,
            'version': 2,
            'type': 'passphrase',
            'salt': salt,
            'payload': encrypted,
          });
          return file.writeAsString(wrapped, flush: true);
        }
      }
    }

    // Device-key encryption (local only)
    if (security != null && security.isLocalBackupEncryptionEnabled) {
      final Map<String, String>? encrypted =
          await security.encryptString(payload);
      if (encrypted != null) {
        final String wrapped = jsonEncode(<String, dynamic>{
          'encrypted': true,
          'version': 1,
          'payload': encrypted,
        });
        return file.writeAsString(wrapped, flush: true);
      }
    }

    return file.writeAsString(payload, flush: true);
  }

  Future<File> exportEventsCsv(List<EventModel> events) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/event_counter_events.csv');

    final List<List<dynamic>> rows = <List<dynamic>>[
      <String>[
        'id',
        'title',
        'date',
        'category',
        'color',
        'emoji',
        'notes',
        'mode',
        'countUnit',
        'isPinned',
        'reminderDays',
        'createdAt',
        'updatedAt',
      ],
      ...events.map((EventModel e) => <dynamic>[
            e.id,
            e.title,
            e.date.toIso8601String(),
            e.category,
            e.color,
            e.emoji,
            e.notes,
            e.mode.name,
            e.countUnit.name,
            e.isPinned,
            e.reminderDays.join('|'),
            e.createdAt.toIso8601String(),
            e.updatedAt.toIso8601String(),
          ]),
    ];

    final String csv = const ListToCsvConverter().convert(rows);
    return file.writeAsString(csv, flush: true);
  }

  Future<List<EventModel>> importEventsJsonFromDefaultFile({
    PinSecurityService? security,
  }) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/event_counter_events.json');
    if (!await file.exists()) {
      return <EventModel>[];
    }

    final String raw = await file.readAsString();
    return parseEventsFromBackupRaw(raw, security: security);
  }

  Future<List<EventModel>> importEventsJsonFromPicker({
    PinSecurityService? security,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return <EventModel>[];
    }

    final PlatformFile picked = result.files.single;
    final String? path = picked.path;
    final String raw;
    if (picked.bytes != null) {
      raw = utf8.decode(picked.bytes!, allowMalformed: true);
    } else if (path != null && path.isNotEmpty) {
      raw = await File(path).readAsString();
    } else {
      return <EventModel>[];
    }

    return parseEventsFromBackupRaw(raw, security: security);
  }

  Future<List<EventModel>> parseEventsFromBackupRaw(
    String raw, {
    PinSecurityService? security,
  }) async {
    if (raw.trim().isEmpty) {
      return <EventModel>[];
    }

    final List<EventModel> parsedFromJson =
        await _tryParseFromJson(raw, security: security);
    if (parsedFromJson.isNotEmpty) {
      return parsedFromJson;
    }

    return _tryParseFromCsv(raw);
  }

  Future<List<EventModel>> _tryParseFromJson(
    String raw, {
    PinSecurityService? security,
    String? passphraseForRestore,
  }) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <EventModel>[];
    }

    if (decoded is List<dynamic>) {
      return _modelsFromDynamicList(decoded);
    }

    if (decoded is! Map) {
      return <EventModel>[];
    }

    final Map<String, dynamic> map = _mapToStringDynamic(decoded);
    if (_looksEncryptedPayload(map)) {
      return _parseEncryptedJson(
        map,
        security: security,
        passphraseForRestore: passphraseForRestore,
      );
    }

    final dynamic eventsNode = map['events'] ?? map['data'] ?? map['items'];
    if (eventsNode is List<dynamic>) {
      return _modelsFromDynamicList(eventsNode);
    }

    if (_looksLikeEventMap(map)) {
      return <EventModel>[EventModel.fromJson(map)];
    }

    return <EventModel>[];
  }

  Future<List<EventModel>> _parseEncryptedJson(
    Map<String, dynamic> decoded, {
    PinSecurityService? security,
    String? passphraseForRestore,
  }) async {
    if (security == null) {
      return <EventModel>[];
    }

    final dynamic payloadNode = decoded['payload'];
    final Map<String, dynamic>? payload = payloadNode is Map
        ? _mapToStringDynamic(payloadNode)
        : (_looksRawCipherMap(decoded) ? decoded : null);
    if (payload == null) {
      return <EventModel>[];
    }

    // Try passphrase-based decryption first (version 2)
    final int version = (decoded['version'] as num?)?.toInt() ?? 1;
    if (version == 2 &&
        decoded['type'] == 'passphrase' &&
        passphraseForRestore != null &&
        passphraseForRestore.isNotEmpty) {
      final String? salt = decoded['salt']?.toString();
      if (salt != null && salt.isNotEmpty) {
        final String? clear = await security.decryptStringWithPassphrase(
          payload,
          passphraseForRestore,
          salt: salt,
        );
        if (clear != null && clear.trim().isNotEmpty) {
          return _tryParseFromJson(clear, security: security);
        }
        return <EventModel>[];
      }
    }

    // Fall back to device-key decryption (version 1)
    final String? clear = await security.decryptString(payload);
    if (clear == null || clear.trim().isEmpty) {
      return <EventModel>[];
    }

    return _tryParseFromJson(clear, security: security);
  }

  List<EventModel> _tryParseFromCsv(String raw) {
    List<List<dynamic>> rows;
    try {
      final String normalized = raw.replaceAll('\r\n', '\n').trim();
      rows = const CsvToListConverter(eol: '\n').convert(normalized);
    } on FormatException {
      try {
        rows = const CsvToListConverter().convert(raw);
      } on FormatException {
        return <EventModel>[];
      }
    }

    if (rows.length < 2) {
      return <EventModel>[];
    }

    final List<String> header =
        rows.first.map((dynamic e) => e.toString().trim()).toList();
    if (!_matchesCsvHeader(header)) {
      return <EventModel>[];
    }

    final List<EventModel> imported = <EventModel>[];
    for (final List<dynamic> row in rows.skip(1)) {
      if (row.every((dynamic value) => value.toString().trim().isEmpty)) {
        continue;
      }
      final Map<String, dynamic> item = <String, dynamic>{
        'id': _csvValue(row, header, 'id'),
        'title': _csvValue(row, header, 'title'),
        'date': _csvValue(row, header, 'date'),
        'category': _csvValue(row, header, 'category'),
        'color': _parseInt(_csvValue(row, header, 'color')),
        'emoji': _csvValue(row, header, 'emoji'),
        'notes': _csvValue(row, header, 'notes'),
        'mode': _csvValue(row, header, 'mode'),
        'countUnit': _csvValue(row, header, 'countUnit'),
        'isPinned': _parseBool(_csvValue(row, header, 'isPinned')),
        'reminderDays':
            _parseReminderDays(_csvValue(row, header, 'reminderDays')),
        'createdAt': _csvValue(row, header, 'createdAt'),
        'updatedAt': _csvValue(row, header, 'updatedAt'),
      };
      imported.add(EventModel.fromJson(item));
    }

    return imported;
  }

  List<EventModel> _modelsFromDynamicList(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((Map<dynamic, dynamic> e) =>
            EventModel.fromJson(_mapToStringDynamic(e)))
        .toList(growable: false);
  }

  bool _looksEncryptedPayload(Map<String, dynamic> decoded) {
    if (decoded['encrypted'] == true) {
      return true;
    }
    final dynamic payload = decoded['payload'];
    if (payload is Map && _looksRawCipherMap(_mapToStringDynamic(payload))) {
      return true;
    }
    return _looksRawCipherMap(decoded);
  }

  bool _looksRawCipherMap(Map<String, dynamic> map) {
    return map.containsKey('nonce') &&
        map.containsKey('ciphertext') &&
        map.containsKey('mac');
  }

  bool _looksLikeEventMap(Map<String, dynamic> map) {
    return map.containsKey('id') &&
        map.containsKey('title') &&
        map.containsKey('date');
  }

  bool _matchesCsvHeader(List<String> header) {
    if (header.length != _csvHeader.length) {
      return false;
    }
    for (int i = 0; i < header.length; i++) {
      if (header[i] != _csvHeader[i]) {
        return false;
      }
    }
    return true;
  }

  String _csvValue(List<dynamic> row, List<String> header, String column) {
    final int index = header.indexOf(column);
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].toString();
  }

  int _parseInt(String value) {
    return int.tryParse(value) ?? 0xFF2196F3;
  }

  bool _parseBool(String value) {
    final String normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  List<int> _parseReminderDays(String raw) {
    if (raw.trim().isEmpty) {
      return <int>[];
    }
    return raw
        .split('|')
        .map((String part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  Map<String, dynamic> _mapToStringDynamic(Map<dynamic, dynamic> map) {
    return map.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }
}
