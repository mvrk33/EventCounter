import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/user_context_provider.dart';

/// Provides time-of-day adaptive color schemes
/// Shifts colors throughout the day for better visual harmony
class TimeBasedColorScheme {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color warmthTint;

  const TimeBasedColorScheme({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.warmthTint,
  });

  /// Sunrise (5-7am): Warm, energizing palette
  static const TimeBasedColorScheme sunrise = TimeBasedColorScheme(
    primary: Color(0xFFFF6B35), // Warm orange
    secondary: Color(0xFFFFD166), // Golden yellow
    tertiary: Color(0xFFEF476F), // Coral
    warmthTint: Color(0xFFFFE5CC), // Very warm
  );

  /// Morning (7am-12pm): Bright, clear palette
  static const TimeBasedColorScheme morning = TimeBasedColorScheme(
    primary: Color(0xFF3F51B5), // Indigo
    secondary: Color(0xFF7986CB), // Light indigo
    tertiary: Color(0xFF5E6AD2), // Purple-blue
    warmthTint: Color(0xFFF0F1FA), // Cool but not cold
  );

  /// Afternoon (12pm-5pm): Vibrant, energetic palette
  static const TimeBasedColorScheme afternoon = TimeBasedColorScheme(
    primary: Color(0xFF5E6AD2), // Bold indigo
    secondary: Color(0xFF9FA8DA), // Lighter indigo
    tertiary: Color(0xFF7986CB), // Adjusted tertiary
    warmthTint: Color(0xFFEDEDF9), // Neutral-cool
  );

  /// Evening (5pm-8pm): Warm, calming palette
  static const TimeBasedColorScheme evening = TimeBasedColorScheme(
    primary: Color(0xFFD4545E), // Warm rose
    secondary: Color(0xFFFFA500), // Amber
    tertiary: Color(0xFFFF9800), // Warm orange
    warmthTint: Color(0xFFFFDCC4), // Warm sunset
  );

  /// Night (8pm-5am): Cool, restful palette
  static const TimeBasedColorScheme night = TimeBasedColorScheme(
    primary: Color(0xFF5B7DB3), // Cool blue
    secondary: Color(0xFF8FA3C8), // Light slate blue
    tertiary: Color(0xFF6B8DD6), // Muted indigo
    warmthTint: Color(0xFFDCE3F3), // Cool tone
  );

  static TimeBasedColorScheme forTimePeriod(TimePeriod period) {
    switch (period) {
      case TimePeriod.earlyMorning:
        return sunrise;
      case TimePeriod.morning:
        return morning;
      case TimePeriod.afternoon:
        return afternoon;
      case TimePeriod.evening:
        return evening;
      case TimePeriod.night:
        return night;
    }
  }
}

/// Provider for time-based color scheme
final timeBasedColorSchemeProvider = Provider<TimeBasedColorScheme>((ref) {
  final userContext = ref.watch(userContextProvider);
  return TimeBasedColorScheme.forTimePeriod(userContext.timePeriod);
});

/// Interpolate between two colors with a blend factor (0-1)
Color lerpColor(Color a, Color b, double t) {
  return Color.lerp(a, b, t.clamp(0.0, 1.0)) ?? a;
}

/// Get adaptive color intensity based on stress and time
/// Returns a factor 0-1 for adjusting opacity/saturation
double getAdaptiveColorIntensity(UserContext context) {
  final timeBase = context.timeIntensityFactor;

  // Reduce intensity under stress
  final stressFactor = context.stressLevel == UserStressLevel.high
      ? 0.7
      : context.stressLevel == UserStressLevel.medium
          ? 0.85
          : 1.0;

  // Reduce intensity with high motion
  final motionFactor = 1.0 - (context.motionIntensity * 0.2);

  return (timeBase * stressFactor * motionFactor).clamp(0.0, 1.0);
}

/// Get blur intensity based on stress and time of day
double getAdaptiveBlurIntensity(UserContext context) {
  final baseBlur = 15.0;

  // Increase blur under stress
  final stressMultiplier = context.stressLevel == UserStressLevel.high
      ? 1.4
      : context.stressLevel == UserStressLevel.medium
          ? 1.15
          : 1.0;

  // Increase blur at night for eye comfort
  final timeMultiplier = context.timePeriod == TimePeriod.night ? 1.2 : 1.0;

  return baseBlur * stressMultiplier * timeMultiplier;
}

/// Get spacing scale factor based on stress and motion
double getAdaptiveSpacingFactor(UserContext context) {
  if (context.stressLevel == UserStressLevel.high) {
    return 0.8; // Reduce spacing when stressed
  } else if (context.motionIntensity > 0.5) {
    return 0.9; // Slightly reduce spacing with high motion
  }
  return 1.0;
}

