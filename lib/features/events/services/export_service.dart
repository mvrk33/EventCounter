import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/pin_security_service.dart';
import '../models/event_model.dart';

class ExportService {
  const ExportService();

  Future<File> exportEventsJson(
    List<EventModel> events, {
    PinSecurityService? security,
  }) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/event_counter_events.json');
    final String payload = jsonEncode(
      events.map((EventModel e) => e.toJson()).toList(growable: false),
    );

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
    if (raw.trim().isEmpty) {
      return <EventModel>[];
    }

    final dynamic decoded = jsonDecode(raw);
    List<dynamic> list;

    if (decoded is Map<String, dynamic> && decoded['encrypted'] == true) {
      final dynamic payload = decoded['payload'];
      if (payload is! Map<String, dynamic> || security == null) {
        return <EventModel>[];
      }
      final String? clear = await security.decryptString(payload);
      if (clear == null || clear.trim().isEmpty) {
        return <EventModel>[];
      }
      final dynamic clearDecoded = jsonDecode(clear);
      if (clearDecoded is! List<dynamic>) {
        return <EventModel>[];
      }
      list = clearDecoded;
    } else if (decoded is List<dynamic>) {
      list = decoded;
    } else {
      return <EventModel>[];
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => EventModel.fromJson(e))
        .toList(growable: false);
  }
}
