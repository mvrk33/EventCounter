import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum EventMode { countdown, countup }

enum EventCountUnit { days, months, years }

/// Recurrence pattern for an event.
enum EventRecurrence {
  once,
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case EventRecurrence.once:
        return 'One time';
      case EventRecurrence.weekly:
        return 'Every week';
      case EventRecurrence.monthly:
        return 'Every month';
      case EventRecurrence.yearly:
        return 'Every year';
    }
  }

  String get emoji {
    switch (this) {
      case EventRecurrence.once:
        return '🗓️';
      case EventRecurrence.weekly:
        return '🗓️';
      case EventRecurrence.monthly:
        return '📆';
      case EventRecurrence.yearly:
        return '🔁';
    }
  }
}

class EventFields {
  const EventFields._();

  static const String id = 'id';
  static const String title = 'title';
  static const String date = 'date';
  static const String category = 'category';
  static const String color = 'color';
  static const String emoji = 'emoji';
  static const String notes = 'notes';
  static const String mode = 'mode';
  static const String reminderDays = 'reminderDays';
  static const String countUnit = 'countUnit';
  static const String isPinned = 'isPinned';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String recurrence = 'recurrence';
  static const String liveNotification = 'liveNotification';
  static const String mood = 'mood';
  static const String checklist = 'checklist';
  static const String requiresTravel = 'requiresTravel';
  static const String visualTheme = 'visualTheme';
  static const String durationMinutes = 'durationMinutes';
}

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.color,
    required this.emoji,
    required this.notes,
    required this.mode,
    required this.reminderDays,
    required this.countUnit,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.recurrence = EventRecurrence.once,
    this.liveNotification = false,
    this.mood,
    this.checklist = const <String>[],
    this.requiresTravel = false,
    this.visualTheme,
    this.duration,
  });

  final String id;
  final String title;
  final DateTime date;
  final String category;
  final int color;
  final String emoji;
  final String notes;
  final EventMode mode;
  final List<int> reminderDays;
  final EventCountUnit countUnit;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EventRecurrence recurrence;
  /// Whether this event shows a persistent live-progress notification.
  final bool liveNotification;

  /// Predicted mood or energy level (e.g. "High Energy", "Low Energy").
  final String? mood;

  /// A list of tasks recommended for this type of event.
  final List<String> checklist;

  /// Whether this event likely requires travel time.
  final bool requiresTravel;

  /// A keyword or key for an AI-generated or curated background theme.
  final String? visualTheme;

  /// Predicted length of the event.
  final Duration? duration;

  /// For recurring events returns the next future occurrence of this date.
  /// For one-time events returns [date] unchanged.
  DateTime get nextOccurrenceDate {
    if (recurrence == EventRecurrence.once) return date;
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime next = DateTime(date.year, date.month, date.day);
    while (next.isBefore(today)) {
      switch (recurrence) {
        case EventRecurrence.yearly:
          next = DateTime(next.year + 1, next.month, next.day);
          break;
        case EventRecurrence.monthly:
          final int m = next.month == 12 ? 1 : next.month + 1;
          final int y = next.month == 12 ? next.year + 1 : next.year;
          next = DateTime(y, m, next.day);
          break;
        case EventRecurrence.weekly:
          next = next.add(const Duration(days: 7));
          break;
        case EventRecurrence.once:
          return next;
      }
    }
    return next;
  }

  /// Whether this recurring event fires today.
  bool get isToday {
    final DateTime t = nextOccurrenceDate;
    final DateTime now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  EventModel copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? category,
    int? color,
    String? emoji,
    String? notes,
    EventMode? mode,
    List<int>? reminderDays,
    EventCountUnit? countUnit,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    EventRecurrence? recurrence,
    bool? liveNotification,
    String? mood,
    List<String>? checklist,
    bool? requiresTravel,
    String? visualTheme,
    Duration? duration,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      category: category ?? this.category,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      notes: notes ?? this.notes,
      mode: mode ?? this.mode,
      reminderDays: reminderDays ?? this.reminderDays,
      countUnit: countUnit ?? this.countUnit,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recurrence: recurrence ?? this.recurrence,
      liveNotification: liveNotification ?? this.liveNotification,
      mood: mood ?? this.mood,
      checklist: checklist ?? this.checklist,
      requiresTravel: requiresTravel ?? this.requiresTravel,
      visualTheme: visualTheme ?? this.visualTheme,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      EventFields.id: id,
      EventFields.title: title,
      EventFields.date: date,
      EventFields.category: category,
      EventFields.color: color,
      EventFields.emoji: emoji,
      EventFields.notes: notes,
      EventFields.mode: mode.name,
      EventFields.reminderDays: reminderDays,
      EventFields.countUnit: countUnit.name,
      EventFields.isPinned: isPinned,
      EventFields.createdAt: createdAt,
      EventFields.updatedAt: updatedAt,
      EventFields.recurrence: recurrence.name,
      EventFields.liveNotification: liveNotification,
      EventFields.mood: mood,
      EventFields.checklist: checklist,
      EventFields.requiresTravel: requiresTravel,
      EventFields.visualTheme: visualTheme,
      EventFields.durationMinutes: duration?.inMinutes,
    };
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      EventFields.id: id,
      EventFields.title: title,
      EventFields.date: Timestamp.fromDate(date),
      EventFields.category: category,
      EventFields.color: color,
      EventFields.emoji: emoji,
      EventFields.notes: notes,
      EventFields.mode: mode.name,
      EventFields.reminderDays: reminderDays,
      EventFields.countUnit: countUnit.name,
      EventFields.isPinned: isPinned,
      EventFields.createdAt: Timestamp.fromDate(createdAt),
      EventFields.updatedAt: Timestamp.fromDate(updatedAt),
      EventFields.recurrence: recurrence.name,
      EventFields.liveNotification: liveNotification,
      EventFields.mood: mood,
      EventFields.checklist: checklist,
      EventFields.requiresTravel: requiresTravel,
      EventFields.visualTheme: visualTheme,
      EventFields.durationMinutes: duration?.inMinutes,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      EventFields.id: id,
      EventFields.title: title,
      EventFields.date: date.toIso8601String(),
      EventFields.category: category,
      EventFields.color: color,
      EventFields.emoji: emoji,
      EventFields.notes: notes,
      EventFields.mode: mode.name,
      EventFields.reminderDays: reminderDays,
      EventFields.countUnit: countUnit.name,
      EventFields.isPinned: isPinned,
      EventFields.createdAt: createdAt.toIso8601String(),
      EventFields.updatedAt: updatedAt.toIso8601String(),
      EventFields.recurrence: recurrence.name,
      EventFields.liveNotification: liveNotification,
      EventFields.mood: mood,
      EventFields.checklist: checklist,
      EventFields.requiresTravel: requiresTravel,
      EventFields.visualTheme: visualTheme,
      EventFields.durationMinutes: duration?.inMinutes,
    };
  }

  factory EventModel.fromMap(Map<dynamic, dynamic> map) {
    final dynamic modeValue = map[EventFields.mode];
    final List<dynamic> reminderRaw =
        (map[EventFields.reminderDays] as List<dynamic>?) ?? <dynamic>[];

    return EventModel(
      id: (map[EventFields.id] ?? '').toString(),
      title: (map[EventFields.title] ?? '').toString(),
      date: _parseDate(map[EventFields.date]),
      category: (map[EventFields.category] ?? 'Other').toString(),
      color: (map[EventFields.color] as int?) ?? 0xFF2196F3,
      emoji: (map[EventFields.emoji] ?? '🗓️').toString(),
      notes: (map[EventFields.notes] ?? '').toString(),
      mode: _parseMode(modeValue),
      reminderDays: reminderRaw
          .map((dynamic e) => (e as num).toInt())
          .toList(growable: false),
      countUnit: _parseCountUnit(map[EventFields.countUnit]),
      isPinned: (map[EventFields.isPinned] as bool?) ?? false,
      createdAt: _parseDate(map[EventFields.createdAt]),
      updatedAt: _parseDate(map[EventFields.updatedAt]),
      recurrence: _parseRecurrence(map[EventFields.recurrence]),
      liveNotification: (map[EventFields.liveNotification] as bool?) ?? false,
      mood: map[EventFields.mood]?.toString(),
      checklist: (map[EventFields.checklist] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      requiresTravel: (map[EventFields.requiresTravel] as bool?) ?? false,
      visualTheme: map[EventFields.visualTheme]?.toString(),
      duration: map[EventFields.durationMinutes] != null
          ? Duration(minutes: (map[EventFields.durationMinutes] as num).toInt())
          : null,
    );
  }

  factory EventModel.fromFirestore(Map<String, dynamic> map) =>
      EventModel.fromMap(map);

  factory EventModel.fromJson(Map<String, dynamic> json) =>
      EventModel.fromMap(json);

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static EventMode _parseMode(dynamic value) {
    final String mode = (value ?? '').toString().toLowerCase();
    if (mode == EventMode.countup.name) return EventMode.countup;
    return EventMode.countdown;
  }

  static EventCountUnit _parseCountUnit(dynamic value) {
    final String unit = (value ?? '').toString().toLowerCase();
    for (final EventCountUnit item in EventCountUnit.values) {
      if (item.name == unit) return item;
    }
    return EventCountUnit.days;
  }

  static EventRecurrence _parseRecurrence(dynamic value) {
    final String r = (value ?? '').toString().toLowerCase();
    for (final EventRecurrence item in EventRecurrence.values) {
      if (item.name == r) return item;
    }
    return EventRecurrence.once;
  }
}

class EventModelAdapter extends TypeAdapter<EventModel> {
  @override
  final int typeId = 1;

  @override
  EventModel read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return EventModel(
      id: fields[0] as String,
      title: fields[1] as String,
      date: fields[2] as DateTime,
      category: fields[3] as String,
      color: fields[4] as int,
      emoji: fields[5] as String,
      notes: fields[6] as String,
      mode: EventMode.values[fields[7] as int],
      reminderDays: (fields[8] as List).cast<int>(),
      countUnit: fields[11] == null
          ? EventCountUnit.days
          : EventCountUnit.values[fields[11] as int],
      isPinned: (fields[12] as bool?) ?? false,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      // field 13 added in v2 – default for older records
      recurrence: fields[13] == null
          ? EventRecurrence.once
          : EventRecurrence.values[fields[13] as int],
      // field 14 added in v3 – default false for older records
      liveNotification: (fields[14] as bool?) ?? false,
      mood: fields[15] as String?,
      checklist: (fields[16] as List?)?.cast<String>() ?? const <String>[],
      requiresTravel: (fields[17] as bool?) ?? false,
      visualTheme: fields[18] as String?,
      duration: fields[19] == null
          ? null
          : Duration(minutes: fields[19] as int),
    );
  }

  @override
  void write(BinaryWriter writer, EventModel obj) {
    writer
      ..writeByte(20) // total fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.emoji)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.mode.index)
      ..writeByte(8)
      ..write(obj.reminderDays)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.countUnit.index)
      ..writeByte(12)
      ..write(obj.isPinned)
      ..writeByte(13)
      ..write(obj.recurrence.index)
      ..writeByte(14)
      ..write(obj.liveNotification)
      ..writeByte(15)
      ..write(obj.mood)
      ..writeByte(16)
      ..write(obj.checklist)
      ..writeByte(17)
      ..write(obj.requiresTravel)
      ..writeByte(18)
      ..write(obj.visualTheme)
      ..writeByte(19)
      ..write(obj.duration?.inMinutes);
  }
}
