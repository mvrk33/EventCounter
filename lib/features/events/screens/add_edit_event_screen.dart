import 'dart:async';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../notifications/notification_service.dart';
import '../../../shared/utils/date_helpers.dart';
import '../models/event_model.dart';
import '../models/suggestion_result.dart';
import '../providers/events_provider.dart';
import '../utils/suggestion_engine.dart';

class AddEditEventScreen extends ConsumerStatefulWidget {
  const AddEditEventScreen({this.existing, super.key});
  final EventModel? existing;

  @override
  ConsumerState<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends ConsumerState<AddEditEventScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late String _category;
  late int _color;
  late String _emoji;
  late List<int> _reminderDays;
  late EventCountUnit _countUnit;
  late EventRecurrence _recurrence;

  SuggestionResult? _pendingSuggestion;
  bool _advancedOpen = false;
  bool _suggestionDismissed = false;
  bool _userHasCustomised = false;
  bool _bannerExpanded = false;
  bool _notificationPermissionChecked = false;
  bool _hasNotificationPermission = true;

  /// Debounce timer for the suggestion engine.
  Timer? _debounce;

  static const List<String> _emojiRow = <String>[
    '🎂',
    '🎉',
    '✈️',
    '💪',
    '🏆',
    '❤️',
    '🌟',
    '🗓️',
    '🎯',
    '🚀',
    '🩺',
    '💼',
    '🎓',
    '🥳',
  ];

  @override
  void initState() {
    super.initState();
    final EventModel? e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now().add(const Duration(days: 1));
    _category = e?.category ?? AppConstants.predefinedCategories.first;
    _color = e?.color ?? const Color(0xFF5E6AD2).toARGB32();
    _emoji = e?.emoji ?? '🗓️';
    _reminderDays = List<int>.from(e?.reminderDays ?? <int>[0, 1]);
    _countUnit = e?.countUnit ?? EventCountUnit.days;
    _recurrence = e?.recurrence ?? EventRecurrence.once;
    _titleController.addListener(_onTitleChanged);
    _refreshNotificationPermissionState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    // In edit mode, only show suggestion if the title actually changed.
    if (widget.existing != null &&
        _titleController.text.trim() == widget.existing!.title.trim()) {
      setState(() => _pendingSuggestion = null);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_userHasCustomised || _suggestionDismissed) return;

      final SuggestionResult? result =
          SuggestionEngine.analyze(_titleController.text);
      setState(() => _pendingSuggestion = result);
    });
  }

  void _acceptSuggestion() {
    final SuggestionResult? s = _pendingSuggestion;
    if (s == null) return;
    setState(() {
      _category = s.primaryCategory;
      _emoji = s.emoji;
      _color = s.primaryColor;
      _recurrence = s.suggestedRecurrence;
      if (s.suggestedReminderDays.isNotEmpty) {
        _reminderDays = List<int>.from(s.suggestedReminderDays);
      }
      _pendingSuggestion = null;
      _bannerExpanded = false;
    });
  }

  void _dismissSuggestion() {
    setState(() {
      _pendingSuggestion = null;
      _suggestionDismissed = true;
      _bannerExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Event' : 'New Event'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        children: <Widget>[
          // ── Title field with smart suggestion ──────────────────────────
          _buildTitleField(context, scheme),
          // ── Smart suggestion banner ────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _pendingSuggestion != null
                ? _buildSuggestionBanner(context, scheme)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          // ── Date ───────────────────────────────────────────────────────
          _buildDateTile(context, scheme),
          const SizedBox(height: 16),
          // ── Count unit ─────────────────────────────────────────────
          _buildCountUnitSection(context, scheme),
          const SizedBox(height: 16),
          // ── Recurrence ─────────────────────────────────────────────
          _buildRecurrenceSection(context, scheme),
          const SizedBox(height: 16),
          // ── Reminders ──────────────────────────────────────────────
          _buildRemindersSection(context, scheme),
          const SizedBox(height: 16),
          // ── Notes ──────────────────────────────────────────────────
          _buildNotesField(context, scheme),
          const SizedBox(height: 16),
          // ── Advanced section ───────────────────────────────────────────
          _buildAdvancedSection(context, scheme),
        ],
      ),
      // ── Sticky save bar ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: Icon(editing ? Icons.check_rounded : Icons.add_rounded),
              label: Text(editing ? 'Update Event' : 'Create Event'),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildTitleField(BuildContext context, ColorScheme scheme) {
    return _FormCard(
      child: TextField(
        controller: _titleController,
        autofocus: widget.existing == null,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Event name…',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(_color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          suffixIcon: _titleController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _titleController.clear();
                    setState(() => _pendingSuggestion = null);
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSuggestionBanner(BuildContext context, ColorScheme scheme) {
    final SuggestionResult s = _pendingSuggestion!;
    final Color accent = Color(s.primaryColor);
    final Color bg = Color(s.bgColor).withValues(alpha: 0.12);

    // Confidence-based label
    final String confidenceLabel = s.confidence >= 0.80
        ? '✨ Looks like a ${s.primaryCategory}!'
        : s.confidence >= 0.50
            ? '💡 This might be a ${s.primaryCategory}'
            : '🤔 Not sure — possibly ${s.primaryCategory}?';

    // Recurrence hint text
    final String recurrenceHint = s.suggestedRecurrence != EventRecurrence.once
        ? ' · ${s.suggestedRecurrence.label}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        label:
            'Smart suggestion: ${s.primaryCategory}. Tap Apply to use, or dismiss.',
        child: GestureDetector(
          onTap: () => setState(() => _bannerExpanded = !_bannerExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Compact row ─────────────────────────────────────────
                Row(
                  children: <Widget>[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        s.emoji,
                        key: ValueKey<String>(s.emoji),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            confidenceLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          Text(
                            'Tap Apply to auto-fill$recurrenceHint',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: accent.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Apply button — minimum 64×36 dp touch target
                    SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: _acceptSuggestion,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(64, 36),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 0),
                          textStyle: GoogleFonts.nunito(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                    // Dismiss — 44×44 dp touch target via padding
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: _dismissSuggestion,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: accent.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Expanded panel ──────────────────────────────────────
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 240),
                  crossFadeState: _bannerExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildBannerExpanded(context, s, accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerExpanded(
      BuildContext context, SuggestionResult s, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),

          // ── Emoji alternatives ───────────────────────────────────────
          if (s.emojiAlternatives.isNotEmpty) ...<Widget>[
            Text(
              'SWAP EMOJI',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.6),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                // Current selection
                _EmojiChip(
                  emoji: s.emoji,
                  selected: true,
                  accent: accent,
                  onTap: () {},
                ),
                const SizedBox(width: 6),
                // Alternatives
                ...s.emojiAlternatives.map((String e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _EmojiChip(
                        emoji: e,
                        selected: false,
                        accent: accent,
                        onTap: () {
                          // Swap emoji and keep banner open
                          setState(() {
                            _pendingSuggestion = SuggestionResult(
                              primaryCategory: s.primaryCategory,
                              emoji: e,
                              primaryColor: s.primaryColor,
                              bgColor: s.bgColor,
                              confidence: s.confidence,
                              secondaryLabels: s.secondaryLabels,
                              emojiAlternatives: <String>[
                                s.emoji,
                                ...s.emojiAlternatives.where(
                                    (String x) => x != e),
                              ],
                              suggestedRecurrence: s.suggestedRecurrence,
                              suggestedReminderDays: s.suggestedReminderDays,
                              isAmbiguous: s.isAmbiguous,
                              disambiguationOptions: s.disambiguationOptions,
                            );
                          });
                        },
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // ── Secondary labels ─────────────────────────────────────────
          if (s.secondaryLabels.isNotEmpty) ...<Widget>[
            Text(
              'ALSO LOOKS LIKE',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.6),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: s.secondaryLabels.map((String label) {
                return GestureDetector(
                  onTap: () {
                    // Let user switch to a secondary category
                    setState(() {
                      _pendingSuggestion = SuggestionResult(
                        primaryCategory: label,
                        emoji: s.emoji,
                        primaryColor: s.primaryColor,
                        bgColor: s.bgColor,
                        confidence: s.confidence,
                        secondaryLabels: <String>[s.primaryCategory],
                        emojiAlternatives: s.emojiAlternatives,
                        suggestedRecurrence: s.suggestedRecurrence,
                        suggestedReminderDays: s.suggestedReminderDays,
                        isAmbiguous: false,
                        disambiguationOptions: const <String>[],
                      );
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 10),
          ],

          // ── Recurrence & reminder preview ───────────────────────────
          Row(
            children: <Widget>[
              if (s.suggestedRecurrence != EventRecurrence.once)
                _PreviewPill(
                  icon: Icons.repeat_rounded,
                  label: s.suggestedRecurrence.label,
                  accent: accent,
                ),
              if (s.suggestedRecurrence != EventRecurrence.once)
                const SizedBox(width: 6),
              if (s.suggestedReminderDays.isNotEmpty)
                _PreviewPill(
                  icon: Icons.notifications_none_rounded,
                  label: _reminderLabel(s.suggestedReminderDays),
                  accent: accent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _reminderLabel(List<int> days) {
    if (days.isEmpty) return 'No reminders';
    final List<String> parts = days.map((int d) {
      if (d == 0) return 'On day';
      return '${d}d before';
    }).toList();
    return parts.join(' · ');
  }

  Widget _buildDateTile(BuildContext context, ColorScheme scheme) {
    final bool isToday = DateHelpers.sameDay(_date, DateTime.now());
    final bool isTomorrow =
        DateHelpers.sameDay(_date, DateTime.now().add(const Duration(days: 1)));
    String label;
    if (isToday) {
      label = 'Today';
    } else if (isTomorrow) {
      label = 'Tomorrow';
    } else {
      label = DateFormat('EEEE, MMMM d, y').format(_date);
    }

    // Preview countdown
    final int daysLeft = DateHelpers.daysBetween(DateTime.now(), _date);
    final String preview = daysLeft > 0
        ? '$daysLeft day${daysLeft == 1 ? '' : 's'} from now'
        : daysLeft == 0
            ? 'Today!'
            : '${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago';

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(20),
      child: _FormCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${_date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      height: 1,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(_date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    preview,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_calendar_rounded,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountUnitSection(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(icon: Icons.timer_outlined, label: 'Count unit'),
        const SizedBox(height: 8),
        _FormCard(
          child: Row(
            children: EventCountUnit.values.map((EventCountUnit unit) {
              final bool selected = _countUnit == unit;
              final String name =
                  unit.name[0].toUpperCase() + unit.name.substring(1);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _countUnit = unit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              selected ? scheme.primary : scheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(icon: Icons.repeat_rounded, label: 'Repeat'),
        const SizedBox(height: 8),
        _FormCard(
          child: Row(
            children: EventRecurrence.values.map((EventRecurrence r) {
              final bool selected = _recurrence == r;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _recurrence = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            r.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r == EventRecurrence.once
                                ? 'Once'
                                : r == EventRecurrence.weekly
                                    ? 'Weekly'
                                    : r == EventRecurrence.monthly
                                        ? 'Monthly'
                                        : 'Yearly',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersSection(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(icon: Icons.notifications_outlined, label: 'Reminders'),
        const SizedBox(height: 8),
        _FormCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <int>[0, 1, 3, 7].map((int d) {
              final bool sel = _reminderDays.contains(d);
              return FilterChip(
                label: Text(d == 0
                    ? 'On event day'
                    : '$d day${d > 1 ? 's' : ''} before'),
                selected: sel,
                selectedColor: scheme.primaryContainer,
                checkmarkColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
                side: BorderSide(
                  color: sel ? scheme.primary : scheme.outlineVariant,
                  width: 1.2,
                ),
                labelStyle: TextStyle(
                  color: sel ? scheme.onPrimaryContainer : scheme.onSurface,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                onSelected: (bool v) => setState(() {
                  if (v) {
                    _reminderDays.add(d);
                  } else {
                    _reminderDays.remove(d);
                  }
                }),
              );
            }).toList(growable: false),
          ),
        ),
        if (_notificationPermissionChecked && !_hasNotificationPermission) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.notifications_off_rounded,
                  size: 16,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications are off. We will ask again when you save with reminders.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesField(BuildContext context, ColorScheme scheme) {
    return _FormCard(
      child: TextField(
        controller: _notesController,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Add notes (optional)…',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Icon(Icons.notes_rounded, size: 20),
          ),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(BuildContext context, ColorScheme scheme) {
    return Column(
      children: <Widget>[
        // Expand/collapse button
        InkWell(
          onTap: () => setState(() => _advancedOpen = !_advancedOpen),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.tune_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Advanced options',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
                Icon(
                  _advancedOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
        // Advanced fields
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          crossFadeState: _advancedOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _buildAdvancedContent(context, scheme),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedContent(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Category
        const _SectionLabel(icon: Icons.label_outline_rounded, label: 'Category'),
        const SizedBox(height: 8),
        _FormCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.predefinedCategories.map((String c) {
              final bool selected = _category == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                selectedColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: 1.2,
                ),
                 onSelected: (_) {
                   setState(() {
                     _category = c;
                     _userHasCustomised = true;
                     _pendingSuggestion = null;
                     // Apply emoji defaults from the emoji bank for this category
                     _emoji = _categoryDefaultEmoji(c);
                   });
                 },
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),
        // Emoji
        const _SectionLabel(icon: Icons.emoji_emotions_outlined, label: 'Emoji'),
        const SizedBox(height: 8),
        _FormCard(
          child: Column(
            children: <Widget>[
              // Emoji quick-picker row
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiRow.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (BuildContext ctx, int i) {
                    final String e = _emojiRow[i];
                    final bool selected = _emoji == e;
                    return GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(_color).withValues(alpha: 0.2)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: Color(_color), width: 2)
                              : Border.all(
                                  color: scheme.outlineVariant, width: 1),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Colour
        const _SectionLabel(icon: Icons.palette_outlined, label: 'Colour'),
        const SizedBox(height: 8),
        _FormCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(_color),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: Color(_color).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Event colour',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.tonal(
                onPressed: _pickColor,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final DateTime? value = await showDatePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickColor() async {
    final Color picked = await showColorPickerDialog(context, Color(_color));
    setState(() => _color = picked.toARGB32());
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name.')),
      );
      return;
    }

    final notifier = ref.read(eventsProvider.notifier);
    if (widget.existing == null) {
      await _requestNotificationsIfNeeded();
      await notifier.addEvent(
        title: title,
        date: _date,
        category: _category,
        color: _color,
        emoji: _emoji,
        notes: _notesController.text.trim(),
        reminderDays: _reminderDays,
        countUnit: _countUnit,
        recurrence: _recurrence,
      );
    } else {
      await notifier.updateEvent(
        widget.existing!.copyWith(
          title: title,
          date: _date,
          category: _category,
          color: _color,
          emoji: _emoji,
          notes: _notesController.text.trim(),
          reminderDays: _reminderDays,
          countUnit: _countUnit,
          recurrence: _recurrence,
          mode: _date.isAfter(DateTime.now())
              ? EventMode.countdown
              : EventMode.countup,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _refreshNotificationPermissionState() async {
    final NotificationService notificationService =
        ref.read(notificationServiceProvider);
    final bool granted = await notificationService.hasNotificationPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationPermissionChecked = true;
      _hasNotificationPermission = granted;
    });
  }

  Future<void> _requestNotificationsIfNeeded() async {
    if (_reminderDays.isEmpty) {
      await _refreshNotificationPermissionState();
      return;
    }

    final NotificationService notificationService =
        ref.read(notificationServiceProvider);
    if (await notificationService.hasNotificationPermission()) {
      await _refreshNotificationPermissionState();
      return;
    }

    final bool granted = await notificationService.requestPermissions();
    if (mounted) {
      setState(() {
        _notificationPermissionChecked = true;
        _hasNotificationPermission = granted;
      });
    }
    if (!mounted || granted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications are still disabled. You can enable them in Alerts later.')),
    );
  }

  /// Returns a sensible default emoji for [category] without needing the
  /// emoji bank import in this file.
  static String _categoryDefaultEmoji(String category) {
    const Map<String, String> defaults = <String, String>{
      'Birthday': '🎂', 'Anniversary': '💑', 'Travel': '✈️',
      'Health': '🩺', 'Fitness': '💪', 'Work': '💼',
      'Finance': '💰', 'Education': '🎓', 'Personal': '⭐',
      'Milestone': '🏆', 'Habit': '🔄', 'Home': '🏠',
      'Vehicle': '🚗', 'Pet': '🐾', 'Food': '🍽️', 'Other': '🗓️',
    };
    return defaults[category] ?? '🗓️';
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: scheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }
}

// ── Banner helper widgets ─────────────────────────────────────────────────────

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.2)
              : accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: accent.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

