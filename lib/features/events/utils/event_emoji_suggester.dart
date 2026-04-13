class EventEmojiSuggester {
  const EventEmojiSuggester._();

  static const Map<String, String> _categoryEmoji = <String, String>{
    'birthday': '🎂',
    'travel': '✈️',
    'health': '💚',
    'work': '💼',
    'anniversary': '💞',
    'personal': '✨',
    'other': '🗓️',
  };

  static const Map<String, String> _keywordEmoji = <String, String>{
    'birthday': '🎂',
    'anniversary': '💞',
    'wedding': '💍',
    'vacation': '🏖️',
    'trip': '✈️',
    'flight': '🛫',
    'exam': '📝',
    'meeting': '📌',
    'project': '🚀',
    'deadline': '⏰',
    'gym': '🏋️',
    'workout': '🏃',
    'doctor': '🩺',
    'hospital': '🏥',
    'bill': '💸',
    'rent': '🏠',
    'party': '🥳',
    'baby': '👶',
    'pet': '🐾',
    'new year': '🎉',
    'christmas': '🎄',
  };

  static String suggest({required String title, required String category}) {
    final String normalizedTitle = title.toLowerCase().trim();
    final String normalizedCategory = category.toLowerCase().trim();

    for (final MapEntry<String, String> entry in _keywordEmoji.entries) {
      if (normalizedTitle.contains(entry.key)) {
        return entry.value;
      }
    }

    return _categoryEmoji[normalizedCategory] ?? '🗓️';
  }
}
