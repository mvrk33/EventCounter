/// Example: Integrating Liquid Glass & Adaptive UI into HomeScreen
///
/// This shows practical integration patterns you can apply throughout your app.
/// Copy relevant sections into your actual screen files.

/*
// Add these imports to home_screen.dart
import '../../../shared/widgets/liquid_glass_effects.dart';
import '../../../shared/theme/time_based_colors.dart';
import '../../../shared/widgets/adaptive_layout.dart';

// ============================================================================
// ENHANCEMENT 1: Add Stress Indicator to Greeting Header
// ============================================================================

// In _buildGreetingHeader(), after the greeting row, add:

Widget _buildGreetingHeader(
    BuildContext context, int thisWeekCount, int habitCount) {
  final hour = DateTime.now().hour;
  final userContext = ref.watch(userContextProvider);
  final colorScheme = ref.watch(timeBasedColorSchemeProvider);
  final isStressed = userContext.stressLevel == UserStressLevel.high;

  final String greeting;
  if (isStressed) {
    greeting = 'Take a breath';
  } else if (hour < 5) {
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
                AdaptiveText(
                  '$greeting,',
                  baseStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary, // Time-based color!
                  ),
                ),
                const SizedBox(height: 2),
                Text(dayStr, style: Theme.of(context).textTheme.bodySmall),
                Text(dateStr, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            // NEW: Add stress indicator badge
            if (isStressed)
              LiquidWaveIndicator(
                stressLevel: userContext.stressLevel,
                color: Colors.red,
                size: 50,
              ),
            const SizedBox(width: 8),
          ],
        ),

        // NEW: Show time period and motion intensity
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AdaptiveText(
                '${userContext.timePeriod.name} • Motion: ${(userContext.motionIntensity * 100).toStringAsFixed(0)}%',
                baseStyle: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ============================================================================
// ENHANCEMENT 2: Simplify Event List Based on Stress
// ============================================================================

// Replace _buildEventCard() call in _eventsTab with:

Widget _buildEventCardAdaptive(EventModel event) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: AdaptiveLayoutBuilder(
      // Normal layout - full details
      normalLayout: _buildEventCardFull(event),

      // Stressed layout - compact, actionable
      stressedLayout: _buildEventCardCompact(event),

      // Night layout - larger text, fewer details
      nightLayout: _buildEventCardNight(event),
    ),
  );
}

// Full event card (normal state)
Widget _buildEventCardFull(EventModel event) {
  return GestureDetector(
    onTap: () => _showEventDetail(event),
    child: LiquidGlassContainer(
      color: Color(event.color),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(event.color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${DateHelpers.eventCountValue(event)} days',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            AdaptiveSpacing(baseValue: 12),

            // Description
            Text(
              event.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Decorations (hidden when stressed)
            StressAdaptiveVisibility(
              hideWhenStressed: true,
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Row(
                    children: [
                      if (event.mood != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(event.mood!),
                        ),
                      if (event.checklist.isNotEmpty)
                        Text('${event.checklist.length} items'),
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

// Compact event card (stressed state)
Widget _buildEventCardCompact(EventModel event) {
  return GestureDetector(
    onTap: () => _showEventDetail(event),
    child: LiquidGlassContainer(
      color: Color(event.color),
      opacity: 0.12,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateHelpers.eventCountDescription(event),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            // Large, easy-to-tap button
            AdaptiveTouchTarget(
              onPressed: () => _showEventDetail(event),
              minSize: 48,
              child: Icon(Icons.arrow_forward_ios, size: 20),
            ),
          ],
        ),
      ),
    ),
  );
}

// Night mode event card
Widget _buildEventCardNight(EventModel event) {
  return GestureDetector(
    onTap: () => _showEventDetail(event),
    child: LiquidGlassContainer(
      color: Color(event.color),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveText(
              event.title,
              baseStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            AdaptiveText(
              DateHelpers.eventCountDescription(event),
              baseStyle: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// ENHANCEMENT 3: Color-Adaptive UI Elements
// ============================================================================

// In build() method, get time-based colors:
final colorScheme = ref.watch(timeBasedColorSchemeProvider);
final userContext = ref.watch(userContextProvider);

// Use colorScheme.primary instead of hardcoded colors:
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: colorScheme.primary, // Shifts throughout day!
  ),
  onPressed: () => _addNewEvent(),
  child: Text('+ New Event'),
)

// ============================================================================
// ENHANCEMENT 4: Floating Action Button with Adaptive Size
// ============================================================================

// Replace FAB with adaptive version:
floatingActionButton: AdaptiveButton(
  primary: true,
  onPressed: () => _addNewEvent(),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.add, size: 20),
      SizedBox(width: 8),
      AdaptiveText('New Event'),
    ],
  ),
)

// ============================================================================
// ENHANCEMENT 5: Search Bar with Adaptive Styling
// ============================================================================

// Update search input decoration:
InputDecoration(
  hintText: 'Search events...',
  prefixIcon: Icon(Icons.search),
  filled: true,
  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: colorScheme.primary.withValues(alpha: 0.2), // Dynamic color
    ),
  ),
)

// ============================================================================
// ENHANCEMENT 6: Settings Icons with Stress Awareness
// ============================================================================

// Use StressAwareIcon for toolbar icons:
Row(
  children: [
    StressAwareIcon(
      icon: Icons.settings,
      onPressed: () => _openSettings(),
      baseSize: 24,
    ),
    StressAwareIcon(
      icon: Icons.filter_list,
      onPressed: () => _showFilterMenu(),
      baseSize: 24,
    ),
  ],
)

// ============================================================================
// COMPLETE EXAMPLE: Full Integration Pattern
// ============================================================================

// This shows how all pieces work together:

class HomeScreenWithAdaptiveUI extends ConsumerStatefulWidget {
  @override
  ConsumerState<HomeScreenWithAdaptiveUI> createState() =>
    _HomeScreenWithAdaptiveUIState();
}

class _HomeScreenWithAdaptiveUIState
    extends ConsumerState<HomeScreenWithAdaptiveUI> {

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(userContextProvider);
    final colorScheme = ref.watch(timeBasedColorSchemeProvider);
    final events = ref.watch(eventsProvider);

    return Scaffold(
      // Time-adaptive background
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // Adaptive appbar
      appBar: AppBar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveText(
              'Daymark',
              baseStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            if (userContext.stressLevel != UserStressLevel.low)
              Text(
                'Stress: ${userContext.stressLevel.name}',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
        actions: [
          StressAwareIcon(
            icon: Icons.notifications,
            onPressed: () {},
          ),
          StressAwareIcon(
            icon: Icons.settings,
            onPressed: () {},
          ),
        ],
      ),

      body: CustomScrollView(
        slivers: [
          // Greeting with stress indicator
          SliverToBoxAdapter(
            child: _buildGreetingHeader(context, 5, 3),
          ),

          // Event list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildEventCardAdaptive(events[index]),
              childCount: events.length,
            ),
          ),
        ],
      ),

      // Adaptive FAB
      floatingActionButton: AdaptiveButton(
        primary: true,
        onPressed: () => _addNewEvent(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add),
            SizedBox(width: 8),
            Text('New Event'),
          ],
        ),
      ),
    );
  }
}

*/

void _docsNothing() {}

