import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/hive_boxes.dart';
import '../../features/events/models/event_model.dart';

final Provider<NotificationService> notificationServiceProvider = Provider<NotificationService>(
  (Ref ref) => NotificationService(),
);

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  static const String _firstLaunchPromptKey = 'notifications_prompted_once';

  bool get _isSupportedPlatform {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Future<void> initialize() async {
    // Skip unsupported platforms (web/desktop) where local notifications are not configured.
    if (!_isSupportedPlatform) {
      _isInitialized = true;
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
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }
    await initialize();
  }

  Future<bool> hasNotificationPermission() async {
    if (!_isSupportedPlatform) {
      return true;
    }
    final PermissionStatus status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestPermissions() async {
    await _ensureInitialized();

    if (!_isSupportedPlatform) {
      return true;
    }

    final PermissionStatus status = await Permission.notification.request();
    if (status.isGranted) {
      return true;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return hasNotificationPermission();
  }

  Future<void> requestPermissionsOnFirstLaunch() async {
    if (!_isSupportedPlatform) {
      return;
    }

    final Box<dynamic> settings = Hive.box<dynamic>(HiveBoxes.settings);
    final bool alreadyPrompted = settings.get(_firstLaunchPromptKey, defaultValue: false) == true;
    if (alreadyPrompted) {
      return;
    }

    await settings.put(_firstLaunchPromptKey, true);
    await requestPermissions();
  }

  // Schedules per-event reminder notifications.
  Future<void> scheduleEventReminders(EventModel event) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) {
      return;
    }

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
              'event_counter_events',
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
                'event_counter_events',
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
    await _ensureInitialized();
    if (!_isSupportedPlatform) {
      return;
    }

    for (final int day in <int>[0, 1, 7]) {
      await _plugin.cancel(_notificationId(eventId, day));
    }
  }

  Future<void> scheduleDailyHabitReminder({required int hour, required int minute}) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) {
      return;
    }

    await _plugin.cancel(999001);
    final DateTime now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.periodicallyShow(
        999001,
        'Event Counter Habit Reminder',
        'Open Event Counter and check in your habits today.',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_counter_habits',
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
          'Event Counter Habit Reminder',
          'Open Event Counter and check in your habits today.',
          RepeatInterval.daily,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'event_counter_habits',
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
