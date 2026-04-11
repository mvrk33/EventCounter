import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/event_model.dart';
import '../../../shared/utils/date_helpers.dart';

/// Keys used to communicate between Flutter and the native widget.
class WidgetKeys {
  static const String title        = 'w_title';
  static const String countNum     = 'w_count_num';
  static const String countUnit    = 'w_count_unit';
  static const String countDir     = 'w_count_dir';
  static const String emoji        = 'w_emoji';
  static const String transparent  = 'w_transparent';
  static const String bgColor      = 'w_bg_color';
  static const String showEmoji    = 'w_show_emoji';
  static const String showTitle    = 'w_show_title';
  static const String textColor    = 'w_text_color';
  // Config keys (saved separately, not pushed to widget each time)
  static const String cfgEventMode    = 'wcfg_event_mode';   // 'nearest' | 'pinned'
  static const String cfgTransparent  = 'wcfg_transparent';
  static const String cfgBgColor      = 'wcfg_bg_color';
  static const String cfgTextColor    = 'wcfg_text_color';
  static const String cfgShowEmoji    = 'wcfg_show_emoji';
  static const String cfgShowTitle    = 'wcfg_show_title';
  static const String cfgCountUnit    = 'wcfg_count_unit';   // 'days' | 'months' | 'years'
  // Tracks all active appWidgetIds (written by native side, read here to update per-widget data)
  static const String knownWidgetIds  = 'known_widget_ids';
  // Pending keys — set before calling pinWidget so the next new widget absorbs them
  static const String pendingTitle      = 'pending_w_title';
  static const String pendingCountNum   = 'pending_w_count_num';
  static const String pendingCountUnit  = 'pending_w_count_unit';
  static const String pendingCountDir   = 'pending_w_count_dir';
  static const String pendingEmoji      = 'pending_w_emoji';
  static const String pendingTransparent= 'pending_w_transparent';
  static const String pendingBgColor    = 'pending_w_bg_color';
  static const String pendingShowEmoji  = 'pending_w_show_emoji';
  static const String pendingShowTitle  = 'pending_w_show_title';
  static const String pendingTextColor  = 'pending_w_text_color';
}

class EventHomeWidgetService {
  const EventHomeWidgetService();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static _DisplayData _computeDisplay(EventModel event, String countUnitCfg) {
    final DateTime effectiveDate = event.nextOccurrenceDate;
    final DateTime now = DateTime.now();
    int countNum;
    switch (countUnitCfg) {
      case 'months':
        countNum = DateHelpers.monthsBetween(now, effectiveDate).abs();
        break;
      case 'years':
        countNum = DateHelpers.yearsBetween(now, effectiveDate).abs();
        break;
      default:
        countNum = DateHelpers.daysBetween(now, effectiveDate).abs();
    }
    final String countDir = effectiveDate.isAfter(now) ? 'left' : 'since';
    return _DisplayData(
      title: event.title,
      emoji: event.emoji,
      countNum: countNum,
      countUnit: countUnitCfg,
      countDir: countDir,
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Write "pending" widget data so the very next new widget placement
  /// (via [requestPinAppWidget]) picks up this specific event's display.
  Future<void> pushPendingEventWidget({
    required EventModel event,
    required bool transparent,
    required Color bgColor,
    required Color textColor,
    required bool showEmoji,
    required bool showTitle,
    required String countUnit,
  }) async {
    if (kIsWeb) return;
    try {
      final _DisplayData d = _computeDisplay(event, countUnit);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.pendingTitle,       d.title);
      await HomeWidget.saveWidgetData<int>   (WidgetKeys.pendingCountNum,    d.countNum);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.pendingCountUnit,   d.countUnit);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.pendingCountDir,    d.countDir);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.pendingEmoji,       d.emoji);
      await HomeWidget.saveWidgetData<bool>  (WidgetKeys.pendingTransparent, transparent);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.pendingBgColor,     _colorToHex(bgColor));
      await HomeWidget.saveWidgetData<bool>  (WidgetKeys.pendingShowEmoji,   showEmoji);
      await HomeWidget.saveWidgetData<bool>  (WidgetKeys.pendingShowTitle,   showTitle);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.pendingTextColor,   _colorToHex(textColor));
    } catch (_) {}
  }

  /// Push the widget data (nearest / pinned event) and trigger a redraw for
  /// all widget instances.  Widgets in "specific" mode keep their own data.
  Future<void> pushEvents(List<EventModel> events) async {
    if (kIsWeb) return;

    try {
      // Read global config
      final String eventMode =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgEventMode) ?? 'nearest';
      final bool transparent =
          await HomeWidget.getWidgetData<bool>(WidgetKeys.cfgTransparent) ?? false;
      final String bgColor =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgBgColor) ?? '#CC5E6AD2';
      final String textColor =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgTextColor) ?? '#FFFFFFFF';
      final bool showEmoji =
          await HomeWidget.getWidgetData<bool>(WidgetKeys.cfgShowEmoji) ?? true;
      final bool showTitle =
          await HomeWidget.getWidgetData<bool>(WidgetKeys.cfgShowTitle) ?? true;
      final String countUnitCfg =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgCountUnit) ?? 'days';

      // Select the event to display
      EventModel? target;
      if (eventMode == 'pinned') {
        target = events.where((EventModel e) => e.isPinned).firstOrNull;
      }
      target ??= _nearestUpcoming(events);

      final String title    = target?.title ?? 'No events';
      final String emoji    = target?.emoji ?? '📅';
      int    countNum       = 0;
      String countUnit      = countUnitCfg;
      String countDir       = 'left';

      if (target != null) {
        final _DisplayData d = _computeDisplay(target, countUnitCfg);
        countNum  = d.countNum;
        countUnit = d.countUnit;
        countDir  = d.countDir;
      }

      // ── Write global w_* keys (backward-compat for un-tracked widgets) ──
      await HomeWidget.saveWidgetData<String>(WidgetKeys.title,       title);
      await HomeWidget.saveWidgetData<int>   (WidgetKeys.countNum,    countNum);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.countUnit,   countUnit);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.countDir,    countDir);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.emoji,       emoji);
      await HomeWidget.saveWidgetData<bool>  (WidgetKeys.transparent, transparent);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.bgColor,     bgColor);
      await HomeWidget.saveWidgetData<bool>  (WidgetKeys.showEmoji,   showEmoji);
      await HomeWidget.saveWidgetData<bool>  (WidgetKeys.showTitle,   showTitle);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.textColor,   textColor);

      // ── Also update per-widget keys for every known non-specific widget ──
      final String knownIdsStr =
          await HomeWidget.getWidgetData<String>(WidgetKeys.knownWidgetIds) ?? '';
      if (knownIdsStr.isNotEmpty) {
        for (final String id in knownIdsStr.split(',')) {
          if (id.isEmpty) continue;
          final String mode =
              await HomeWidget.getWidgetData<String>('w_${id}_event_mode') ?? '';
          if (mode == 'specific') continue; // preserve specific-event widgets
          await HomeWidget.saveWidgetData<String>('w_${id}_title',       title);
          await HomeWidget.saveWidgetData<int>   ('w_${id}_count_num',   countNum);
          await HomeWidget.saveWidgetData<String>('w_${id}_count_unit',  countUnit);
          await HomeWidget.saveWidgetData<String>('w_${id}_count_dir',   countDir);
          await HomeWidget.saveWidgetData<String>('w_${id}_emoji',       emoji);
          await HomeWidget.saveWidgetData<bool>  ('w_${id}_transparent', transparent);
          await HomeWidget.saveWidgetData<String>('w_${id}_bg_color',    bgColor);
          await HomeWidget.saveWidgetData<bool>  ('w_${id}_show_emoji',  showEmoji);
          await HomeWidget.saveWidgetData<bool>  ('w_${id}_show_title',  showTitle);
          await HomeWidget.saveWidgetData<String>('w_${id}_text_color',  textColor);
          await HomeWidget.saveWidgetData<String>('w_${id}_event_mode',  eventMode);
        }
      }

      await HomeWidget.updateWidget(
        androidName: 'DayMarkWidgetProvider',
        iOSName: 'DayMarkWidget',
      );
    } catch (_) {
      // Never let widget errors affect the main event flow.
    }
  }

  EventModel? _nearestUpcoming(List<EventModel> events) {
    if (events.isEmpty) return null;
    final DateTime now = DateTime.now();
    final List<EventModel> upcoming = events
        .where((EventModel e) => e.nextOccurrenceDate.isAfter(now))
        .toList(growable: false)
      ..sort((EventModel a, EventModel b) =>
          a.nextOccurrenceDate.compareTo(b.nextOccurrenceDate));
    return upcoming.isEmpty ? events.first : upcoming.first;
  }
}

class _DisplayData {
  const _DisplayData({
    required this.title,
    required this.emoji,
    required this.countNum,
    required this.countUnit,
    required this.countDir,
  });
  final String title;
  final String emoji;
  final int    countNum;
  final String countUnit;
  final String countDir;
}

