/// Metin içindeki web adreslerini bulmak için ortak yardımcı.
class UrlDetector {
  /// Yazma sırasında da eşleşir: "http:/" gibi yarım şema da URL sayılır,
  /// böylece emoji dönüşümü (":/" -> 😕) adresin ortasında tetiklenmez.
  static final RegExp typingPattern = RegExp(
    r'(?:https?|ftp|file):/\S*|www\.\S+',
    caseSensitive: false,
  );

  /// Tıklanabilir link olarak gösterilecek tam adresler.
  static final RegExp linkPattern = RegExp(
    r'(?:https?|ftp)://\S+|www\.\S+',
    caseSensitive: false,
  );

  static const String _trailingPunctuation = '.,;:!?)]}\'"';

  /// Linkin sonuna yapışmış noktalama işaretlerini ayırır.
  /// Ör. "https://site.com." -> link "https://site.com", kalan "."
  static int trimmedEnd(String text, int start, int end) {
    var trimmedEnd = end;
    while (trimmedEnd > start &&
        _trailingPunctuation.contains(text[trimmedEnd - 1])) {
      trimmedEnd--;
    }
    return trimmedEnd;
  }

  /// "www." ile başlayan adreslere şema ekleyip Uri'ye çevirir.
  static Uri? toUri(String url) {
    final normalized =
        url.toLowerCase().startsWith('www.') ? 'https://$url' : url;
    return Uri.tryParse(normalized);
  }
}
