# Widget Refactor - Complete Implementation Guide

## 📋 What Changed

### ✂️ Removed
- **Swipe-to-delete functionality** from event cards (Dismissible widget)
- **Global widget settings** - no longer share settings across all widgets
- **Swipe background indicators** (pin/delete visual feedback)

### ✅ Added  
- **Per-event widget configuration** - customize each event widget independently
- **Menu-based actions** - tap the three-dot menu on event cards
- **Add to Home Screen button** - in both event cards and event detail modal
- **Event widget config dialog** - beautiful UI for widget customization
- **Live preview** - see how widget will look before pinning

## 🎯 User Features

### Event Card Actions (Three-Dot Menu)

When users tap the menu icon on an event card:

1. **Edit** ✏️
   - Navigates to event editor
   - Allows changing title, date, emoji, category, etc.

2. **Add to Home** 🏠
   - Opens widget configuration dialog
   - Allows per-event customization:
     - Toggle emoji visibility
     - Toggle event name visibility
     - Change background (solid/transparent)
     - Select count unit (days/months/years)
   - Live preview of widget appearance
   - Pins widget to home screen

3. **Delete** 🗑️
   - Removes the event from the app
   - Shown in red to indicate destructive action

### Event Detail Modal

Clicking an event card shows a modal with three main buttons:

- **Edit event** (Primary action - filled button)
- **Add Widget** (Secondary action - tonal button) ← NEW
- **Delete event** (Destructive action - outlined red)

### Widget Configuration Dialog

When user selects "Add to Home":

```
┌────────────────────────────────────┐
│  Configure Event Widget            │
│  For: Birthday Party               │
├────────────────────────────────────┤
│                                    │
│      Live Preview Box              │
│  ┌──────────────────────┐         │
│  │      🎂              │         │
│  │      23              │         │
│  │    days left         │         │
│  │   Birthday Party     │         │
│  └──────────────────────┘         │
│                                    │
├────────────────────────────────────┤
│  Display Options                   │
│  ☑ Show emoji                      │
│  ☑ Show event name                 │
│  ☐ Transparent background          │
├────────────────────────────────────┤
│  Count In                          │
│  [Days] [Months] [Years]           │
│                                    │
│  [Cancel]  [Add Widget]            │
└────────────────────────────────────┘
```

## 🏗️ Technical Architecture

### File Structure

```
lib/features/events/
├── models/
│   └── event_model.dart
├── widgets/
│   ├── event_card.dart ✏️ MODIFIED
│   ├── event_card_polished.dart ✏️ MODIFIED  
│   └── event_detail_modal.dart ✏️ MODIFIED
├── screens/
│   ├── home_screen.dart ✏️ MODIFIED
│   │   ├── _buildEventTile() → Removed Dismissible
│   │   ├── _addEventToHomeScreen() → NEW
│   │   ├── _EventWidgetConfigDialog → NEW
│   │   └── _showEventDetail() → Updated
│   └── add_edit_event_screen.dart
├── providers/
│   └── events_provider.dart
├── services/
│   └── event_share_service.dart
```

### Data Flow

```
User Interaction
      ↓
┌─────────────────────────────────────────┐
│  Event Card (event_card_polished.dart)  │
│  - PopupMenu with 3 options             │
│  - onEdit callback                      │
│  - onDelete callback                    │
│  - onAddToHomeScreen callback           │
└─────────────────────────────────────────┘
      ↓ (user taps "Add to Home")
┌─────────────────────────────────────────┐
│  Home Screen (_buildEventTile)          │
│  - Calls _addEventToHomeScreen()        │
│  - Shows dialog                         │
└─────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────┐
│  _EventWidgetConfigDialog               │
│  - Live preview                         │
│  - Configuration options               │
│  - Save to HomeWidget storage           │
│  - Call Android pinWidget method        │
└─────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────┐
│  Android MainActivity.kt                │
│  - Receives pinWidget method call       │
│  - Calls AppWidgetManager.requestPin()  │
│  - Shows widget on home screen          │
└─────────────────────────────────────────┘
```

## 🔧 Implementation Details

### Event Card Changes

**Before:**
```dart
IconButton(
  onPressed: onDelete,
  icon: const Icon(Icons.delete_outline),
),
```

**After:**
```dart
PopupMenuButton<String>(
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
      child: Row(children: [Icon(..., color: Colors.red), Text('Delete', style: ...)]),
    ),
  ],
)
```

### Home Screen Widget Tile

**Before:**
```dart
Dismissible(
  key: ValueKey(...),
  confirmDismiss: (direction) { /* delete or pin logic */ },
  background: /* pin indicator */,
  secondaryBackground: /* delete indicator */,
  child: EventCardPolished(...),
)
```

**After:**
```dart
EventCardPolished(
  event: event,
  onTap: () => _showEventDetail(context, event),
  onShare: () => _shareEvent(event),
  onEdit: () => Navigator.push(...AddEditEventScreen...),
  onDelete: () => ref.read(eventsProvider.notifier).deleteEvent(...),
  onAddToHomeScreen: () => _addEventToHomeScreen(event),
)
```

### Widget Configuration Storage

Each event widget stores its configuration with event-specific keys:

```dart
await HomeWidget.saveWidgetData<String>(
  'event_widget_${widget.event.id}_id',
  widget.event.id,
);
await HomeWidget.saveWidgetData<String>(
  'event_widget_${widget.event.id}_eventMode',
  'specific', // Marks this as a per-event widget
);
await HomeWidget.saveWidgetData<bool>(
  'event_widget_${widget.event.id}_transparent',
  _transparent,
);
await HomeWidget.saveWidgetData<String>(
  'event_widget_${widget.event.id}_bgColor',
  _colorToHex(_bgColor),
);
// ... and more for textColor, showEmoji, showTitle, countUnit
```

## 📱 Android Integration

The `MainActivity.kt` already has the correct setup:

```kotlin
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "daymark/widget_actions"
).setMethodCallHandler { call, result ->
    when (call.method) {
        "pinWidget" -> result.success(requestPinWidget(this))
        else -> result.notImplemented()
    }
}
```

This receives the `pinWidget` call from Flutter and uses Android's AppWidgetManager to show the request-pin dialog.

## 🎨 UI/UX Improvements

### Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| **Delete Method** | Swipe left | Three-dot menu |
| **Accidental Actions** | Possible via swipe | Prevented by tap |
| **Widget Customization** | Global (all same) | Per-event (individual) |
| **Widget Count** | 1 possible | Multiple with different styles |
| **Actions Available** | Pin (swipe left), Delete (swipe right) | Edit, Add Widget, Delete in menu |
| **Mobile Pattern** | Swipe-based | Tap-based (more modern) |

## 🚀 Getting Started for Users

### To Add an Event as a Widget:

1. **Open the event list** in EventCounter
2. **Tap the three-dot menu** on an event card
3. **Select "Add to Home"** 
4. **Customize the widget appearance:**
   - Toggle emoji and name visibility
   - Choose count unit (days/months/years)
   - Adjust background (solid/transparent)
5. **See the live preview** update in real-time
6. **Tap "Add Widget"** to pin to home screen
7. **Select widget placement** on your home screen

### To Manage Existing Widgets:

- Widgets are **independent from events** - deleting an event doesn't remove its widget
- Each widget can be **independently customized** using the same process
- Multiple **instances of the same event** can exist as different widgets with different styles

## 📊 Configuration Options Per Widget

### Display Settings
- **Show Emoji**: ✓ / ✗ (whether to display event emoji)
- **Show Title**: ✓ / ✗ (whether to display event name)
- **Transparent**: ✓ / ✗ (blend with wallpaper or solid color)

### Count Settings
- **Days**: Default, best for near-term events
- **Months**: Better for longer timescales
- **Years**: Best for long-term milestones

### Color Settings
- **Background**: Uses event color by default
- **Text**: White text by default (can be customized in dialog)

## ✅ Quality Assurance

All modifications pass:
- ✅ Flutter analyzer (no errors)
- ✅ Code structure and conventions
- ✅ Type safety
- ✅ Null safety
- ✅ Integration with existing Android code

## 🐛 Known Limitations & Future Enhancements

### Current Behavior
- Widgets use Android's native `requestPinAppWidget()` API
- Widget appearance syncs via HomeWidget package
- Per-event config stored in HomeWidget local storage

### Possible Enhancements
- Color picker for individual widget styling
- Custom text colors per widget
- Widget size options (1x1, 2x2, etc.)
- Cloud sync of widget configurations
- Widget template presets

## 📚 Dependencies Used

- `flutter_riverpod`: State management
- `home_widget`: Widget storage and updates
- `flutter/services.dart`: MethodChannel for Android integration
- Flutter Material Design 3: UI components

## 🎓 Code Examples

### Adding Edit and Delete Callbacks

```dart
EventCardPolished(
  event: event,
  onEdit: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEditEventScreen(existing: event)
      ),
    );
  },
  onDelete: () {
    ref.read(eventsProvider.notifier).deleteEvent(event.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );
  },
  onAddToHomeScreen: () => _addEventToHomeScreen(event),
)
```

### Showing Widget Config Dialog

```dart
Future<void> _addEventToHomeScreen(EventModel event) async {
  if (!mounted) return;
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => 
      _EventWidgetConfigDialog(event: event),
  );
}
```

---

**Status:** ✅ Implementation Complete  
**Last Updated:** April 11, 2026  
**Version:** 1.0

The widget system now fully supports individual customization per event with a modern, tap-based interface!

