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
  late bool _liveNotification;

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
    _liveNotification = e?.liveNotification ?? false;
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
      _countUnit = s.suggestedCountUnit;
      if (s.suggestedDate != null) {
        _date = s.suggestedDate!;
      }
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              editing ? 'Edit Event' : 'New Event',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: false,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            stretch: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                const SizedBox(height: 24),
                // ── Count unit ─────────────────────────────────────────────
                _buildCountUnitSection(context, scheme),
                const SizedBox(height: 24),
                // ── Recurrence ─────────────────────────────────────────────
                _buildRecurrenceSection(context, scheme),
                const SizedBox(height: 24),
                // ── Reminders ──────────────────────────────────────────────
                _buildRemindersSection(context, scheme),
                const SizedBox(height: 24),
                // ── Notes ──────────────────────────────────────────────────
                _buildNotesField(context, scheme),
                const SizedBox(height: 24),
                // ── Advanced section ───────────────────────────────────────────
                _buildAdvancedSection(context, scheme),
              ]),
            ),
          ),
        ],
      ),
      // ── Sticky save bar ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.8),
          border: Border(
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(editing ? Icons.check_rounded : Icons.add_rounded),
                  const SizedBox(width: 10),
                  Text(
                    editing ? 'Update Event' : 'Create Event',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildTitleField(BuildContext context, ColorScheme scheme) {
    return _FormCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextField(
        controller: _titleController,
        autofocus: widget.existing == null,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: 'Event name…',
          hintStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 56,
            height: 56,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(_color).withValues(alpha: 0.25),
                  Color(_color).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Color(_color).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          suffixIcon: _titleController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
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

    // Date hint text
    String dateHint = '';
    if (s.suggestedDate != null) {
      final bool isToday = DateHelpers.sameDay(s.suggestedDate!, DateTime.now());
      final bool isTomorrow = DateHelpers.sameDay(
          s.suggestedDate!, DateTime.now().add(const Duration(days: 1)));
      if (isToday) {
        dateHint = ' · Today';
      } else if (isTomorrow) {
        dateHint = ' · Tomorrow';
      } else {
        dateHint = ' · ${DateFormat('MMM d').format(s.suggestedDate!)}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        label:
            'Smart suggestion: ${s.primaryCategory}. Tap Apply to use, or dismiss.',
        child: GestureDetector(
          onTap: () => setState(() => _bannerExpanded = !_bannerExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.15),
                  accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Compact row ─────────────────────────────────────────
                Row(
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          s.emoji,
                          key: ValueKey<String>(s.emoji),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            confidenceLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          Text(
                            'Tap Apply to auto-fill$recurrenceHint$dateHint',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Apply button
                    SizedBox(
                      height: 40,
                      child: FilledButton(
                        onPressed: _acceptSuggestion,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 0),
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    // Dismiss
                    IconButton(
                      onPressed: _dismissSuggestion,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: accent.withValues(alpha: 0.4),
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
              if (s.suggestedDate != null) const SizedBox(width: 6),
              if (s.suggestedDate != null)
                _PreviewPill(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('MMM d').format(s.suggestedDate!),
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
      borderRadius: BorderRadius.circular(28),
      child: _FormCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.15),
                    scheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${_date.day}',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(_date).toUpperCase(),
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_calendar_rounded,
                size: 20,
                color: scheme.primary,
              ),
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
        const SizedBox(height: 12),
        Row(
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
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? scheme.onPrimary
                            : scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(icon: Icons.repeat_rounded, label: 'Repeat'),
        const SizedBox(height: 12),
        _FormCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: EventRecurrence.values.map((EventRecurrence r) {
              final bool selected = _recurrence == r;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _recurrence = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            r.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.6),
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
    // Preset options; any custom values added by user also appear as chips.
    const List<int> presets = <int>[0, 1, 3, 7, 14, 30];
    final List<int> allChips = <int>{
      ...presets,
      ..._reminderDays.where((int d) => !presets.contains(d)),
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel(icon: Icons.notifications_outlined, label: 'Reminders'),
        const SizedBox(height: 12),
        _FormCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Reminder day chips ────────────────────────────────────
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ...allChips.map((int d) {
                    final bool sel = _reminderDays.contains(d);
                    return FilterChip(
                      label: Text(d == 0
                          ? 'On event day'
                          : '$d day${d > 1 ? 's' : ''} before'),
                      selected: sel,
                      onSelected: (bool v) => setState(() {
                        if (v) {
                          _reminderDays.add(d);
                        } else {
                          _reminderDays.remove(d);
                        }
                      }),
                      selectedColor: scheme.primary.withValues(alpha: 0.15),
                      checkmarkColor: scheme.primary,
                      backgroundColor: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: sel ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      labelStyle: GoogleFonts.nunito(
                        color: sel ? scheme.primary : scheme.onSurface.withValues(alpha: 0.8),
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    );
                  }),
                  // ── + Custom chip ────────────────────────────────────
                  ActionChip(
                    avatar: Icon(Icons.add_rounded,
                        size: 18, color: scheme.primary),
                    label: const Text('Custom'),
                    onPressed: () async {
                      final int? days = await _showCustomDayDialog(context);
                      if (days != null && days > 0) {
                        setState(() {
                          if (!_reminderDays.contains(days)) {
                            _reminderDays.add(days);
                          }
                        });
                      }
                    },
                    backgroundColor: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3), width: 1.5),
                    ),
                    labelStyle: GoogleFonts.nunito(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, thickness: 1),
              ),
              // ── Live notification toggle ──────────────────────────────
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Color(0xFFFFC107)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.show_chart_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Live Progress',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            )),
                        Text(
                          'Show countdown in notification shade',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _liveNotification,
                    onChanged: (bool v) =>
                        setState(() => _liveNotification = v),
                    activeColor: scheme.primary,
                  ),
                ],
              ),
            ],
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

  /// Shows a dialog asking the user for a custom number of days before the event.
  Future<int?> _showCustomDayDialog(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Custom reminder'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. 10',
              suffixText: 'days before',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int? v = int.tryParse(ctrl.text.trim());
                Navigator.of(ctx).pop(v);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotesField(BuildContext context, ColorScheme scheme) {
    return _FormCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _notesController,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 5,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Add notes (optional)…',
          hintStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Icon(Icons.notes_rounded, size: 22, color: scheme.primary.withValues(alpha: 0.6)),
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1.5),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.tune_rounded, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Advanced options',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
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
        const SizedBox(height: 12),
        _FormCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppConstants.predefinedCategories.map((String c) {
              final bool selected = _category == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _category = c;
                    _userHasCustomised = true;
                    _pendingSuggestion = null;
                    // Apply emoji defaults from the emoji bank for this category
                    _emoji = _categoryDefaultEmoji(c);
                  });
                },
                selectedColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                labelStyle: GoogleFonts.nunito(
                  color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 24),
        // Emoji
        const _SectionLabel(icon: Icons.emoji_emotions_outlined, label: 'Emoji'),
        const SizedBox(height: 12),
        _FormCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              // Emoji quick-picker row
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiRow.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext ctx, int i) {
                    final String e = _emojiRow[i];
                    final bool selected = _emoji == e;
                    return GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(_color).withValues(alpha: 0.15)
                              : scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? Color(_color) : scheme.outlineVariant.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Colour
        const _SectionLabel(icon: Icons.palette_outlined, label: 'Colour'),
        const SizedBox(height: 12),
        _FormCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(_color),
                      Color(_color).withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: Color(_color).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Event Colour',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: _pickColor,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                child: Text(
                  'Change',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
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
        liveNotification: _liveNotification,
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
          liveNotification: _liveNotification,
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
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: scheme.primary.withValues(alpha: 0.7),
              letterSpacing: 1.2,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(20),
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

