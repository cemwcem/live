// Web'de tarayıcıdan ek bilgi (ekran, saat dilimi, cihaz modeli) toplar;
// diğer platformlarda boş döner.
export 'browser_hints_stub.dart'
    if (dart.library.js_interop) 'browser_hints_web.dart';
