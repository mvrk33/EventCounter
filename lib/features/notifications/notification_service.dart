import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/events/models/event_model.dart';

final Provider<NotificationService> notificationServiceProvider = Provider<NotificationService>(
  (Ref ref) => NotificationService(),
);

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    // Skip unsupported platforms (web/desktop) where local notifications are not configured.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      // initializeTimeZones() is in timezone/data/latest.dart
      tz_data.initializeTimeZones();
    } catch (_) {
      // Already initialized
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Schedules per-event reminder notifications.
  Future<void> scheduleEventReminders(EventModel event) async {
    await cancelEventReminders(event.id);

    for (final int day in event.reminderDays) {
      final DateTime scheduleAt = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        9,
      ).subtract(Duration(days: day));

      if (scheduleAt.isBefore(DateTime.now())) {
        continue;
      }

      try {
        await _plugin.zonedSchedule(
          _notificationId(event.id, day),
          '${event.emoji} ${event.title}',
          day == 0
              ? 'Today is your event day.'
              : '$day day(s) left until ${event.title}.',
          tz.TZDateTime.from(scheduleAt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daymark_events',
              'Event Reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // If exact alarms are not permitted, fall back to inexact alarms
        if (e is PlatformException && e.code == 'exact_alarms_not_permitted') {
          await _plugin.zonedSchedule(
            _notificationId(event.id, day),
            '${event.emoji} ${event.title}',
            day == 0
                ? 'Today is your event day.'
                : '$day day(s) left until ${event.title}.',
            tz.TZDateTime.from(scheduleAt, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'daymark_events',
                'Event Reminders',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> cancelEventReminders(String eventId) async {
    for (final int day in <int>[0, 1, 7]) {
      await _plugin.cancel(_notificationId(eventId, day));
    }
  }

  Future<void> scheduleDailyHabitReminder({required int hour, required int minute}) async {
    await _plugin.cancel(999001);
    final DateTime now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.periodicallyShow(
        999001,
        'DayMark Habit Reminder',
        'Open DayMark and check in your habits today.',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daymark_habits',
            'Habit Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // If exact alarms are not permitted, fall back to inexact alarms
      if (e is PlatformException && e.code == 'exact_alarms_not_permitted') {
        await _plugin.periodicallyShow(
          999001,
          'DayMark Habit Reminder',
          'Open DayMark and check in your habits today.',
          RepeatInterval.daily,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daymark_habits',
              'Habit Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } else {
        rethrow;
      }
    }
  }

  int _notificationId(String eventId, int day) {
    return eventId.hashCode ^ day;
  }
}
