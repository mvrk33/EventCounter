import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../../../shared/utils/date_helpers.dart';

class EventCardStyle {
  const EventCardStyle({
    required this.accent,
    required this.surfaceTop,
    required this.surfaceBottom,
    required this.border,
    required this.glow,
    required this.badgeTop,
    required this.badgeBottom,
    required this.badgeBorder,
    required this.badgeText,
    required this.statusText,
    required this.iconTint,
  });

  final Color accent;
  final Color surfaceTop;
  final Color surfaceBottom;
  final Color border;
  final Color glow;
  final Color badgeTop;
  final Color badgeBottom;
  final Color badgeBorder;
  final Color badgeText;
  final Color statusText;
  final Color iconTint;
}

class EventCardStyleResolver {
  const EventCardStyleResolver._();

  static EventCardStyle resolve(EventModel event, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final HSLColor source = HSLColor.fromColor(Color(event.color));
    final int categorySeed = _stableHash(event.category.toLowerCase());
    final int titleSeed = _stableHash(event.title.toLowerCase());

    final DateTime today = DateHelpers.normalizeDay(DateTime.now());
    final DateTime next = DateHelpers.normalizeDay(event.nextOccurrenceDate);
    final int dayDelta = DateHelpers.daysBetween(today, next);

    final double urgency = dayDelta <= 0
        ? 0.15
        : (1 - (dayDelta.clamp(0, 120) / 120.0)).clamp(0.0, 1.0);

    final double categoryHue = (categorySeed % 360).toDouble();
    final double hueJitter = ((titleSeed % 31) - 15).toDouble();
    final double modeHue = event.mode == EventMode.countup ? 20 : -8;
    final double recurrenceHue = event.recurrence.index * 4.0;

    final double hue = _wrapHue(
      source.hue * 0.55 +
          categoryHue * 0.45 +
          hueJitter +
          modeHue +
          recurrenceHue,
    );

    final double saturation = (
      0.54 +
      ((titleSeed % 17) / 100.0) +
      urgency * 0.20 +
      (event.mode == EventMode.countdown ? 0.05 : -0.03)
    ).clamp(0.44, 0.86);

    final double lightness = (
      (isDark ? 0.50 : 0.40) +
      (event.isPinned ? 0.04 : 0.0) +
      urgency * 0.06 +
      (event.mode == EventMode.countup ? -0.03 : 0.0)
    ).clamp(0.36, 0.70);

    final Color accent = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
    
    // Adaptive surfaces
    final Color surfaceTop = isDark 
        ? Color.lerp(const Color(0xFF25123D), accent, 0.46)!
        : Color.lerp(Colors.white, accent, 0.12)!;
    final Color surfaceBottom = isDark
        ? Color.lerp(const Color(0xFF110B28), accent, 0.26)!
        : Color.lerp(const Color(0xFFF3F4F9), accent, 0.06)!;
        
    final Color border = isDark
        ? Color.lerp(accent, Colors.white, 0.18)!
        : Color.lerp(accent, Colors.black, 0.1)!;
        
    final Color badgeTop = isDark 
        ? Color.lerp(const Color(0xFF221139), accent, 0.52)!
        : Color.lerp(Colors.white, accent, 0.2)!;
    final Color badgeBottom = isDark
        ? Color.lerp(const Color(0xFF130C26), accent, 0.34)!
        : Color.lerp(const Color(0xFFF3F4F9), accent, 0.15)!;

    return EventCardStyle(
      accent: accent,
      surfaceTop: surfaceTop,
      surfaceBottom: surfaceBottom,
      border: border,
      glow: Color.lerp(accent, Colors.pinkAccent, 0.18)!,
      badgeTop: badgeTop,
      badgeBottom: badgeBottom,
      badgeBorder: Color.lerp(accent, isDark ? Colors.white : Colors.black, 0.22)!,
      badgeText: accent,
      statusText: Color.lerp(accent, isDark ? Colors.white : Colors.black, 0.12)!,
      iconTint: Color.lerp(accent, isDark ? Colors.white : Colors.black, 0.40)!,
    );
  }

  static int _stableHash(String value) {
    int hash = 0;
    for (int i = 0; i < value.length; i++) {
      hash = (hash * 31 + value.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }

  static double _wrapHue(double hue) {
    final double wrapped = hue % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }
}

