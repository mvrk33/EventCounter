import '../../features/events/models/event_model.dart';

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

  static int eventCountValue(EventModel event) {
    final DateTime now = DateTime.now();
    final DateTime from = event.mode == EventMode.countdown ? now : event.date;
    final DateTime to = event.mode == EventMode.countdown ? event.date : now;

    switch (event.countUnit) {
      case EventCountUnit.days:
        return daysBetween(from, to);
      case EventCountUnit.months:
        return monthsBetween(from, to);
      case EventCountUnit.years:
        return yearsBetween(from, to);
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
    final int value = eventCountValue(event);
    final String unit = unitLabel(event.countUnit, value);
    final String suffix = event.mode == EventMode.countdown ? 'left' : 'since';
    return '$value $unit $suffix';
  }

  static List<DateTime> lastNDays(int days) {
    final DateTime today = normalizeDay(DateTime.now());
    return List<DateTime>.generate(
      days,
      (int i) => today.subtract(Duration(days: days - i - 1)),
      growable: false,
    );
  }
}
