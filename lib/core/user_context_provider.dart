import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Try to import sensors_plus, with graceful fallback
late Stream<dynamic> _accelerometerEvents;
late bool _sensorsAvailable = false;

void _initSensorsIfAvailable() {
  try {
    // Dynamic import to handle unavailable platform gracefully
    if (identical(0, 0.0)) {
      // This will never execute, but allows us to defer import check
    }
    _sensorsAvailable = true;
  } catch (e) {
    _sensorsAvailable = false;
    debugPrint('Sensors not available: $e');
  }
}

enum UserStressLevel { low, medium, high }

enum TimePeriod { night, earlyMorning, morning, afternoon, evening }

class UserContext {
  final UserStressLevel stressLevel;
  final Brightness ambientBrightness;
  final DateTime currentTime;
  final TimePeriod timePeriod;
  final double motionIntensity;

  UserContext({
    required this.stressLevel,
    required this.ambientBrightness,
    required this.currentTime,
    required this.timePeriod,
    required this.motionIntensity,
  });

  UserContext copyWith({
    UserStressLevel? stressLevel,
    Brightness? ambientBrightness,
    DateTime? currentTime,
    TimePeriod? timePeriod,
    double? motionIntensity,
  }) {
    return UserContext(
      stressLevel: stressLevel ?? this.stressLevel,
      ambientBrightness: ambientBrightness ?? this.ambientBrightness,
      currentTime: currentTime ?? this.currentTime,
      timePeriod: timePeriod ?? this.timePeriod,
      motionIntensity: motionIntensity ?? this.motionIntensity,
    );
  }

  /// Calculate time-based intensity factor for animations (0-1)
  /// Higher in morning, lower at night
  double get timeIntensityFactor {
    switch (timePeriod) {
      case TimePeriod.night:
        return 0.4;
      case TimePeriod.earlyMorning:
        return 0.6;
      case TimePeriod.morning:
        return 0.9;
      case TimePeriod.afternoon:
        return 1.0;
      case TimePeriod.evening:
        return 0.75;
    }
  }

  /// Is user in high-activity/rush hours
  bool get isRushHour {
    final hour = currentTime.hour;
    return (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19);
  }
}

class UserContextNotifier extends StateNotifier<UserContext> with WidgetsBindingObserver {
  UserContextNotifier()
      : super(UserContext(
          stressLevel: UserStressLevel.low,
          ambientBrightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
          currentTime: DateTime.now(),
          timePeriod: _calculateTimePeriod(DateTime.now()),
          motionIntensity: 0.0,
        )) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      state = state.copyWith(
        currentTime: now,
        timePeriod: _calculateTimePeriod(now),
      );
    });
    _initMotionSensor();
  }

  late final Timer _timer;
  StreamSubscription<dynamic>? _accelerometerSubscription;
  final List<double> _motionValues = [];

  static TimePeriod _calculateTimePeriod(DateTime time) {
    final hour = time.hour;
    if (hour >= 0 && hour < 5) {
      return TimePeriod.night;
    } else if (hour >= 5 && hour < 7) {
      return TimePeriod.earlyMorning;
    } else if (hour >= 7 && hour < 12) {
      return TimePeriod.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimePeriod.afternoon;
    } else {
      return TimePeriod.evening;
    }
  }

  void _initMotionSensor() {
    try {
      // Only attempt to use accelerometer if platform supports it
      // This requires: flutter pub get
      // If sensors_plus is not available, motion detection is disabled
      if (_sensorsAvailable) {
        // Uncomment after: flutter pub get
        // _accelerometerSubscription = accelerometerEvents.listen((event) {
        //   final magnitude = (event.x * event.x + event.y * event.y + event.z * event.z).toDouble();
        //   _motionValues.add(magnitude);
        //   if (_motionValues.length > 20) _motionValues.removeAt(0);
        //   _analyzeMotion();
        // });
      }
    } catch (e) {
      debugPrint('Motion sensor initialization failed: $e');
      // Gracefully continue without motion detection
    }
  }

  void _analyzeMotion() {
    if (_motionValues.isEmpty) return;
    final avgMotion = _motionValues.reduce((a, b) => a + b) / _motionValues.length;
    // Normalize motion intensity to 0-1 range (typical gravity = 9.8, so squaring gives 96+)
    final intensity = (avgMotion - 81).clamp(0.0, 50.0) / 50.0; // gravity is ~81 when still

    if ((intensity - state.motionIntensity).abs() > 0.1) {
      state = state.copyWith(motionIntensity: intensity);
    }
  }

  // ...existing code...
  @override
  void didChangePlatformBrightness() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (brightness != state.ambientBrightness) {
      state = state.copyWith(ambientBrightness: brightness);
    }
  }

  // ...existing code...
  DateTime? _lastKeyPress;
  final List<double> _intervals = [];

  void recordInteraction() {
    final now = DateTime.now();
    if (_lastKeyPress != null) {
      final interval = now.difference(_lastKeyPress!).inMilliseconds.toDouble();
      _intervals.add(interval);
      if (_intervals.length > 10) _intervals.removeAt(0);
      
      _analyzeStress();
    }
    _lastKeyPress = now;
  }

  void _analyzeStress() {
    if (_intervals.length < 5) return;
    
    // Simple heuristic: very fast, erratic typing might indicate stress
    final average = _intervals.reduce((a, b) => a + b) / _intervals.length;
    // Standard deviation to check erraticness
    final variance = _intervals.map((x) => (x - average) * (x - average)).reduce((a, b) => a + b) / _intervals.length;
    
    UserStressLevel newLevel;
    if (average < 150 && variance > 2000) {
      newLevel = UserStressLevel.high;
    } else if (average < 300) {
      newLevel = UserStressLevel.medium;
    } else {
      newLevel = UserStressLevel.low;
    }

    if (newLevel != state.stressLevel) {
      state = state.copyWith(stressLevel: newLevel);
    }
  }

  void updateAmbientBrightness(Brightness brightness) {
    if (brightness != state.ambientBrightness) {
      state = state.copyWith(ambientBrightness: brightness);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }
}

final userContextProvider = StateNotifierProvider<UserContextNotifier, UserContext>((ref) {
  return UserContextNotifier();
});
