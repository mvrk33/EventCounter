import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../models/event_model.dart';

class ExportService {
  const ExportService();

  Future<File> exportEventsJson(List<EventModel> events) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/daymark_events.json');
    final String payload = jsonEncode(
      events.map((EventModel e) => e.toJson()).toList(growable: false),
    );
    return file.writeAsString(payload, flush: true);
  }

  Future<File> exportEventsCsv(List<EventModel> events) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/daymark_events.csv');

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

  Future<List<EventModel>> importEventsJsonFromDefaultFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/daymark_events.json');
    if (!await file.exists()) {
      return <EventModel>[];
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <EventModel>[];
    }

    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => EventModel.fromJson(e))
        .toList(growable: false);
  }
}
