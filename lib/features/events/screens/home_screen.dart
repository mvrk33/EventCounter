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
import '../../../core/user_context_provider.dart';
import '../../../shared/utils/date_helpers.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/liquid_glass.dart';
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
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;
    
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
          if (_searchQuery.isEmpty && _selectedCategory == 'All' && !isStressed)
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

    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                'INSIGHTS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              _buildInsightPageIndicator(insights.length),
            ],
          ),
        ),
        SizedBox(
          height: isStressed ? 160 : 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            physics: const BouncingScrollPhysics(),
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final insight = insights[index];
              return Container(
                width: MediaQuery.of(context).size.width * (isStressed ? 0.75 : 0.82),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: _StaggeredAnimatedInsightCard(
                  insight: insight,
                  index: index,
                  compact: isStressed,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInsightPageIndicator(int count) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: List.generate(
        count,
        (index) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: index == 0 ? 0.6 : 0.2),
          ),
        ),
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
        width: 220,
        titleSize: 14,
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
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;

    final String greeting;
    if (isStressed) {
      greeting = 'Breathe deep';
    } else if (hour < 5) {
      greeting = 'Late hours';
    } else if (hour < 12) {
      greeting = 'Rise & shine';
    } else if (hour < 17) {
      greeting = 'Keep going';
    } else {
      greeting = 'Wind down';
    }

    final String dayStr = DateFormat('EEEE').format(DateTime.now());
    final String dateStr = DateFormat('MMMM d').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 42,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      dateStr.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              _buildLiveClock(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveClock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: StreamBuilder(
        stream: Stream.periodic(const Duration(minutes: 1)),
        builder: (context, snapshot) {
          return Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                      color: scheme.primary.withValues(alpha: 0.5)),
                  hintText: 'Search markers...',
                  hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.3)),
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: Icon(Icons.close_rounded,
                              color: scheme.onSurface.withValues(alpha: 0.35),
                              size: 18),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildToolButton(
            context,
            icon: Icons.tune_rounded,
            isSelected: _filtersExpanded,
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
          ),
          const SizedBox(width: 8),
          _buildToolButton(
            context,
            icon: _cardView.icon,
            isSelected: _cardView == _HomeCardView.comfortable,
            onPressed: () {
              _setCardView(
                _cardView == _HomeCardView.comfortable
                    ? _HomeCardView.compact
                    : _HomeCardView.comfortable,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primary
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isSelected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.6),
        ),
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
    // Split events into 'Soon' (within 7 days) and 'Later'
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final soon = events.where((e) {
      final d = DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day);
      final diff = d.difference(today).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();
    
    final later = events.where((e) {
      final d = DateTime(e.nextOccurrenceDate.year, e.nextOccurrenceDate.month, e.nextOccurrenceDate.day);
      final diff = d.difference(today).inDays;
      return diff > 7 || diff < 0;
    }).toList();

    return <Widget>[
      if (soon.isNotEmpty) ...[
        _sectionHeader(context, 'UPCOMING SOON', soon.length),
        _eventList(context, soon),
      ],
      if (later.isNotEmpty) ...[
        _sectionHeader(context, 'ALL EVENTS', later.length),
        _eventList(context, later),
      ],
    ];
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 2.0,
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: GoogleFonts.plusJakartaSans(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                fontWeight: FontWeight.w800,
                fontSize: 12,
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


class _DashboardTag extends StatelessWidget {
  const _DashboardTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color contentColor = isDark ? Colors.white : Colors.black;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: contentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: contentColor.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: contentColor.withValues(alpha: 0.8), size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: contentColor.withValues(alpha: 0.8),
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

class _StaggeredAnimatedInsightCard extends StatelessWidget {
  const _StaggeredAnimatedInsightCard({
    required this.insight,
    required this.index,
    this.compact = false,
  });

  final _DashboardInsight insight;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 100 + index * 50);
    final curve = Curves.easeInOut;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: curve,
      margin: compact
          ? const EdgeInsets.only(right: 12)
          : const EdgeInsets.symmetric(vertical: 6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: curve,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: _GlassInsightCard(
              insight: insight,
              onTap: insight.onTap,
              compact: compact,
            ),
          );
        },
      ),
    );
  }
}

class _GlassInsightCard extends ConsumerWidget {
  const _GlassInsightCard({
    required this.insight,
    required this.onTap,
    this.compact = false,
  });

  final _DashboardInsight insight;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final isStressed = userContext.stressLevel == UserStressLevel.high;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color contentColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showQuickPreview(context, insight),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: insight.gradient.first.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LiquidGlassContainer(
          borderRadius: 32,
          blur: isStressed ? 25 : 18,
          opacity: isDark 
              ? (isStressed ? 0.12 : 0.08)
              : (isStressed ? 0.18 : 0.12),
          color: insight.gradient.first,
          child: Stack(
            children: [
              // Decorative inner glow
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        contentColor.withValues(alpha: 0.1),
                        contentColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              if (insight.backgroundEmoji != null)
                Positioned(
                  right: 12,
                  bottom: -10,
                  child: Text(
                    insight.backgroundEmoji!,
                    style: TextStyle(
                      fontSize: compact ? 80 : 110,
                      color: contentColor.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardTag(label: insight.tag, icon: insight.icon),
                    const Spacer(),
                    Text(
                      insight.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: contentColor.withValues(alpha: 0.95),
                        fontSize: compact ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: contentColor.withValues(alpha: 0.5),
                              fontSize: compact ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: contentColor.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickPreview(BuildContext context, _DashboardInsight insight) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                insight.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                insight.subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (insight.onTap != null)
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        insight.onTap?.call();
                      },
                      child: const Text('View details'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
