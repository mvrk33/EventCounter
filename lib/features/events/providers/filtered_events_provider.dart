import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import 'events_provider.dart';

enum EventSort {
  pinnedFirst('Pinned First'),
  nearest('Nearest'),
  farthest('Farthest'),
  recentlyUpdated('Recently Updated'),
  titleAz('Title A–Z');

  const EventSort(this.label);
  final String label;
}

class EventFilters {
  const EventFilters({
    this.searchQuery = '',
    this.category = 'All',
    this.sort = EventSort.nearest,
  });

  final String searchQuery;
  final String category;
  final EventSort sort;

  EventFilters copyWith({
    String? searchQuery,
    String? category,
    EventSort? sort,
  }) {
    return EventFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      sort: sort ?? this.sort,
    );
  }
}

final StateProvider<EventFilters> eventFiltersProvider =
    StateProvider<EventFilters>((Ref ref) => const EventFilters());

final Provider<List<EventModel>> filteredEventsProvider =
    Provider<List<EventModel>>((Ref ref) {
  final List<EventModel> events = ref.watch(eventsProvider);
  final EventFilters filters = ref.watch(eventFiltersProvider);

  final String query = filters.searchQuery.toLowerCase();
  final String category = filters.category;
  final EventSort sort = filters.sort;

  final List<EventModel> filtered = events.where((EventModel event) {
    final bool categoryOk = category == 'All' || event.category == category;
    if (!categoryOk) return false;
    if (query.isEmpty) return true;
    final String haystack =
        '${event.title} ${event.notes} ${event.category}'.toLowerCase();
    return haystack.contains(query);
  }).toList();

  switch (sort) {
    case EventSort.pinnedFirst:
      filtered.sort((EventModel a, EventModel b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.date.compareTo(b.date);
      });
      break;
    case EventSort.nearest:
      filtered.sort((EventModel a, EventModel b) => a.date.compareTo(b.date));
      break;
    case EventSort.farthest:
      filtered.sort((EventModel a, EventModel b) => b.date.compareTo(a.date));
      break;
    case EventSort.recentlyUpdated:
      filtered.sort((EventModel a, EventModel b) => b.updatedAt.compareTo(a.updatedAt));
      break;
    case EventSort.titleAz:
      filtered.sort((EventModel a, EventModel b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      break;
  }

  return filtered;
});
