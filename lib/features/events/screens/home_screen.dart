import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../../../core/auth_service.dart';
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
  Timer? _searchDebounce;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  _EventSort _sort = _EventSort.nearest;
  _HomeCardView _cardView = _HomeCardView.comfortable;
  bool _filtersExpanded = false;

  List<EventModel>? _cachedVisibleEvents;
  List<EventModel>? _cachedSourceEvents;
  String _cachedSearchQuery = '';
  String _cachedSelectedCategory = 'All';
  _EventSort _cachedSort = _EventSort.nearest;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndexFromNav(_navIndex));
    _cardView = _readPersistedCardView();
    // Trigger a cloud restore after the home screen appears so events stored
    // in Firestore are pulled down even if the user skipped RestoreDataScreen
    // or auto-restore was previously disabled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialCloudSync());
  }

  Future<void> _initialCloudSync() async {
    final auth = ref.read(authServiceProvider);
    if (!auth.isSignedIn || !mounted) return;
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).restoreAll();
    } catch (_) {
      // Silently ignore — events already in local Hive remain visible.
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (int pageIndex) {
            setState(() {
              _navIndex = _navIndexFromTab(pageIndex);
            });
          },
          children: tabs,
        ),
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
      final d = DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day);
      return d.difference(today).inDays <= 7 && !d.isBefore(today);
    }).length;

    // Find "next up" event — the nearest upcoming event
    EventModel? nextUpEvent;
    {
      final upcoming = events.where((e) {
        final d = DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day);
        return !d.isBefore(today);
      }).toList(growable: false);
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => a.nextOccurrenceDate.compareTo(b.nextOccurrenceDate));
        nextUpEvent = upcoming.first;
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        final SyncService sync = ref.read(syncServiceProvider);
        final messenger = ScaffoldMessenger.of(context);
        await sync.restoreAll(messenger: messenger);
        await sync.syncAll(messenger: messenger);
      },
      child: CustomScrollView(
        slivers: <Widget>[
          // ── Greeting header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildGreetingHeader(context, thisWeekCount, habits.length),
          ),
          // ── Insight Dashboard (Replaces "Next Up" spotlight) ──────────
          if (_searchQuery.isEmpty && _selectedCategory == 'All')
            SliverToBoxAdapter(
              child: _buildInsightDashboard(context, nextUpEvent, habits),
            ),
          // ── Cloud sync banner (shows while initial restore runs) ──────
          if (_isSyncing)
            SliverToBoxAdapter(
              child: _buildSyncBanner(context),
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

  Widget _buildInsightDashboard(
      BuildContext context, EventModel? nextUp, List<dynamic> habits) {
    final events = ref.watch(eventsProvider);
    final insights = _generateIntelligentInsights(events, habits);

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: insights.length,
        itemBuilder: (context, index) {
          final insight = insights[index];
          return _InsightCard(
            width: insight.width,
            gradient: insight.gradient,
            onTap: insight.onTap,
            child: Stack(
              children: [
                if (insight.backgroundEmoji != null)
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Text(
                      insight.backgroundEmoji!,
                      style: TextStyle(
                        fontSize: 100,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardTag(label: insight.tag, icon: insight.icon),
                      const Spacer(),
                      Text(
                        insight.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: insight.titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insight.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_DashboardInsight> _generateIntelligentInsights(
      List<EventModel> events, List<dynamic> habits) {
    final List<_DashboardInsight> insights = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Next Up (Primary Insight)
    final upcoming = events
        .where((e) => !DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day).isBefore(today))
        .toList();
    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => a.nextOccurrenceDate.compareTo(b.nextOccurrenceDate));
      final next = upcoming.first;
      final diff = DateHelpers.daysBetween(today, next.nextOccurrenceDate).abs();
      
      insights.add(_DashboardInsight(
        tag: 'COMING UP',
        icon: Icons.auto_awesome_rounded,
        title: next.title,
        subtitle: diff == 0 ? 'Happening Today' : 'In $diff days',
        gradient: [const Color(0xFF6366F1), const Color(0xFF4338CA)],
        backgroundEmoji: next.emoji,
        width: 280,
        titleSize: 20,
        onTap: () => _showEventDetail(context, next),
      ));
    }

    // 2. High Density Day
    final Map<DateTime, int> dayCounts = {};
    for (final e in upcoming) {
      final d = DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day);
      dayCounts[d] = (dayCounts[d] ?? 0) + 1;
    }
    
    DateTime? busyDay;
    int maxCount = 0;
    dayCounts.forEach((date, count) {
      if (count > 1 && count > maxCount) {
        maxCount = count;
        busyDay = date;
      }
    });

    if (busyDay != null && busyDay!.difference(today).inDays <= 14) {
      final dayName = DateFormat('EEEE').format(busyDay!);
      insights.add(_DashboardInsight(
        tag: 'BUSY DAY',
        icon: Icons.calendar_month_rounded,
        title: '$maxCount events on $dayName',
        subtitle: busyDay == today ? 'Better get ready!' : 'Mark your calendar',
        gradient: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
        width: 220,
      ));
    }

    // 3. Habit Momentum
    if (habits.isNotEmpty) {
      dynamic topHabit;
      int maxStreak = 0;
      for (final h in habits) {
        if (h.currentStreak > maxStreak) {
          maxStreak = h.currentStreak;
          topHabit = h;
        }
      }
      
      if (maxStreak >= 3) {
        insights.add(_DashboardInsight(
          tag: 'MOMENTUM',
          icon: Icons.local_fire_department_rounded,
          title: '$maxStreak Day Streak',
          subtitle: 'Keep it up with ${topHabit.title}!',
          gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          backgroundEmoji: topHabit.emoji,
          width: 220,
          onTap: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
        ));
      }
    }

    // 4. Milestone Alert (Count-ups)
    final past = events.where((e) => e.mode == EventMode.countup || e.nextOccurrenceDate.isBefore(today)).toList();
    for (final e in past) {
      final days = DateHelpers.daysBetween(e.date, today).abs();
      if (days > 0 && (days % 100 == 0 || days == 365 || days == 30)) {
        insights.add(_DashboardInsight(
          tag: 'MILESTONE',
          icon: Icons.emoji_events_rounded,
          title: '$days Days Since',
          subtitle: e.title,
          gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
          backgroundEmoji: '🎉',
          width: 220,
        ));
        break; // Just show one milestone at a time
      }
    }

    // 5. Category Balance
    if (events.length > 5) {
      final Map<String, int> catCounts = {};
      for (final e in events) {
        catCounts[e.category] = (catCounts[e.category] ?? 0) + 1;
      }
      
      String? majorCat;
      int catMax = 0;
      catCounts.forEach((cat, count) {
        if (count > catMax) {
          catMax = count;
          majorCat = cat;
        }
      });

      if (majorCat != null && catMax > events.length / 2) {
        insights.add(_DashboardInsight(
          tag: 'BALANCE',
          icon: Icons.pie_chart_rounded,
          title: 'Focusing on $majorCat',
          subtitle: 'That\'s $catMax of your markers!',
          gradient: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
          width: 220,
        ));
      }
    }

    return insights;
  }

  // Removed _buildNextUpCard as it is replaced by _buildInsightDashboard

  Widget _buildGreetingHeader(
      BuildContext context, int thisWeekCount, int habitCount) {
    final hour = DateTime.now().hour;

    final String greeting;
    if (hour < 5) {
      greeting = 'Late night';
    } else if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final String dayStr = DateFormat('EEEE').format(DateTime.now());
    final String dateStr = DateFormat('MMMM d').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hour < 5
                          ? Icons.nightlight_round
                          : hour < 17
                              ? Icons.wb_sunny_rounded
                              : Icons.wb_twilight_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'This Week',
                  value: '$thisWeekCount',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Habits',
                  value: '$habitCount',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Total',
                  value: '${ref.watch(eventsProvider).length}',
                  icon: Icons.all_inclusive_rounded,
                  color: const Color(0xFFA855F7),
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
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 120), () {
                  if (!mounted) return;
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
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

  Widget _buildSyncBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Syncing your events from cloud…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
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
            // Illustration
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    scheme.primaryContainer.withValues(alpha: 0.55),
                    scheme.primaryContainer.withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  isEmpty ? '🗓️' : '🔍',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isEmpty ? 'No events yet' : 'No matching events',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isEmpty
                  ? 'Tap the ＋ button below\nto create your first event.'
                  : 'Try adjusting your search\nor clear the active filters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.50),
                    height: 1.6,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!isEmpty) ...<Widget>[
              const SizedBox(height: 28),
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
    if (identical(events, _cachedSourceEvents) &&
        _searchQuery == _cachedSearchQuery &&
        _selectedCategory == _cachedSelectedCategory &&
        _sort == _cachedSort &&
        _cachedVisibleEvents != null) {
      return _cachedVisibleEvents!;
    }

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

    _cachedSourceEvents = events;
    _cachedSearchQuery = _searchQuery;
    _cachedSelectedCategory = _selectedCategory;
    _cachedSort = _sort;
    _cachedVisibleEvents = sorted;
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
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      scheme.outlineVariant.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
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

class _DashboardInsight {
  const _DashboardInsight({
    required this.tag,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.backgroundEmoji,
    this.width = 200,
    this.titleSize = 18,
    this.onTap,
  });

  final String tag;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final String? backgroundEmoji;
  final double width;
  final double titleSize;
  final VoidCallback? onTap;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.child,
    required this.gradient,
    this.width,
    this.onTap,
  });

  final Widget child;
  final List<Color> gradient;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DashboardTag extends StatelessWidget {
  const _DashboardTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Compact pill badge used inside the hero gradient banner.
class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
      await EventHomeWidgetService().pushPendingEventWidget(
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  Text(
                    'Widget Preview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Live preview - styled like a real widget
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _transparent
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : _bgColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: <BoxShadow>[
                      if (!_transparent)
                        BoxShadow(
                          color: _bgColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -15,
                        top: -15,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (_showEmoji)
                              Text(
                                widget.event.emoji,
                                style: const TextStyle(fontSize: 36),
                              ),
                            Text(
                              '$value',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: _transparent ? scheme.onSurface : _textColor,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              _countUnit,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: (_transparent ? scheme.onSurface : _textColor)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            if (_showTitle)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  widget.event.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: (_transparent ? scheme.onSurface : _textColor)
                                        .withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildConfigSection(
                context,
                'WIDGET SIZE',
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
              ),
              const SizedBox(height: 16),
              _buildConfigSection(
                context,
                'OPTIONS',
                Column(
                  children: [
                    _ConfigToggle(
                      label: 'Show emoji',
                      value: _showEmoji,
                      onChanged: (v) => setState(() => _showEmoji = v),
                    ),
                    _ConfigToggle(
                      label: 'Show event name',
                      value: _showTitle,
                      onChanged: (v) => setState(() => _showTitle = v),
                    ),
                    _ConfigToggle(
                      label: 'Transparent background',
                      value: _transparent,
                      onChanged: (v) => setState(() => _transparent = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildConfigSection(
                context,
                'COUNT UNIT',
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
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _pinEventWidget,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_to_home_screen_rounded),
                  label: const Text(
                    'Add Widget',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigSection(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ConfigToggle extends StatelessWidget {
  const _ConfigToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
