import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  static const String appName = 'Event Counter';
  static const String appSubtitle = 'Event Counter & Tracker';
  static const String logoAssetPath = 'assets/branding/app_logo.png';
  static const String loadingCaption = 'Track moments, milestones, and streaks.';

  static const List<String> predefinedCategories = <String>[
    'Birthday',
    'Anniversary',
    'Travel',
    'Health',
    'Fitness',
    'Work',
    'Finance',
    'Education',
    'Milestone',
    'Home',
    'Vehicle',
    'Pet',
    'Habit',
    'Personal',
    'Food',
    'Other',
  ];

  static const List<int> defaultEventReminderDays = <int>[0, 1, 7];

  static const TimeOfDay defaultHabitReminderTime = TimeOfDay(hour: 20, minute: 0);
}
