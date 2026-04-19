import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;
    final int value = DateHelpers.eventCountValue(event);
    final String compactDescription = DateHelpers.eventCountCompactDescription(event);
    final EventCardStyle style = EventCardStyleResolver.resolve(event, Theme.of(context).brightness);
    final Color accent = style.accent;

    // Use comfortable or compact layout based on density setting
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
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              style.surfaceTop.withValues(alpha: 0.95),
              style.surfaceBottom.withValues(alpha: 0.92),
            ],
          ),
          border: Border.all(
            color: style.border.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: style.accent.withValues(alpha: 0.05),
              blurRadius: 30,
              spreadRadius: -5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                ref.read(userContextProvider.notifier).recordInteraction();
                onTap();
              },
              splashColor: accent.withValues(alpha: 0.1),
              highlightColor: accent.withValues(alpha: 0.05),
              child: Stack(
                children: <Widget>[
                  // Subtle inner glow
                  Positioned(
                    top: -40,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.08),
                        // Removed invalid 'filter' property. If blur is needed, use BackdropFilter.
                      ),
                    ),
                  ),
                  if (event.visualTheme != null && !isStressed)
                    Positioned.fill(
                      child: _buildVisualThemeLayer(event.visualTheme!, accent),
                    ),
                  Padding(
                    padding: contentPadding,
                    child: isComfortable
                        ? _buildComfortableLayout(
                            context, style, value, compactDescription, scheme)
                        : _buildCompactLayout(
                            context, style, value, compactDescription, scheme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualThemeLayer(String theme, Color accent) {
    switch (theme) {
      case 'ocean_waves':
        return Opacity(
          opacity: 0.08,
          child: CustomPaint(painter: _WavePainter(color: accent)),
        );
      case 'pine_trees':
        return Opacity(
          opacity: 0.06,
          child: CustomPaint(painter: _TreePainter(color: accent)),
        );
      case 'coffee_steam':
        return Opacity(
          opacity: 0.1,
          child: CustomPaint(painter: _SteamPainter(color: accent)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildComfortableLayout(
    BuildContext context,
    EventCardStyle style,
    int value,
    String compactDescription,
    ColorScheme scheme,
  ) {
    final Color accent = style.accent;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime nextDate = DateTime(event.nextOccurrenceDate.year, event.nextOccurrenceDate.month, event.nextOccurrenceDate.day);
    final bool isUpcoming = !nextDate.isBefore(today);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // ── Premium Avatar Container ──────────────────────────────────
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.25),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            Text(
              event.emoji,
              style: const TextStyle(fontSize: 34),
            ),
          ],
        ),
        const SizedBox(width: 20),
        // ── Content Section ──────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildSmallPill(context, Icons.folder_rounded, event.category, accent),
                  const SizedBox(width: 8),
                  Text(
                    _formatEventDate(event),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildNextOccurrenceInfoComfortable(context, scheme, style),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // ── Count Badge ──────────────────────────────────
        _buildCountBadge(context, style, value, isUpcoming),
        const SizedBox(width: 4),
        _buildMenuButton(context),
      ],
    );
  }

  Widget _buildCountBadge(BuildContext context, EventCardStyle style, int value, bool isUpcoming) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: style.accent.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: style.accent,
                  height: 1.0,
                ),
          ),
          Text(
            isUpcoming ? 'DAYS' : 'AGO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: style.accent.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    EventCardStyle style,
    int value,
    String compactDescription,
    ColorScheme scheme,
  ) {
    final Color accent = style.accent;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime nextDate = DateTime(event.nextOccurrenceDate.year, event.nextOccurrenceDate.month, event.nextOccurrenceDate.day);
    final bool isUpcoming = !nextDate.isBefore(today);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Minimal Side Pillar ──────────────────────────────────
          Container(
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                event.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // ── Content Section ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 11,
                          color: accent.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      event.category.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: accent.withValues(alpha: 0.7),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildNextOccurrenceInfoCompact(context, scheme, style),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Integrated Count Pill ──────────────────────────────────
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isUpcoming ? 'D' : 'AGO',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _buildMenuButton(context),
        ],
      ),
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
              Icon(Icons.edit_rounded, size: 18),
              SizedBox(width: 12),
              Text('Edit', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'add_widget',
          child: Row(
            children: <Widget>[
              Icon(Icons.add_to_home_screen_rounded, size: 18),
              SizedBox(width: 12),
              Text('Add to Home', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ),
        ),
      ],
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: scheme.onSurface.withValues(alpha: 0.35),
      ),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 140),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildActionButtonsComfortable(
    BuildContext context,
    EventCardStyle style,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onShare,
            borderRadius: BorderRadius.circular(12),
            splashColor: style.accent.withValues(alpha: 0.1),
            highlightColor: style.accent.withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: style.accent.withValues(alpha: 0.12),
                border: Border.all(
                  color: style.accent.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.ios_share_rounded,
                size: 20,
                color: style.accent.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Menu button
        _buildMenuButton(context),
      ],
    );
  }

  Widget _buildActionButtonsCompact(
    BuildContext context,
    EventCardStyle style,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onShare,
            borderRadius: BorderRadius.circular(10),
            splashColor: style.accent.withValues(alpha: 0.1),
            highlightColor: style.accent.withValues(alpha: 0.04),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: style.accent.withValues(alpha: 0.1),
                border: Border.all(
                  color: style.accent.withValues(alpha: 0.14),
                  width: 0.9,
                ),
              ),
              child: Icon(
                Icons.ios_share_rounded,
                size: 16,
                color: style.accent.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Menu button
        _buildMenuButton(context),
      ],
    );
  }


  Widget _buildNextOccurrenceInfoComfortable(
    BuildContext context,
    ColorScheme scheme,
    EventCardStyle style,
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
    IconData? icon;
    Color? statusColor;
    Color bgColor;

    if (nextDate.isBefore(today)) {
      // Past event, show days since
      info = '$daysSince days since';
      icon = Icons.check_circle_rounded;
      statusColor = const Color(0xFF8B5CF6).withValues(alpha: 0.9);
      bgColor = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
    } else if (DateHelpers.sameDay(nextDate, today)) {
      // Today
      info = 'Happening today';
      icon = Icons.flash_on_rounded;
      statusColor = const Color(0xFFF59E0B).withValues(alpha: 0.95);
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.12);
    } else {
      // Future event, show days until
      info = '$daysUntil ${daysUntil == 1 ? 'day' : 'days'} to go';
      icon = Icons.trending_up_rounded;
      statusColor = const Color(0xFF10B981).withValues(alpha: 0.9);
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: statusColor),
          if (icon != null) const SizedBox(width: 10),
          Text(
            info,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNextOccurrenceInfoCompact(
    BuildContext context,
    ColorScheme scheme,
    EventCardStyle style,
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
    Color? statusColor;

    if (nextDate.isBefore(today)) {
      // Past event, show days since
      info = '$daysSince d ago';
      statusColor = const Color(0xFF8B5CF6).withValues(alpha: 0.85);
    } else if (DateHelpers.sameDay(nextDate, today)) {
      // Today
      info = 'Today!';
      statusColor = const Color(0xFFF59E0B).withValues(alpha: 0.9);
    } else {
      // Future event, show days until
      info = 'in $daysUntil d';
      statusColor = const Color(0xFF10B981).withValues(alpha: 0.85);
    }

    return Text(
      info,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: statusColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        fontSize: 10,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatEventDate(EventModel event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDate = DateTime(event.nextOccurrenceDate.year, event.nextOccurrenceDate.month, event.nextOccurrenceDate.day);

    if (DateHelpers.sameDay(nextDate, today)) {
      return 'Today';
    } else if (DateHelpers.sameDay(nextDate, today.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    } else {
      return DateFormat('MMM d').format(nextDate);
    }
  }

  Widget _buildSmallPill(BuildContext context, IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.7, size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.8);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TreePainter extends CustomPainter {
  _TreePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final x = 20.0 + (i * 60.0);
      path.moveTo(x, size.height - 10);
      path.lineTo(x + 20, size.height - 50);
      path.lineTo(x + 40, size.height - 10);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SteamPainter extends CustomPainter {
  _SteamPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final x = size.width - 40.0 - (i * 15.0);
      final path = Path();
      path.moveTo(x, 40);
      path.quadraticBezierTo(x + 5, 30, x, 20);
      path.quadraticBezierTo(x - 5, 10, x, 0);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
