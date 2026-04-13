# Material 3 Visual Style Guide for EventCounter

## Color Palette

### Light Theme
```
Primary: #5E6AD2 (Vibrant Purple)
On Primary: #FFFFFF (White)
Primary Container: #EAE5FF
On Primary Container: #21005E

Secondary: (Generated from seed)
Tertiary: (Generated from seed)

Surface: #FFFFFF (White)
Surface Container: #F5F3FF
Surface Container High: #E5E6F5
Surface Container Highest: #EDEAF7

On Surface: #1A1B2F
On Surface Variant: #47474E

Outline: #7A7A82
Outline Variant: #C8C7D0

Error: #B3261E
On Error: #FFFFFF
Error Container: #F9DEDC

Inverse Surface: #2D2E42
Inverse On Surface: #F4EFF4
Inverse Primary: #D0BCFF
```

### Dark Theme
```
Primary: #8B92E8 (Light Purple)
On Primary: #000000
Primary Container: #5E6AD2
On Primary Container: #FFFBFE

Secondary: (Generated from seed)
Tertiary: (Generated from seed)

Surface: #1E1F2E (Dark)
Surface Container: #252637
Surface Container High: #2D2E42
Surface Container Highest: #393A52

On Surface: #E5E1E6
On Surface Variant: #C8C7D0

Outline: #918F96
Outline Variant: #49474E

Error: #F2B8B5
On Error: #601410
Error Container: #8C1D18

Inverse Surface: #E5E1E6
Inverse On Surface: #2D2E42
Inverse Primary: #5E6AD2
```

## Typography Scale

### Display Large
- Font Size: 57sp
- Weight: Light (300)
- Line Height: 64sp
- Letter Spacing: 0px
- Use: Rare, only for very large headlines

### Display Medium
- Font Size: 45sp
- Weight: Regular (400)
- Line Height: 52sp
- Letter Spacing: 0px
- Use: Large content headers

### Display Small
- Font Size: 36sp
- Weight: Bold (700)
- Line Height: 44sp
- Letter Spacing: 0px
- Use: Primary content sections

### Headline Large
- Font Size: 32sp
- Weight: Bold (800)
- Line Height: 40sp
- Letter Spacing: 0px
- Use: Screen/page titles

### Headline Medium
- Font Size: 28sp
- Weight: Bold (700)
- Line Height: 36sp
- Letter Spacing: 0px
- Use: Section headers

### Headline Small
- Font Size: 24sp
- Weight: Bold (700)
- Line Height: 32sp
- Letter Spacing: 0px
- Use: Card titles, important content

### Title Large
- Font Size: 22sp
- Weight: Bold (700)
- Line Height: 28sp
- Letter Spacing: 0px
- Use: Important content, emphasis

### Title Medium
- Font Size: 16sp
- Weight: Semi-Bold (600)
- Line Height: 24sp
- Letter Spacing: 0.15px
- Use: Body emphasis, secondary titles

### Title Small
- Font Size: 14sp
- Weight: Bold (700)
- Line Height: 20sp
- Letter Spacing: 0.1px
- Use: Secondary content, labels

### Body Large
- Font Size: 16sp
- Weight: Medium (500)
- Line Height: 24sp
- Letter Spacing: 0.15px
- Use: Main body text, large content

### Body Medium
- Font Size: 14sp
- Weight: Regular (400)
- Line Height: 20sp
- Letter Spacing: 0.25px
- Use: Default body text, secondary text

### Body Small
- Font Size: 12sp
- Weight: Regular (400)
- Line Height: 16sp
- Letter Spacing: 0.4px
- Use: Supporting text, captions

### Label Large
- Font Size: 14sp
- Weight: Bold (700)
- Line Height: 20sp
- Letter Spacing: 0.1px
- Use: Buttons, labels, badges

### Label Medium
- Font Size: 12sp
- Weight: Semi-Bold (600)
- Line Height: 16sp
- Letter Spacing: 0.5px
- Use: Small labels, chips

### Label Small
- Font Size: 11sp
- Weight: Medium (500)
- Line Height: 16sp
- Letter Spacing: 0.5px
- Use: Tiny labels, status

## Spacing Scale

```
2dp   - Minimal gaps, icon spacing
4dp   - Compact spacing
8dp   - Tight spacing (base unit)
12dp  - Small spacing
16dp  - Standard padding (most common)
20dp  - Comfortable spacing
24dp  - Section spacing
32dp  - Large section spacing
```

## Component Specifications

### Buttons

#### Filled Button (Primary)
```
Background: Primary color
Foreground: On Primary color
Height: 40dp
Border Radius: 12dp
Padding: 24px horizontal, 12px vertical
Elevation: 0
Font: Label Large (14sp, Bold)
Pressed State: Darker primary
Disabled: Gray background, reduced opacity
```

#### Outlined Button (Secondary)
```
Background: Transparent
Border: 1dp, Outline color
Foreground: Primary color
Height: 40dp
Border Radius: 12dp
Padding: 24px horizontal, 12px vertical
Elevation: 0
Font: Label Medium (12sp, Semi-bold)
Pressed State: Slight background tint
Disabled: Gray border, reduced opacity
```

#### Text Button (Tertiary)
```
Background: Transparent
Foreground: Primary color
Height: Auto
Border Radius: 10dp
Padding: 12px horizontal, 8px vertical
Elevation: 0
Font: Label Medium (12sp, Semi-bold)
Pressed State: Slight background tint
Disabled: Gray foreground, reduced opacity
```

### Cards
```
Background: Surface color
Border Radius: 12dp
Elevation: 0 (flat design)
Surface Tint: Primary with 5% opacity
Padding: 16dp (standard)
Border: None (optional outline in 1% opacity)
Shadow: None (Material 3 flat style)
```

### Input Fields
```
Background: Surface Container Highest with 50% opacity
Border Radius: 12dp
Border: None (unfocused)
Border on Focus: 2dp, Primary color
Height: 48dp
Padding: 16dp horizontal, 14dp vertical
Font: Body Medium (14sp, Regular)
Label: Title Small (14sp, Semi-bold)
Hint: Body Medium with 45% opacity
Cursor: Primary color
Error: 1dp border, Error color
```

### Cards / Surfaces
```
Background: Surface color
Border Radius: 12dp
Padding: 16dp
Elevation: 0
Surface Tint: Primary with 5% opacity
Text Color: On Surface color
```

### Navigation Bar
```
Height: 80dp
Background: Surface color
Item Height: 60dp
Icon Size: 24dp
Label Size: 12sp (Label Small)
Label Selected Color: Primary
Label Unselected Color: On Surface with 55% opacity
Indicator: Primary Container background
Border Radius Indicator: Pill shape (max)
```

### App Bar
```
Height: 64dp
Background: Transparent
Elevation: 0
Title: Headline Large (32sp, Bold)
Title Color: On Surface
Icon Color: On Surface
Action Icon Size: 24dp
Scrolled Under Elevation: 0
```

### Dialogs
```
Background: Surface color
Border Radius: 28dp
Elevation: 0
Surface Tint: Primary with 5% opacity
Title: Headline Small (24sp, Bold)
Content: Body Medium (14sp, Regular)
Action Buttons: Material 3 button styles
Padding: 24dp vertical, 24dp horizontal
```

### Bottom Sheet
```
Background: Surface color
Border Radius Top: 28dp (rounded only top)
Elevation: 0
Surface Tint: Primary with 5% opacity
Drag Handle: Yes, On Surface Variant color
Padding: 24dp
Content: Full width
Height: Flexible, content-driven
```

### FAB (Floating Action Button)
```
Background: Primary color
Foreground: On Primary color
Size: 56dp
Border Radius: 16dp
Elevation: 0
Icon Size: 24dp
Shadow: Slight (optional)
Pressed State: Darker primary
```

### Chips
```
Background: Surface Container Highest
Border: 1dp, Outline Variant
Border Radius: 999dp (stadium)
Padding: 12px horizontal, 8px vertical
Label: Label Medium (12sp, Semi-bold)
Height: ~32dp
Selected Background: Primary Container
Selected Label: Primary color
```

### Progress Indicators
```
Color: Primary color
Track Color: Surface Container Highest
Height (Linear): 4dp
Radius (Circular): 20dp (size 40dp)
```

### Badges
```
Background: Error color
Text Color: On Error color
Size: 16dp (default)
Border Radius: 50% (circular)
Font: Label Small (11sp, Medium)
```

### Dividers
```
Color: Outline Variant with 50% opacity
Height: 1dp
Spacing: 1dp (tight)
Full Width: Yes (no margins)
```

## Elevation System (Material 3)

Most components use **flat design** (0 elevation):
- Cards: 0
- Buttons: 0
- Dialogs: 0
- Bottom Sheets: 0
- FAB: 0 (optional slight shadow)

When elevation is needed:
- Light: 1dp blur, low opacity shadow
- Medium: 3dp blur, medium opacity shadow
- High: 6dp blur, higher opacity shadow

## Animation & Motion

### Transitions (Material 3)
- **Duration**: 200-300ms for standard
- **Curve**: Ease Out for scale/fade
- **Curve**: Custom Material curves for smoothness

### Ripple Effects
- Color: Primary color with 20% opacity
- Duration: 150ms
- Bounded: Contains within element bounds

### State Changes
- Hover: 2% background tint increase
- Pressed: 4% background tint increase
- Disabled: 38% opacity reduction

## Responsive Behavior

### Breakpoints
- **Small** (< 600dp): Phone layout
- **Medium** (600-905dp): Tablet layout
- **Large** (> 905dp): Desktop layout

### Padding Adjustments
- Small: 16dp standard
- Medium: 24dp standard
- Large: 32dp standard

## Dark Mode Adjustments

### Light to Dark Shift
- All colors automatically inverted appropriately
- Text contrast maintained
- Primary color brightened for visibility
- Surface colors darkened
- No manual color changes needed

## Accessibility

### Contrast Ratios
- Text on Background: 4.5:1 minimum
- Large Text: 3:1 minimum
- UI Components: 3:1 minimum

### Touch Targets
- Minimum: 48dp x 48dp
- Comfortable: 56dp x 56dp
- Buttons use 40-48dp height

### Text Sizing
- Default: 14sp
- Large: 18sp+ for headings
- Minimum: 12sp (for captions only)

---

## Implementation Checklist

When implementing components:
- [ ] Use correct border radius from this guide
- [ ] Apply correct padding values
- [ ] Use typography scale exactly as specified
- [ ] Apply Material 3 colors (not custom colors)
- [ ] Maintain 48dp minimum touch targets
- [ ] Test contrast in both light and dark modes
- [ ] Verify animations are smooth
- [ ] Check responsive behavior

---

**Visual Style Version**: 1.0
**Material Design**: Material 3
**Last Updated**: April 11, 2026

