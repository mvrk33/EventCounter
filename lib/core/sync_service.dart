import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/events/models/event_model.dart';
import '../features/habits/models/habit_model.dart';
import 'auth_service.dart';
import 'hive_boxes.dart';

final Provider<SyncService> syncServiceProvider = Provider<SyncService>((Ref ref) {
  return SyncService(
    authService: ref.read(authServiceProvider),
    firestore: Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null,
    eventsBox: Hive.isBoxOpen(HiveBoxes.events) ? Hive.box<EventModel>(HiveBoxes.events) : null,
    habitsBox: Hive.isBoxOpen(HiveBoxes.habits) ? Hive.box<HabitModel>(HiveBoxes.habits) : null,
    syncMetaBox: Hive.isBoxOpen(HiveBoxes.syncMeta) ? Hive.box<dynamic>(HiveBoxes.syncMeta) : null,
    connectivity: Connectivity(),
  );
});

class SyncService {
  SyncService({
    required AuthService authService,
    required FirebaseFirestore? firestore,
    required Box<EventModel>? eventsBox,
    required Box<HabitModel>? habitsBox,
    required Box<dynamic>? syncMetaBox,
    required Connectivity connectivity,
  })  : _authService = authService,
        _firestore = firestore,
        _eventsBox = eventsBox,
        _habitsBox = habitsBox,
        _syncMetaBox = syncMetaBox,
        _connectivity = connectivity;

  final AuthService _authService;
  final FirebaseFirestore? _firestore;
  final Box<EventModel>? _eventsBox;
  final Box<HabitModel>? _habitsBox;
  final Box<dynamic>? _syncMetaBox;
  final Connectivity _connectivity;

  String _autoRestoreDisabledKeyForCurrentUser() {
    final String uid = _authService.currentUser?.uid ?? 'guest';
    return 'disable_auto_restore_$uid';
  }

  Future<bool> shouldAutoRestoreOnLaunch() async {
    final bool disabled =
        (_syncMetaBox?.get(_autoRestoreDisabledKeyForCurrentUser()) as bool?) ?? false;
    return !disabled;
  }

  Future<void> setAutoRestoreEnabled(bool enabled) async {
    if (_syncMetaBox == null) {
      return;
    }
    await _syncMetaBox.put(_autoRestoreDisabledKeyForCurrentUser(), !enabled);
  }

  Future<void> startFreshLocalData({ScaffoldMessengerState? messenger}) async {
    if (_eventsBox == null || _habitsBox == null) {
      _showSnackBar(messenger, 'Local storage unavailable.');
      return;
    }

    await _eventsBox.clear();
    await _habitsBox.clear();
    if (_syncMetaBox != null) {
      await _syncMetaBox.delete('last_synced_at');
      await _syncMetaBox.put('pending_sync', false);
    }
    _showSnackBar(messenger, 'Started fresh with empty local data.');
  }

  Future<void> clearCloudBackup({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync()) {
      _showSnackBar(messenger, 'Cloud backup unavailable in guest/offline mode.');
      return;
    }

    try {
      final String uid = _authService.currentUser!.uid;
      final CollectionReference<Map<String, dynamic>> eventsRef =
          _firestore!.collection('users').doc(uid).collection('events');
      final CollectionReference<Map<String, dynamic>> habitsRef =
          _firestore.collection('users').doc(uid).collection('habits');

      final QuerySnapshot<Map<String, dynamic>> eventsSnapshot = await eventsRef.get();
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot = await habitsRef.get();

      await _deleteDocsInBatches(eventsSnapshot.docs.map((doc) => doc.reference));
      await _deleteDocsInBatches(habitsSnapshot.docs.map((doc) => doc.reference));

      await _setLastSyncedNow();
      _showSnackBar(messenger, 'Cloud backup cleared (events/habits only).');
    } catch (_) {
      _showSnackBar(messenger, 'Failed to clear cloud backup.');
    }
  }

  Future<CloudBackupSummary> getCloudBackupSummary() async {
    if (!_canCloudSync()) {
      return const CloudBackupSummary(eventsCount: 0, habitsCount: 0);
    }

    try {
      final String uid = _authService.currentUser!.uid;
      final QuerySnapshot<Map<String, dynamic>> eventsSnapshot =
          await _firestore!.collection('users').doc(uid).collection('events').get();
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot =
          await _firestore.collection('users').doc(uid).collection('habits').get();

      return CloudBackupSummary(
        eventsCount: eventsSnapshot.docs.length,
        habitsCount: habitsSnapshot.docs.length,
      );
    } catch (_) {
      return const CloudBackupSummary(eventsCount: 0, habitsCount: 0);
    }
  }

  DateTime? get lastSyncedAt {
    final String? iso = _syncMetaBox?.get('last_synced_at') as String?;
    if (iso == null || iso.isEmpty) {
      return null;
    }
    return DateTime.tryParse(iso);
  }

  Future<void> syncAll({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync()) {
      _showSnackBar(messenger, 'Cloud sync unavailable in guest/offline mode.');
      return;
    }

    if (_eventsBox == null || _habitsBox == null) {
      _showSnackBar(messenger, 'Local storage unavailable.');
      return;
    }

    try {
      final WriteBatch batch = _firestore!.batch();
      final String uid = _authService.currentUser!.uid;

      for (final EventModel event in _eventsBox.values) {
        final DocumentReference<Map<String, dynamic>> ref = _eventDoc(uid, event.id);
        batch.set(ref, event.toFirestore(), SetOptions(merge: true));
      }

      for (final HabitModel habit in _habitsBox.values) {
        final DocumentReference<Map<String, dynamic>> ref = _habitDoc(uid, habit.id);
        batch.set(ref, habit.toFirestore(), SetOptions(merge: true));
      }

      await batch.commit();
      await _setLastSyncedNow();
      _showSnackBar(messenger, 'Sync completed successfully.');
    } catch (_) {
      _showSnackBar(messenger, 'Sync failed. Will retry when online.');
      await _enqueuePendingSync();
    }
  }

  Future<void> restoreAll({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync()) {
      return;
    }

    if (_eventsBox == null || _habitsBox == null) {
      return;
    }

    try {
      final String uid = _authService.currentUser!.uid;
      final QuerySnapshot<Map<String, dynamic>> eventsSnapshot =
          await _firestore!.collection('users').doc(uid).collection('events').get();
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot =
          await _firestore.collection('users').doc(uid).collection('habits').get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in eventsSnapshot.docs) {
        final EventModel remoteEvent = EventModel.fromFirestore(doc.data());
        final EventModel? localEvent = _eventsBox.get(remoteEvent.id);
        if (localEvent == null || remoteEvent.updatedAt.isAfter(localEvent.updatedAt)) {
          await _eventsBox.put(remoteEvent.id, remoteEvent);
        }
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in habitsSnapshot.docs) {
        final HabitModel remoteHabit = HabitModel.fromFirestore(doc.data());
        final HabitModel? localHabit = _habitsBox.get(remoteHabit.id);
        if (localHabit == null || remoteHabit.updatedAt.isAfter(localHabit.updatedAt)) {
          await _habitsBox.put(remoteHabit.id, remoteHabit);
        }
      }

      await _setLastSyncedNow();
      _showSnackBar(messenger, 'Restore completed.');
    } catch (_) {
      _showSnackBar(messenger, 'Restore failed.');
    }
  }

  Future<void> syncEvent(EventModel event) async {
    if (_eventsBox != null) {
      await _eventsBox.put(event.id, event);
    }
    if (!_canCloudSync()) {
      await _enqueuePendingSync();
      return;
    }

    await _eventDoc(_authService.currentUser!.uid, event.id).set(
      event.toFirestore(),
      SetOptions(merge: true),
    );
    await _setLastSyncedNow();
  }

  Future<void> syncHabit(HabitModel habit) async {
    if (_habitsBox != null) {
      await _habitsBox.put(habit.id, habit);
    }
    if (!_canCloudSync()) {
      await _enqueuePendingSync();
      return;
    }

    await _habitDoc(_authService.currentUser!.uid, habit.id).set(
      habit.toFirestore(),
      SetOptions(merge: true),
    );
    await _setLastSyncedNow();
  }

  Future<void> deleteEvent(String id) async {
    if (_eventsBox != null) {
      await _eventsBox.delete(id);
    }
    if (!_canCloudSync()) {
      await _enqueuePendingSync();
      return;
    }
    await _eventDoc(_authService.currentUser!.uid, id).delete();
    await _setLastSyncedNow();
  }

  Future<void> deleteHabit(String id) async {
    if (_habitsBox != null) {
      await _habitsBox.delete(id);
    }
    if (!_canCloudSync()) {
      await _enqueuePendingSync();
      return;
    }
    await _habitDoc(_authService.currentUser!.uid, id).delete();
    await _setLastSyncedNow();
  }

  Future<void> replayPendingSync() async {
    final bool pending = (_syncMetaBox?.get('pending_sync') as bool?) ?? false;
    if (!pending) {
      return;
    }
    final List<ConnectivityResult> connectivity = await _connectivity.checkConnectivity();
    if (!connectivity.any((ConnectivityResult e) => e != ConnectivityResult.none)) {
      return;
    }
    await syncAll();
    if (_syncMetaBox != null) {
      await _syncMetaBox.put('pending_sync', false);
    }
  }

  bool _canCloudSync() {
    return _firestore != null && _authService.isSignedIn;
  }

  Future<void> _setLastSyncedNow() async {
    if (_syncMetaBox != null) {
      await _syncMetaBox.put('last_synced_at', DateTime.now().toUtc().toIso8601String());
    }
  }

  Future<void> _enqueuePendingSync() async {
    if (_syncMetaBox != null) {
      await _syncMetaBox.put('pending_sync', true);
    }
  }

  DocumentReference<Map<String, dynamic>> _eventDoc(String uid, String id) {
    return _firestore!.collection('users').doc(uid).collection('events').doc(id);
  }

  DocumentReference<Map<String, dynamic>> _habitDoc(String uid, String id) {
    return _firestore!.collection('users').doc(uid).collection('habits').doc(id);
  }

  Future<void> _deleteDocsInBatches(
    Iterable<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const int maxWritesPerBatch = 450;
    final List<DocumentReference<Map<String, dynamic>>> list = refs.toList();
    for (int i = 0; i < list.length; i += maxWritesPerBatch) {
      final int end = (i + maxWritesPerBatch < list.length)
          ? i + maxWritesPerBatch
          : list.length;
      final WriteBatch batch = _firestore!.batch();
      for (int j = i; j < end; j++) {
        batch.delete(list[j]);
      }
      await batch.commit();
    }
  }

  void _showSnackBar(ScaffoldMessengerState? messenger, String text) {
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

class CloudBackupSummary {
  const CloudBackupSummary({
    required this.eventsCount,
    required this.habitsCount,
  });

  final int eventsCount;
  final int habitsCount;

  bool get hasBackup => eventsCount > 0 || habitsCount > 0;
}

