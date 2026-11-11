import 'package:flutter/foundation.dart';

/// Web dışı platformlar için boş implementasyon.
class AudioPlayback {
  AudioPlayback(String url, {required VoidCallback onChanged});

  static bool get isSupported => false;

  bool get isPlaying => false;
  bool get hasError => true;
  Duration get position => Duration.zero;
  Duration? get duration => null;

  Future<void> toggle() async {}
  void seek(Duration position) {}
  void dispose() {}
}
