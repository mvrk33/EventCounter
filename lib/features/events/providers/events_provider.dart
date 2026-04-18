import 'dart:async';

import 'package:flutter/foundation.dart';
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
    homeWidgetService: EventHomeWidgetService(),
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
  late final ValueListenable<Box<EventModel>> _boxListenable = _box.listenable();
  Timer? _sideEffectsDebounce;
  VoidCallback? _boxListener;
  int _lastSideEffectsHash = 0;

  void _listenBox() {
    _boxListener = () {
      final List<EventModel> list = _box.values.toList(growable: false)
        ..sort((EventModel a, EventModel b) => a.date.compareTo(b.date));
      state = list;
      _scheduleSideEffects(list);
    };
    _boxListenable.addListener(_boxListener!);
  }

  void _scheduleSideEffects(List<EventModel> list) {
    final int sideEffectsHash = Object.hashAll(
      list.map((EventModel e) => Object.hash(e.id, e.updatedAt.millisecondsSinceEpoch)),
    );
    if (sideEffectsHash == _lastSideEffectsHash) {
      return;
    }
    _lastSideEffectsHash = sideEffectsHash;

    _sideEffectsDebounce?.cancel();
    _sideEffectsDebounce = Timer(const Duration(milliseconds: 250), () {
      _homeWidgetService.pushEvents(list);
      // Update live "today's events" notification whenever events change.
      _notificationService.showLiveEventNotification(list).ignore();
    });
  }

  @override
  void dispose() {
    _sideEffectsDebounce?.cancel();
    if (_boxListener != null) {
      _boxListenable.removeListener(_boxListener!);
    }
    super.dispose();
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
    bool liveNotification = false,
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
      liveNotification: liveNotification,
      createdAt: now,
      updatedAt: now,
    );
    await _syncService.syncEvent(event);
    if (event.reminderDays.isNotEmpty && await _notificationService.hasNotificationPermission()) {
      await _notificationService.scheduleEventReminders(event);
    }
  }

  Future<void> updateEvent(EventModel event) async {
    final EventModel updated = event.copyWith(updatedAt: DateTime.now());
    await _syncService.syncEvent(updated);
    if (updated.reminderDays.isNotEmpty && await _notificationService.hasNotificationPermission()) {
      await _notificationService.scheduleEventReminders(updated);
    }
  }

  Future<void> deleteEvent(String id) async {
    final EventModel? event = _box.get(id);
    await _notificationService.cancelEventReminders(
      id,
      knownReminderDays: event?.reminderDays ?? const <int>[0, 1, 2, 3, 7, 14, 30],
    );
    await _notificationService.cancelLiveProgressNotification(id);
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
