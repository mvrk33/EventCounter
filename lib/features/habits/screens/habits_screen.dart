import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            habits.isEmpty
                                ? 'Start tracking your streaks'
                                : '${habits.length} habit${habits.length == 1 ? '' : 's'} tracked',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.50),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: () => _showAddHabitDialog(context, ref),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New habit', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                // ── Summary banner (only if we have habits) ───────────
                if (habits.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF2C1A0E), const Color(0xFF1E1E1E)]
                            : [const Color(0xFFFFF3E0), Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _HabitSummaryBadge(
                              icon: '🔥',
                              label: 'On streak',
                              value: '$activeStreaks',
                              color: Colors.orange,
                            ),
                          ),
                          VerticalDivider(
                            color: Colors.orange.withValues(alpha: 0.2),
                            thickness: 1,
                            width: 32,
                            indent: 4,
                            endIndent: 4,
                          ),
                          Expanded(
                            child: _HabitSummaryBadge(
                              icon: '✅',
                              label: 'Done today',
                              value: '$checkedToday/${habits.length}',
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
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
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'New Habit',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              _FormCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Habit name (e.g. Read 20 mins)',
                    hintStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.local_fire_department_rounded, color: scheme.primary),
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 16),
              _FormCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: emojiController,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Emoji',
                    hintStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.emoji_emotions_outlined, color: scheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
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
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: scheme.primary,
                  ),
                  child: Text(
                    'Create Habit',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared Helpers ──────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: habitColor.withValues(alpha: isDark ? 0.15 : 0.08),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: habitColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 14, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  habitColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  habitColor.withValues(alpha: isDark ? 0.05 : 0.02),
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                // Emoji circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: habitColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(habit.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                // Title + streak badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        habit.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          _StreakBadge(
                            icon: '🔥',
                            label: '${habit.currentStreak} day streak',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _StreakBadge(
                            icon: '🏆',
                            label: '${habit.longestStreak} best',
                            color: Colors.amber.shade800,
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
                    Icons.more_vert_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.3),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          // ── Calendar section ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
              height: 52,
              child: checkedToday
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Completed today',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.6),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

