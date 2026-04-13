/// Emoji candidates per category. Index 0 is the primary pick.
/// The expanded suggestion banner shows indices 1–4 as quick alternatives.
class EventEmojiBank {
  const EventEmojiBank._();

  static const Map<String, List<String>> _bank = <String, List<String>>{
    'Birthday':    <String>['🎂', '🎉', '🥳', '🎁', '👑', '🎈', '🎊', '🍰', '🎀', '🪅', '🎏', '✨'],
    'Anniversary': <String>['💑', '💍', '❤️', '💞', '🌹', '💏', '🥂', '🕯️', '💐', '💌', '🫶', '💝'],
    'Travel':      <String>['✈️', '🌍', '🏖️', '🎒', '🗺️', '🌏', '🧳', '🛫', '🚢', '🗼', '🌄', '🏔️'],
    'Health':      <String>['🩺', '🏥', '💊', '❤️‍🩹', '🧬', '🩹', '🧪', '💉', '🫀', '🩻', '🩸', '🧘'],
    'Fitness':     <String>['💪', '🏋️', '🏃', '🧘', '🏅', '🚴', '🏊', '🎽', '🥊', '⚽', '🎯', '🏆'],
    'Work':        <String>['💼', '🚀', '📌', '⏰', '🏢', '📊', '💻', '🤝', '📋', '🏆', '🖥️', '📁'],
    'Finance':     <String>['💰', '💳', '🏦', '📈', '💵', '💴', '🪙', '💹', '🏧', '💸', '📉', '🤑'],
    'Education':   <String>['🎓', '📝', '📚', '🏫', '🏛️', '✏️', '🔬', '📐', '🖊️', '🔭', '📖', '🧮'],
    'Personal':    <String>['⭐', '🥳', '🎭', '🎵', '✨', '🎶', '🎸', '🎤', '🎬', '🌟', '🎙️', '🎹'],
    'Milestone':   <String>['🏆', '🌟', '🎯', '🚀', '🎖️', '🥇', '🎗️', '🏁', '⭐', '🎊', '🏅', '👑'],
    'Habit':       <String>['🔄', '🔥', '✅', '📅', '⚡', '📓', '🧘', '🌱', '⏱️', '💯', '🎯', '📆'],
    'Home':        <String>['🏠', '🔑', '🛋️', '🏡', '🪴', '🛏️', '🚪', '🏗️', '🪞', '🛁', '🪟', '🧹'],
    'Vehicle':     <String>['🚗', '🏍️', '🚐', '🛻', '🔑', '🛞', '⛽', '🔧', '🚘', '🏎️', '🛵', '🚛'],
    'Pet':         <String>['🐾', '🐶', '🐱', '🐰', '🦜', '🐹', '🐠', '🦮', '🐕', '🐈', '🦴', '🐾'],
    'Food':        <String>['🍽️', '🥗', '🍴', '🥞', '🍜', '🍕', '🥩', '🍣', '🥘', '🍱', '🍖', '☕'],
    'Other':       <String>['🗓️', '📌', '⭐', '🎯', '✨', '📝', '🔔', '💡', '🎲', '🌈', '🎁', '🗂️'],
  };

  /// Primary emoji for [categoryId].
  static String primary(String categoryId) =>
      _bank[categoryId]?.first ?? '🗓️';

  /// All emoji options for [categoryId] (primary + alternatives).
  static List<String> alternatives(String categoryId) =>
      _bank[categoryId] ?? const <String>['🗓️'];
}
