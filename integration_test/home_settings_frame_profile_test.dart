import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daymark/core/auth_service.dart';
import 'package:daymark/core/hive_boxes.dart';
import 'package:daymark/core/pin_security_service.dart';
import 'package:daymark/core/sync_service.dart';
import 'package:daymark/features/events/models/event_model.dart';
import 'package:daymark/features/events/providers/events_provider.dart';
import 'package:daymark/features/events/screens/home_screen.dart';
import 'package:daymark/features/events/services/export_service.dart';
import 'package:daymark/features/events/services/home_widget_service.dart';
import 'package:daymark/features/habits/models/habit_model.dart';
import 'package:daymark/features/habits/providers/habits_provider.dart';
import 'package:daymark/features/notifications/notification_service.dart';
import 'package:daymark/features/settings/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(EventModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HabitModelAdapter());
    }
    await Hive.openBox<EventModel>(HiveBoxes.events);
    await Hive.openBox<HabitModel>(HiveBoxes.habits);
    await Hive.openBox<dynamic>(HiveBoxes.settings);
    await Hive.openBox<dynamic>(HiveBoxes.syncMeta);
  });

  setUp(() async {
    await Hive.box<EventModel>(HiveBoxes.events).clear();
    await Hive.box<HabitModel>(HiveBoxes.habits).clear();
    await Hive.box<dynamic>(HiveBoxes.settings).clear();
    await Hive.box<dynamic>(HiveBoxes.syncMeta).clear();
  });

  testWidgets('profile HomeScreen scroll frame timeline',
      (WidgetTester tester) async {
    final Box<EventModel> eventsBox = Hive.box<EventModel>(HiveBoxes.events);
    final Box<HabitModel> habitsBox = Hive.box<HabitModel>(HiveBoxes.habits);
    final DateTime now = DateTime.now();

    for (int i = 0; i < 140; i++) {
      final EventModel event = EventModel(
        id: 'perf-$i',
        title: 'Event $i',
        date: now.add(Duration(days: i + 1)),
        category: i.isEven ? 'Work' : 'Personal',
        color: 0xFF5E6AD2,
        emoji: '🗓️',
        notes: i % 5 == 0 ? 'Longer note for item $i' : '',
        mode: EventMode.countdown,
        reminderDays: const <int>[],
        countUnit: EventCountUnit.days,
        isPinned: i % 9 == 0,
        createdAt: now,
        updatedAt: now,
      );
      await eventsBox.put(event.id, event);
    }

    final FakeSyncService sync = FakeSyncService(localEventsBox: eventsBox);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authServiceProvider.overrideWithValue(FakeAuthService()),
          syncServiceProvider.overrideWithValue(sync),
          eventsProvider.overrideWith(
            (Ref ref) => TestEventsNotifier(
              box: eventsBox,
              syncService: sync,
              notificationService: FakeNotificationService(),
              homeWidgetService: FakeEventHomeWidgetService(),
            ),
          ),
          habitsProvider.overrideWith(
            (Ref ref) => TestHabitsNotifier(
              box: habitsBox,
              syncService: sync,
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final _FrameStats stats = await _profileScrollFrames(
      tester,
      scrollable: find.byType(CustomScrollView).first,
      cycles: 3,
      upDistance: -900,
      downDistance: 700,
      upVelocity: 2600,
      downVelocity: 2200,
    );
    debugPrint('HOME frame profile: $stats');
    expect(stats.sampleCount, greaterThan(0));
  });

  testWidgets('profile SettingsScreen scroll frame timeline',
      (WidgetTester tester) async {
    final Box<EventModel> eventsBox = Hive.box<EventModel>(HiveBoxes.events);
    final DateTime now = DateTime.now();
    final EventModel event = EventModel(
      id: 'settings-seed',
      title: 'Settings Event',
      date: now.add(const Duration(days: 5)),
      category: 'Personal',
      color: 0xFF5E6AD2,
      emoji: '🎯',
      notes: '',
      mode: EventMode.countdown,
      reminderDays: const <int>[],
      countUnit: EventCountUnit.days,
      createdAt: now,
      updatedAt: now,
    );
    await eventsBox.put(event.id, event);

    final FakeSyncService sync = FakeSyncService(localEventsBox: eventsBox);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authServiceProvider.overrideWithValue(FakeAuthService()),
          syncServiceProvider.overrideWithValue(sync),
          eventsProvider.overrideWith(
            (Ref ref) => TestEventsNotifier(
              box: eventsBox,
              syncService: sync,
              notificationService: FakeNotificationService(),
              homeWidgetService: FakeEventHomeWidgetService(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              exportService: FakeExportService(),
              shareFiles: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final _FrameStats stats = await _profileScrollFrames(
      tester,
      scrollable: find.byType(CustomScrollView).first,
      cycles: 3,
      upDistance: -700,
      downDistance: 600,
      upVelocity: 2200,
      downVelocity: 2000,
    );
    debugPrint('SETTINGS frame profile: $stats');
    expect(stats.sampleCount, greaterThan(0));
  });
}

Future<_FrameStats> _profileScrollFrames(
  WidgetTester tester, {
  required Finder scrollable,
  required int cycles,
  required double upDistance,
  required double downDistance,
  required double upVelocity,
  required double downVelocity,
}) async {
  final List<FrameTiming> timings = <FrameTiming>[];
  void onTimings(List<FrameTiming> frameTimings) {
    timings.addAll(frameTimings);
  }

  SchedulerBinding.instance.addTimingsCallback(onTimings);
  try {
    for (int i = 0; i < cycles; i++) {
      await tester.fling(scrollable, Offset(0, upDistance), upVelocity);
      await tester.pumpAndSettle();
      await tester.fling(scrollable, Offset(0, downDistance), downVelocity);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(milliseconds: 120));
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
  }

  return _FrameStats.fromTimings(timings);
}

class _FrameStats {
  const _FrameStats({
    required this.sampleCount,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.worstBuildMs,
    required this.worstRasterMs,
  });

  final int sampleCount;
  final double avgBuildMs;
  final double avgRasterMs;
  final double worstBuildMs;
  final double worstRasterMs;

  factory _FrameStats.fromTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) {
      return const _FrameStats(
        sampleCount: 0,
        avgBuildMs: 0,
        avgRasterMs: 0,
        worstBuildMs: 0,
        worstRasterMs: 0,
      );
    }

    final List<double> buildMs = timings
        .map((FrameTiming t) =>
            t.buildDuration.inMicroseconds / Duration.microsecondsPerMillisecond)
        .toList(growable: false);
    final List<double> rasterMs = timings
        .map((FrameTiming t) =>
            t.rasterDuration.inMicroseconds / Duration.microsecondsPerMillisecond)
        .toList(growable: false);

    final double avgBuild =
        buildMs.reduce((double a, double b) => a + b) / buildMs.length;
    final double avgRaster =
        rasterMs.reduce((double a, double b) => a + b) / rasterMs.length;
    final double worstBuild =
        buildMs.reduce((double a, double b) => a > b ? a : b);
    final double worstRaster =
        rasterMs.reduce((double a, double b) => a > b ? a : b);

    return _FrameStats(
      sampleCount: timings.length,
      avgBuildMs: avgBuild,
      avgRasterMs: avgRaster,
      worstBuildMs: worstBuild,
      worstRasterMs: worstRaster,
    );
  }

  @override
  String toString() {
    return 'samples=$sampleCount, '
        'avgBuild=${avgBuildMs.toStringAsFixed(2)}ms, '
        'avgRaster=${avgRasterMs.toStringAsFixed(2)}ms, '
        'worstBuild=${worstBuildMs.toStringAsFixed(2)}ms, '
        'worstRaster=${worstRasterMs.toStringAsFixed(2)}ms';
  }
}

class FakeAuthService extends AuthService {
  FakeAuthService() : super();

  @override
  bool get isSignedIn => false;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);
}

class FakeSyncService extends SyncService {
  FakeSyncService({this.localEventsBox})
      : super(
          authService: FakeAuthService(),
          pinSecurityService: PinSecurityService(settingsBox: null),
          firestore: null,
          eventsBox: null,
          habitsBox: null,
          syncMetaBox: null,
          connectivity: Connectivity(),
        );

  final Box<EventModel>? localEventsBox;

  @override
  Future<void> syncEvent(EventModel event) async {
    await localEventsBox?.put(event.id, event);
  }

  @override
  Future<void> deleteEvent(String id) async {
    await localEventsBox?.delete(id);
  }

  @override
  Future<void> syncHabit(HabitModel habit) async {}

  @override
  Future<void> deleteHabit(String id) async {}
}

class FakeNotificationService extends NotificationService {
  @override
  Future<void> showLiveEventNotification(List<EventModel> events) async {}

  @override
  Future<bool> hasNotificationPermission() async => false;

  @override
  Future<void> scheduleEventReminders(EventModel event) async {}

  @override
  Future<void> cancelEventReminders(String eventId,
      {List<int> knownReminderDays = const <int>[0, 1, 2, 3, 7, 14, 30]}) async {}

  @override
  Future<void> cancelLiveProgressNotification(String eventId) async {}
}

class FakeEventHomeWidgetService extends EventHomeWidgetService {
  @override
  Future<void> pushEvents(List<EventModel> events) async {}
}

class FakeExportService extends ExportService {
  @override
  Future<File> exportEventsJson(List<EventModel> events,
      {PinSecurityService? security}) async {
    final Directory dir = await Directory.systemTemp.createTemp('daymark_perf');
    final File file = File('${dir.path}/events.json');
    return file.writeAsString('[]');
  }

  @override
  Future<File> exportEventsCsv(List<EventModel> events) async {
    final Directory dir = await Directory.systemTemp.createTemp('daymark_perf');
    final File file = File('${dir.path}/events.csv');
    return file.writeAsString('id,title');
  }
}

class TestEventsNotifier extends EventsNotifier {
  TestEventsNotifier({
    required super.box,
    required super.syncService,
    required super.notificationService,
    required super.homeWidgetService,
  }) : super(
          uuid: const Uuid(),
        );
}

class TestHabitsNotifier extends HabitsNotifier {
  TestHabitsNotifier({
    required super.box,
    required super.syncService,
  }) : super(
          uuid: const Uuid(),
        );
}

