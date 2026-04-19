import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/user_context_provider.dart';
import '../theme/time_based_colors.dart';

/// Advanced visual effects painter for liquid glass appearance
class LiquidGlassEffectsPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final double stressLevel; // 0-1
  final double motionIntensity; // 0-1
  final TimePeriod timePeriod;

  LiquidGlassEffectsPainter({
    required this.animationValue,
    required this.primaryColor,
    required this.stressLevel,
    required this.motionIntensity,
    required this.timePeriod,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint wave pattern layer (more intense when stressed)
    _paintWaveLayer(canvas, size);

    // Paint refraction shimmer layer
    _paintRefractionLayer(canvas, size);

    // Paint motion parallax layer
    _paintMotionLayer(canvas, size);
  }

  void _paintWaveLayer(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.08 * (0.5 + stressLevel * 0.5))
      ..strokeWidth = 1.5;

    final path = Path();
    final waveHeight = 8 * (0.5 + stressLevel);
    final waveFrequency = 0.02;

    for (double x = 0; x <= size.width; x += 2) {
      final y = size.height / 2 +
          math.sin((x + animationValue * 50) * waveFrequency) * waveHeight;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _paintRefractionLayer(Canvas canvas, Size size) {
    // Create shimmer effect that moves across the surface
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08 * (1.0 - stressLevel)),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final shimmerOffset = (animationValue % 1.0) * (size.width + size.height);
    canvas.save();
    canvas.translate(shimmerOffset - size.width * 0.5, shimmerOffset - size.height * 0.5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 2, size.height * 2), shimmerPaint);
    canvas.restore();
  }

  void _paintMotionLayer(Canvas canvas, Size size) {
    if (motionIntensity < 0.1) return;

    final circlePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.05 * motionIntensity);

    // Paint expanding circles based on motion
    for (int i = 1; i <= 3; i++) {
      final radius = (size.width / 2) * (0.3 + motionIntensity * i * 0.2);
      final opacity = (1.0 - (i * 0.3)).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        Paint()
          ..color = primaryColor.withValues(alpha: opacity * 0.04 * motionIntensity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LiquidGlassEffectsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.stressLevel != stressLevel ||
        oldDelegate.motionIntensity != motionIntensity;
  }
}

/// Widget that combines liquid glass effects with adaptive responsiveness
class AdaptiveLiquidGlassEffects extends ConsumerStatefulWidget {
  final Widget child;
  final Color? baseColor;
  final double borderRadius;
  final Duration animationDuration;
  final VoidCallback? onMotionDetected;

  const AdaptiveLiquidGlassEffects({
    super.key,
    required this.child,
    this.baseColor,
    this.borderRadius = 24.0,
    this.animationDuration = const Duration(seconds: 12),
    this.onMotionDetected,
  });

  @override
  ConsumerState<AdaptiveLiquidGlassEffects> createState() =>
      _AdaptiveLiquidGlassEffectsState();
}

class _AdaptiveLiquidGlassEffectsState
    extends ConsumerState<AdaptiveLiquidGlassEffects>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(userContextProvider);
    final colorScheme = ref.watch(timeBasedColorSchemeProvider);
    final theme = Theme.of(context);

    final stressValue =
        userContext.stressLevel == UserStressLevel.high ? 1.0 : 0.0;
    final motionValue = userContext.motionIntensity;
    final effectiveBlur = getAdaptiveBlurIntensity(userContext);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          // Background with blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (widget.baseColor ?? colorScheme.primary)
                        .withValues(alpha: 0.08),
                    (widget.baseColor ?? colorScheme.primary)
                        .withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                  color: (widget.baseColor ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // Animated effects layer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: LiquidGlassEffectsPainter(
                  animationValue: _controller.value,
                  primaryColor: widget.baseColor ?? colorScheme.primary,
                  stressLevel: stressValue,
                  motionIntensity: motionValue,
                  timePeriod: userContext.timePeriod,
                ),
                child: SizedBox.expand(
                  child: Container(),
                ),
              );
            },
          ),

          // Content
          widget.child,
        ],
      ),
    );
  }
}

/// Animated refraction widget with micro-interactions
class RefractiveGlass extends ConsumerWidget {
  final Widget child;
  final Color surfaceColor;
  final double depth;

  const RefractiveGlass({
    super.key,
    required this.child,
    required this.surfaceColor,
    this.depth = 0.5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15.0 * depth,
          sigmaY: 15.0 * depth,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                surfaceColor.withValues(
                  alpha: (0.1 + (userContext.motionIntensity * 0.05)) * depth,
                ),
                surfaceColor.withValues(
                  alpha: (0.05 + (userContext.motionIntensity * 0.02)) * depth,
                ),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1 * depth),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Liquid wave animation for stress indication
class LiquidWaveIndicator extends ConsumerStatefulWidget {
  final UserStressLevel stressLevel;
  final Color color;
  final double size;

  const LiquidWaveIndicator({
    super.key,
    required this.stressLevel,
    required this.color,
    this.size = 40,
  });

  @override
  ConsumerState<LiquidWaveIndicator> createState() =>
      _LiquidWaveIndicatorState();
}

class _LiquidWaveIndicatorState extends ConsumerState<LiquidWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final intensity = widget.stressLevel == UserStressLevel.high
            ? 1.0
            : widget.stressLevel == UserStressLevel.medium
                ? 0.5
                : 0.2;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: CustomPaint(
            painter: _WavePainter(
              animationValue: _controller.value,
              color: widget.color,
              intensity: intensity,
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double intensity;

  _WavePainter({
    required this.animationValue,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4 * intensity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 3;

    for (int i = 0; i < 3; i++) {
      final radius =
          baseRadius * (1 + (animationValue + i * 0.3) % 1.0);
      final opacity = (1 - ((animationValue + i * 0.3) % 1.0)).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.6 * opacity * intensity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}


