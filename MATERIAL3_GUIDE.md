# Material 3 (Material U) Design System Implementation

## Overview
This project now uses **Material 3**, Google's latest design system, providing a modern, cohesive, and accessible user interface.

## ✅ Implementation Status

### Core Configuration
- **useMaterial3: true** - Enabled in ThemeData
- **Color System** - Dynamic ColorScheme with seed colors
  - Light Theme Seed: `#5E6AD2` (Purple)
  - Dark Theme Seed: `#8B92E8` (Light Purple)
- **Typography** - Google Fonts (Nunito) following Material 3 scale

### Material 3 Components Styled

#### Navigation
- **AppBar** - Transparent with custom title styling
- **NavigationBar** - Bottom navigation with Material 3 indicators
- **Bottom Sheet** - Rounded top with drag handle

#### Input Components
- **TextField/Input** - Filled style with custom border radius
- **Chips** - Stadium shape with Material 3 sizing
- **Progress Indicators** - Colored and themed

#### Action Components
- **Buttons** - Filled, Outlined, Text buttons with Material 3 styling
  - Filled Button: Primary background
  - Outlined Button: Border style
  - Text Button: Minimal style
- **FAB** - Floating Action Button with rounded corners
- **Badges** - Error color styling

#### Surfaces & Containers
- **Cards** - Subtle elevation with surface tint
- **Dialogs** - Large border radius (28dp) with Material 3 shadows
- **SnackBars** - Floating with rounded corners
- **ListTiles** - Rounded with Material 3 typography

## Design Specifications

### Border Radius
- Default Components: `12dp`
- Large Surfaces (Dialogs, Bottom Sheets): `28dp`
- Extra Large: `32dp`
- Buttons: `12dp`
- FAB: `16dp`

### Color Tokens
Material 3 uses a comprehensive color system:
- **Primary** - Main brand color
- **Secondary** - Supporting color
- **Tertiary** - Tertiary accent
- **Surface** - Background surfaces
- **Error** - Error/warning states

### Spacing
- Consistent padding throughout app
- Navigation bar: 80dp height
- AppBar: 64dp height
- Input padding: 16px horizontal, 14px vertical

### Typography Scale (Material 3)
- **Display Large**: 57sp, Light
- **Display Medium**: 45sp, Regular
- **Display Small**: 36sp, Bold
- **Headline Large**: 32sp, Bold
- **Headline Medium**: 28sp, Bold
- **Headline Small**: 24sp, Bold
- **Title Large**: 22sp, Bold
- **Title Medium**: 16sp, Semi-bold
- **Title Small**: 14sp, Bold
- **Body Large**: 16sp, Medium
- **Body Medium**: 14sp, Regular
- **Body Small**: 12sp, Regular
- **Label Large**: 14sp, Bold
- **Label Medium**: 12sp, Semi-bold
- **Label Small**: 11sp, Medium

## Usage Guidelines

### Best Practices
1. **Use ColorScheme colors** in custom widgets
   ```dart
   Color color = Theme.of(context).colorScheme.primary;
   ```

2. **Follow Material 3 elevation** (no shadows by default)
   ```dart
   elevation: 0,
   ```

3. **Use surfaceTint** for subtle color overlays
   ```dart
   surfaceTintColor: scheme.primary.withValues(alpha: 0.05),
   ```

4. **Rounded corners** should be consistent
   ```dart
   borderRadius: BorderRadius.circular(12),
   ```

5. **Typography** - Use theme text styles
   ```dart
   style: Theme.of(context).textTheme.bodyLarge,
   ```

## Theme Switching
The app supports Light and Dark themes via `themeModeProvider`:
- Light Theme: Clean, bright surfaces
- Dark Theme: Dark surfaces with adjusted colors
- Auto: System theme detection

## Customization

To customize colors, edit `lib/shared/theme/app_theme.dart`:

```dart
static const Color _lightSeed = Color(0xFF5E6AD2); // Change light theme seed
static const Color _darkSeed = Color(0xFF8B92E8);  // Change dark theme seed
```

## References
- [Material Design 3 Guidelines](https://m3.material.io/)
- [Flutter Material 3 Documentation](https://docs.flutter.dev/ui/design-systems/material3)
- [Material 3 Color System](https://m3.material.io/styles/color/overview)

