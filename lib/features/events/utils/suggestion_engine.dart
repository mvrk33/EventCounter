import '../models/event_model.dart';
import '../models/suggestion_result.dart';
import 'event_emoji_bank.dart';
import 'event_rules_data.dart';
/// Lightweight, fully offline suggestion engine.
/// Call [SuggestionEngine.analyze] on every debounce tick (300 ms).
/// Runs in < 1 ms on the main isolate — pure in-memory const list scan.
class SuggestionEngine {
  const SuggestionEngine._();
  /// Analyses [title] and returns a [SuggestionResult], or null when the
  /// title is too short, abstract, or scores below the minimum threshold.
  static SuggestionResult? analyze(String title) {
    final String t = title.trim();
    if (t.length < 3) return null;
    final String resolved = _resolveAliases(t.toLowerCase());
    final List<String> tokens = _tokenize(resolved);
    if (tokens.isEmpty) return null;
    final List<_Hit> hits = <_Hit>[];
    for (final CategoryRule rule in kEventRules) {
      final double raw = _matchScore(resolved, tokens, rule.keyword);
      if (raw > 0) {
        hits.add(_Hit(rule, raw * rule.baseScore));
      }
    }
    if (hits.isEmpty) return null;
    // Sort by score DESC; on ties, prefer the more specific (longer) keyword.
    hits.sort((_Hit a, _Hit b) {
      final int scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return b.rule.keyword.length.compareTo(a.rule.keyword.length);
    });
    final double topScore = hits.first.score.clamp(0.0, 1.0);
    if (topScore < 0.30) return null;
    final CategoryRule top = hits.first.rule;
    // Ambiguity: top-two within 0.15 of each other
    final bool isAmbiguous =
        hits.length > 1 && (topScore - hits[1].score) < 0.15;
    final List<String> disambig = isAmbiguous
        ? <String>[hits[1].rule.categoryId]
        : <String>[];
    // Secondary labels (deduplicated, primary removed)
    final Set<String> secondary = <String>{...top.secondaryCategories};
    if (isAmbiguous) secondary.add(hits[1].rule.categoryId);
    secondary.remove(top.categoryId);

    // Sorted, deduplicated reminder days from the matched rule
    final List<int> reminders =
        top.reminderDays.toSet().toList(growable: false)..sort();

    // Anniversary / Birthday intelligence
    final bool isLongTerm = resolved.contains('anniversary') ||
        resolved.contains('birthday') ||
        top.categoryId == 'Anniversary' ||
        top.categoryId == 'Birthday';

    final EventRecurrence finalRecurrence =
        isLongTerm ? EventRecurrence.yearly : top.recurrence;

    final EventCountUnit finalCountUnit =
        isLongTerm ? EventCountUnit.years : EventCountUnit.days;

    final List<int> finalReminders = isLongTerm
        ? (<int>{0, 1, 7, ...reminders}.toList()..sort())
        : reminders;

    if (isLongTerm) {
      secondary.add('Milestone');
      if (top.categoryId != 'Anniversary' && resolved.contains('anniversary')) {
        secondary.add('Anniversary');
      }
    }
    secondary.remove(top.categoryId);

    // Emoji alternatives...
    final List<String> emojiAlts = EventEmojiBank.alternatives(top.categoryId)
        .where((String e) => e != top.emoji)
        .take(4)
        .toList(growable: false);

    final DateTime? suggestedDate = _extractDate(resolved);
    final String? cleanedTitle = _cleanTitle(t, suggestedDate != null);

    // Predict mood/energy level
    String? mood;
    final String lowerTitle = t.toLowerCase();
    if (RegExp(r'concert|party|gym|workout|run|dance|festival|sport').hasMatch(lowerTitle)) {
      mood = 'High Energy';
    } else if (RegExp(r'reading|meditation|sleep|nap|chill|relax|library|study').hasMatch(lowerTitle)) {
      mood = 'Low Energy';
    }

    // Smart Preparation Checklists
    final List<String> checklist = <String>[];
    if (top.categoryId == 'Travel' || lowerTitle.contains('trip') || lowerTitle.contains('flight')) {
      checklist.addAll(['Passport', 'Charger', 'Toiletries', 'Tickets']);
    } else if (top.categoryId == 'Birthday' || lowerTitle.contains('birthday')) {
      checklist.addAll(['Buy gift', 'Order cake', 'Send invites']);
    } else if (top.categoryId == 'Work' || lowerTitle.contains('meeting')) {
      checklist.addAll(['Prepare agenda', 'Take notes', 'Follow up']);
    }

    // Smart Time-to-Leave & Travel
    final bool requiresTravel = top.categoryId == 'Travel' ||
        RegExp(r'coffee|dinner|meeting|gym|concert|party|airport|office').hasMatch(lowerTitle);

    // AI-Generated Visual Theme keyword
    String? visualTheme;
    if (lowerTitle.contains('beach')) visualTheme = 'ocean_waves';
    if (lowerTitle.contains('forest') || lowerTitle.contains('hike')) visualTheme = 'pine_trees';
    if (lowerTitle.contains('coffee')) visualTheme = 'coffee_steam';

    // Time-Block Prediction
    Duration? suggestedDuration;
    if (RegExp(r'meeting|call|coffee').hasMatch(lowerTitle)) {
      suggestedDuration = const Duration(minutes: 30);
    } else if (RegExp(r'movie|concert|dinner|party').hasMatch(lowerTitle)) {
      suggestedDuration = const Duration(hours: 2, minutes: 30);
    } else if (RegExp(r'gym|workout|run').hasMatch(lowerTitle)) {
      suggestedDuration = const Duration(hours: 1);
    }

    return SuggestionResult(
      primaryCategory: top.categoryId,
      secondaryLabels: secondary.toList(growable: false),
      emoji: top.emoji,
      emojiAlternatives: emojiAlts,
      primaryColor: top.primaryColor,
      bgColor: top.bgColor,
      suggestedRecurrence: finalRecurrence,
      suggestedCountUnit: finalCountUnit,
      suggestedReminderDays: finalReminders,
      suggestedDate: suggestedDate,
      suggestedMood: mood,
      cleanedTitle: cleanedTitle,
      suggestedChecklist: checklist,
      requiresTravel: requiresTravel,
      suggestedVisualTheme: visualTheme,
      suggestedDuration: suggestedDuration,
      confidence: topScore,
      isAmbiguous: isAmbiguous,
      disambiguationOptions: disambig,
    );
  }

  /// Strips temporal metadata from the title if a date was extracted.
  static String? _cleanTitle(String title, bool dateExtracted) {
    if (!dateExtracted) return null;

    String cleaned = title;
    final List<String> patterns = [
      r'today',
      r'tomorrow',
      r'at \d+(am|pm|:\d+)',
      r'in \d+ days?',
      r'in \d+ weeks?',
      r'in \d+ months?',
      r'next (monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
      r'this (monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
      r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ];

    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // Clean up extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned.isEmpty ? null : cleaned;
  }

  static DateTime? _extractDate(String text) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // "today"
    if (text.contains('today')) return today;

    // "tomorrow"
    if (text.contains('tomorrow')) return today.add(const Duration(days: 1));

    // "in X days"
    final RegExp inDaysRegex = RegExp(r'in (\d+) days?');
    final Match? daysMatch = inDaysRegex.firstMatch(text);
    if (daysMatch != null) {
      final int days = int.tryParse(daysMatch.group(1)!) ?? 0;
      return today.add(Duration(days: days));
    }

    // "in X weeks"
    final RegExp inWeeksRegex = RegExp(r'in (\d+) weeks?');
    final Match? weeksMatch = inWeeksRegex.firstMatch(text);
    if (weeksMatch != null) {
      final int weeks = int.tryParse(weeksMatch.group(1)!) ?? 0;
      return today.add(Duration(days: weeks * 7));
    }

    // "in X months"
    final RegExp inMonthsRegex = RegExp(r'in (\d+) months?');
    final Match? monthsMatch = inMonthsRegex.firstMatch(text);
    if (monthsMatch != null) {
      final int months = int.tryParse(monthsMatch.group(1)!) ?? 0;
      return DateTime(today.year, today.month + months, today.day);
    }

    // Days of week: "next monday", "this friday", etc.
    final Map<String, int> weekDays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    for (final dayEntry in weekDays.entries) {
      if (text.contains('next ${dayEntry.key}')) {
        int daysUntil = dayEntry.value - today.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        return today.add(Duration(days: daysUntil));
      }
      if (text.contains('this ${dayEntry.key}') ||
          (text.contains(dayEntry.key) &&
              !text.contains('last') &&
              !text.contains('next'))) {
        int daysUntil = dayEntry.value - today.weekday;
        if (daysUntil < 0) daysUntil += 7;
        return today.add(Duration(days: daysUntil));
      }
    }

    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────
  static String _resolveAliases(String input) {
    String out = input;
    for (final MapEntry<String, String> entry in kAliasMap.entries) {
      if (out.contains(entry.key)) {
        out = out.replaceAll(entry.key, entry.value);
      }
    }
    return out;
  }
  static List<String> _tokenize(String text) {
    return text
        .replaceAll(RegExp(r"['\-]"), ' ')
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty)
        .toList(growable: false);
  }
  /// Match tiers:
  ///   1.00 — exact whole-word token match for every keyword token
  ///   0.85 — prefix match on any token (>= 4 chars typed)
  ///   0.65 — infix / substring match
  ///   0.00 — no match
  static double _matchScore(
      String title, List<String> tokens, String keyword) {
    if (!title.contains(keyword)) {
      // Prefix: any typed token starts a keyword token
      final List<String> kwTokens = _tokenize(keyword);
      bool anyPrefix = false;
      for (final String kt in kwTokens) {
        for (final String t in tokens) {
          if (kt.startsWith(t) && t.length >= 4) {
            anyPrefix = true;
          }
        }
      }
      return anyPrefix ? 0.85 : 0.0;
    }
    // Substring match — check for exact whole-word upgrade
    final List<String> kwTokens = _tokenize(keyword);
    final bool allExact = kwTokens.every((String kt) => tokens.contains(kt));
    return allExact ? 1.0 : 0.65;
  }
}
class _Hit {
  const _Hit(this.rule, this.score);
  final CategoryRule rule;
  final double score;
}