import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../core/user_context_provider.dart';
import 'liquid_glass_effects.dart';
import '../theme/time_based_colors.dart';

class LiquidGlassContainer extends ConsumerStatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 15.0,
    this.opacity = 0.1,
    this.color,
  });

  @override
  ConsumerState<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends ConsumerState<LiquidGlassContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _mousePos = const Offset(100, 100);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userContext = ref.watch(userContextProvider);
    final colorScheme = ref.watch(timeBasedColorSchemeProvider);
    final isDark = userContext.ambientBrightness == Brightness.dark;
    
    // Adaptive sizing based on stress
    final isStressed = userContext.stressLevel == UserStressLevel.high;
    final scale = isStressed ? 1.02 : 1.0;
    
    // Adjust visual properties based on environment
    final effectiveBlur = getAdaptiveBlurIntensity(userContext);
    final effectiveOpacity = isDark ? widget.opacity * 1.5 : widget.opacity;
    final colorIntensity = getAdaptiveColorIntensity(userContext);

    return MouseRegion(
      onHover: (event) {
        setState(() {
          _mousePos = event.localPosition;
        });
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 600),
        scale: scale,
        curve: Curves.easeOutBack,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
            child: Stack(
              children: [
                // Enhanced glass container with animated background
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: (widget.color ?? theme.colorScheme.primary)
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      width: isStressed ? 2.0 : 1.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (widget.color ?? (isDark ? Colors.black : Colors.white))
                            .withValues(alpha: effectiveOpacity * colorIntensity),
                        (widget.color ?? (isDark ? Colors.black : Colors.white))
                            .withValues(alpha: effectiveOpacity * 0.5 * colorIntensity),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Animated "Fluid" highlight with motion parallax
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final wave = math.sin(_controller.value * 2 * math.pi) * 20;
                          final motionOffset = userContext.motionIntensity * 30;

                          return Positioned(
                            left: _mousePos.dx - 100 + (isStressed ? wave : 0) + motionOffset,
                            top: _mousePos.dy - 100 + (isStressed ? wave : 0) + motionOffset,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    (widget.color ?? theme.colorScheme.primary)
                                        .withValues(
                                          alpha: (isDark ? 0.2 : 0.15) * colorIntensity,
                                        ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Content
                      widget.child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdaptiveButton extends ConsumerWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool primary;
  final bool useAdaptiveEffects;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.primary = true,
    this.useAdaptiveEffects = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final colorScheme = ref.watch(timeBasedColorSchemeProvider);

    // Physical adaptation: grow larger if stressed or rushed
    final isStressed = userContext.stressLevel == UserStressLevel.high;
    final isRushed = userContext.isRushHour;
    final shouldEnlarge = isStressed || isRushed;

    final padding = shouldEnlarge
        ? const EdgeInsets.symmetric(horizontal: 36, vertical: 22)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    
    final fontSize = shouldEnlarge ? 18.0 : 15.0;
    final borderRadius = shouldEnlarge ? 16 : 20;

    final buttonChild = Listener(
      onPointerDown: (_) {
        ref.read(userContextProvider.notifier).recordInteraction();
        if (isStressed) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        child: primary 
          ? FilledButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onPressed();
              },
              style: FilledButton.styleFrom(
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius.toDouble()),
                ),
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onPressed();
              },
              style: OutlinedButton.styleFrom(
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius.toDouble()),
                ),
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: child,
            ),
      ),
    );

    // Optionally wrap with adaptive effects
    if (useAdaptiveEffects) {
      return Semantics(
        button: true,
        enabled: true,
        onTap: onPressed,
        child: buttonChild,
      );
    }

    return buttonChild;
  }
}
