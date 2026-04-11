import 'package:flutter/material.dart';

import '../../../shared/utils/date_helpers.dart';

class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    required this.checkIns,
    this.accentColor,
    super.key,
  });

  final List<DateTime> checkIns;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = accentColor ?? scheme.primary;
    final Set<DateTime> set = checkIns.map(DateHelpers.normalizeDay).toSet();
    final List<DateTime> days = DateHelpers.lastNDays(35); // 5 weeks
    final DateTime today = DateHelpers.normalizeDay(DateTime.now());

    // Group days into weeks
    final List<List<DateTime>> weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Month label
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Last 5 weeks',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
          ),
        ),
        // Day-of-week header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <String>['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (String d) => SizedBox(
                  width: 28,
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        ...weeks.map((List<DateTime> week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: week.map((DateTime day) {
                final bool checked = set.any((DateTime d) => DateHelpers.sameDay(d, day));
                final bool isToday = DateHelpers.sameDay(day, today);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: checked
                        ? color
                        : isToday
                            ? color.withValues(alpha: 0.12)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
                        : null,
                  ),
                  child: checked
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : isToday
                          ? Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            )
                          : null,
                );
              }).toList(growable: false),
            ),
          );
        }),
      ],
    );
  }
}
