import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/date_helpers.dart';
import '../models/event_model.dart';
import '../providers/events_provider.dart';

class EventDetailModal extends ConsumerStatefulWidget {
  const EventDetailModal({required this.event, super.key});

  final EventModel event;

  @override
  ConsumerState<EventDetailModal> createState() => _EventDetailModalState();
}

class _EventDetailModalState extends ConsumerState<EventDetailModal> {
  @override
  Widget build(BuildContext context) {
    final EventModel event = _resolvedEvent();
    final int value = DateHelpers.eventCountValue(event);
    final String countPhrase = DateHelpers.eventCountPhrase(event);
    final bool isCountdown = event.mode == EventMode.countdown;
    final Color accentColor = Color(event.color);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: <Widget>[
            // ── Drag handle ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // ── Header row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      event.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: event.isPinned ? accentColor : null,
                    ),
                    tooltip: event.isPinned ? 'Unpin' : 'Pin to top',
                    onPressed: () async {
                      await ref
                          .read(eventsProvider.notifier)
                          .togglePinned(event);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Edit event',
                    onPressed: () => Navigator.of(context).pop('edit'),
                  ),
                ],
              ),
            ),
            // ── Scrollable body ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ── Hero card ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            accentColor,
                            Color.lerp(accentColor, Colors.black, 0.18)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: <Widget>[
                          // ── Emoji watermark ────────────────────────────
                          Positioned(
                            right: -12,
                            bottom: -16,
                            child: Opacity(
                              opacity: 0.15,
                              child: Text(
                                event.emoji,
                                style: const TextStyle(
                                  fontSize: 110,
                                  fontFamily: 'sans-serif',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // ── Content ─────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          event.emoji,
                                          style: const TextStyle(
                                            fontSize: 30,
                                            fontFamily: 'sans-serif',
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Category badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.20),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        event.category,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('MMMM d, y').format(event.date),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                // ── Big countdown / countup number ──────
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Text(
                                        '$value',
                                        key: ValueKey<int>(value),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 64,
                                          fontWeight: FontWeight.w900,
                                          height: 1.0,
                                          letterSpacing: -2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            countPhrase,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.90),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            isCountdown
                                                ? 'remaining'
                                                : 'elapsed',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.62),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Info section ─────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: <Widget>[
                          _InfoRow(
                            icon: Icons.push_pin_rounded,
                            label: 'Pinned',
                            value: event.isPinned ? 'Yes' : 'No',
                            iconColor: accentColor,
                          ),
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Created',
                            value:
                                DateFormat('MMM d, y').format(event.createdAt),
                            iconColor: accentColor,
                          ),
                          _InfoRow(
                            icon: Icons.timer_rounded,
                            label: 'Count unit',
                            value: event.countUnit.name[0].toUpperCase() +
                                event.countUnit.name.substring(1),
                            iconColor: accentColor,
                          ),
                          _InfoRow(
                            icon: Icons.notifications_rounded,
                            label: 'Reminders',
                            value: event.reminderDays.isEmpty
                                ? 'None'
                                : event.reminderDays
                                    .map((int d) =>
                                        d == 0 ? 'On day' : '$d d before')
                                    .join(', '),
                            iconColor: accentColor,
                          ),
                          if (event.duration != null)
                            _InfoRow(
                              icon: Icons.access_time_rounded,
                              label: 'Est. Duration',
                              value: '${event.duration!.inHours}h ${event.duration!.inMinutes % 60}m',
                              iconColor: accentColor,
                            ),
                          _InfoRow(
                            icon: Icons.mood_rounded,
                            label: 'Predicted Mood',
                            value: event.mood ?? 'Neutral',
                            iconColor: accentColor,
                          ),
                          _InfoRow(
                            icon: Icons.commute_rounded,
                            label: 'Travel Needed',
                            value: event.requiresTravel ? 'Yes' : 'No',
                            iconColor: accentColor,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    // ── Checklist ──────────────────────────────────────────
                    if (event.checklist.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.checklist_rounded,
                                    color: accentColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Preparation Checklist',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: accentColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...event.checklist.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          size: 16, color: accentColor.withValues(alpha: 0.6)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                    // ── Notes ──────────────────────────────────────────
                    if (event.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.notes_rounded,
                                    color: accentColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Notes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: accentColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              event.notes,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // ── Actions ─────────────────────────────────────────
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop('edit'),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                Navigator.of(context).pop('add_widget'),
                            icon: const Icon(Icons.add_to_home_screen_rounded,
                                size: 18),
                            label: const Text('Widget'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop('delete'),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete event'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.45)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  EventModel _resolvedEvent() {
    final List<EventModel> events = ref.watch(eventsProvider);
    for (final EventModel event in events) {
      if (event.id == widget.event.id) return event;
    }
    return widget.event;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            indent: 62,
            endIndent: 16,
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }
}
