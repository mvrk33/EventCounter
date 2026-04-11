import 'package:flutter/material.dart';

/// Material 3 Design System Constants and Utilities
class Material3Constants {
  Material3Constants._();

  /// Border Radius Constants
  static const double smallBorderRadius = 8.0;
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double extraLargeBorderRadius = 28.0;
  static const double fabBorderRadius = 16.0;

  /// Spacing Constants (Material 3)
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing14 = 14.0;

  /// Component Heights
  static const double appBarHeight = 64.0;
  static const double navigationBarHeight = 80.0;
  static const double buttonHeight = 40.0;
  static const double inputHeight = 48.0;

  /// Elevation Constants (Material 3 - mostly zero)
  static const double elevationNone = 0.0;
  static const double elevationLight = 1.0;
  static const double elevationMedium = 3.0;

  /// Opacity Constants
  static const double opacityNone = 0.0;
  static const double opacityFaint = 0.05;
  static const double opacitySlight = 0.12;
  static const double opacityMedium = 0.38;
  static const double opacityHigh = 0.6;
  static const double opacityFull = 1.0;
}

/// Material 3 Helper Extension on BuildContext
extension Material3ContextExtension on BuildContext {
  /// Get Material 3 Color Scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get Material 3 Text Theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get Material 3 Primary Color
  Color get primaryColor => colorScheme.primary;

  /// Get Material 3 Secondary Color
  Color get secondaryColor => colorScheme.secondary;

  /// Get Material 3 Error Color
  Color get errorColor => colorScheme.error;

  /// Get Material 3 Surface Color
  Color get surfaceColor => colorScheme.surface;

  /// Get Material 3 Surface Container
  Color get surfaceContainer => colorScheme.surfaceContainer;

  /// Get Material 3 Surface Container High
  Color get surfaceContainerHigh => colorScheme.surfaceContainerHigh;

  /// Get Material 3 Surface Container Highest
  Color get surfaceContainerHighest => colorScheme.surfaceContainerHighest;

  /// Get Material 3 Outline Color
  Color get outlineColor => colorScheme.outline;

  /// Get Material 3 Outline Variant Color
  Color get outlineVariantColor => colorScheme.outlineVariant;

  /// Get Material 3 OnSurface Color
  Color get onSurfaceColor => colorScheme.onSurface;
}

/// Material 3 Border Radius Builder
class Material3BorderRadius {
  Material3BorderRadius._();

  static BorderRadius small() =>
      BorderRadius.circular(Material3Constants.smallBorderRadius);

  static BorderRadius normal() =>
      BorderRadius.circular(Material3Constants.defaultBorderRadius);

  static BorderRadius large() =>
      BorderRadius.circular(Material3Constants.largeBorderRadius);

  static BorderRadius extraLarge() =>
      BorderRadius.circular(Material3Constants.extraLargeBorderRadius);

  static BorderRadius fab() =>
      BorderRadius.circular(Material3Constants.fabBorderRadius);

  static BorderRadius topLarge() => const BorderRadius.vertical(
        top: Radius.circular(Material3Constants.extraLargeBorderRadius),
      );

  static BorderRadius allExceptBottom() => BorderRadius.only(
        topLeft: const Radius.circular(Material3Constants.extraLargeBorderRadius),
        topRight: const Radius.circular(Material3Constants.extraLargeBorderRadius),
      );
}

/// Material 3 Elevation Builder
class Material3Elevation {
  Material3Elevation._();

  static ShapeDecoration none(ColorScheme scheme) => ShapeDecoration(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Material3BorderRadius.normal(),
        ),
        shadows: const [],
      );

  static ShapeDecoration light(ColorScheme scheme) => ShapeDecoration(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Material3BorderRadius.normal(),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      );

  static ShapeDecoration medium(ColorScheme scheme) => ShapeDecoration(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Material3BorderRadius.normal(),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 3),
          ),
        ],
      );
}

/// Material 3 Padding Builder
class Material3Padding {
  Material3Padding._();

  static const EdgeInsets extraSmall = EdgeInsets.all(Material3Constants.spacing8);
  static const EdgeInsets small = EdgeInsets.all(Material3Constants.spacing12);
  static const EdgeInsets normal = EdgeInsets.all(Material3Constants.spacing16);
  static const EdgeInsets large = EdgeInsets.all(Material3Constants.spacing24);
  static const EdgeInsets extraLarge = EdgeInsets.all(Material3Constants.spacing32);

  static const EdgeInsets horizontalSmall =
      EdgeInsets.symmetric(horizontal: Material3Constants.spacing12);
  static const EdgeInsets horizontalNormal =
      EdgeInsets.symmetric(horizontal: Material3Constants.spacing16);
  static const EdgeInsets horizontalLarge =
      EdgeInsets.symmetric(horizontal: Material3Constants.spacing24);

  static const EdgeInsets verticalSmall =
      EdgeInsets.symmetric(vertical: Material3Constants.spacing12);
  static const EdgeInsets verticalNormal =
      EdgeInsets.symmetric(vertical: Material3Constants.spacing16);
  static const EdgeInsets verticalLarge =
      EdgeInsets.symmetric(vertical: Material3Constants.spacing24);

  static const EdgeInsets inputField =
      EdgeInsets.symmetric(horizontal: Material3Constants.spacing16, vertical: Material3Constants.spacing14);
}

/// Material 3 Button Style Builder
class Material3ButtonStyles {
  Material3ButtonStyles._();

  static ButtonStyle primaryFilled(ColorScheme scheme) => FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: Material3Padding.horizontalNormal,
        shape: RoundedRectangleBorder(borderRadius: Material3BorderRadius.normal()),
      );

  static ButtonStyle secondaryOutlined(ColorScheme scheme) => OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        padding: Material3Padding.horizontalNormal,
        shape: RoundedRectangleBorder(borderRadius: Material3BorderRadius.normal()),
      );

  static ButtonStyle tertiary(ColorScheme scheme) => TextButton.styleFrom(
        foregroundColor: scheme.primary,
        padding: Material3Padding.horizontalSmall,
        shape: RoundedRectangleBorder(borderRadius: Material3BorderRadius.small()),
      );

  static ButtonStyle destructive(ColorScheme scheme) => FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
        padding: Material3Padding.horizontalNormal,
        shape: RoundedRectangleBorder(borderRadius: Material3BorderRadius.normal()),
      );
}


