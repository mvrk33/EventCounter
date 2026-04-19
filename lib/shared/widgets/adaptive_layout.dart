import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/user_context_provider.dart';
import '../theme/time_based_colors.dart';

/// Builds adaptive layouts based on user stress and context
class AdaptiveLayoutBuilder extends ConsumerWidget {
  final Widget normalLayout;
  final Widget? stressedLayout;
  final Widget? nightLayout;

  const AdaptiveLayoutBuilder({
    super.key,
    required this.normalLayout,
    this.stressedLayout,
    this.nightLayout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);

    // Prioritize stressed layout over night layout
    if (userContext.stressLevel == UserStressLevel.high && stressedLayout != null) {
      return stressedLayout!;
    }

    if (userContext.timePeriod == TimePeriod.night && nightLayout != null) {
      return nightLayout!;
    }

    return normalLayout;
  }
}

/// Responsive spacing that adapts to context
class AdaptiveSpacing extends ConsumerWidget {
  final double baseValue;
  final Widget? child;

  const AdaptiveSpacing({
    super.key,
    this.baseValue = 16.0,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final factor = getAdaptiveSpacingFactor(userContext);
    final scaledValue = baseValue * factor;

    if (child != null) {
      return SizedBox(height: scaledValue, width: scaledValue, child: child);
    }
    return SizedBox(height: scaledValue);
  }
}

/// Responsive horizontal spacing
class AdaptiveHorizontalSpacing extends ConsumerWidget {
  final double baseValue;
  final Widget? child;

  const AdaptiveHorizontalSpacing({
    super.key,
    this.baseValue = 16.0,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final factor = getAdaptiveSpacingFactor(userContext);
    final scaledValue = baseValue * factor;

    if (child != null) {
      return SizedBox(height: scaledValue, width: scaledValue, child: child);
    }
    return SizedBox(width: scaledValue);
  }
}

/// Text style that adapts to context
class AdaptiveText extends ConsumerWidget {
  final String text;
  final TextStyle? baseStyle;
  final bool simplifyWhenStressed;
  final bool reduceSizeAtNight;

  const AdaptiveText(
    this.text, {
    super.key,
    this.baseStyle,
    this.simplifyWhenStressed = true,
    this.reduceSizeAtNight = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    var style = baseStyle ?? Theme.of(context).textTheme.bodyMedium;

    // Reduce font size under stress
    if (simplifyWhenStressed && userContext.stressLevel == UserStressLevel.high) {
      style = style?.copyWith(
        fontSize: (style.fontSize ?? 14) * 0.9,
        letterSpacing: 0,
      );
    }

    // Slightly increase font size at night for readability
    if (reduceSizeAtNight && userContext.timePeriod == TimePeriod.night) {
      style = style?.copyWith(
        fontSize: (style.fontSize ?? 14) * 1.05,
        fontWeight: FontWeight.w500,
      );
    }

    return AnimatedDefaultTextStyle(
      style: style ?? const TextStyle(),
      duration: const Duration(milliseconds: 300),
      child: Text(text),
    );
  }
}

/// Adaptive padding that responds to stress level
class AdaptivePadding extends ConsumerWidget {
  final Widget child;
  final EdgeInsets baseInsets;
  final bool reduceWhenStressed;

  const AdaptivePadding({
    super.key,
    required this.child,
    this.baseInsets = const EdgeInsets.all(16),
    this.reduceWhenStressed = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);

    EdgeInsets effectiveInsets = baseInsets;

    if (reduceWhenStressed && userContext.stressLevel == UserStressLevel.high) {
      // Reduce padding by 20% when stressed
      effectiveInsets = EdgeInsets.only(
        left: baseInsets.left * 0.8,
        top: baseInsets.top * 0.8,
        right: baseInsets.right * 0.8,
        bottom: baseInsets.bottom * 0.8,
      );
    }

    // Increase padding slightly at night for visual breathing room
    if (userContext.timePeriod == TimePeriod.night) {
      effectiveInsets = EdgeInsets.only(
        left: effectiveInsets.left * 1.1,
        top: effectiveInsets.top * 1.1,
        right: effectiveInsets.right * 1.1,
        bottom: effectiveInsets.bottom * 1.1,
      );
    }

    return AnimatedPadding(
      padding: effectiveInsets,
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}

/// Button that grows larger when user is stressed or rushed
class AdaptiveTouchTarget extends ConsumerWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double minSize;

  const AdaptiveTouchTarget({
    super.key,
    required this.child,
    required this.onPressed,
    this.minSize = 48,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);

    final isStressed = userContext.stressLevel == UserStressLevel.high;
    final isRushed = userContext.isRushHour;

    // Increase minimum touch target if stressed or rushed
    final effectiveMinSize = (isStressed || isRushed) ? minSize * 1.2 : minSize;

    return Semantics(
      button: true,
      onTap: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: effectiveMinSize, minWidth: effectiveMinSize),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Container that simplifies when stressed
class AdaptiveContainer extends ConsumerWidget {
  final Widget child;
  final BoxDecoration? decoration;
  final EdgeInsets padding;
  final Color? color;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.decoration,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;

    BoxDecoration effectiveDecoration = decoration ?? const BoxDecoration();

    if (isStressed) {
      // Simplify decoration under stress: remove shadows, reduce complexity
      effectiveDecoration = BoxDecoration(
        color: effectiveDecoration.color ?? color,
        border: effectiveDecoration.border,
        borderRadius: effectiveDecoration.borderRadius,
      );
    }

    return AnimatedContainer(
      decoration: effectiveDecoration,
      padding: padding,
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}

/// Hides decorative elements when stressed
class StressAdaptiveVisibility extends ConsumerWidget {
  final Widget child;
  final bool hideWhenStressed;

  const StressAdaptiveVisibility({
    super.key,
    required this.child,
    this.hideWhenStressed = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final shouldHide = hideWhenStressed && userContext.stressLevel == UserStressLevel.high;

    return AnimatedOpacity(
      opacity: shouldHide ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: shouldHide
        ? SizedBox.shrink()
        : child,
    );
  }
}

/// Layout that simplifies on night mode
class NightModeSimplified extends ConsumerWidget {
  final Widget child;
  final bool simplifyAtNight;

  const NightModeSimplified({
    super.key,
    required this.child,
    this.simplifyAtNight = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final isNight = simplifyAtNight && userContext.timePeriod == TimePeriod.night;

    return DefaultTextStyle(
      style: DefaultTextStyle.of(context).style.copyWith(
        color: isNight
            ? DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.9)
            : null,
      ),
      child: child,
    );
  }
}

/// Dynamic card that reduces complexity based on context
class ContextAwareCard extends ConsumerWidget {
  final Widget child;
  final Color? backgroundColor;
  final double? elevation;
  final bool showDecorations;

  const ContextAwareCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.elevation,
    this.showDecorations = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final colorScheme = ref.watch(timeBasedColorSchemeProvider);

    final isStressed = userContext.stressLevel == UserStressLevel.high;

    // Reduce elevation under stress
    final effectiveElevation = isStressed ? 0.0 : (elevation ?? 2.0);

    // Hide decorative elements under stress
    final showDecorationsEffective = showDecorations && !isStressed;

    return Card(
      elevation: effectiveElevation,
      color: backgroundColor,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          border: showDecorationsEffective
              ? Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  width: 1,
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// List view that adjusts density based on stress
class AdaptiveListView extends ConsumerWidget {
  final List<Widget> children;
  final ScrollPhysics physics;
  final MainAxisAlignment mainAxisAlignment;

  const AdaptiveListView({
    super.key,
    required this.children,
    this.physics = const BouncingScrollPhysics(),
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;

    // Reduce spacing between items when stressed
    final spacing = isStressed ? 8.0 : 12.0;

    final items = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(SizedBox(height: spacing));
      }
    }

    return ListView(
      physics: physics,
      children: items,
    );
  }
}

/// Expands touch targets when under stress
class StressAwareIcon extends ConsumerWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double baseSize;

  const StressAwareIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.baseSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;

    final iconSize = isStressed ? baseSize * 1.3 : baseSize;
    final padding = isStressed ? 12.0 : 8.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: iconSize,
        color: color,
        splashRadius: isStressed ? 28 : 24,
      ),
    );
  }
}



