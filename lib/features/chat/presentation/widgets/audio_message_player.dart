import 'package:flutter/material.dart';

import '../../../../core/audio/audio_playback.dart';

/// Mesaj balonu içinde ses kaydını çalan küçük oynatıcı.
/// Çalınamazsa (format desteklenmiyor vb.) [onOpenExternally] ile dosya açılır.
class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.onOpenExternally,
  });

  final String url;
  final VoidCallback onOpenExternally;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  AudioPlayback? _playback;

  // Oynatıcı ilk dokunuşta oluşturulur; böylece listede çok sayıda ses
  // mesajı varken sayfa açılışında hiçbir dosya indirilmez.
  AudioPlayback _ensurePlayback() {
    return _playback ??= AudioPlayback(widget.url, onChanged: _refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant AudioMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _playback?.dispose();
      _playback = null;
    }
  }

  @override
  void dispose() {
    _playback?.dispose();
    super.dispose();
  }

  String _format(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    if (!AudioPlayback.isSupported || (playback?.hasError ?? false)) {
      return _buildFallback();
    }

    final isPlaying = playback?.isPlaying ?? false;
    final position = playback?.position ?? Duration.zero;
    final duration = playback?.duration;
    final totalMs = duration?.inMilliseconds ?? 0;
    final progress = totalMs > 0
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final timeText = duration == null
        ? _format(position)
        : '${_format(position)} / ${_format(duration)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            tooltip: isPlaying ? 'Duraklat' : 'Oynat',
            onPressed: () => _ensurePlayback().toggle(),
          ),
          SizedBox(
            width: 130,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: progress,
                onChanged: totalMs > 0
                    ? (value) => playback?.seek(
                        Duration(milliseconds: (value * totalMs).round()),
                      )
                    : null,
              ),
            ),
          ),
          Text(timeText, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onOpenExternally,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_outlined, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Ses bu tarayıcıda çalınamadı — açmak için dokun',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
