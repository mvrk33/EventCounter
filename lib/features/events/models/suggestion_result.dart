import '../models/event_model.dart';

/// Rich result returned by [SuggestionEngine.analyze].
class SuggestionResult {
  const SuggestionResult({
    required this.primaryCategory,
    required this.emoji,
    required this.primaryColor,
    required this.bgColor,
    required this.confidence,
    this.secondaryLabels = const <String>[],
    this.emojiAlternatives = const <String>[],
    this.suggestedRecurrence = EventRecurrence.once,
    this.suggestedReminderDays = const <int>[],
    this.isAmbiguous = false,
    this.disambiguationOptions = const <String>[],
  });

  /// The best-matching category name (e.g. "Birthday").
  final String primaryCategory;

  /// Additional categories this event might belong to (multi-label).
  final List<String> secondaryLabels;

  /// Primary emoji for this event.
  final String emoji;

  /// Up to 4 alternative emoji choices shown in the expanded banner.
  final List<String> emojiAlternatives;

  /// ARGB color int for the event accent.
  final int primaryColor;

  /// ARGB color int for the banner/card background tint.
  final int bgColor;

  /// Suggested recurrence pattern.
  final EventRecurrence suggestedRecurrence;

  /// Suggested reminder days (0 = on event day, 1 = 1 day before, etc.)
  final List<int> suggestedReminderDays;

  /// Confidence score in [0.0, 1.0].
  final double confidence;

  /// True when the top-2 category scores are within 0.15 of each other.
  final bool isAmbiguous;

  /// Other candidate categories when [isAmbiguous] is true.
  final List<String> disambiguationOptions;
}

