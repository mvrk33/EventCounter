import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  static const String appName = 'DayMark';
  static const String appSubtitle = 'Day Counter & Tracker';

  static const List<String> predefinedCategories = <String>[
    'Birthday',
    'Travel',
    'Health',
    'Work',
    'Anniversary',
    'Personal',
    'Other',
  ];

  static const List<int> defaultEventReminderDays = <int>[0, 1, 7];

  static const TimeOfDay defaultHabitReminderTime = TimeOfDay(hour: 20, minute: 0);
}
