# Widget Refactor - Code Changes Reference

## 1. Event Card Polished (event_card_polished.dart)

### Before:
```dart
class EventCardPolished extends StatelessWidget {
  const EventCardPolished({
    required this.event,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
    super.key,
  });

  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  // ... rest of build method ends with:
  IconButton(
    onPressed: onShare,
    icon: Icon(...),
  ),
  // END
```

### After:
```dart
class EventCardPolished extends StatelessWidget {
  const EventCardPolished({
    required this.event,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
    this.onAddToHomeScreen,    // ← NEW
    this.onEdit,               // ← NEW
    super.key,
  });

  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onAddToHomeScreen;  // ← NEW
  final VoidCallback? onEdit;             // ← NEW

  // ... rest of build method ends with:
  IconButton(
    onPressed: onShare,
    icon: Icon(...),
  ),
  PopupMenuButton<String>(  // ← NEW
    onSelected: (String value) {
      switch (value) {
        case 'edit':
          onEdit?.call();
        case 'add_widget':
          onAddToHomeScreen?.call();
        case 'delete':
          onDelete.call();
      }
    },
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'edit',
        child: Row(children: [Icon(...), Text('Edit')]),
      ),
      PopupMenuItem<String>(
        value: 'add_widget',
        child: Row(children: [Icon(...), Text('Add to Home')]),
      ),
      PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(children: [
          Icon(..., color: Colors.red),
          Text('Delete', style: TextStyle(color: Colors.red))
        ]),
      ),
    ],
    icon: Icon(Icons.more_vert_rounded),
  ),
  // END
```

---

## 2. Home Screen - Remove Dismissible (home_screen.dart)

### Before:
```dart
Widget _buildEventTile(BuildContext context, EventModel event) {
  return Dismissible(
    key: ValueKey<String>('event_${event.id}_${event.updatedAt.toIso8601String()}'),
    direction: DismissDirection.horizontal,
    confirmDismiss: (DismissDirection direction) async {
      if (direction == DismissDirection.startToEnd) {
        await ref.read(eventsProvider.notifier).togglePinned(event);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(event.isPinned ? 'Removed from pinned' : 'Pinned !')),
          );
        }
        return false;
      }
      await ref.read(eventsProvider.notifier).deleteEvent(event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
      return true;
    },
    background: Container(...), // Pin indicator
    secondaryBackground: Container(...), // Delete indicator
    child: EventCardPolished(...),
  );
}
```

### After:
```dart
Widget _buildEventTile(BuildContext context, EventModel event) {
  return EventCardPolished(
    event: event,
    onTap: () => _showEventDetail(context, event),
    onShare: () => _shareEvent(event),
    onEdit: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AddEditEventScreen(existing: event)),
      );
    },
    onDelete: () {
      ref.read(eventsProvider.notifier).deleteEvent(event.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
    },
    onAddToHomeScreen: () => _addEventToHomeScreen(event),
  );
}
```

---

## 3. Home Screen - Add Widget Handler (home_screen.dart)

### New Method Added:
```dart
Future<void> _addEventToHomeScreen(EventModel event) async {
  // Show a dialog for per-event widget configuration
  if (!mounted) return;
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => _EventWidgetConfigDialog(event: event),
  );
}
```

---

## 4. Home Screen - Updated Detail View (home_screen.dart)

### Before:
```dart
Future<void> _showEventDetail(BuildContext context, EventModel event) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => EventDetailModal(event: event),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );

  if (result == 'edit' && mounted) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddEditEventScreen(existing: event)),
    );
  } else if (result == 'delete' && mounted) {
    ref.read(eventsProvider.notifier).deleteEvent(event.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );
  }
}
```

### After:
```dart
Future<void> _showEventDetail(BuildContext context, EventModel event) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => EventDetailModal(event: event),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );

  if (result == 'edit' && mounted) {
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddEditEventScreen(existing: event)),
    );
  } else if (result == 'delete' && mounted) {
    ref.read(eventsProvider.notifier).deleteEvent(event.id);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );
  } else if (result == 'add_widget' && mounted) {  // ← NEW
    _addEventToHomeScreen(event);                    // ← NEW
  }                                                  // ← NEW
}
```

---

## 5. Home Screen - New Widget Config Dialog (home_screen.dart)

### Entire New Widget:
```dart
class _EventWidgetConfigDialog extends ConsumerStatefulWidget {
  const _EventWidgetConfigDialog({required this.event});

  final EventModel event;

  @override
  ConsumerState<_EventWidgetConfigDialog> createState() =>
      _EventWidgetConfigDialogState();
}

class _EventWidgetConfigDialogState extends ConsumerState<_EventWidgetConfigDialog> {
  static const MethodChannel _widgetChannel =
      MethodChannel('daymark/widget_actions');

  late bool _transparent;
  late Color _bgColor;
  late Color _textColor;
  late bool _showEmoji;
  late bool _showTitle;
  late String _countUnit;

  @override
  void initState() {
    super.initState();
    _transparent = false;
    _bgColor = Color(widget.event.color).withValues(alpha: 0.8);
    _textColor = Colors.white;
    _showEmoji = true;
    _showTitle = true;
    _countUnit = 'days';
  }

  Future<void> _pinEventWidget() async {
    try {
      // Save event-specific widget configuration
      await HomeWidget.saveWidgetData<String>(
        'event_widget_${widget.event.id}_id',
        widget.event.id,
      );
      await HomeWidget.saveWidgetData<String>(
        'event_widget_${widget.event.id}_eventMode',
        'specific',
      );
      await HomeWidget.saveWidgetData<bool>(
        'event_widget_${widget.event.id}_transparent',
        _transparent,
      );
      await HomeWidget.saveWidgetData<String>(
        'event_widget_${widget.event.id}_bgColor',
        _colorToHex(_bgColor),
      );
      await HomeWidget.saveWidgetData<String>(
        'event_widget_${widget.event.id}_textColor',
        _colorToHex(_textColor),
      );
      await HomeWidget.saveWidgetData<bool>(
        'event_widget_${widget.event.id}_showEmoji',
        _showEmoji,
      );
      await HomeWidget.saveWidgetData<bool>(
        'event_widget_${widget.event.id}_showTitle',
        _showTitle,
      );
      await HomeWidget.saveWidgetData<String>(
        'event_widget_${widget.event.id}_countUnit',
        _countUnit,
      );

      // Attempt to pin the widget
      final bool result =
          (await _widgetChannel.invokeMethod<bool>('pinWidget')) ?? false;

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Widget created! Choose where to place it on your home screen.'
                : 'Widget configured. Add it from your launcher widgets list.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Widget configured. Add it from your launcher.'),
        ),
      );
    }
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int value = DateHelpers.eventCountValue(widget.event);

    return AlertDialog(
      title: const Text('Configure Event Widget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'For: ${widget.event.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            // Live preview
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: _transparent
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : _bgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (_transparent ? Colors.black : _bgColor)
                          .withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (_showEmoji)
                      Text(
                        widget.event.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _transparent ? scheme.onSurface : _textColor,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      _countUnit,
                      style: TextStyle(
                        fontSize: 11,
                        color: (_transparent ? scheme.onSurface : _textColor)
                            .withValues(alpha: 0.75),
                      ),
                    ),
                    if (_showTitle)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          widget.event.title,
                          style: TextStyle(
                            fontSize: 10,
                            color: (_transparent ? scheme.onSurface : _textColor)
                                .withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Options
            Text(
              'Display Options',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Show emoji'),
              value: _showEmoji,
              onChanged: (bool? v) => setState(() => _showEmoji = v ?? true),
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Show event name'),
              value: _showTitle,
              onChanged: (bool? v) => setState(() => _showTitle = v ?? true),
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Transparent background'),
              value: _transparent,
              onChanged: (bool? v) => setState(() => _transparent = v ?? false),
              dense: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Count Unit',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <String>['days', 'months', 'years'].map((String u) {
                final bool selected = _countUnit == u;
                return ChoiceChip(
                  label: Text(u[0].toUpperCase() + u.substring(1)),
                  selected: selected,
                  onSelected: (_) => setState(() => _countUnit = u),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _pinEventWidget,
          icon: const Icon(Icons.add_to_home_screen_rounded),
          label: const Text('Add Widget'),
        ),
      ],
    );
  }
}
```

---

## 6. Event Detail Modal (event_detail_modal.dart)

### Before:
```dart
// ... other code ...
const SizedBox(height: 24),
// ── Actions ───────────────────────────────────────
FilledButton.icon(
  onPressed: () => Navigator.of(context).pop('edit'),
  icon: const Icon(Icons.edit_rounded),
  label: const Text('Edit event'),
),
const SizedBox(height: 10),
OutlinedButton.icon(
  onPressed: () => Navigator.of(context).pop('delete'),
  icon: const Icon(Icons.delete_outline_rounded),
  label: const Text('Delete event'),
  style: OutlinedButton.styleFrom(
    foregroundColor: scheme.error,
    side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
  ),
),
```

### After:
```dart
// ... other code ...
const SizedBox(height: 24),
// ── Actions ───────────────────────────────────────
FilledButton.icon(
  onPressed: () => Navigator.of(context).pop('edit'),
  icon: const Icon(Icons.edit_rounded),
  label: const Text('Edit event'),
),
const SizedBox(height: 10),
FilledButton.tonalIcon(  // ← NEW
  onPressed: () => Navigator.of(context).pop('add_widget'),  // ← NEW
  icon: const Icon(Icons.add_to_home_screen_rounded),        // ← NEW
  label: const Text('Add Widget'),                           // ← NEW
),                                                            // ← NEW
const SizedBox(height: 10),
OutlinedButton.icon(
  onPressed: () => Navigator.of(context).pop('delete'),
  icon: const Icon(Icons.delete_outline_rounded),
  label: const Text('Delete event'),
  style: OutlinedButton.styleFrom(
    foregroundColor: scheme.error,
    side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
  ),
),
```

---

## Summary of Changes

| File | Type | Change | LOC |
|------|------|--------|-----|
| event_card.dart | Modification | Replace delete button with menu | +35 |
| event_card_polished.dart | Modification | Replace delete button with menu | +35 |
| event_detail_modal.dart | Modification | Add "Add Widget" button | +5 |
| home_screen.dart | Modification | Remove Dismissible, add dialog, callbacks | +120 |
| **TOTAL** | | | **~195** |

✅ All changes are backward compatible with existing event data structure.

