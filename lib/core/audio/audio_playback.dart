// Web'de tarayıcının yerleşik <audio> elementi kullanılır (ek paket yok);
// diğer platformlarda stub devreye girer ve dosya linki gösterilir.
export 'audio_playback_stub.dart'
    if (dart.library.js_interop) 'audio_playback_web.dart';
