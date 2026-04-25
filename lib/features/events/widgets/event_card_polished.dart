import 'dart:ui';
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
  grid,
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
    final bool isGrid = density == EventCardDensity.grid;
    
    // Adaptive spacing based on density and stress level
    final double horizontalMargin = isStressed ? 12 : (isGrid ? 0 : 16);
    final double verticalMargin = isComfortable ? (isStressed ? 10 : 8) : (isGrid ? 0 : 4);
    
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: horizontalMargin, 
      vertical: verticalMargin
    );
    
    final EdgeInsets contentPadding = isComfortable
        ? const EdgeInsets.all(20)
        : (isGrid 
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isGrid ? 28 : 24),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: isGrid ? 15 : 20,
              offset: Offset(0, isGrid ? 4 : 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isGrid ? 28 : 24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isGrid ? 28 : 24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    style.surfaceTop.withValues(alpha: isDark ? 0.85 : 0.92),
                    style.surfaceBottom.withValues(alpha: isDark ? 0.75 : 0.82),
                  ],
                ),
                border: Border.all(
                  color: style.border.withValues(alpha: isDark ? 0.25 : 0.15),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(isGrid ? 28 : 24),
                  onTap: () {
                    ref.read(userContextProvider.notifier).recordInteraction();
                    onTap();
                  },
                  child: Padding(
                    padding: contentPadding,
                    child: isComfortable
                        ? _buildComfortableLayout(context, style, value, breakdown)
                        : (isGrid 
                            ? _buildGridLayout(context, style, value, breakdown)
                            : _buildCompactLayout(context, style, value, breakdown)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridLayout(
    BuildContext context,
    EventCardStyle style,
    int value,
    DateBreakdown breakdown,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = style.accent;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                event.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            if (event.isPinned)
              Icon(Icons.push_pin_rounded, size: 14, color: accent.withValues(alpha: 0.5)),
          ],
        ),
        const Spacer(),
        Text(
          event.title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$value',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: accent,
                fontSize: 24,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                event.countUnit.name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.6),
                ),
              ),
            ),
            const Spacer(),
            _buildGridMenuButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildGridMenuButton(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final position = details.globalPosition;
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
          items: <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
            const PopupMenuItem<String>(value: 'add_widget', child: Text('Add to Home')),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ).then((v) {
          switch (v) {
            case 'edit': onEdit?.call(); break;
            case 'add_widget': onAddToHomeScreen?.call(); break;
            case 'delete': onDelete.call(); break;
          }
        });
      },
      child: Icon(Icons.more_horiz_rounded, size: 18, color: Colors.grey.withValues(alpha: 0.5)),
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

    // Check if next occurrence is close (within 7 days)
    final daysToNext = nextDate.difference(today).inDays;

    String? closeLabel;
    Color closeColor = accent;
    if (daysToNext == 0) {
      closeLabel = "TODAY";
      closeColor = Colors.redAccent;
    } else if (daysToNext == 1) {
      closeLabel = "TOMORROW";
      closeColor = Colors.orangeAccent;
    } else if (daysToNext > 1 && daysToNext <= 7) {
      closeLabel = "IN $daysToNext DAYS";
      closeColor = Colors.blueAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.2),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.1), width: 2),
              ),
              child: Center(
                child: Text(
                  event.emoji,
                  style: const TextStyle(fontSize: 34),
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
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${breakdown.years}y ${breakdown.months}m ${breakdown.days}d',
                      style: GoogleFonts.plusJakartaSans(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildCountBadge(context, style, value, isUpcoming),
            const SizedBox(width: 4),
            _buildMenuButton(context),
          ],
        ),
        if (event.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              event.notes,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (closeLabel != null) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: closeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                closeLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: closeColor,
                ),
              ),
            ),
          ),
        ],
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
    
    final String dateStr = DateFormat('MMM d').format(event.date);
    
    // Check if next occurrence is close (within 7 days)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(event.nextOccurrenceDate.year, event.nextOccurrenceDate.month, event.nextOccurrenceDate.day);
    final daysToNext = next.difference(today).inDays;
    
    String? closeLabel;
    Color closeColor = accent;
    if (daysToNext == 0) {
      closeLabel = "TODAY";
      closeColor = Colors.redAccent;
    } else if (daysToNext == 1) {
      closeLabel = "TOMORROW";
      closeColor = Colors.orangeAccent;
    } else if (daysToNext > 1 && daysToNext <= 7) {
      closeLabel = "IN $daysToNext DAYS";
      closeColor = Colors.blueAccent;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // HIGH VISIBILITY EMOJI
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.4 : 0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              event.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (event.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.push_pin_rounded, size: 12, color: accent.withValues(alpha: 0.6)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (closeLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: closeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        closeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.3,
                          color: closeColor,
                        ),
                      ),
                    ),
                    _dotSeparator(isDark),
                  ],
                  Text(
                    dateStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // CONFIGURED COUNT BADGE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.1), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: accent,
                  fontSize: 16,
                ),
              ),
              Text(
                event.countUnit.name.substring(0, 3).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        _buildMenuButton(context),
      ],
    );
  }

  Widget _dotSeparator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '•',
        style: TextStyle(
          fontSize: 8,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
        ),
      ),
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
