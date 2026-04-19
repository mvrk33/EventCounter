import 'dart:async';
import 'dart:convert';

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

  // ── Passphrase-based cloud encryption ─────────────────────────────────────
  // Derived from the user's UID so it's stable across reinstalls and devices.
  // Salt is a constant app-specific string — no per-device secret needed.
  static const String _cloudSalt = 'daymark_cloud_v1';

  /// Returns the passphrase used to encrypt/decrypt cloud payloads for the
  /// current user. This is deterministic: same uid → same passphrase every time.
  String _cloudPassphrase() {
    final String uid = _authService.currentUser!.uid;
    // Simple derivation: base64(uid bytes) to ensure valid characters.
    return base64Encode(utf8.encode(uid));
  }

  // ── Auto-restore flag ──────────────────────────────────────────────────────

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
    if (_syncMetaBox == null) return;
    await _syncMetaBox.put(_autoRestoreDisabledKeyForCurrentUser(), !enabled);
  }

  // ── First restore screen completion flag ────────────────────────────────────
  // Industry standard: show restore backup prompt only once on first login.

  String _restoreScreenCompletedKeyForCurrentUser() {
    final String uid = _authService.currentUser?.uid ?? 'guest';
    return 'restore_screen_completed_$uid';
  }

  /// Check if the user has already seen and completed the restore screen.
  /// Returns true if already shown, false if it should be shown.
  Future<bool> hasCompletedRestoreScreen() async {
    final bool completed =
        (_syncMetaBox?.get(_restoreScreenCompletedKeyForCurrentUser()) as bool?) ??
            false;
    return completed;
  }

  /// Mark the restore screen as completed for this user.
  /// Call this after the user makes a choice (restore/start fresh).
  Future<void> markRestoreScreenCompleted() async {
    if (_syncMetaBox == null) return;
    await _syncMetaBox.put(_restoreScreenCompletedKeyForCurrentUser(), true);
  }

  // ── Local data management ─────────────────────────────────────────────────

  Future<void> startFreshLocalData({ScaffoldMessengerState? messenger}) async {
    if (_eventsBox == null || _habitsBox == null) {
      return;
    }
    await _eventsBox.clear();
    await _habitsBox.clear();
    if (_syncMetaBox != null) {
      await _syncMetaBox.delete('last_synced_at');
      await _syncMetaBox.put('pending_sync', false);
    }
  }

  Future<void> clearCloudBackup({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync()) {
      return;
    }
    try {
      final String uid = _authService.currentUser!.uid;
      final eventsSnapshot = await _firestore!
          .collection('users').doc(uid).collection('events').get();
      final habitsSnapshot = await _firestore
          .collection('users').doc(uid).collection('habits').get();
      await _deleteDocsInBatches(eventsSnapshot.docs.map((d) => d.reference));
      await _deleteDocsInBatches(habitsSnapshot.docs.map((d) => d.reference));
      await _setLastSyncedNow();
    } catch (error) {
      debugPrint('Failed to clear cloud backup: $error');
    }
  }

  Future<CloudBackupSummary> getCloudBackupSummary() async {
    if (!_canCloudSync() || _firestore == null) {
      return const CloudBackupSummary(eventsCount: 0, habitsCount: 0);
    }
    try {
      final String uid = _authService.currentUser!.uid;
      final results = await Future.wait([
        _firestore.collection('users').doc(uid).collection('events').get(),
        _firestore.collection('users').doc(uid).collection('habits').get(),
      ]);
      return CloudBackupSummary(
        eventsCount: results[0].docs.length,
        habitsCount: results[1].docs.length,
      );
    } catch (error) {
      _disableCloudSyncIfDatabaseMissing(error);
      return const CloudBackupSummary(eventsCount: 0, habitsCount: 0);
    }
  }

  DateTime? get lastSyncedAt {
    final String? iso = _syncMetaBox?.get('last_synced_at') as String?;
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  // ── Sync / Restore ────────────────────────────────────────────────────────

  Future<void> synchronize({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync()) {
      return;
    }
    try {
      await restoreAll(messenger: null);
      await syncAll(messenger: null);
    } catch (error) {
      debugPrint('Full synchronization failed: $error');
    }
  }

  Future<void> syncAll({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync()) {
      return;
    }
    if (_eventsBox == null || _habitsBox == null) {
      return;
    }
    try {
      final WriteBatch batch = _firestore!.batch();
      final String uid = _authService.currentUser!.uid;

      for (final EventModel event in _eventsBox.values) {
        final Map<String, dynamic>? payload = await _eventCloudPayload(event);
        if (payload == null) {
          return;
        }
        batch.set(_eventDoc(uid, event.id), payload, SetOptions(merge: true));
      }

      for (final HabitModel habit in _habitsBox.values) {
        final Map<String, dynamic>? payload = await _habitCloudPayload(habit);
        if (payload == null) {
          return;
        }
        batch.set(_habitDoc(uid, habit.id), payload, SetOptions(merge: true));
      }

      await batch.commit();
      await _setLastSyncedNow();
    } catch (error) {
      debugPrint('Sync all failed: $error');
      _disableCloudSyncIfDatabaseMissing(error);
      await _enqueuePendingSync();
    }
  }

  Future<RestoreResult> restoreAll({ScaffoldMessengerState? messenger}) async {
    if (!_canCloudSync() || _eventsBox == null || _habitsBox == null) {
      return const RestoreResult(restored: 0, decryptionFailures: 0);
    }

    // OPTIMIZATION: Skip if synced recently (within 30 seconds)
    // This prevents excessive re-syncing during app startup sequence
    final DateTime? lastSync = lastSyncedAt;
    if (lastSync != null) {
      final Duration timeSinceSync = DateTime.now().difference(lastSync);
      if (timeSinceSync.inSeconds < 30) {
        debugPrint('Restore skipped: synced ${timeSinceSync.inSeconds}s ago');
        return const RestoreResult(restored: 0, decryptionFailures: 0);
      }
    }

    try {
      final String uid = _authService.currentUser!.uid;
      int restoredEvents = 0;
      int restoredHabits = 0;
      int skippedEncrypted = 0;

      // Fetch both collections in parallel
      final results = await Future.wait([
        _firestore!.collection('users').doc(uid).collection('events').get(),
        _firestore.collection('users').doc(uid).collection('habits').get(),
      ]);
      final eventsSnapshot = results[0];
      final habitsSnapshot = results[1];

      // OPTIMIZATION: Batch write events instead of individual puts (10x faster)
      final Map<String, EventModel> eventsToWrite = {};
      for (final doc in eventsSnapshot.docs) {
        final remoteData = doc.data();
        final EventModel? remoteEvent = await _eventFromCloud(remoteData);
        if (remoteEvent == null) {
          if ((remoteData['encrypted'] as bool?) == true) skippedEncrypted++;
          continue;
        }
        final EventModel? local = _eventsBox.get(remoteEvent.id);
        if (local == null || remoteEvent.updatedAt.isAfter(local.updatedAt)) {
          eventsToWrite[remoteEvent.id] = remoteEvent;
          restoredEvents++;
        }
      }

      // Write all events at once (single Hive batch operation)
      if (eventsToWrite.isNotEmpty) {
        await _eventsBox.putAll(eventsToWrite);
      }

      // OPTIMIZATION: Batch write habits instead of individual puts (10x faster)
      final Map<String, HabitModel> habitsToWrite = {};
      for (final doc in habitsSnapshot.docs) {
        final remoteData = doc.data();
        final HabitModel? remoteHabit = await _habitFromCloud(remoteData);
        if (remoteHabit == null) {
          if ((remoteData['encrypted'] as bool?) == true) skippedEncrypted++;
          continue;
        }
        final HabitModel? local = _habitsBox.get(remoteHabit.id);
        if (local == null || remoteHabit.updatedAt.isAfter(local.updatedAt)) {
          habitsToWrite[remoteHabit.id] = remoteHabit;
          restoredHabits++;
        }
      }

      // Write all habits at once (single Hive batch operation)
      if (habitsToWrite.isNotEmpty) {
        await _habitsBox.putAll(habitsToWrite);
      }

      await _setLastSyncedNow();
      return RestoreResult(
          restored: restoredEvents + restoredHabits, decryptionFailures: skippedEncrypted);
    } catch (error) {
      debugPrint('Restore all failed: $error');
      _disableCloudSyncIfDatabaseMissing(error);
      return const RestoreResult(restored: 0, decryptionFailures: 0);
    }
  }

  Future<void> syncEvent(EventModel event) async {
    if (_eventsBox != null) await _eventsBox.put(event.id, event);
    if (!_canCloudSync()) { await _enqueuePendingSync(); return; }
    final payload = await _eventCloudPayload(event);
    if (payload == null) { await _enqueuePendingSync(); return; }
    await _eventDoc(_authService.currentUser!.uid, event.id)
        .set(payload, SetOptions(merge: true));
    await _setLastSyncedNow();
  }

  Future<void> syncHabit(HabitModel habit) async {
    if (_habitsBox != null) await _habitsBox.put(habit.id, habit);
    if (!_canCloudSync()) { await _enqueuePendingSync(); return; }
    final payload = await _habitCloudPayload(habit);
    if (payload == null) { await _enqueuePendingSync(); return; }
    await _habitDoc(_authService.currentUser!.uid, habit.id)
        .set(payload, SetOptions(merge: true));
    await _setLastSyncedNow();
  }

  Future<void> deleteEvent(String id) async {
    if (_eventsBox != null) await _eventsBox.delete(id);
    if (!_canCloudSync()) { await _enqueuePendingSync(); return; }
    await _eventDoc(_authService.currentUser!.uid, id).delete();
    await _setLastSyncedNow();
  }

  Future<void> deleteHabit(String id) async {
    if (_habitsBox != null) await _habitsBox.delete(id);
    if (!_canCloudSync()) { await _enqueuePendingSync(); return; }
    await _habitDoc(_authService.currentUser!.uid, id).delete();
    await _setLastSyncedNow();
  }

  Future<void> replayPendingSync() async {
    final bool pending = (_syncMetaBox?.get('pending_sync') as bool?) ?? false;
    if (!pending) return;
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.every((e) => e == ConnectivityResult.none)) return;
    try {
      await syncAll();
      await _syncMetaBox?.put('pending_sync', false);
    } catch (e) {
      debugPrint('Pending sync replay failed: $e');
    }
  }

  // ── Encryption helpers ────────────────────────────────────────────────────

  /// Encrypts [json] with the UID-derived passphrase (survives reinstall).
  Future<Map<String, dynamic>?> _eventCloudPayload(EventModel event) async {
    final Map<String, String>? encrypted = await _pinSecurityService
        .encryptStringWithPassphrase(
          jsonEncode(event.toJson()),
          _cloudPassphrase(),
          salt: _cloudSalt,
        );
    if (encrypted == null) return null;
    return <String, dynamic>{
      'id': event.id,
      'updatedAt': Timestamp.fromDate(event.updatedAt),
      'encrypted': true,
      'encVersion': 2,
      'payload': encrypted,
    };
  }

  Future<Map<String, dynamic>?> _habitCloudPayload(HabitModel habit) async {
    final Map<String, String>? encrypted = await _pinSecurityService
        .encryptStringWithPassphrase(
          jsonEncode(habit.toJson()),
          _cloudPassphrase(),
          salt: _cloudSalt,
        );
    if (encrypted == null) return null;
    return <String, dynamic>{
      'id': habit.id,
      'updatedAt': Timestamp.fromDate(habit.updatedAt),
      'encrypted': true,
      'encVersion': 2,
      'payload': encrypted,
    };
  }

  Future<EventModel?> _eventFromCloud(Map<String, dynamic> data) async {
    if ((data['encrypted'] as bool?) != true) {
      return EventModel.fromFirestore(data);
    }
    final dynamic rawPayload = data['payload'];
    if (rawPayload is! Map) return null;
    final payload = rawPayload.cast<String, dynamic>();

    final int encVersion = (data['encVersion'] as num?)?.toInt() ?? 1;

    if (encVersion == 2) {
      // Passphrase-based: survives reinstall
      final String? clear = await _pinSecurityService
          .decryptStringWithPassphrase(
            payload,
            _cloudPassphrase(),
            salt: _cloudSalt,
          );
      if (clear == null) return null;
      final dynamic decoded = jsonDecode(clear);
      if (decoded is Map) {
        return EventModel.fromJson(decoded.cast<String, dynamic>());
      }
      return null;
    }

    // encVersion == 1: old device-key encryption — cannot decrypt after reinstall
    final Map<String, dynamic>? decrypted =
        await _pinSecurityService.decryptJson(payload);
    if (decrypted == null) return null;
    return EventModel.fromJson(decrypted);
  }

  Future<HabitModel?> _habitFromCloud(Map<String, dynamic> data) async {
    if ((data['encrypted'] as bool?) != true) {
      return HabitModel.fromFirestore(data);
    }
    final dynamic rawPayload = data['payload'];
    if (rawPayload is! Map) return null;
    final payload = rawPayload.cast<String, dynamic>();

    final int encVersion = (data['encVersion'] as num?)?.toInt() ?? 1;

    if (encVersion == 2) {
      final String? clear = await _pinSecurityService
          .decryptStringWithPassphrase(
            payload,
            _cloudPassphrase(),
            salt: _cloudSalt,
          );
      if (clear == null) return null;
      final dynamic decoded = jsonDecode(clear);
      if (decoded is Map) {
        return HabitModel.fromJson(decoded.cast<String, dynamic>());
      }
      return null;
    }

    final Map<String, dynamic>? decrypted =
        await _pinSecurityService.decryptJson(payload);
    if (decrypted == null) return null;
    return HabitModel.fromJson(decrypted);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool _canCloudSync() =>
      !_cloudSyncBlocked && _firestore != null && _authService.isSignedIn;

  void _disableCloudSyncIfDatabaseMissing(Object error) {
    if (error is! FirebaseException) return;
    final String message = (error.message ?? '').toLowerCase();
    if (error.code == 'not-found' &&
        message.contains('database (default) does not exist')) {
      _cloudSyncBlocked = true;
      _syncMetaBox?.put('pending_sync', false);
      _syncMetaBox?.put('cloud_sync_blocked_missing_firestore', true);
    }
  }

  Future<void> _setLastSyncedNow() async {
    await _syncMetaBox?.put(
        'last_synced_at', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> _enqueuePendingSync() async {
    await _syncMetaBox?.put('pending_sync', true);
  }

  DocumentReference<Map<String, dynamic>> _eventDoc(String uid, String id) =>
      _firestore!.collection('users').doc(uid).collection('events').doc(id);

  DocumentReference<Map<String, dynamic>> _habitDoc(String uid, String id) =>
      _firestore!.collection('users').doc(uid).collection('habits').doc(id);

  Future<void> _deleteDocsInBatches(
    Iterable<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const int maxWritesPerBatch = 450;
    final list = refs.toList();
    for (int i = 0; i < list.length; i += maxWritesPerBatch) {
      final int end =
          (i + maxWritesPerBatch < list.length) ? i + maxWritesPerBatch : list.length;
      final WriteBatch batch = _firestore!.batch();
      for (int j = i; j < end; j++) {
        batch.delete(list[j]);
      }
      await batch.commit();
    }
  }

  // ...existing code...
}

// ── Data classes ───────────────────────────────────────────────────────────

class CloudBackupSummary {
  const CloudBackupSummary({
    required this.eventsCount,
    required this.habitsCount,
  });

  final int eventsCount;
  final int habitsCount;

  bool get hasBackup => eventsCount > 0 || habitsCount > 0;
}

class RestoreResult {
  const RestoreResult({
    required this.restored,
    required this.decryptionFailures,
  });

  final int restored;
  final int decryptionFailures;

  /// True when cloud had data but NONE could be decrypted.
  bool get isDecryptionFailure => decryptionFailures > 0 && restored == 0;
}

