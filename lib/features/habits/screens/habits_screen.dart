import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/date_helpers.dart';
import '../models/habit_model.dart';
import '../providers/habits_provider.dart';
import '../widgets/streak_calendar.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Compute totals
    final int activeStreaks = habits.where((h) => h.currentStreak > 0).length;
    final int checkedToday = habits.where((h) {
      final today = DateHelpers.normalizeDay(DateTime.now());
      return h.checkIns.any((d) => DateHelpers.sameDay(d, today));
    }).length;

    return CustomScrollView(
      slivers: <Widget>[
        // ── Header ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Title row
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Habits',
                              style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 2),
                          Text(
                            habits.isEmpty
                                ? 'Start tracking your streaks'
                                : '${habits.length} habit${habits.length == 1 ? '' : 's'} tracked',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.50),
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddHabitDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New habit'),
                    ),
                  ],
                ),
                // ── Summary banner (only if we have habits) ───────────
                if (habits.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF2C1A0E), const Color(0xFF3A200A)]
                            : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.18),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        _HabitSummaryBadge(
                          icon: '🔥',
                          label: 'On streak',
                          value: '$activeStreaks',
                          color: Colors.orange,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.orange.withValues(alpha: 0.25),
                        ),
                        _HabitSummaryBadge(
                          icon: '✅',
                          label: 'Done today',
                          value: '$checkedToday / ${habits.length}',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // ── Empty state ───────────────────────────────────────────────
        if (habits.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withValues(alpha: 0.08),
                            ),
                          ),
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withValues(alpha: 0.14),
                            ),
                          ),
                          const Text('🔥', style: TextStyle(fontSize: 40)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('No habits yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                    const SizedBox(height: 10),
                    Text(
                      'Tap "New habit" above to start\nyour first daily streak.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.50),
                            height: 1.55,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) =>
                    _HabitCard(habit: habits[index], ref: ref),
                childCount: habits.length,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddHabitDialog(BuildContext context, WidgetRef ref) async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController emojiController = TextEditingController(text: '✅');

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Habit name',
                  prefixIcon: Icon(Icons.local_fire_department_rounded),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  prefixIcon: Icon(Icons.emoji_emotions_outlined),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final String title = titleController.text.trim();
                if (title.isEmpty) return;
                await ref.read(habitsProvider.notifier).addHabit(
                      title: title,
                      color: Colors.orange.toARGB32(),
                      emoji: emojiController.text.trim().isEmpty
                          ? '✅'
                          : emojiController.text.trim(),
                    );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.ref});

  final HabitModel habit;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color habitColor = Color(habit.color);
    final bool checkedToday = _isCheckedToday();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: habitColor.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          // ── Coloured header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
            decoration: BoxDecoration(
              color: habitColor.withValues(alpha: isDark ? 0.12 : 0.07),
            ),
            child: Row(
              children: <Widget>[
                // Emoji circle
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        habitColor.withValues(alpha: 0.20),
                        habitColor.withValues(alpha: 0.10),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(habit.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                // Title + streak badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        habit.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: <Widget>[
                          _StreakBadge(
                            icon: '🔥',
                            label: '${habit.currentStreak} streak',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _StreakBadge(
                            icon: '🏆',
                            label: '${habit.longestStreak} best',
                            color: Colors.amber.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.28),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // ── Calendar section ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: StreakCalendar(
              checkIns: habit.checkIns,
              accentColor: habitColor,
            ),
          ),
          // ── Check-in button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: checkedToday
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Done today ✓'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          ref.read(habitsProvider.notifier).checkInToday(habit),
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: const Text('Check in today'),
                      style: FilledButton.styleFrom(
                        backgroundColor: habitColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCheckedToday() {
    final DateTime today = DateHelpers.normalizeDay(DateTime.now());
    return habit.checkIns.any((DateTime d) => DateHelpers.sameDay(d, today));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('Delete "${habit.title}"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(habitsProvider.notifier).deleteHabit(habit.id);
    }
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary badge used in the habits hero panel ───────────────────────────
class _HabitSummaryBadge extends StatelessWidget {
  const _HabitSummaryBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

