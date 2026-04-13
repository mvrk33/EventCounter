import '../../features/events/models/event_model.dart';

class DateBreakdown {
  const DateBreakdown({
    required this.sign,
    required this.years,
    required this.months,
    required this.days,
  });

  final int sign;
  final int years;
  final int months;
  final int days;

  int get totalMonths => years * 12 + months;
}

class DateHelpers {
  const DateHelpers._();

  static DateTime normalizeDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static int daysBetween(DateTime from, DateTime to) {
    final DateTime start = normalizeDay(from);
    final DateTime end = normalizeDay(to);
    return end.difference(start).inDays;
  }

  static bool sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int countdownDays(DateTime target) {
    return daysBetween(DateTime.now(), target);
  }

  static int countupDays(DateTime startDate) {
    return daysBetween(startDate, DateTime.now());
  }

  static int monthsBetween(DateTime from, DateTime to) {
    if (sameDay(from, to)) {
      return 0;
    }
    if (from.isAfter(to)) {
      return -monthsBetween(to, from);
    }

    int months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) {
      months -= 1;
    }
    return months;
  }

  static int yearsBetween(DateTime from, DateTime to) {
    return monthsBetween(from, to) ~/ 12;
  }

  static DateBreakdown breakdownBetween(DateTime from, DateTime to) {
    final DateTime start = normalizeDay(from);
    final DateTime end = normalizeDay(to);
    if (sameDay(start, end)) {
      return const DateBreakdown(sign: 1, years: 0, months: 0, days: 0);
    }

    final int sign = start.isAfter(end) ? -1 : 1;
    DateTime cursor = sign < 0 ? end : start;
    final DateTime target = sign < 0 ? start : end;

    int years = 0;
    while (true) {
      final DateTime next = _addYearsClamped(cursor, 1);
      if (next.isAfter(target)) {
        break;
      }
      years += 1;
      cursor = next;
    }

    int months = 0;
    while (true) {
      final DateTime next = _addMonthsClamped(cursor, 1);
      if (next.isAfter(target)) {
        break;
      }
      months += 1;
      cursor = next;
    }

    final int days = target.difference(cursor).inDays;
    return DateBreakdown(sign: sign, years: years, months: months, days: days);
  }

  static int eventCountValue(EventModel event) {
    final DateBreakdown breakdown = _eventBreakdown(event);

    switch (event.countUnit) {
      case EventCountUnit.days:
        return breakdown.sign *
            daysBetween(
              event.mode == EventMode.countdown ? DateTime.now() : event.date,
              event.mode == EventMode.countdown ? event.date : DateTime.now(),
            ).abs();
      case EventCountUnit.months:
        return breakdown.sign * breakdown.totalMonths;
      case EventCountUnit.years:
        return breakdown.sign * breakdown.years;
    }
  }

  static String unitLabel(EventCountUnit unit, int value) {
    final bool singular = value.abs() == 1;
    switch (unit) {
      case EventCountUnit.days:
        return singular ? 'day' : 'days';
      case EventCountUnit.months:
        return singular ? 'month' : 'months';
      case EventCountUnit.years:
        return singular ? 'year' : 'years';
    }
  }

  static String eventCountDescription(EventModel event) {
    final String phrase = eventCountPhrase(event);
    final String suffix = event.mode == EventMode.countdown ? 'left' : 'since';
    return '$phrase $suffix';
  }

  static String eventCountPhrase(EventModel event) {
    final DateBreakdown breakdown = _eventBreakdown(event);
    final String sign = breakdown.sign < 0 ? '-' : '';

    switch (event.countUnit) {
      case EventCountUnit.days:
        final int totalDays = daysBetween(
          event.mode == EventMode.countdown ? DateTime.now() : event.date,
          event.mode == EventMode.countdown ? event.date : DateTime.now(),
        ).abs();
        return '$sign$totalDays ${unitLabel(EventCountUnit.days, totalDays)}';
      case EventCountUnit.months:
        final int months = breakdown.totalMonths;
        final String monthPart =
            '$months ${unitLabel(EventCountUnit.months, months)}';
        if (breakdown.days == 0) {
          return '$sign$monthPart';
        }
        return '$sign$monthPart ${breakdown.days} ${unitLabel(EventCountUnit.days, breakdown.days)}';
      case EventCountUnit.years:
        final String yearsPart =
            '${breakdown.years} ${unitLabel(EventCountUnit.years, breakdown.years)}';
        final String monthsPart =
            '${breakdown.months} ${unitLabel(EventCountUnit.months, breakdown.months)}';
        final String daysPart =
            '${breakdown.days} ${unitLabel(EventCountUnit.days, breakdown.days)}';
        return '$sign$yearsPart $monthsPart $daysPart';
    }
  }

  static String eventCountCompactDescription(EventModel event) {
    final DateBreakdown breakdown = _eventBreakdown(event);
    final String sign = breakdown.sign < 0 ? '-' : '';
    final String suffix = event.mode == EventMode.countdown ? 'left' : 'since';
    switch (event.countUnit) {
      case EventCountUnit.days:
        final int totalDays = daysBetween(
          event.mode == EventMode.countdown ? DateTime.now() : event.date,
          event.mode == EventMode.countdown ? event.date : DateTime.now(),
        ).abs();
        return '$sign${totalDays}d $suffix';
      case EventCountUnit.months:
        return '$sign${breakdown.totalMonths}m ${breakdown.days}d $suffix';
      case EventCountUnit.years:
        return '$sign${breakdown.years}y ${breakdown.months}m ${breakdown.days}d $suffix';
    }
  }

  static List<DateTime> lastNDays(int days) {
    final DateTime today = normalizeDay(DateTime.now());
    return List<DateTime>.generate(
      days,
      (int i) => today.subtract(Duration(days: days - i - 1)),
      growable: false,
    );
  }

  static DateBreakdown _eventBreakdown(EventModel event) {
    final DateTime now = DateTime.now();
    final DateTime from = event.mode == EventMode.countdown ? now : event.date;
    final DateTime to = event.mode == EventMode.countdown ? event.date : now;
    return breakdownBetween(from, to);
  }

  static DateTime _addYearsClamped(DateTime date, int years) {
    final int nextYear = date.year + years;
    final int day = _clampDay(nextYear, date.month, date.day);
    return DateTime(nextYear, date.month, day);
  }

  static DateTime _addMonthsClamped(DateTime date, int months) {
    final int yearOffset = (date.month - 1 + months) ~/ 12;
    final int targetYear = date.year + yearOffset;
    final int targetMonth = ((date.month - 1 + months) % 12) + 1;
    final int day = _clampDay(targetYear, targetMonth, date.day);
    return DateTime(targetYear, targetMonth, day);
  }

  static int _clampDay(int year, int month, int day) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    return day <= lastDay ? day : lastDay;
  }
}
