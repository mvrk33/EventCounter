import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../shared/utils/date_helpers.dart';
import '../models/event_model.dart';
import '../providers/events_provider.dart';
import '../utils/smart_category_helper.dart';

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

  SmartSuggestion? _pendingSuggestion;
  bool _advancedOpen = false;

  static const List<String> _emojiRow = <String>[
    '🎂','🎉','✈️','💪','🏆','❤️','🌟','📅','🎯','🚀','🩺','💼','🎓','🥳',
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
    _emoji = e?.emoji ?? '📅';
    _reminderDays = List<int>.from(e?.reminderDays ?? <int>[0, 1]);
    _countUnit = e?.countUnit ?? EventCountUnit.days;
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    final SmartSuggestion? s =
        SmartCategoryHelper.fromTitle(_titleController.text);
    if (s != null && s.category != _category) {
      setState(() => _pendingSuggestion = s);
    } else if (s == null) {
      setState(() => _pendingSuggestion = null);
    }
  }

  void _acceptSuggestion() {
    if (_pendingSuggestion == null) return;
    setState(() {
      _category = _pendingSuggestion!.category;
      _emoji = _pendingSuggestion!.emoji;
      _color = _pendingSuggestion!.color;
      _pendingSuggestion = null;
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
    final SmartSuggestion s = _pendingSuggestion!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color(s.color).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(s.color).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            Text(s.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '✨ Looks like a ${s.category}!',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(s.color),
                    ),
                  ),
                  Text(
                    s.suggestYearly
                        ? 'Auto-fill: category, emoji, colour + yearly recurrence'
                        : 'Auto-fill: category, emoji & colour',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: Color(s.color).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _acceptSuggestion,
              style: FilledButton.styleFrom(
                backgroundColor: Color(s.color),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                textStyle:
                    GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              child: const Text('Apply'),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => setState(() => _pendingSuggestion = null),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(s.color).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(BuildContext context, ColorScheme scheme) {
    final bool isToday = DateHelpers.sameDay(_date, DateTime.now());
    final bool isTomorrow = DateHelpers.sameDay(
        _date, DateTime.now().add(const Duration(days: 1)));
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
        _SectionLabel(icon: Icons.timer_outlined, label: 'Count unit'),
        const SizedBox(height: 8),
        _FormCard(
          child: Row(
            children: EventCountUnit.values.map((EventCountUnit unit) {
              final bool selected = _countUnit == unit;
              final String name = unit.name[0].toUpperCase() + unit.name.substring(1);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _countUnit = unit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? scheme.primary : scheme.outlineVariant,
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

  Widget _buildRemindersSection(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(icon: Icons.notifications_outlined, label: 'Reminders'),
        const SizedBox(height: 8),
        _FormCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <int>[0, 1, 7].map((int d) {
              final bool sel = _reminderDays.contains(d);
              return FilterChip(
                label: Text(d == 0 ? 'On event day' : '$d day${d > 1 ? 's' : ''} before'),
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
        _SectionLabel(icon: Icons.label_outline_rounded, label: 'Category'),
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
                    final SmartSuggestion? s =
                        SmartCategoryHelper.fromCategory(c);
                    if (s != null) {
                      _emoji = s.emoji;
                      _color = s.color;
                    }
                  });
                },
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),
        // Emoji
        _SectionLabel(icon: Icons.emoji_emotions_outlined, label: 'Emoji'),
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
                          child: Text(e,
                              style: const TextStyle(fontSize: 22)),
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
        _SectionLabel(icon: Icons.palette_outlined, label: 'Colour'),
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
    final Color picked =
        await showColorPickerDialog(context, Color(_color));
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
      await notifier.addEvent(
        title: title,
        date: _date,
        category: _category,
        color: _color,
        emoji: _emoji,
        notes: _notesController.text.trim(),
        reminderDays: _reminderDays,
        countUnit: _countUnit,
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
          mode: _date.isAfter(DateTime.now())
              ? EventMode.countdown
              : EventMode.countup,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
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
