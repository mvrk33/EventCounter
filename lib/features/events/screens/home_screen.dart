import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../../../core/hive_boxes.dart';
import '../../../core/constants.dart';
import '../../../core/sync_service.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../habits/providers/habits_provider.dart';
import '../../habits/screens/habits_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/event_model.dart';
import '../providers/events_provider.dart';
import '../services/event_share_service.dart';
import '../services/home_widget_service.dart';
import '../widgets/event_card_polished.dart';
import '../widgets/event_detail_modal.dart';
import 'add_edit_event_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _homeCardViewSettingKey = 'home_card_view_v1';

  int _navIndex = 0;
  late final PageController _pageController;
  final ScreenshotController _screenshotController = ScreenshotController();
  final EventShareService _eventShareService = const EventShareService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  _EventSort _sort = _EventSort.nearest;
  _HomeCardView _cardView = _HomeCardView.comfortable;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndexFromNav(_navIndex));
    _cardView = _readPersistedCardView();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      _eventsTab(context),
      const HabitsScreen(),
      const NotificationsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (int pageIndex) {
          setState(() {
            _navIndex = _navIndexFromTab(pageIndex);
          });
        },
        children: tabs,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _navIndex,
        onTap: (int index) {
          if (index == 2) {
            // Always return to Home (index 0) after dismissing the add screen,
            // regardless of which tab the user was on when they tapped New.
            Navigator.of(context)
                .push(
              MaterialPageRoute<void>(
                  builder: (_) => const AddEditEventScreen()),
            )
                .then((_) {
              if (mounted) {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
                setState(() => _navIndex = 0);
              }
            });
            return;
          }
          _pageController.animateToPage(
            _tabIndexFromNav(index),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
          setState(() {
            _navIndex = index;
          });
        },
      ),
    );
  }

  int _tabIndexFromNav(int navIndex) {
    if (navIndex <= 1) return navIndex;
    if (navIndex == 3) return 2;
    return 3;
  }

  int _navIndexFromTab(int tabIndex) {
    if (tabIndex <= 1) return tabIndex;
    if (tabIndex == 2) return 3;
    return 4;
  }

  Widget _eventsTab(BuildContext context) {
    final events = ref.watch(eventsProvider);
    final habits = ref.watch(habitsProvider);
    final List<EventModel> visibleEvents = _buildVisibleEvents(events);

    // Count how many events are happening this week
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int thisWeekCount = events.where((e) {
      // Use nextOccurrenceDate for recurring events to get the actual upcoming date
      final d = DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day);
      return d.difference(today).inDays <= 7 && !d.isBefore(today);
    }).length;

    return RefreshIndicator(
      onRefresh: () async {
        final SyncService sync = ref.read(syncServiceProvider);
        await sync.syncAll(messenger: ScaffoldMessenger.of(context));
      },
      child: CustomScrollView(
        slivers: <Widget>[
          // ── Greeting header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildGreetingHeader(context, thisWeekCount, habits.length),
          ),
          // ── Search & filter bar ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildSearchBar(context),
          ),
          // ── Category chips ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _filtersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildFilterPanel(
                  context, events.length, visibleEvents.length),
            ),
          ),
          // ── Empty states ───────────────────────────────────────────────
          if (events.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, isEmpty: true),
            )
          else if (visibleEvents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, isEmpty: false),
            )
          else ...[
            // ── Section list ───────────────────────────────────────────
            ..._buildSectionedSlivers(context, visibleEvents),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(
      BuildContext context, int thisWeekCount, int habitCount) {
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final String dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Greeting + date
          Text(
            '$greeting 👋',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 3),
          Text(
            dateStr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.50),
                ),
          ),
          const SizedBox(height: 18),
          // Dashboard stat cards (full-width pair)
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  icon: Icons.event_rounded,
                  label: 'This week',
                  value: '$thisWeekCount',
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Active habits',
                  value: '$habitCount',
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (String value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.4)),
                hintText: 'Search events…',
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(Icons.cancel_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.35),
                            size: 18),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter toggle button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _filtersExpanded
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: () =>
                  setState(() => _filtersExpanded = !_filtersExpanded),
              icon: Icon(
                Icons.tune_rounded,
                color: _filtersExpanded
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface.withValues(alpha: 0.55),
              ),
              tooltip: 'Filter & sort',
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _cardView == _HomeCardView.comfortable
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: () {
                _setCardView(
                  _cardView == _HomeCardView.comfortable
                      ? _HomeCardView.compact
                      : _HomeCardView.comfortable,
                );
              },
              icon: Icon(
                _cardView.icon,
                color: _cardView == _HomeCardView.comfortable
                    ? scheme.onSecondaryContainer
                    : scheme.onSurface.withValues(alpha: 0.55),
              ),
              tooltip: 'Card view: ${_cardView.label}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(
      BuildContext context, int totalCount, int visibleCount) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    <String>['All', ...AppConstants.predefinedCategories].map(
                  (String cat) {
                    final bool selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          color: selected ? scheme.onPrimary : scheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        backgroundColor: scheme.surface,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  },
                ).toList(growable: false),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Text(
                  '$visibleCount of $totalCount events',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_EventSort>(
                      value: _sort,
                      isDense: true,
                      style: Theme.of(context).textTheme.labelLarge,
                      onChanged: (_EventSort? value) {
                        if (value != null) setState(() => _sort = value);
                      },
                      items: _EventSort.values
                          .map(
                            (_EventSort s) => DropdownMenuItem<_EventSort>(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Card view',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_HomeCardView>(
              segments: _HomeCardView.values
                  .map(
                    (_HomeCardView view) => ButtonSegment<_HomeCardView>(
                      value: view,
                      icon: Icon(view.icon, size: 18),
                      label: Text(view.label),
                    ),
                  )
                  .toList(growable: false),
              selected: <_HomeCardView>{_cardView},
              onSelectionChanged: (Set<_HomeCardView> selection) {
                if (selection.isEmpty) return;
                _setCardView(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isEmpty}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isEmpty ? '🗓️' : '🔍',
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEmpty ? 'No events yet' : 'No matching events',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isEmpty
                  ? 'Tap the + button below\nto create your first event.'
                  : 'Try adjusting your search\nor clear the filters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
              textAlign: TextAlign.center,
            ),
            if (!isEmpty) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _clearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<EventModel> _buildVisibleEvents(List<EventModel> events) {
    final List<EventModel> filtered = events.where((EventModel event) {
      final bool categoryOk =
          _selectedCategory == 'All' || event.category == _selectedCategory;
      if (!categoryOk) return false;
      if (_searchQuery.isEmpty) return true;
      final String haystack =
          '${event.title} ${event.notes} ${event.category}'.toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList(growable: false);

    final List<EventModel> sorted = <EventModel>[...filtered];
    sorted.sort((EventModel a, EventModel b) {
      switch (_sort) {
        case _EventSort.pinnedFirst:
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return a.date.compareTo(b.date);
        case _EventSort.nearest:
          return a.date.compareTo(b.date);
        case _EventSort.farthest:
          return b.date.compareTo(a.date);
        case _EventSort.recentlyUpdated:
          return b.updatedAt.compareTo(a.updatedAt);
        case _EventSort.titleAz:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return sorted;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _sort = _EventSort.nearest;
    });
  }

  List<Widget> _buildSectionedSlivers(
      BuildContext context, List<EventModel> events) {
    final List<Widget> slivers = <Widget>[];
    final List<EventModel> pinned =
        events.where((e) => e.isPinned).toList(growable: false);
    final List<EventModel> regular =
        events.where((e) => !e.isPinned).toList(growable: false);

    if (pinned.isNotEmpty) {
      slivers.add(_sectionHeader(context, '📌  Pinned'));
      slivers.add(_eventList(context, pinned));
    }

    final Map<String, List<EventModel>> sections = <String, List<EventModel>>{
      '🗓️  This Week': <EventModel>[],
      '🗓️  This Month': <EventModel>[],
      '🔭  Later': <EventModel>[],
      '⏳  Past & Count Up': <EventModel>[],
    };

    for (final EventModel event in regular) {
      sections[_bucketFor(event)]!.add(event);
    }

    for (final MapEntry<String, List<EventModel>> section in sections.entries) {
      if (section.value.isEmpty) continue;
      slivers.add(_sectionHeader(context, section.key));
      slivers.add(_eventList(context, section.value));
    }

    return slivers;
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventList(BuildContext context, List<EventModel> events) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) =>
            _buildEventTile(context, events[index]),
        childCount: events.length,
      ),
    );
  }

  String _bucketFor(EventModel event) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    // Use nextOccurrenceDate for recurring events to get the actual upcoming date
    final DateTime eventDay =
        DateTime(event.nextOccurrenceDate.year, event.nextOccurrenceDate.month, event.nextOccurrenceDate.day);

    if (event.mode == EventMode.countup || eventDay.isBefore(today)) {
      return '⏳  Past & Count Up';
    }
    final int diff = eventDay.difference(today).inDays;
    if (diff <= 7) return '🗓️  This Week';
    if (diff <= 31) return '🗓️  This Month';
    return '🔭  Later';
  }

  Widget _buildEventTile(BuildContext context, EventModel event) {
    return EventCardPolished(
      event: event,
      density: _cardView == _HomeCardView.comfortable
          ? EventCardDensity.comfortable
          : EventCardDensity.compact,
      onTap: () => _showEventDetail(context, event),
      onShare: () => _shareEvent(event),
      onEdit: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => AddEditEventScreen(existing: event)),
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
        MaterialPageRoute<void>(
            builder: (_) => AddEditEventScreen(existing: event)),
      );
    } else if (result == 'delete' && mounted) {
      ref.read(eventsProvider.notifier).deleteEvent(event.id);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
    } else if (result == 'add_widget' && mounted) {
      _addEventToHomeScreen(event);
    }
  }

  Future<void> _shareEvent(EventModel event) async {
    final bytes = await _screenshotController.captureFromWidget(
      _eventShareService.buildShareCard(
        emoji: event.emoji,
        title: event.title,
        subtitle:
            '${event.category} • ${DateHelpers.eventCountDescription(event)}',
        color: Color(event.color),
      ),
      pixelRatio: 2,
    );
    await _eventShareService.shareCardImage(bytes);
  }

  Future<void> _addEventToHomeScreen(EventModel event) async {
    // Show a dialog for per-event widget configuration
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => _EventWidgetConfigDialog(event: event),
    );
  }

  void _setCardView(_HomeCardView view) {
    if (_cardView == view) {
      return;
    }
    setState(() => _cardView = view);
    if (Hive.isBoxOpen(HiveBoxes.settings)) {
      Hive.box<dynamic>(HiveBoxes.settings)
          .put(_homeCardViewSettingKey, view.name);
    }
  }

  _HomeCardView _readPersistedCardView() {
    if (!Hive.isBoxOpen(HiveBoxes.settings)) {
      return _HomeCardView.comfortable;
    }
    final String? raw = Hive.box<dynamic>(HiveBoxes.settings)
        .get(_homeCardViewSettingKey) as String?;
    for (final _HomeCardView item in _HomeCardView.values) {
      if (item.name == raw) {
        return item;
      }
    }
    return _HomeCardView.comfortable;
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.50),
                ),
          ),
        ],
      ),
    );
  }
}

enum _EventSort {
  pinnedFirst('Pinned First'),
  nearest('Nearest'),
  farthest('Farthest'),
  recentlyUpdated('Recently Updated'),
  titleAz('Title A–Z');

  const _EventSort(this.label);
  final String label;
}

enum _HomeCardView {
  comfortable('Comfortable', Icons.view_agenda_rounded),
  compact('Compact', Icons.view_headline_rounded);

  const _HomeCardView(this.label, this.icon);
  final String label;
  final IconData icon;
}

// Per-event widget size selection and configuration dialog
class _EventWidgetConfigDialog extends ConsumerStatefulWidget {
  const _EventWidgetConfigDialog({required this.event});

  final EventModel event;

  @override
  ConsumerState<_EventWidgetConfigDialog> createState() =>
      _EventWidgetConfigDialogState();
}

class _EventWidgetConfigDialogState
    extends ConsumerState<_EventWidgetConfigDialog> {
  static const MethodChannel _widgetChannel =
      MethodChannel('event_counter/widget_actions');

  late bool _transparent;
  late Color _bgColor;
  late Color _textColor;
  late bool _showEmoji;
  late bool _showTitle;
  late String _countUnit;
  String _selectedSize = '2x2'; // Default to 2x2

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
      // Write pending widget data so the new widget slot picks up this event
      await const EventHomeWidgetService().pushPendingEventWidget(
        event: widget.event,
        transparent: _transparent,
        bgColor: _bgColor,
        textColor: _textColor,
        showEmoji: _showEmoji,
        showTitle: _showTitle,
        countUnit: _countUnit,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          widget.event.title,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                (_transparent ? scheme.onSurface : _textColor)
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
            // Widget size selection
            Text(
              'Widget Size',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <String>['2x2', '4x2', '4x4'].map((String size) {
                final bool selected = _selectedSize == size;
                return ChoiceChip(
                  label: Text(size),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSize = size),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Display options
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
