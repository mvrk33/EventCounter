// Material 3 Widget Examples
// This file demonstrates how to use Material 3 components in Event Counter

import 'package:flutter/material.dart';
import 'material3_constants.dart';

/// Example 1: Using Material 3 Colors
ColorScheme exampleColors(BuildContext context) {
  return Theme.of(context).colorScheme;
}

/// Example 2: Using Material 3 Typography
void exampleTypography(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;

  // Display styles (large headlines)
  Text('Large Title', style: textTheme.displayLarge);

  // Headline styles
  Text('Section Title', style: textTheme.headlineSmall);

  // Title styles
  Text('Card Title', style: textTheme.titleLarge);

  // Body styles
  Text('Body text', style: textTheme.bodyMedium);

  // Label styles
  Text('Label text', style: textTheme.labelMedium);
}

/// Example 3: Material 3 Button Styles
class Material3ButtonExamples extends StatelessWidget {
  const Material3ButtonExamples({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Filled Button (Primary Action)
        FilledButton(
          onPressed: () {},
          style: Material3ButtonStyles.primaryFilled(colorScheme),
          child: const Text('Primary Action'),
        ),

        // Outlined Button (Secondary Action)
        OutlinedButton(
          onPressed: () {},
          style: Material3ButtonStyles.secondaryOutlined(colorScheme),
          child: const Text('Secondary Action'),
        ),

        // Text Button (Tertiary Action)
        TextButton(
          onPressed: () {},
          style: Material3ButtonStyles.tertiary(colorScheme),
          child: const Text('Tertiary Action'),
        ),

        // Destructive Button (Danger)
        FilledButton(
          onPressed: () {},
          style: Material3ButtonStyles.destructive(colorScheme),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Example 4: Material 3 Card
class Material3CardExample extends StatelessWidget {
  const Material3CardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: Material3BorderRadius.normal(),
      ),
      child: Padding(
        padding: Material3Padding.normal,
        child: Column(
          children: [
            Text(
              'Card Title',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Material3Constants.spacing12),
            Text(
              'Card content goes here',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Example 5: Material 3 Input Field
class Material3InputExample extends StatelessWidget {
  const Material3InputExample({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Enter text',
        labelText: 'Label',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: Material3BorderRadius.normal(),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Material3BorderRadius.normal(),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Material3BorderRadius.normal(),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: Material3Padding.inputField,
      ),
    );
  }
}

/// Example 6: Material 3 Dialog
void showMaterial3Dialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Dialog Title',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      content: Text(
        'Dialog content',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: Material3BorderRadius.extraLarge(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

/// Example 7: Material 3 Bottom Sheet
void showMaterial3BottomSheet(BuildContext context) {
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
          Text(
            'Bottom Sheet Title',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Material3Constants.spacing16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Action'),
          ),
        ],
      ),
    ),
  );
}

/// Example 8: Material 3 Chip
class Material3ChipExample extends StatefulWidget {
  const Material3ChipExample({super.key});

  @override
  State<Material3ChipExample> createState() => _Material3ChipExampleState();
}

class _Material3ChipExampleState extends State<Material3ChipExample> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: const Text('Chip'),
      selected: selected,
      onSelected: (value) => setState(() => selected = value),
      shape: StadiumBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

/// Example 9: Material 3 FAB (Floating Action Button)
class Material3FABExample extends StatelessWidget {
  const Material3FABExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: Material3BorderRadius.fab(),
      ),
      child: const Icon(Icons.add),
    );
  }
}

/// Example 10: Using Material 3 Extensions
class Material3ExtensionExample extends StatelessWidget {
  const Material3ExtensionExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Using extension methods for clean code
    return Container(
      color: context.surfaceColor,
      child: Text(
        'Using extensions',
        style: context.textTheme.bodyLarge?.copyWith(
          color: context.primaryColor,
        ),
      ),
    );
  }
}

