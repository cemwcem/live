import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Tarayıcının <audio> elementiyle sesi sayfa içinde çalar.
/// Storage linki <audio> ile çalındığında CORS gerekmez.
class AudioPlayback {
  AudioPlayback(String url, {required VoidCallback onChanged})
    : _onChanged = onChanged,
      _audio = web.HTMLAudioElement() {
    _audio
      ..preload = 'metadata'
      ..src = url;
    for (final type in _events) {
      _audio.addEventListener(type, _listener);
    }
  }

  static const _events = [
    'play',
    'pause',
    'ended',
    'timeupdate',
    'loadedmetadata',
    'durationchange',
    'error',
  ];

  /// Aynı anda tek bir ses çalsın diye en son çalan tutulur.
  static AudioPlayback? _active;

  static bool get isSupported => true;

  final VoidCallback _onChanged;
  final web.HTMLAudioElement _audio;
  bool _hasError = false;

  late final JSFunction _listener = ((web.Event event) {
    if (event.type == 'error') {
      _hasError = true;
    }
    _onChanged();
  }).toJS;

  bool get isPlaying => !_audio.paused && !_audio.ended;
  bool get hasError => _hasError;
  Duration get position => _toDuration(_audio.currentTime) ?? Duration.zero;
  Duration? get duration => _toDuration(_audio.duration);

  static Duration? _toDuration(double seconds) {
    // Bazı kayıt formatlarında süre çalınana kadar NaN/Infinity gelir.
    if (!seconds.isFinite || seconds < 0) {
      return null;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Future<void> toggle() async {
    if (isPlaying) {
      _audio.pause();
      return;
    }
    final active = _active;
    if (active != null && !identical(active, this)) {
      active._audio.pause();
    }
    _active = this;
    try {
      await _audio.play().toDart;
    } catch (_) {
      // play() hemen ardından pause() gelirse AbortError fırlatır; bu bir
      // hata değildir. Gerçek oynatma hatasında _audio.error dolu olur.
      if (_audio.error != null) {
        _hasError = true;
      }
      _onChanged();
    }
  }

  void seek(Duration position) {
    _audio.currentTime = position.inMilliseconds / 1000;
  }

  void dispose() {
    _audio.pause();
    for (final type in _events) {
      _audio.removeEventListener(type, _listener);
    }
    _audio.removeAttribute('src');
    _audio.load();
    if (identical(_active, this)) {
      _active = null;
    }
  }
}
