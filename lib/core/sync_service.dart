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
import 'pin_security_service.dart';

final Provider<SyncService> syncServiceProvider =
    Provider<SyncService>((Ref ref) {
  return SyncService(
    authService: ref.read(authServiceProvider),
    pinSecurityService: ref.read(pinSecurityServiceProvider),
    firestore: Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null,
    eventsBox: Hive.isBoxOpen(HiveBoxes.events)
        ? Hive.box<EventModel>(HiveBoxes.events)
        : null,
    habitsBox: Hive.isBoxOpen(HiveBoxes.habits)
        ? Hive.box<HabitModel>(HiveBoxes.habits)
        : null,
    syncMetaBox: Hive.isBoxOpen(HiveBoxes.syncMeta)
        ? Hive.box<dynamic>(HiveBoxes.syncMeta)
        : null,
    connectivity: Connectivity(),
  );
});

class SyncService {
  SyncService({
    required AuthService authService,
    required PinSecurityService pinSecurityService,
    required FirebaseFirestore? firestore,
    required Box<EventModel>? eventsBox,
    required Box<HabitModel>? habitsBox,
    required Box<dynamic>? syncMetaBox,
    required Connectivity connectivity,
  })  : _authService = authService,
        _pinSecurityService = pinSecurityService,
        _firestore = firestore,
        _eventsBox = eventsBox,
        _habitsBox = habitsBox,
        _syncMetaBox = syncMetaBox,
        _connectivity = connectivity;

  final AuthService _authService;
  final PinSecurityService _pinSecurityService;
  final FirebaseFirestore? _firestore;
  final Box<EventModel>? _eventsBox;
  final Box<HabitModel>? _habitsBox;
  final Box<dynamic>? _syncMetaBox;
  final Connectivity _connectivity;
  bool _cloudSyncBlocked = false;

  String _autoRestoreDisabledKeyForCurrentUser() {
    final String uid = _authService.currentUser?.uid ?? 'guest';
    return 'disable_auto_restore_$uid';
  }

  Future<bool> shouldAutoRestoreOnLaunch() async {
    final bool disabled =
        (_syncMetaBox?.get(_autoRestoreDisabledKeyForCurrentUser()) as bool?) ??
            false;
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
      _showSnackBar(
          messenger, 'Cloud backup unavailable in guest/offline mode.');
      return;
    }

    try {
      final String uid = _authService.currentUser!.uid;
      final CollectionReference<Map<String, dynamic>> eventsRef =
          _firestore!.collection('users').doc(uid).collection('events');
      final CollectionReference<Map<String, dynamic>> habitsRef =
          _firestore.collection('users').doc(uid).collection('habits');

      final QuerySnapshot<Map<String, dynamic>> eventsSnapshot =
          await eventsRef.get();
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot =
          await habitsRef.get();

      await _deleteDocsInBatches(
          eventsSnapshot.docs.map((doc) => doc.reference));
      await _deleteDocsInBatches(
          habitsSnapshot.docs.map((doc) => doc.reference));

      await _setLastSyncedNow();
      _showSnackBar(messenger, 'Cloud backup cleared (events/habits only).');
    } catch (error) {
      debugPrint('Failed to clear cloud backup: $error');
      _showSnackBar(messenger, 'Failed to clear cloud backup.');
    }
  }

  Future<CloudBackupSummary> getCloudBackupSummary() async {
    if (!_canCloudSync()) {
      return const CloudBackupSummary(eventsCount: 0, habitsCount: 0);
    }
    final FirebaseFirestore? firestore = _firestore;
    if (firestore == null) {
      return const CloudBackupSummary(eventsCount: 0, habitsCount: 0);
    }

    try {
      final String uid = _authService.currentUser!.uid;
      // Run queries in parallel for better latency (vs sequential)
      final Future<QuerySnapshot<Map<String, dynamic>>> eventsFuture =
          firestore
              .collection('users')
              .doc(uid)
              .collection('events')
              .get();
      final Future<QuerySnapshot<Map<String, dynamic>>> habitsFuture =
          firestore
              .collection('users')
              .doc(uid)
              .collection('habits')
              .get();

      // Execute both in parallel instead of waiting for first to complete
      final List<QuerySnapshot<Map<String, dynamic>>> results =
          await Future.wait<QuerySnapshot<Map<String, dynamic>>>(
        <Future<QuerySnapshot<Map<String, dynamic>>>>[
          eventsFuture,
          habitsFuture,
        ],
      );
      final int eventsCount = results[0].docs.length;
      final int habitsCount = results[1].docs.length;

      return CloudBackupSummary(
        eventsCount: eventsCount,
        habitsCount: habitsCount,
      );
    } catch (error) {
      _disableCloudSyncIfDatabaseMissing(error);
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
        final DocumentReference<Map<String, dynamic>> ref =
            _eventDoc(uid, event.id);
        final Map<String, dynamic>? payload = await _eventCloudPayload(event);
        if (payload == null) {
          _showSnackBar(messenger, 'Set a PIN to use encrypted cloud sync.');
          return;
        }
        batch.set(ref, payload, SetOptions(merge: true));
      }

      for (final HabitModel habit in _habitsBox.values) {
        final DocumentReference<Map<String, dynamic>> ref =
            _habitDoc(uid, habit.id);
        final Map<String, dynamic>? payload = await _habitCloudPayload(habit);
        if (payload == null) {
          _showSnackBar(messenger, 'Set a PIN to use encrypted cloud sync.');
          return;
        }
        batch.set(ref, payload, SetOptions(merge: true));
      }

      await batch.commit();
      await _setLastSyncedNow();
      _showSnackBar(messenger, 'Sync completed successfully.');
    } catch (error) {
      debugPrint('Sync all failed: $error');
      _disableCloudSyncIfDatabaseMissing(error);
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
          await _firestore!
              .collection('users')
              .doc(uid)
              .collection('events')
              .get();
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('habits')
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in eventsSnapshot.docs) {
        final EventModel? remoteEvent = await _eventFromCloud(doc.data());
        if (remoteEvent == null) {
          continue;
        }
        final EventModel? localEvent = _eventsBox.get(remoteEvent.id);
        if (localEvent == null ||
            remoteEvent.updatedAt.isAfter(localEvent.updatedAt)) {
          await _eventsBox.put(remoteEvent.id, remoteEvent);
        }
      }

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in habitsSnapshot.docs) {
        final HabitModel? remoteHabit = await _habitFromCloud(doc.data());
        if (remoteHabit == null) {
          continue;
        }
        final HabitModel? localHabit = _habitsBox.get(remoteHabit.id);
        if (localHabit == null ||
            remoteHabit.updatedAt.isAfter(localHabit.updatedAt)) {
          await _habitsBox.put(remoteHabit.id, remoteHabit);
        }
      }

      await _setLastSyncedNow();
      _showSnackBar(messenger, 'Restore completed.');
    } catch (error) {
      debugPrint('Restore all failed: $error');
      _disableCloudSyncIfDatabaseMissing(error);
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

    final Map<String, dynamic>? payload = await _eventCloudPayload(event);
    if (payload == null) {
      await _enqueuePendingSync();
      return;
    }
    await _eventDoc(_authService.currentUser!.uid, event.id)
        .set(payload, SetOptions(merge: true));
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

    final Map<String, dynamic>? payload = await _habitCloudPayload(habit);
    if (payload == null) {
      await _enqueuePendingSync();
      return;
    }
    await _habitDoc(_authService.currentUser!.uid, habit.id)
        .set(payload, SetOptions(merge: true));
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
    final List<ConnectivityResult> connectivity =
        await _connectivity.checkConnectivity();
    // Check if device is online (has ANY connection that is NOT none)
    if (connectivity.every((ConnectivityResult e) => e == ConnectivityResult.none)) {
      return;
    }
    try {
      await syncAll();
      if (_syncMetaBox != null) {
        await _syncMetaBox.put('pending_sync', false);
      }
    } catch (e) {
      debugPrint('Pending sync replay failed: $e');
      // Keep pending_sync flag set to retry later
    }
  }

  bool _canCloudSync() {
    return !_cloudSyncBlocked && _firestore != null && _authService.isSignedIn;
  }

  void _disableCloudSyncIfDatabaseMissing(Object error) {
    final bool isFirebaseError = error is FirebaseException;
    if (!isFirebaseError) {
      return;
    }

    final FirebaseException firebaseError = error;
    final String message = (firebaseError.message ?? '').toLowerCase();
    final bool missingDefaultDatabase =
        firebaseError.code == 'not-found' && message.contains('database (default) does not exist');
    if (missingDefaultDatabase) {
      _cloudSyncBlocked = true;
      _syncMetaBox?.put('pending_sync', false);
      _syncMetaBox?.put('cloud_sync_blocked_missing_firestore', true);
    }
  }

  // Encryption is always on for cloud sync.
  Future<Map<String, dynamic>?> _eventCloudPayload(EventModel event) async {
    await _pinSecurityService.ensureEncryptionKey();
    final Map<String, String>? encrypted =
        await _pinSecurityService.encryptJson(event.toJson());
    if (encrypted == null) return null;
    return <String, dynamic>{
      'id': event.id,
      'updatedAt': Timestamp.fromDate(event.updatedAt),
      'encrypted': true,
      'payload': encrypted,
    };
  }

  Future<Map<String, dynamic>?> _habitCloudPayload(HabitModel habit) async {
    await _pinSecurityService.ensureEncryptionKey();
    final Map<String, String>? encrypted =
        await _pinSecurityService.encryptJson(habit.toJson());
    if (encrypted == null) return null;
    return <String, dynamic>{
      'id': habit.id,
      'updatedAt': Timestamp.fromDate(habit.updatedAt),
      'encrypted': true,
      'payload': encrypted,
    };
  }

  Future<EventModel?> _eventFromCloud(Map<String, dynamic> data) async {
    if ((data['encrypted'] as bool?) != true) {
      return EventModel.fromFirestore(data);
    }
    final dynamic payload = data['payload'];
    if (payload is! Map) {
      return null;
    }
    final Map<String, dynamic>? decrypted =
        await _pinSecurityService.decryptJson(payload.cast<String, dynamic>());
    if (decrypted == null) {
      return null;
    }
    return EventModel.fromJson(decrypted);
  }

  Future<HabitModel?> _habitFromCloud(Map<String, dynamic> data) async {
    if ((data['encrypted'] as bool?) != true) {
      return HabitModel.fromFirestore(data);
    }
    final dynamic payload = data['payload'];
    if (payload is! Map) {
      return null;
    }
    final Map<String, dynamic>? decrypted =
        await _pinSecurityService.decryptJson(payload.cast<String, dynamic>());
    if (decrypted == null) {
      return null;
    }
    return HabitModel.fromJson(decrypted);
  }

  Future<void> _setLastSyncedNow() async {
    if (_syncMetaBox != null) {
      await _syncMetaBox.put(
          'last_synced_at', DateTime.now().toUtc().toIso8601String());
    }
  }

  Future<void> _enqueuePendingSync() async {
    if (_syncMetaBox != null) {
      await _syncMetaBox.put('pending_sync', true);
    }
  }

  DocumentReference<Map<String, dynamic>> _eventDoc(String uid, String id) {
    return _firestore!
        .collection('users')
        .doc(uid)
        .collection('events')
        .doc(id);
  }

  DocumentReference<Map<String, dynamic>> _habitDoc(String uid, String id) {
    return _firestore!
        .collection('users')
        .doc(uid)
        .collection('habits')
        .doc(id);
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
