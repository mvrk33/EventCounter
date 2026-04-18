import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../../../shared/utils/date_helpers.dart';

enum EventCardDensity {
  compact,
  comfortable,
}

class EventCardPolished extends StatelessWidget {
  const EventCardPolished({
    required this.event,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
    this.onAddToHomeScreen,
    this.onEdit,
    this.density = EventCardDensity.comfortable,
    super.key,
  });

  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onAddToHomeScreen;
  final VoidCallback? onEdit;
  final EventCardDensity density;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int value = DateHelpers.eventCountValue(event);
    final String compactDescription = DateHelpers.eventCountCompactDescription(event);
    final String fullDescription = DateHelpers.eventCountDescription(event);
    final Color accent = Color(event.color);
    final bool comfortable = density == EventCardDensity.comfortable;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: comfortable ? 8 : 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: scheme.surface,
          child: InkWell(
            onTap: onTap,
            splashColor: accent.withValues(alpha: 0.08),
            highlightColor: accent.withValues(alpha: 0.04),
            child: Stack(
              children: <Widget>[
                // ── Subtle gradient tint (left-side colour hint) ──────────
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: comfortable ? 120 : 90,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          accent.withValues(alpha: 0.07),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                // ── Main content ──────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(14, comfortable ? 16 : 14, 6, 14),
                  child: comfortable
                      ? _buildComfortableLayout(
                          context,
                          accent,
                          value,
                          compactDescription,
                          fullDescription,
                        )
                      : _buildCompactLayout(
                          context,
                          accent,
                          value,
                          compactDescription,
                          scheme,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComfortableLayout(
    BuildContext context,
    Color accent,
    int value,
    String compactDescription,
    String fullDescription,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAvatar(accent, 64, 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (event.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.push_pin_rounded, size: 15, color: accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Next occurrence info ──────────────────────────────────
                  _buildNextOccurrenceInfo(context, scheme, accent),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildCountBadge(context, accent, value, compactDescription, large: true),
          ],
        ),
        if (event.notes.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            event.notes.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  height: 1.3,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                fullDescription,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildShareButton(context),
            _buildMenuButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    Color accent,
    int value,
    String compactDescription,
    ColorScheme scheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildAvatar(accent, 56, 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (event.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.push_pin_rounded, size: 14, color: accent),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // ── Next occurrence info ──────────────────────────────────
              _buildNextOccurrenceInfoCompact(context, scheme, accent),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _buildCountBadge(context, accent, value, compactDescription, large: false),
        _buildShareButton(context),
        _buildMenuButton(context),
      ],
    );
  }

  Widget _buildAvatar(Color accent, double size, double emojiSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: Text(event.emoji, style: TextStyle(fontSize: emojiSize))),
    );
  }

  Widget _buildCountBadge(
    BuildContext context,
    Color accent,
    int value,
    String compactDescription, {
    required bool large,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(horizontal: large ? 13 : 11, vertical: large ? 7 : 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Text(
            '$value',
            style: (large ? textTheme.headlineSmall : textTheme.titleLarge)?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          compactDescription,
          style: textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50),
          ),
        ),
      ],
    );
  }

  Widget _buildShareButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onShare,
      icon: Icon(
        Icons.ios_share_rounded,
        size: 18,
        color: scheme.onSurface.withValues(alpha: 0.32),
      ),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      onSelected: (String v) {
        switch (v) {
          case 'edit':
            onEdit?.call();
          case 'add_widget':
            onAddToHomeScreen?.call();
          case 'delete':
            onDelete.call();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: <Widget>[
              Icon(Icons.edit_rounded, size: 16),
              SizedBox(width: 12),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'add_widget',
          child: Row(
            children: <Widget>[
              Icon(Icons.add_to_home_screen_rounded, size: 16),
              SizedBox(width: 12),
              Text('Add to Home'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: scheme.onSurface.withValues(alpha: 0.32),
      ),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildNextOccurrenceInfo(
    BuildContext context,
    ColorScheme scheme,
    Color accent,
  ) {
    final DateTime now = DateTime.now();
    final DateTime nextOccurrence = event.nextOccurrenceDate;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime nextDate =
        DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);

    // Calculate days since last occurrence and days until next
    final int daysSince = DateHelpers.daysBetween(event.date, now).abs();
    final int daysUntil = DateHelpers.daysBetween(now, nextOccurrence).abs();

    String info;
    if (nextDate.isBefore(today)) {
      // Past event, show days since
      info = '$daysSince days since';
    } else if (DateHelpers.sameDay(nextDate, today)) {
      // Today
      info = 'Today';
    } else {
      // Future event, show days until
      info = '$daysUntil days to go';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        info,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.9),
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildNextOccurrenceInfoCompact(
    BuildContext context,
    ColorScheme scheme,
    Color accent,
  ) {
    final DateTime now = DateTime.now();
    final DateTime nextOccurrence = event.nextOccurrenceDate;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime nextDate =
        DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);

    // Calculate days since last occurrence and days until next
    final int daysSince = DateHelpers.daysBetween(event.date, now).abs();
    final int daysUntil = DateHelpers.daysBetween(now, nextOccurrence).abs();

    String info;
    if (nextDate.isBefore(today)) {
      // Past event, show days since
      info = '$daysSince days since';
    } else if (DateHelpers.sameDay(nextDate, today)) {
      // Today
      info = 'Today';
    } else {
      // Future event, show days until
      info = '$daysUntil days to go';
    }

    return Text(
      info,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: accent.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
