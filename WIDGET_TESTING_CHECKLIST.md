# Widget Refactor - Testing Checklist

## ✅ Pre-Testing Setup

- [ ] Run `flutter pub get` to ensure all dependencies are installed
- [ ] Run `flutter clean` to clear build cache
- [ ] Run `flutter analyze` and verify no errors (warnings are OK)
- [ ] Build and run the app: `flutter run`

## 🧪 UI/UX Testing

### Event Card Menu Tests

- [ ] **Event cards display correctly** with polished design
- [ ] **Three-dot menu icon visible** on each event card
- [ ] **Menu opens** when tapping the three-dot icon
- [ ] **Menu has three options**: Edit, Add to Home, Delete
- [ ] **Menu icons are correct**: 
  - ✏️ Edit
  - 🏠 Add to Home  
  - 🗑️ Delete (in red)
- [ ] **Menu items have text labels** (not just icons)
- [ ] **Edit option is in normal color**
- [ ] **Add to Home option is in normal color**
- [ ] **Delete option text and icon are RED**

### Swipe Functionality Removal Tests

- [ ] **No swipe gestures work on event cards** (swipe left/right should do nothing)
- [ ] **No background indicators appear** on card swipe attempts
- [ ] **Event cards don't dismiss or change on swipe**
- [ ] **Event card remains fully tappable** (InkWell effect works)
- [ ] **No "Pin" or "Delete" swipe actions visible**

### Event Detail Modal Tests

- [ ] **Clicking event card opens detail modal** (tapping the card itself, not menu)
- [ ] **Modal shows three buttons at bottom**:
  - ✏️ "Edit event" (filled primary button)
  - 🏠 "Add Widget" (tonal secondary button) ← NEW
  - 🗑️ "Delete event" (outlined red button)
- [ ] **All buttons have icons and text labels**
- [ ] **"Edit event" button is blue/primary color**
- [ ] **"Add Widget" button is secondary/tonal color**
- [ ] **"Delete event" button has red text and outline**

## 🎨 Menu Action Tests

### Edit Action

- [ ] **Tapping "Edit" from card menu** navigates to edit screen
- [ ] **Tapping "Edit event" from modal** navigates to edit screen
- [ ] **Edit screen shows event details** ready for modification
- [ ] **Changes save correctly** when returning to list

### Delete Action

- [ ] **Tapping "Delete" from card menu** removes the event
- [ ] **Tapping "Delete event" from modal** removes the event
- [ ] **Event disappears from list** after deletion
- [ ] **Snackbar shows** "Event deleted" confirmation
- [ ] **Undo is not available** (permanent deletion)

### Add to Home Action (Critical)

- [ ] **Tapping "Add to Home" from card menu** opens config dialog
- [ ] **Tapping "Add Widget" from modal** opens config dialog
- [ ] **Dialog appears centered on screen**
- [ ] **Dialog title shows** "Configure Event Widget"
- [ ] **Dialog shows** "For: {EventTitle}"

## 🎛️ Widget Config Dialog Tests

### Dialog Layout

- [ ] **Live preview box is centered** at top of dialog
- [ ] **Preview shows event emoji** (if "Show emoji" is checked)
- [ ] **Preview shows large countdown number**
- [ ] **Preview shows count unit label** (e.g., "days left")
- [ ] **Preview shows event title** (if "Show title" is checked)
- [ ] **Preview has rounded corners** and shadow
- [ ] **Preview background color matches** event color by default

### Display Options Checkboxes

- [ ] **"Show emoji" checkbox appears**
  - [ ] Checked by default ✓
  - [ ] Toggling unchecks it
  - [ ] Unchecking hides emoji in preview
- [ ] **"Show event name" checkbox appears**
  - [ ] Checked by default ✓
  - [ ] Toggling unchecks it
  - [ ] Unchecking hides title in preview
- [ ] **"Transparent background" checkbox appears**
  - [ ] Unchecked by default ✗
  - [ ] Toggling checks it
  - [ ] Checking makes preview semi-transparent

### Count Unit Selection

- [ ] **"Count In" section appears** with three options
- [ ] **"Days" button appears** and is selectable
- [ ] **"Months" button appears** and is selectable
- [ ] **"Years" button appears** and is selectable
- [ ] **Only one option can be selected** at a time
- [ ] **Selected option highlighted** (different color/style)
- [ ] **Preview updates** to show selected unit text

### Live Preview Updates

- [ ] **Preview updates in real-time** as options are toggled
- [ ] **Emoji appears/disappears** when checkbox is toggled
- [ ] **Title appears/disappears** when checkbox is toggled
- [ ] **Background changes** when transparent toggle is changed
- [ ] **Unit label changes** (days/months/years) when selection changes
- [ ] **Preview always shows sample values** (e.g., "47 days left")

### Dialog Actions

- [ ] **"Cancel" button appears** at bottom left
- [ ] **Tapping "Cancel"** closes dialog without saving
- [ ] **"Add Widget" button appears** at bottom right
- [ ] **"Add Widget" button is filled/primary style**
- [ ] **Tapping "Add Widget"** attempts to pin widget
- [ ] **Success message appears** after pinning
- [ ] **Message says** "Widget created! Choose where to place it..."

## 📍 Android Widget Pinning Tests

### Widget Request Handling

- [ ] **After tapping "Add Widget"**, Android widget selector appears (if supported)
- [ ] **User can choose widget placement** on home screen
- [ ] **Widget appears on home screen** after confirmation
- [ ] **Widget shows event information** with configured settings
- [ ] **Multiple event widgets** can coexist on home screen
- [ ] **Each widget independently shows** its configured event

### Widget Styling on Home Screen

- [ ] **Widget displays event emoji** (if enabled in config)
- [ ] **Widget displays countdown/count-up number** in large font
- [ ] **Widget displays unit text** (days/months/years)
- [ ] **Widget displays event title** (if enabled in config)
- [ ] **Widget background is event color** by default
- [ ] **Widget text is white** by default
- [ ] **Widget has rounded corners** for visual appeal

## 🔄 State Management Tests

### Event List Updates

- [ ] **Deleting an event** removes it from all sections (pinned/week/month/later)
- [ ] **Events remain sorted** correctly after any action
- [ ] **Edit history preserved** if available
- [ ] **Other events unaffected** by operations on one event

### Per-Event Widget Persistence

- [ ] **Widget config saved separately** per event (not globally)
- [ ] **Changing one event's widget** doesn't affect another's
- [ ] **Widget config survives** app restart
- [ ] **Multiple widgets of same event** can have different configs

## 🎯 Edge Cases

- [ ] **Events with empty titles** still work in menu
- [ ] **Events with emojis** display correctly in menu
- [ ] **Long event titles** truncate correctly in preview
- [ ] **Rapidly tapping menu** doesn't cause crashes
- [ ] **Closing dialog mid-dialog** doesn't cause errors
- [ ] **Network disconnection** doesn't prevent local menu actions
- [ ] **App backgrounding** preserves menu state

## 📊 Performance Tests

- [ ] **Menu opens quickly** (< 500ms)
- [ ] **Dialog appears smoothly** (no jank)
- [ ] **Scrolling event list remains smooth** with menu open
- [ ] **No memory leaks** when opening/closing dialogs repeatedly
- [ ] **Widget pinning doesn't block UI** (async operation)

## 🔐 Safety Tests

- [ ] **Accidental taps on "Delete"** don't happen easily
- [ ] **Delete requires explicit menu tap** (not swipeable)
- [ ] **No actions trigger without user confirmation**
- [ ] **Error messages display clearly** if operations fail

## 🌐 Compatibility Tests

### Android Versions
- [ ] **Android 8 (API 26)**: Works with fallback
- [ ] **Android 9-10 (API 28-29)**: Full widget support
- [ ] **Android 11-12 (API 30-31)**: Full widget support
- [ ] **Android 13+ (API 33+)**: Full widget support

### Devices
- [ ] **Phone (portrait)**: Menu and dialog layout correct
- [ ] **Phone (landscape)**: Menu and dialog adapt properly
- [ ] **Tablet**: Layout scales appropriately
- [ ] **Small screen (< 5")**: All elements remain accessible
- [ ] **Large screen (> 6.5")**: Spacing looks balanced

## 🐛 Bug Verification

Check that these issues are NOT present:

- [ ] No crashes when opening menu multiple times
- [ ] No crashes when deleting events rapidly
- [ ] No crashes when pinning widgets
- [ ] No UI freezes during operations
- [ ] No orphaned dialogs that won't close
- [ ] No missing icons or labels in menu
- [ ] No text overflow in dialog

## 📝 Documentation Tests

- [ ] Developer can understand the implementation from code comments
- [ ] New developer can find event card customization points
- [ ] Architecture clearly separates concerns
- [ ] Future maintenance is straightforward

## ✨ Visual Polish Tests

- [ ] All icons are properly aligned
- [ ] All text has good contrast
- [ ] All buttons have proper spacing
- [ ] Menu positioning is optimal (doesn't go off-screen)
- [ ] Dialog fits on smallest common phone (375px wide)
- [ ] Preview box is clearly visible and attractive
- [ ] Color scheme is consistent with app theme

## 🎬 Final Acceptance Tests

- [ ] **User can complete full workflow**: 
  1. View event list ✓
  2. Open three-dot menu ✓
  3. Select "Add to Home" ✓
  4. Configure widget ✓
  5. Pin to home screen ✓
  6. See widget on home screen ✓

- [ ] **User can edit event via menu** ✓
- [ ] **User can delete event via menu** ✓
- [ ] **User can access all actions from event detail modal** ✓
- [ ] **No swipe functionality interferes** ✓

---

## 📋 Test Results Summary

| Category | Tests | Passed | Failed | Notes |
|----------|-------|--------|--------|-------|
| UI/UX | 8 | ☐ | ☐ | |
| Menu Actions | 9 | ☐ | ☐ | |
| Widget Config | 21 | ☐ | ☐ | |
| Android Integration | 8 | ☐ | ☐ | |
| State Management | 6 | ☐ | ☐ | |
| Edge Cases | 7 | ☐ | ☐ | |
| Performance | 5 | ☐ | ☐ | |
| **TOTAL** | **64** | ☐ | ☐ | |

## 🚀 Sign-Off

- [ ] All tests passed
- [ ] No critical issues remaining
- [ ] Ready for production release
- [ ] User documentation updated
- [ ] Tested by: _________________ 
- [ ] Date: _________________

---

**Testing Status:** Ready to Begin  
**Last Updated:** April 11, 2026

