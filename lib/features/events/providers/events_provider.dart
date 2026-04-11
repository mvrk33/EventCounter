import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/hive_boxes.dart';
import '../../../core/sync_service.dart';
import '../../notifications/notification_service.dart';
import '../models/event_model.dart';
import '../services/home_widget_service.dart';

final Provider<Uuid> uuidProvider = Provider<Uuid>((Ref ref) => const Uuid());

final StateNotifierProvider<EventsNotifier, List<EventModel>> eventsProvider =
    StateNotifierProvider<EventsNotifier, List<EventModel>>((Ref ref) {
  return EventsNotifier(
    box: Hive.box<EventModel>(HiveBoxes.events),
    syncService: ref.read(syncServiceProvider),
    notificationService: ref.read(notificationServiceProvider),
    homeWidgetService: const EventHomeWidgetService(),
    uuid: ref.read(uuidProvider),
  );
});

class EventsNotifier extends StateNotifier<List<EventModel>> {
  EventsNotifier({
    required Box<EventModel> box,
    required SyncService syncService,
    required NotificationService notificationService,
    required EventHomeWidgetService homeWidgetService,
    required Uuid uuid,
  })  : _box = box,
        _syncService = syncService,
        _notificationService = notificationService,
        _homeWidgetService = homeWidgetService,
        _uuid = uuid,
        super(box.values.toList(growable: false)) {
    _listenBox();
  }

  final Box<EventModel> _box;
  final SyncService _syncService;
  final NotificationService _notificationService;
  final EventHomeWidgetService _homeWidgetService;
  final Uuid _uuid;

  void _listenBox() {
    _box.listenable().addListener(() {
      final List<EventModel> list = _box.values.toList(growable: false)
        ..sort((EventModel a, EventModel b) => a.date.compareTo(b.date));
      state = list;
      _homeWidgetService.pushEvents(list);
    });
  }

  // Creates a local-first event and syncs in background.
  Future<void> addEvent({
    required String title,
    required DateTime date,
    required String category,
    required int color,
    required String emoji,
    required String notes,
    required List<int> reminderDays,
    required EventCountUnit countUnit,
    EventRecurrence recurrence = EventRecurrence.once,
  }) async {
    final DateTime now = DateTime.now();
    final EventMode mode = date.isAfter(now) ? EventMode.countdown : EventMode.countup;
    final EventModel event = EventModel(
      id: _uuid.v4(),
      title: title.trim(),
      date: date,
      category: category,
      color: color,
      emoji: emoji,
      notes: notes,
      mode: mode,
      reminderDays: reminderDays,
      countUnit: countUnit,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
    );
    await _syncService.syncEvent(event);
    await _notificationService.scheduleEventReminders(event);
  }

  Future<void> updateEvent(EventModel event) async {
    final EventModel updated = event.copyWith(updatedAt: DateTime.now());
    await _syncService.syncEvent(updated);
    await _notificationService.scheduleEventReminders(updated);
  }

  Future<void> deleteEvent(String id) async {
    await _notificationService.cancelEventReminders(id);
    await _syncService.deleteEvent(id);
  }

  Future<void> togglePinned(EventModel event) async {
    await _syncService.syncEvent(
      event.copyWith(
        isPinned: !event.isPinned,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> importEvents(List<EventModel> events) async {
    for (final EventModel imported in events) {
      final EventModel? local = _box.get(imported.id);
      if (local == null || imported.updatedAt.isAfter(local.updatedAt)) {
        await _syncService.syncEvent(imported.copyWith(updatedAt: DateTime.now()));
      }
    }
  }
}
