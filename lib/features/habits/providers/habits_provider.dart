import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../../../core/hive_boxes.dart';
import '../../../core/sync_service.dart';
import '../../events/providers/events_provider.dart';
import '../../../shared/utils/date_helpers.dart';
import '../models/habit_model.dart';

final StateNotifierProvider<HabitsNotifier, List<HabitModel>> habitsProvider =
    StateNotifierProvider<HabitsNotifier, List<HabitModel>>((Ref ref) {
  return HabitsNotifier(
    box: Hive.box<HabitModel>(HiveBoxes.habits),
    syncService: ref.read(syncServiceProvider),
    uuid: ref.read(uuidProvider),
  );
});

class HabitsNotifier extends StateNotifier<List<HabitModel>> {
  HabitsNotifier({
    required Box<HabitModel> box,
    required SyncService syncService,
    required Uuid uuid,
  })  : _box = box,
        _syncService = syncService,
        _uuid = uuid,
        super(box.values.toList(growable: false)) {
    _listenBox();
  }

  final Box<HabitModel> _box;
  final SyncService _syncService;
  final Uuid _uuid;
  late final ValueListenable<Box<HabitModel>> _boxListenable = _box.listenable();
  VoidCallback? _boxListener;

  void _listenBox() {
    _boxListener = () {
      state = _box.values.toList(growable: false);
    };
    _boxListenable.addListener(_boxListener!);
  }

  @override
  void dispose() {
    if (_boxListener != null) {
      _boxListenable.removeListener(_boxListener!);
    }
    super.dispose();
  }

  Future<void> addHabit({
    required String title,
    required int color,
    required String emoji,
  }) async {
    final DateTime now = DateTime.now();
    final HabitModel habit = HabitModel(
      id: _uuid.v4(),
      title: title.trim(),
      color: color,
      emoji: emoji,
      checkIns: <DateTime>[],
      currentStreak: 0,
      longestStreak: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _syncService.syncHabit(habit);
  }

  // Adds one daily check-in and recomputes streak counters.
  Future<void> checkInToday(HabitModel habit) async {
    final DateTime today = DateHelpers.normalizeDay(DateTime.now());
    final Set<DateTime> normalized = habit.checkIns.map(DateHelpers.normalizeDay).toSet();
    if (normalized.any((DateTime d) => DateHelpers.sameDay(d, today))) {
      return;
    }
    normalized.add(today);

    final List<DateTime> sorted = normalized.toList()..sort();
    final int current = _computeCurrentStreak(sorted);
    final int longest = _computeLongestStreak(sorted);

    await _syncService.syncHabit(
      habit.copyWith(
        checkIns: sorted,
        currentStreak: current,
        longestStreak: longest,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteHabit(String id) async {
    await _syncService.deleteHabit(id);
  }

  int _computeCurrentStreak(List<DateTime> checkIns) {
    if (checkIns.isEmpty) {
      return 0;
    }

    final DateTime today = DateHelpers.normalizeDay(DateTime.now());
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime last = DateHelpers.normalizeDay(checkIns.last);

    if (!DateHelpers.sameDay(last, today) && !DateHelpers.sameDay(last, yesterday)) {
      return 0;
    }

    int streak = 1;
    for (int i = checkIns.length - 1; i > 0; i--) {
      final DateTime current = DateHelpers.normalizeDay(checkIns[i]);
      final DateTime previous = DateHelpers.normalizeDay(checkIns[i - 1]);
      if (current.difference(previous).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeLongestStreak(List<DateTime> checkIns) {
    if (checkIns.isEmpty) {
      return 0;
    }

    int longest = 1;
    int current = 1;
    for (int i = 1; i < checkIns.length; i++) {
      final int diff = DateHelpers.normalizeDay(checkIns[i])
          .difference(DateHelpers.normalizeDay(checkIns[i - 1]))
          .inDays;
      if (diff == 1) {
        current++;
      } else if (diff > 1) {
        current = 1;
      }
      if (current > longest) {
        longest = current;
      }
    }
    return longest;
  }
}
