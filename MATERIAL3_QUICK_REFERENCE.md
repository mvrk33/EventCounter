# Material 3 Quick Reference Guide

## 🎯 Quick Start

### 1. Use Material 3 Colors
```dart
final colorScheme = Theme.of(context).colorScheme;

// Primary color (brand)
Color primary = colorScheme.primary;

// Surface colors (backgrounds)
Color surface = colorScheme.surface;
Color containerHigh = colorScheme.surfaceContainerHigh;

// Text colors
Color onSurface = colorScheme.onSurface;
```

### 2. Use Material 3 Typography
```dart
final textTheme = Theme.of(context).textTheme;

Text('Title', style: textTheme.headlineSmall);
Text('Body', style: textTheme.bodyMedium);
Text('Label', style: textTheme.labelMedium);
```

### 3. Use Material 3 Buttons
```dart
// Primary action (filled)
FilledButton(
  onPressed: () {},
  child: const Text('Save'),
);

// Secondary action (outlined)
OutlinedButton(
  onPressed: () {},
  child: const Text('Cancel'),
);

// Tertiary action (text)
TextButton(
  onPressed: () {},
  child: const Text('Learn More'),
);
```

### 4. Use Material 3 Border Radius
```dart
import 'package:daymark/shared/theme/material3_constants.dart';

// Standard components
borderRadius: Material3BorderRadius.normal(), // 12dp

// Large surfaces (dialogs, bottom sheets)
borderRadius: Material3BorderRadius.extraLarge(), // 28dp

// FAB
borderRadius: Material3BorderRadius.fab(), // 16dp
```

### 5. Use Material 3 Spacing
```dart
import 'package:daymark/shared/theme/material3_constants.dart';

// All sides
padding: Material3Padding.normal, // 16dp

// Horizontal only
padding: Material3Padding.horizontalLarge, // 24dp horizontal

// Vertical only
padding: Material3Padding.verticalSmall, // 12dp vertical

// Input fields
padding: Material3Padding.inputField, // 16h, 14v
```

## 🎨 Color Reference

### Semantic Colors
| Color | Usage | Property |
|-------|-------|----------|
| Primary | Brand, CTAs, highlights | `colorScheme.primary` |
| Secondary | Accents, supporting | `colorScheme.secondary` |
| Tertiary | Highlights, banners | `colorScheme.tertiary` |
| Error | Error states, warnings | `colorScheme.error` |
| Surface | Backgrounds | `colorScheme.surface` |
| Container | Secondary surfaces | `colorScheme.surfaceContainer` |
| Outline | Borders, dividers | `colorScheme.outline` |

### On-Colors (Text/Icons)
| Color | Usage |
|-------|-------|
| `onPrimary` | Text on primary background |
| `onSurface` | Text on surface background |
| `onError` | Text on error background |
| `onInverseSurface` | Text on inverse surface |

## 📐 Spacing Scale

| Size | Value | Usage |
|------|-------|-------|
| Extra Small | 8dp | Internal spacing |
| Small | 12dp | Item spacing |
| Normal | 16dp | Default padding |
| Large | 24dp | Section spacing |
| Extra Large | 32dp | Large sections |

## 🔘 Component Sizes

| Component | Height | Notes |
|-----------|--------|-------|
| AppBar | 64dp | Standard action bar |
| NavigationBar | 80dp | Bottom navigation |
| Button | 40dp | Minimum touch target |
| Input | 48dp | TextField height |
| ListTile | Auto | Variable with content |

## 🔀 Border Radius Reference

| Size | Value | Usage |
|------|-------|-------|
| Small | 8dp | Minor elements |
| Normal | 12dp | Cards, buttons, inputs |
| Large | 16dp | FAB, large elements |
| Extra Large | 28dp | Dialogs, bottom sheets |

## 📝 Typography Scale

### Display (Headlines)
- **Large**: 57sp, Light (rare)
- **Medium**: 45sp, Regular (large content)
- **Small**: 36sp, Bold (section titles)

### Headline
- **Large**: 32sp, Bold (screen titles)
- **Medium**: 28sp, Bold (section headers)
- **Small**: 24sp, Bold (card headers)

### Title
- **Large**: 22sp, Bold (important content)
- **Medium**: 16sp, Semi-bold (body emphasize)
- **Small**: 14sp, Bold (secondary content)

### Body
- **Large**: 16sp, Medium (main content)
- **Medium**: 14sp, Regular (default text)
- **Small**: 12sp, Regular (secondary text)

### Label
- **Large**: 14sp, Bold (buttons, labels)
- **Medium**: 12sp, Semi-bold (small labels)
- **Small**: 11sp, Medium (tags)

## 🎯 Common Patterns

### Material 3 Card
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: Material3BorderRadius.normal(),
  ),
  child: Padding(
    padding: Material3Padding.normal,
    child: Column(
      children: [
        Text('Title', style: textTheme.titleLarge),
        SizedBox(height: Material3Constants.spacing16),
        Text('Content', style: textTheme.bodyMedium),
      ],
    ),
  ),
)
```

### Material 3 Button Row
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton(
      onPressed: () {},
      child: const Text('Cancel'),
    ),
    SizedBox(width: Material3Constants.spacing12),
    FilledButton(
      onPressed: () {},
      child: const Text('Confirm'),
    ),
  ],
)
```

### Material 3 Input Field
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint text',
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: Material3BorderRadius.normal(),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: Material3BorderRadius.normal(),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
  ),
)
```

### Material 3 Dialog
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: Material3BorderRadius.extraLarge(),
    ),
    title: Text('Title', style: textTheme.headlineSmall),
    content: Text('Content', style: textTheme.bodyMedium),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
    ],
  ),
)
```

### Material 3 Bottom Sheet
```dart
showModalBottomSheet(
  context: context,
  shape: RoundedRectangleBorder(
    borderRadius: Material3BorderRadius.topLarge(),
  ),
  showDragHandle: true,
  builder: (context) => Padding(
    padding: Material3Padding.large,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sheet Title', style: textTheme.headlineSmall),
        SizedBox(height: Material3Constants.spacing16),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Action')),
      ],
    ),
  ),
)
```

## 🔗 Useful Extensions

```dart
// Direct access to colors
context.primaryColor
context.surfaceColor
context.errorColor
context.onSurfaceColor

// Direct access to typography
context.textTheme.headlineSmall
context.textTheme.bodyMedium

// Direct access to scheme
context.colorScheme
```

## ⚙️ Theme Switching

The app automatically supports light/dark modes. Users can:
1. Follow system theme (default)
2. Force light theme
3. Force dark theme

Theme is managed via `themeModeProvider` in riverpod.

## 🎨 Color System

### Dynamic Colors
Material 3 generates a complete color palette from a single seed color:
- **Light Seed**: #5E6AD2 (Purple)
- **Dark Seed**: #8B92E8 (Light Purple)

All colors automatically adjust for:
- Light/dark mode
- Accessibility (high contrast)
- Semantic meaning

### Custom Color Palette
The theme automatically generates:
- 14+ primary colors
- 10+ surface containers
- Proper error states
- Outline variants

## 🚀 Performance Tips

1. **Use theme colors** - No rebuilds needed
2. **Cache ColorScheme** - Store in variables if used multiple times
3. **Use const constructors** - Most Material 3 widgets are const
4. **Lazy build widgets** - Only build visible content

## ❌ Anti-Patterns to Avoid

```dart
// ❌ Don't hardcode colors
Color badColor = Color(0xFF5E6AD2);

// ❌ Don't create custom border radius
BorderRadius badRadius = BorderRadius.circular(15);

// ❌ Don't use arbitrary padding
padding: EdgeInsets.all(17);

// ❌ Don't use old Material 2 styles
ElevatedButton(...) // Use FilledButton instead

// ✅ Do use theme system
Color goodColor = colorScheme.primary;
BorderRadius goodRadius = Material3BorderRadius.normal();
padding: Material3Padding.normal;
FilledButton(...)
```

## 📚 Files to Review

1. **Theme Definition**: `lib/shared/theme/app_theme.dart`
2. **Constants**: `lib/shared/theme/material3_constants.dart`
3. **Examples**: `lib/shared/theme/material3_examples.dart`
4. **Full Guide**: `MATERIAL3_GUIDE.md`
5. **Checklist**: `MATERIAL3_IMPLEMENTATION_CHECKLIST.md`

---

**Remember**: Consistency is key! Always use Material 3 constants and theme colors to maintain a cohesive design system.

