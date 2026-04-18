import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daymark/core/auth_service.dart';
import 'package:daymark/core/hive_boxes.dart';
import 'package:daymark/core/pin_security_service.dart';
import 'package:daymark/core/sync_service.dart';
import 'package:daymark/features/events/models/event_model.dart';
import 'package:daymark/features/events/providers/events_provider.dart';
import 'package:daymark/features/events/screens/widget_config_screen.dart';
import 'package:daymark/features/events/services/export_service.dart';
import 'package:daymark/features/events/services/home_widget_service.dart';
import 'package:daymark/features/habits/models/habit_model.dart';
import 'package:daymark/features/notifications/notification_service.dart';
import 'package:daymark/features/settings/screens/account_screen.dart';
import 'package:daymark/features/settings/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:share_plus/share_plus.dart';
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

  testWidgets('sign-in dialog validation and sync action show feedback',
      (WidgetTester tester) async {
    final FakeAuthService auth = FakeAuthService();
    final FakeSyncService sync = FakeSyncService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authServiceProvider.overrideWithValue(auth),
          syncServiceProvider.overrideWithValue(sync),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with Email & backup local data'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email and password are required.'), findsOneWidget);

    await tester.tap(find.text('Sync Now'));
    await tester.pumpAndSettle();
    expect(sync.syncCalls, 1);
  });

  testWidgets('settings import/export flow works with injected services',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final EventModel seeded = EventModel(
      id: 'seed-1',
      title: 'Seed Event',
      date: now.add(const Duration(days: 14)),
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
    final EventModel imported = EventModel(
      id: 'import-1',
      title: 'Imported Event',
      date: now.add(const Duration(days: 30)),
      category: 'Work',
      color: 0xFF009688,
      emoji: '📦',
      notes: 'from test',
      mode: EventMode.countdown,
      reminderDays: const <int>[],
      countUnit: EventCountUnit.days,
      createdAt: now,
      updatedAt: now,
    );

    final Box<EventModel> eventsBox = Hive.box<EventModel>(HiveBoxes.events);
    await eventsBox.put(seeded.id, seeded);

    final FakeSyncService sync = FakeSyncService(localEventsBox: eventsBox);
    final FakeExportService exportService =
        FakeExportService(importResult: <EventModel>[imported]);
    final FakeNotificationService notifications = FakeNotificationService();
    final FakeEventHomeWidgetService widgets = FakeEventHomeWidgetService();
    final List<String> sharedPaths = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authServiceProvider.overrideWithValue(FakeAuthService()),
          syncServiceProvider.overrideWithValue(sync),
          eventsProvider.overrideWith(
            (Ref ref) => TestEventsNotifier(
              box: eventsBox,
              syncService: sync,
              notificationService: notifications,
              homeWidgetService: widgets,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              exportService: exportService,
              shareFiles: (List<XFile> files) async {
                sharedPaths.addAll(files.map((XFile f) => f.path));
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Export').at(1));
    await tester.pumpAndSettle();

    expect(exportService.exportJsonCalls, 1);
    expect(exportService.exportCsvCalls, 1);
    expect(sharedPaths.length, 2);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Imported 1 events.'), findsOneWidget);
    expect(eventsBox.containsKey(imported.id), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('widget config apply and pin flows are testable',
      (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final EventModel event = EventModel(
      id: 'w1',
      title: 'Widget Event',
      date: now.add(const Duration(days: 2)),
      category: 'Personal',
      color: 0xFF6750A4,
      emoji: '🗓️',
      notes: 'preview',
      mode: EventMode.countdown,
      reminderDays: const <int>[],
      countUnit: EventCountUnit.days,
      createdAt: now,
      updatedAt: now,
    );

    final Box<EventModel> eventsBox = Hive.box<EventModel>(HiveBoxes.events);
    await eventsBox.put(event.id, event);

    final InMemoryWidgetConfigStore store = InMemoryWidgetConfigStore();
    final FakeEventHomeWidgetService widgets = FakeEventHomeWidgetService();
    final FakeSyncService sync = FakeSyncService(localEventsBox: eventsBox);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          syncServiceProvider.overrideWithValue(sync),
          eventsProvider.overrideWith(
            (Ref ref) => TestEventsNotifier(
              box: eventsBox,
              syncService: sync,
              notificationService: FakeNotificationService(),
              homeWidgetService: widgets,
            ),
          ),
        ],
        child: MaterialApp(
          home: WidgetConfigScreen(
            store: store,
            homeWidgetService: widgets,
            pinWidget: () async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Finder listFinder = find.byType(ListView).first;
    for (int i = 0;
        i < 8 && find.text('Apply & Update Widget').evaluate().isEmpty;
        i++) {
      await tester.drag(listFinder, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(find.text('Apply & Update Widget'), findsOneWidget);
    await tester.tap(find.text('Apply & Update Widget'));
    await tester.pumpAndSettle();
    expect(find.text('Widget updated! Add it from your launcher.'), findsOneWidget);
    expect(widgets.pushCalls, greaterThan(0));


    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class FakeAuthService extends AuthService {
  FakeAuthService() : super();

  final StreamController<User?> _authController =
      StreamController<User?>.broadcast();

  @override
  bool get isSignedIn => false;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  Future<UserCredential?> signInWithApple() async => null;

  @override
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('Not used in this test flow.');
  }

  @override
  Future<UserCredential> createAccountWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) {
    throw UnimplementedError('Not used in this test flow.');
  }
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
  int syncCalls = 0;

  @override
  DateTime? get lastSyncedAt => DateTime(2026, 4, 18);

  @override
  Future<void> syncAll({ScaffoldMessengerState? messenger}) async {
    syncCalls += 1;
    messenger?.showSnackBar(const SnackBar(content: Text('Sync mocked.')));
  }

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
  int pushCalls = 0;

  @override
  Future<void> pushEvents(List<EventModel> events) async {
    pushCalls += 1;
  }
}

class FakeExportService extends ExportService {
  FakeExportService({required this.importResult});

  final List<EventModel> importResult;
  int exportJsonCalls = 0;
  int exportCsvCalls = 0;

  @override
  Future<File> exportEventsJson(List<EventModel> events,
      {PinSecurityService? security}) async {
    exportJsonCalls += 1;
    final Directory dir = await Directory.systemTemp.createTemp('daymark_export');
    final File file = File('${dir.path}/events.json');
    return file.writeAsString('[]');
  }

  @override
  Future<File> exportEventsCsv(List<EventModel> events) async {
    exportCsvCalls += 1;
    final Directory dir = await Directory.systemTemp.createTemp('daymark_export');
    final File file = File('${dir.path}/events.csv');
    return file.writeAsString('id,title');
  }

  @override
  Future<List<EventModel>> importEventsJsonFromPicker(
      {PinSecurityService? security}) async {
    return importResult;
  }
}

class InMemoryWidgetConfigStore implements WidgetConfigStore {
  final Map<String, dynamic> _data = <String, dynamic>{};

  @override
  Future<T?> getData<T>(String key) async => _data[key] as T?;

  @override
  Future<void> saveData<T>(String key, T value) async {
    _data[key] = value;
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

