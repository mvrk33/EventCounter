import 'package:flutter/material.dart';

/// Smart auto-suggestion: map event title keywords → category / emoji / color.
class SmartCategoryHelper {
  const SmartCategoryHelper._();

  static const List<_KWDef> _keywords = <_KWDef>[
    // Birthdays
    _KWDef('birthday',    'Birthday',    '🎂', 0xFFE91E63, true),
    _KWDef('bday',        'Birthday',    '🎂', 0xFFE91E63, true),
    _KWDef("mom's",       'Birthday',    '🎂', 0xFFE91E63, true),
    _KWDef("dad's",       'Birthday',    '🎂', 0xFFE91E63, true),
    // Anniversary
    _KWDef('anniversary', 'Anniversary', '💑', 0xFFE53935, true),
    _KWDef('wedding',     'Anniversary', '💍', 0xFFF50057, false),
    _KWDef('marriage',    'Anniversary', '💍', 0xFFF50057, false),
    _KWDef('valentine',   'Anniversary', '❤️', 0xFFE53935, true),
    // Travel
    _KWDef('vacation',    'Travel',      '🏖️', 0xFF00BCD4, false),
    _KWDef('travel',      'Travel',      '✈️', 0xFF2196F3, false),
    _KWDef('trip',        'Travel',      '✈️', 0xFF2196F3, false),
    _KWDef('flight',      'Travel',      '🛫', 0xFF1976D2, false),
    _KWDef('cruise',      'Travel',      '🚢', 0xFF0288D1, false),
    _KWDef('holiday',     'Travel',      '🌴', 0xFF00BCD4, false),
    // Health
    _KWDef('gym',         'Health',      '🏋️', 0xFF4CAF50, false),
    _KWDef('workout',     'Health',      '🏃', 0xFF4CAF50, false),
    _KWDef('fitness',     'Health',      '💪', 0xFF43A047, false),
    _KWDef('doctor',      'Health',      '🩺', 0xFF66BB6A, false),
    _KWDef('hospital',    'Health',      '🏥', 0xFF66BB6A, false),
    _KWDef('marathon',    'Health',      '🏅', 0xFF43A047, false),
    _KWDef('race',        'Health',      '🏁', 0xFF43A047, false),
    _KWDef('dentist',     'Health',      '🦷', 0xFF66BB6A, false),
    // Work
    _KWDef('deadline',    'Work',        '⏰', 0xFFFF9800, false),
    _KWDef('project',     'Work',        '🚀', 0xFFFF9800, false),
    _KWDef('meeting',     'Work',        '📌', 0xFF9C27B0, false),
    _KWDef('exam',        'Work',        '📝', 0xFF7B1FA2, false),
    _KWDef('interview',   'Work',        '🎤', 0xFF7B1FA2, false),
    _KWDef('launch',      'Work',        '🚀', 0xFFFF9800, false),
    _KWDef('conference',  'Work',        '🏢', 0xFF9C27B0, false),
    // Personal
    _KWDef('graduation',  'Personal',    '🎓', 0xFF673AB7, false),
    _KWDef('party',       'Personal',    '🥳', 0xFFFF5722, false),
    _KWDef('baby',        'Personal',    '👶', 0xFFFF80AB, false),
    _KWDef('christmas',   'Personal',    '🎄', 0xFF388E3C, true),
    _KWDef('new year',    'Personal',    '🎉', 0xFFFF6F00, true),
    _KWDef('thanksgiving','Personal',    '🦃', 0xFFFF8F00, true),
    _KWDef('halloween',   'Personal',    '🎃', 0xFFE65100, true),
    _KWDef('easter',      'Personal',    '🐣', 0xFFAB47BC, true),
    _KWDef('concert',     'Personal',    '🎵', 0xFF5E6AD2, false),
    _KWDef('show',        'Personal',    '🎭', 0xFF5E6AD2, false),
    _KWDef('rent',        'Work',        '🏠', 0xFF607D8B, false),
    _KWDef('bill',        'Work',        '💸', 0xFF607D8B, false),
    _KWDef('loan',        'Work',        '💰', 0xFF607D8B, false),
    _KWDef('milestone',   'Personal',    '🏆', 0xFFFFC107, false),
  ];

  static const Map<String, _KWDef> _categoryDefaults = <String, _KWDef>{
    'Birthday':    _KWDef('Birthday',    'Birthday',    '🎂', 0xFFE91E63, true),
    'Anniversary': _KWDef('Anniversary', 'Anniversary', '💑', 0xFFE53935, true),
    'Travel':      _KWDef('Travel',      'Travel',      '✈️', 0xFF2196F3, false),
    'Health':      _KWDef('Health',      'Health',      '💪', 0xFF4CAF50, false),
    'Work':        _KWDef('Work',        'Work',        '💼', 0xFF9C27B0, false),
    'Personal':    _KWDef('Personal',    'Personal',    '⭐', 0xFFFFC107, false),
    'Other':       _KWDef('Other',       'Other',       '📅', 0xFF607D8B, false),
  };

  /// Detect smart suggestion from event title. Returns null if no match.
  static SmartSuggestion? fromTitle(String title) {
    final String lower = title.toLowerCase();
    for (final _KWDef def in _keywords) {
      if (lower.contains(def.key)) {
        return SmartSuggestion(
          category: def.category,
          emoji: def.emoji,
          color: def.color,
          suggestYearly: def.likelyYearly,
        );
      }
    }
    return null;
  }

  /// Get smart defaults for a known category name.
  static SmartSuggestion? fromCategory(String category) {
    final _KWDef? def = _categoryDefaults[category];
    if (def == null) return null;
    return SmartSuggestion(
      category: def.category,
      emoji: def.emoji,
      color: def.color,
      suggestYearly: def.likelyYearly,
    );
  }

  static List<String> get categories => _categoryDefaults.keys.toList();
}

/// Result of a smart category suggestion.
class SmartSuggestion {
  const SmartSuggestion({
    required this.category,
    required this.emoji,
    required this.color,
    this.suggestYearly = false,
  });
  final String category;
  final String emoji;
  final int color; // ARGB int
  final bool suggestYearly;
}

class _KWDef {
  const _KWDef(this.key, this.category, this.emoji, this.color, this.likelyYearly);
  final String key;
  final String category;
  final String emoji;
  final int color;
  final bool likelyYearly;
}

