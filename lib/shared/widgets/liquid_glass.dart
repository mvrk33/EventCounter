import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/user_context_provider.dart';
import '../theme/time_based_colors.dart';

class LiquidGlassContainer extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 8.0, // REDUCED for performance
    this.opacity = 0.06, // Clean, subtle look
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = ref.watch(userContextProvider.select((ctx) => ctx.ambientBrightness == Brightness.dark));

    // Static, clean colors without expensive gradients or animations
    final effectiveOpacity = isDark ? opacity * 1.5 : opacity;
    final surfaceColor = color ?? (isDark ? Colors.black : Colors.white);
    final borderColor = (color ?? theme.colorScheme.primary).withValues(alpha: isDark ? 0.15 : 0.1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        // Static blur is efficient as long as the widget doesn't rebuild constantly
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: surfaceColor.withValues(alpha: effectiveOpacity),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
          ),
          child: child,
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
    // Watch only necessary fields for performance
    final isStressed = ref.watch(userContextProvider.select((ctx) => ctx.stressLevel == UserStressLevel.high));
    final isRushed = ref.watch(userContextProvider.select((ctx) => ctx.isRushHour));
    
    final shouldEnlarge = isStressed || isRushed;

    // Static layout values
    final padding = shouldEnlarge
        ? const EdgeInsets.symmetric(horizontal: 36, vertical: 20)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    
    final fontSize = shouldEnlarge ? 17.0 : 15.0;
    final borderRadius = shouldEnlarge ? 12.0 : 16.0;

    return Listener(
      onPointerDown: (_) {
        ref.read(userContextProvider.notifier).recordInteraction();
        if (isStressed) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      },
      child: primary 
        ? FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            style: FilledButton.styleFrom(
              padding: padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              textStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
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
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              textStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: child,
          ),
    );
  }
}
