import '../models/suggestion_result.dart';
import 'suggestion_engine.dart';

export '../models/suggestion_result.dart';
export 'suggestion_engine.dart';

/// Legacy facade kept for backward compatibility.
/// New code should use [SuggestionEngine] and [SuggestionResult] directly.
@Deprecated('Use SuggestionEngine.analyze() instead.')
class SmartCategoryHelper {
  const SmartCategoryHelper._();

  static SuggestionResult? fromTitle(String title) =>
      SuggestionEngine.analyze(title);

  static List<String> get categories => const <String>[
        'Birthday', 'Anniversary', 'Travel', 'Health', 'Fitness', 'Work',
        'Finance', 'Education', 'Milestone', 'Home', 'Vehicle', 'Pet',
        'Habit', 'Personal', 'Food', 'Other',
      ];
}

/// Legacy result type — kept so any existing code that imports this file
/// still compiles.  New code should use [SuggestionResult].
@Deprecated('Use SuggestionResult instead.')
class SmartSuggestion {
  const SmartSuggestion({
    required this.category,
    required this.emoji,
    required this.color,
    this.suggestYearly = false,
  });
  final String category;
  final String emoji;
  final int color;
  final bool suggestYearly;
}
