import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  // Brand seed colors — keep the same indigo identity
  static const Color _lightSeed = Color(0xFF5E6AD2);
  static const Color _darkSeed  = Color(0xFF8B92E8);

  // Radii
  static const double _radius   = 16.0;
  static const double _radiusLg = 24.0;
  static const double _radiusXl = 32.0;

  static TextTheme _buildTextTheme(Color onSurface) {
    return TextTheme(
      displayLarge:   GoogleFonts.plusJakartaSans(fontSize: 57, fontWeight: FontWeight.w300, color: onSurface),
      displayMedium:  GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.w400, color: onSurface),
      displaySmall:   GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w700, color: onSurface),
      headlineLarge:  GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: onSurface, letterSpacing: -0.6),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.4),
      headlineSmall:  GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.3),
      titleLarge:     GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.2),
      titleMedium:    GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall:     GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge:      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
      bodyMedium:     GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodySmall:      GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, color: onSurface),
      labelLarge:     GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: onSurface),
      labelMedium:    GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface),
      labelSmall:     GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, color: onSurface),
    );
  }

  static ThemeData _build(ColorScheme scheme, Color scaffoldBg) {
    final textTheme = _buildTextTheme(scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        toolbarHeight: 64,
      ),
      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: scheme.primary.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      // ── Inputs ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface.withValues(alpha: 0.40),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface.withValues(alpha: 0.70),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      // ── Buttons ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
        side: BorderSide(color: scheme.outlineVariant, width: 1),
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
      ),
      // ── Navigation Bar ────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary);
          }
          return GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, color: scheme.onSurface.withValues(alpha: 0.5));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer, size: 22);
          }
          return IconThemeData(color: scheme.onSurface.withValues(alpha: 0.5), size: 22);
        }),
      ),
      // ── Misc ──────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.45),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onInverseSurface,
        ),
        elevation: 0,
        actionTextColor: scheme.inversePrimary,
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusLg)),
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.primary.withValues(alpha: 0.04),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface, letterSpacing: -0.2,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w400, color: scheme.onSurface.withValues(alpha: 0.80),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusXl)),
        ),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.primary.withValues(alpha: 0.03),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
        subtitleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w400, color: scheme.onSurface.withValues(alpha: 0.60),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: scheme.error, textColor: scheme.onError),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightSeed,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF2F3FB),
      surfaceContainerHighest: const Color(0xFFE5E6F5),
    );
    return _build(scheme, const Color(0xFFF4F5FB));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _darkSeed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF1E1F2E),
      surfaceContainerLow: const Color(0xFF252637),
      surfaceContainerHighest: const Color(0xFF2D2E42),
    );
    return _build(scheme, const Color(0xFF131420));
  }
}
