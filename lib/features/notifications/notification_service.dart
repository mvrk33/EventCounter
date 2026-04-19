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

  // ── Scheduled reminder notifications ───────────────────────────────────────

  /// Schedules per-event reminder notifications.
  /// Uses [event.nextOccurrenceDate] so recurring events always fire at the
  /// correct next occurrence (e.g. next anniversary, not the original date).
  Future<void> scheduleEventReminders(EventModel event) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) return;

    await cancelEventReminders(event.id);

    // Use next occurrence so yearly/monthly/weekly reminders are always correct.
    final DateTime nextDate = event.nextOccurrenceDate;

    for (final int day in event.reminderDays) {
      // Fire at 9 AM, X days before the next occurrence.
      final DateTime scheduleAt = DateTime(
        nextDate.year,
        nextDate.month,
        nextDate.day,
        9,
      ).subtract(Duration(days: day));

      if (scheduleAt.isBefore(DateTime.now())) {
        continue;
      }

      final String body = day == 0
          ? '${event.emoji} Today is ${event.title}!'
          : '${event.emoji} ${event.title} is in $day day${day == 1 ? '' : 's'}.';

      Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
            _notificationId(event.id, day),
            '${event.emoji} ${event.title}',
            body,
            tz.TZDateTime.from(scheduleAt, tz.local),
            NotificationDetails(
              android: AndroidNotificationDetails(
                _kEventChannel,
                'Event Reminders',
                channelDescription: 'Scheduled reminders before your events',
                importance: Importance.max,
                priority: Priority.high,
                styleInformation: BigTextStyleInformation(body),
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: mode,
          );

      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted') {
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Cancels all scheduled reminders for [eventId].
  /// Cancels every day value in [knownReminderDays] (falls back to common set).
  Future<void> cancelEventReminders(
    String eventId, {
    List<int> knownReminderDays = const <int>[0, 1, 2, 3, 7, 14, 30],
  }) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) return;

    for (final int day in knownReminderDays) {
      await _plugin.cancel(_notificationId(eventId, day));
    }
    // Always cancel the live progress notification too.
    await _plugin.cancel(_liveProgressId(eventId));
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

  /// Shows a live notification listing today's events AND refreshes the
  /// ongoing progress notification for every event.
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
    } else {
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
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kLiveChannel,
            'Live Event Alerts',
            channelDescription: 'Notifies you when events are happening today',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }

    // Refresh the persistent progress notification for every event.
    await refreshLiveProgressNotifications(allEvents);
  }

  // ── Live progress (ongoing) notifications ──────────────────────────────────

  /// Posts/updates a persistent ongoing notification for every event that has
  /// [liveNotification] enabled, and cancels it for events that have it off.
  Future<void> refreshLiveProgressNotifications(
      List<EventModel> allEvents) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) return;
    if (!await hasNotificationPermission()) return;

    for (final EventModel event in allEvents) {
      if (event.liveNotification) {
        await _postLiveProgressNotification(event);
      } else {
        // Cancel any stale progress notification if the flag was turned off.
        await _plugin.cancel(_liveProgressId(event.id));
      }
    }
  }

  Future<void> _postLiveProgressNotification(EventModel event) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime nextDate = DateTime(
      event.nextOccurrenceDate.year,
      event.nextOccurrenceDate.month,
      event.nextOccurrenceDate.day,
    );

    final int daysUntil = nextDate.difference(today).inDays;

    // Compute progress (0–100).
    int progress = 0;
    int maxProgress = 100;
    String subtitle;

    if (event.mode == EventMode.countdown || daysUntil >= 0) {
      // Countdown: progress fills as the day approaches.
      final int totalDays = _periodDays(event);
      if (totalDays > 0) {
        final int elapsed = (totalDays - daysUntil).clamp(0, totalDays);
        progress = ((elapsed / totalDays) * 100).round().clamp(0, 100);
      }

      if (daysUntil == 0) {
        subtitle = 'Today! 🎉';
        progress = 100;
      } else if (daysUntil == 1) {
        subtitle = 'Tomorrow – 1 day to go';
      } else {
        subtitle = '$daysUntil ${daysUntil == 1 ? 'day' : 'days'} to go';
      }
    } else {
      // Count-up: days since the event.
      final int daysSince = today.difference(nextDate).inDays.abs();
      subtitle = '$daysSince days ago';
      progress = 100; // already passed
    }

    await _plugin.show(
      _liveProgressId(event.id),
      '${event.emoji} ${event.title}',
      subtitle,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kLiveChannel,
          'Live Event Alerts',
          channelDescription: 'Ongoing countdown progress for your events',
          importance: Importance.low,   // low = no sound/heads-up, stays in shade
          priority: Priority.low,
          ongoing: true,               // can't be dismissed by swipe
          onlyAlertOnce: true,         // no sound after first post
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress,
          indeterminate: false,
          styleInformation: BigTextStyleInformation(
            subtitle,
            contentTitle: '${event.emoji} ${event.title}',
            summaryText: 'Daymark',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,   // iOS: don't pop up, just update silently
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  /// Cancels the live progress notification for a single event.
  Future<void> cancelLiveProgressNotification(String eventId) async {
    await _ensureInitialized();
    if (!_isSupportedPlatform) return;
    await _plugin.cancel(_liveProgressId(eventId));
  }

  /// Returns the total period in days for the event's recurrence,
  /// used to compute progress towards next occurrence.
  int _periodDays(EventModel event) {
    switch (event.recurrence) {
      case EventRecurrence.weekly:
        return 7;
      case EventRecurrence.monthly:
        return 30;
      case EventRecurrence.yearly:
        return 365;
      case EventRecurrence.once:
        // For a one-time event, use days from creation to event date.
        final int total = event.date
            .difference(event.createdAt)
            .inDays
            .abs();
        return total > 0 ? total : 1;
    }
  }

  int _liveProgressId(String eventId) =>
      (eventId.hashCode & 0x7FFFFF) + 500000;

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

    Future<void> doSchedule(AndroidScheduleMode mode) async {
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
      await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      if (e is PlatformException && e.code == 'exact_alarms_not_permitted') {
        await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
      } else {
        rethrow;
      }
    }
  }

  int _notificationId(String eventId, int day) {
    return eventId.hashCode ^ day;
  }
}
