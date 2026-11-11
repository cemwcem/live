/// Ek dosya türü tespiti (uzantı -> MIME) için ortak yardımcı.
class AttachmentTypes {
  static const Map<String, String> _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'pdf': 'application/pdf',
    // Ses kayıtları (mobil ses kaydedicilerin ürettiği yaygın formatlar).
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/ogg',
    'weba': 'audio/webm',
    'amr': 'audio/amr',
    '3gp': 'audio/3gpp',
    '3gpp': 'audio/3gpp',
    'flac': 'audio/flac',
  };

  static String extensionOf(String? fileName) {
    if (fileName == null || !fileName.contains('.')) {
      return '';
    }
    return fileName.split('.').last.toLowerCase();
  }

  static String guessMimeType(String fileName) {
    return _mimeByExtension[extensionOf(fileName)] ?? 'application/octet-stream';
  }

  /// MIME tipine, o yoksa dosya uzantısına bakar (eski mesajlar
  /// "application/octet-stream" ile kaydedilmiş olabilir).
  static bool isAudio({String? mimeType, String? fileName}) {
    if (mimeType != null && mimeType.startsWith('audio/')) {
      return true;
    }
    return guessMimeType(fileName ?? '').startsWith('audio/');
  }
}
