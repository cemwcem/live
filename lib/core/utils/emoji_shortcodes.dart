class EmojiEntry {
  const EmojiEntry({
    required this.code,
    required this.emoji,
    required this.label,
  });

  final String code;
  final String emoji;
  final String label;
}

class EmojiShortcodes {
  static const List<EmojiEntry> entries = <EmojiEntry>[
    EmojiEntry(code: ':)', emoji: '🙂', label: 'Gulumseme'),
    EmojiEntry(code: ':-)', emoji: '🙂', label: 'Gulumseme'),
    EmojiEntry(code: ':D', emoji: '😄', label: 'Kahkaha'),
    EmojiEntry(code: ':-D', emoji: '😄', label: 'Kahkaha'),
    EmojiEntry(code: ';)', emoji: '😉', label: 'Goz kirpma'),
    EmojiEntry(code: ';-)', emoji: '😉', label: 'Goz kirpma'),
    EmojiEntry(code: ':(', emoji: '🙁', label: 'Uzgün'),
    EmojiEntry(code: ':-(', emoji: '🙁', label: 'Uzgün'),
    EmojiEntry(code: ':P', emoji: '😛', label: 'Dil cikarma'),
    EmojiEntry(code: ':-P', emoji: '😛', label: 'Dil cikarma'),
    EmojiEntry(code: ':O', emoji: '😮', label: 'Sasirma'),
    EmojiEntry(code: ':-O', emoji: '😮', label: 'Sasirma'),
    EmojiEntry(code: '<3', emoji: '❤️', label: 'Kalp'),
    EmojiEntry(code: ':/', emoji: '😕', label: 'Kararsiz'),
    EmojiEntry(code: ":'(", emoji: '😢', label: 'Aglama'),
  ];

  static List<EmojiEntry> get uniqueEntries {
    final seenEmoji = <String>{};
    final filtered = <EmojiEntry>[];
    for (final entry in entries) {
      if (seenEmoji.add(entry.emoji)) {
        filtered.add(entry);
      }
    }
    return filtered;
  }

  static String emojify(String text) {
    var result = text;
    for (final entry in entries) {
      result = result.replaceAll(entry.code, entry.emoji);
    }
    return result;
  }
}