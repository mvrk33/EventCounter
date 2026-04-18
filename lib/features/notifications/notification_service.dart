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

// Channel IDs
const String _kEventChannel = 'event_counter_events';
const String _kHabitChannel = 'event_counter_habits';
const String _kLiveChannel = 'event_counter_live';

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
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

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

    // If permanently denied, user must go to settings.
    final PermissionStatus status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    final PermissionStatus result = await Permission.notification.request();
    if (result.isGranted) {
      return true;
    }

    // Also request via the plugin for completeness.
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
              _kEventChannel,
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
                _kEventChannel,
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
        'Daymark Habit Reminder',
        'Open Daymark and check in your habits today.',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kHabitChannel,
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
          'Daymark Habit Reminder',
          'Open Daymark and check in your habits today.',
          RepeatInterval.daily,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kHabitChannel,
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

  // ── Live / Today's events notification ─────────────────────────────────────

  /// Shows a live notification listing today's events.
  /// Call this once at app start (and again whenever events change).
  Future<void> showLiveEventNotification(List<EventModel> allEvents) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) return;

    final DateTime today = DateTime.now();
    final List<EventModel> todayEvents = allEvents.where((EventModel e) {
      final DateTime next = e.nextOccurrenceDate;
      return next.year == today.year &&
          next.month == today.month &&
          next.day == today.day;
    }).toList();

    if (todayEvents.isEmpty) {
      await _plugin.cancel(999002);
      return;
    }

    final String title = todayEvents.length == 1
        ? '${todayEvents.first.emoji} ${todayEvents.first.title} is today!'
        : '${todayEvents.length} events happening today!';
    final String body = todayEvents
        .map((EventModel e) => '${e.emoji} ${e.title}')
        .join(' · ');

    await _plugin.show(
      999002,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kLiveChannel,
          'Live Event Alerts',
          channelDescription: 'Notifies you when events are happening today',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Schedules a daily morning notification (8 AM) summarising today's events.
  Future<void> scheduleTodayEventsNotification() async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) return;

    // Cancel any existing schedule first.
    await _plugin.cancel(999003);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    Future<void> _doSchedule(AndroidScheduleMode mode) async {
      await _plugin.zonedSchedule(
        999003,
        '📅 Good morning!',
        'Check your events and habits for today in Daymark.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kLiveChannel,
            'Live Event Alerts',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    try {
      await _doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      if (e is PlatformException && e.code == 'exact_alarms_not_permitted') {
        await _doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
      } else {
        rethrow;
      }
    }
  }

  int _notificationId(String eventId, int day) {
    return eventId.hashCode ^ day;
  }
}
