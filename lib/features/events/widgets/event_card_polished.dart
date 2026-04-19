import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';
import '../utils/event_card_style_resolver.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../core/user_context_provider.dart';

enum EventCardDensity {
  compact,
  comfortable,
}

class EventCardPolished extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;
    final int value = DateHelpers.eventCountValue(event);
    final breakdown = DateHelpers.breakdownBetween(
      event.mode == EventMode.countdown ? DateTime.now() : event.date,
      event.mode == EventMode.countdown ? event.date : DateTime.now(),
    );
    final EventCardStyle style = EventCardStyleResolver.resolve(event, Theme.of(context).brightness);
    final Color accent = style.accent;

    final bool isComfortable = density == EventCardDensity.comfortable;
    final EdgeInsets padding = isComfortable
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    final EdgeInsets contentPadding = isComfortable
        ? const EdgeInsets.all(16)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.04 : 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              ref.read(userContextProvider.notifier).recordInteraction();
              onTap();
            },
            child: Padding(
              padding: contentPadding,
              child: isComfortable
                  ? _buildComfortableLayout(context, style, value, breakdown)
                  : _buildCompactLayout(context, style, value, breakdown),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComfortableLayout(
    BuildContext context,
    EventCardStyle style,
    int value,
    DateBreakdown breakdown,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = style.accent;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime nextDate = DateTime(event.nextOccurrenceDate.year, event.nextOccurrenceDate.month, event.nextOccurrenceDate.day);
    final bool isUpcoming = !nextDate.isBefore(today);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              event.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${breakdown.years}y ${breakdown.months}m ${breakdown.days}d',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildCountBadge(context, style, value, isUpcoming),
        _buildMenuButton(context),
      ],
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    EventCardStyle style,
    int value,
    DateBreakdown breakdown,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = style.accent;
    
    // Informative time description
    String timeInfo;
    if (breakdown.years > 0) {
      timeInfo = '${breakdown.years}y ${breakdown.months}m';
    } else if (breakdown.totalMonths > 0) {
      timeInfo = '${breakdown.totalMonths}m ${breakdown.days}d';
    } else {
      timeInfo = '${breakdown.days}d';
    }
    
    final String suffix = event.mode == EventMode.countdown ? 'left' : 'ago';
    final String dateStr = DateFormat('MMM d').format(event.date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Emoji with subtle background
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              event.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '$timeInfo $suffix',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: accent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 8,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildMenuButton(context),
      ],
    );
  }

  Widget _buildCountBadge(BuildContext context, EventCardStyle style, int value, bool isUpcoming) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: style.accent,
              fontSize: 18,
            ),
          ),
          Text(
            isUpcoming ? event.countUnit.name.toUpperCase() : 'AGO',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: style.accent.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (String v) {
        switch (v) {
          case 'edit': onEdit?.call(); break;
          case 'add_widget': onAddToHomeScreen?.call(); break;
          case 'delete': onDelete.call(); break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
        const PopupMenuItem<String>(value: 'add_widget', child: Text('Add to Home')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
    );
  }
}
