import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HabitFields {
  const HabitFields._();

  static const String id = 'id';
  static const String title = 'title';
  static const String color = 'color';
  static const String emoji = 'emoji';
  static const String checkIns = 'checkIns';
  static const String currentStreak = 'currentStreak';
  static const String longestStreak = 'longestStreak';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

class HabitModel {
  const HabitModel({
    required this.id,
    required this.title,
    required this.color,
    required this.emoji,
    required this.checkIns,
    required this.currentStreak,
    required this.longestStreak,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int color;
  final String emoji;
  final List<DateTime> checkIns;
  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime updatedAt;

  HabitModel copyWith({
    String? id,
    String? title,
    int? color,
    String? emoji,
    List<DateTime>? checkIns,
    int? currentStreak,
    int? longestStreak,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      checkIns: checkIns ?? this.checkIns,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      HabitFields.id: id,
      HabitFields.title: title,
      HabitFields.color: color,
      HabitFields.emoji: emoji,
      HabitFields.checkIns: checkIns,
      HabitFields.currentStreak: currentStreak,
      HabitFields.longestStreak: longestStreak,
      HabitFields.createdAt: createdAt,
      HabitFields.updatedAt: updatedAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      HabitFields.id: id,
      HabitFields.title: title,
      HabitFields.color: color,
      HabitFields.emoji: emoji,
      HabitFields.checkIns: checkIns.map(Timestamp.fromDate).toList(growable: false),
      HabitFields.currentStreak: currentStreak,
      HabitFields.longestStreak: longestStreak,
      HabitFields.createdAt: Timestamp.fromDate(createdAt),
      HabitFields.updatedAt: Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      HabitFields.id: id,
      HabitFields.title: title,
      HabitFields.color: color,
      HabitFields.emoji: emoji,
      HabitFields.checkIns: checkIns.map((DateTime e) => e.toIso8601String()).toList(growable: false),
      HabitFields.currentStreak: currentStreak,
      HabitFields.longestStreak: longestStreak,
      HabitFields.createdAt: createdAt.toIso8601String(),
      HabitFields.updatedAt: updatedAt.toIso8601String(),
    };
  }

  factory HabitModel.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawCheckIns = (map[HabitFields.checkIns] as List<dynamic>?) ?? <dynamic>[];

    return HabitModel(
      id: (map[HabitFields.id] ?? '').toString(),
      title: (map[HabitFields.title] ?? '').toString(),
      color: (map[HabitFields.color] as int?) ?? 0xFF4CAF50,
      emoji: (map[HabitFields.emoji] ?? '✅').toString(),
      checkIns: rawCheckIns.map(_parseDate).toList(growable: false),
      currentStreak: (map[HabitFields.currentStreak] as int?) ?? 0,
      longestStreak: (map[HabitFields.longestStreak] as int?) ?? 0,
      createdAt: _parseDate(map[HabitFields.createdAt]),
      updatedAt: _parseDate(map[HabitFields.updatedAt]),
    );
  }

  factory HabitModel.fromFirestore(Map<String, dynamic> map) {
    return HabitModel.fromMap(map);
  }

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel.fromMap(json);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class HabitModelAdapter extends TypeAdapter<HabitModel> {
  @override
  final int typeId = 2;

  @override
  HabitModel read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return HabitModel(
      id: fields[0] as String,
      title: fields[1] as String,
      color: fields[2] as int,
      emoji: fields[3] as String,
      checkIns: (fields[4] as List).cast<DateTime>(),
      currentStreak: fields[5] as int,
      longestStreak: fields[6] as int,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HabitModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.color)
      ..writeByte(3)
      ..write(obj.emoji)
      ..writeByte(4)
      ..write(obj.checkIns)
      ..writeByte(5)
      ..write(obj.currentStreak)
      ..writeByte(6)
      ..write(obj.longestStreak)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}
