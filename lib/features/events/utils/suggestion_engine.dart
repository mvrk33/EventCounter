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

    // ── Anniversary intelligence ─────────────────────────────────────────
    // Any title that mentions "anniversary" (however the subject is tagged)
    // is always a yearly, milestone-grade event counted in years.
    final bool hasAnniversary = resolved.contains('anniversary');
    final EventRecurrence finalRecurrence =
        hasAnniversary ? EventRecurrence.yearly : top.recurrence;
    final List<int> finalReminders = hasAnniversary
        ? (<int>{0, 1, 7, ...reminders}.toList()..sort())
        : reminders;
    if (hasAnniversary) {
      secondary.add('Milestone');
      if (top.categoryId != 'Anniversary') secondary.add('Anniversary');
    }
    secondary.remove(top.categoryId); // always keep primary out of secondary

    // Emoji alternatives (all except primary)
    final List<String> emojiAlts = EventEmojiBank.alternatives(top.categoryId)
        .where((String e) => e != top.emoji)
        .take(4)
        .toList(growable: false);
    return SuggestionResult(
      primaryCategory: top.categoryId,
      secondaryLabels: secondary.toList(growable: false),
      emoji: top.emoji,
      emojiAlternatives: emojiAlts,
      primaryColor: top.primaryColor,
      bgColor: top.bgColor,
      suggestedRecurrence: finalRecurrence,
      suggestedReminderDays: finalReminders,
      confidence: topScore,
      isAmbiguous: isAmbiguous,
      disambiguationOptions: disambig,
    );
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