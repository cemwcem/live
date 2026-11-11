import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

// navigator.userAgentData (User-Agent Client Hints) — yalnızca Chromium
// tabanlı tarayıcılarda (Chrome, Edge, Opera, Samsung) vardır; Safari ve
// Firefox'ta yoktur. package:web bu API'yi içermediği için küçük tanımlar:
extension type _UAData._(JSObject _) implements JSObject {
  external bool get mobile;
  external JSPromise<_UAValues> getHighEntropyValues(JSArray<JSString> hints);
}

extension type _UAValues._(JSObject _) implements JSObject {
  external String? get model;
  external String? get platform;
  external String? get platformVersion;
}

Future<Map<String, Object>> collectBrowserHints() async {
  final result = <String, Object>{};

  try {
    final screen = web.window.screen;
    result['screen'] = '${screen.width}x${screen.height}';
    result['pixelRatio'] = web.window.devicePixelRatio;
  } catch (_) {}

  try {
    final intl = globalContext.getProperty<JSObject>('Intl'.toJS);
    final format = intl.callMethod<JSObject>('DateTimeFormat'.toJS);
    final options = format.callMethod<JSObject>('resolvedOptions'.toJS);
    final timeZone = options.getProperty<JSAny?>('timeZone'.toJS);
    if (timeZone.isA<JSString>()) {
      result['timeZone'] = (timeZone as JSString).toDart;
    }
  } catch (_) {}

  try {
    final uaData = (web.window.navigator as JSObject)
        .getProperty<JSAny?>('userAgentData'.toJS);
    if (uaData != null && !uaData.isUndefinedOrNull) {
      final data = uaData as _UAData;
      result['uaMobile'] = data.mobile;
      final values = await data
          .getHighEntropyValues(
            ['model', 'platform', 'platformVersion'].map((e) => e.toJS).toList().toJS,
          )
          .toDart
          .timeout(const Duration(seconds: 2));
      final model = values.model;
      if (model != null && model.isNotEmpty) {
        result['uaModel'] = model;
      }
      final platform = values.platform;
      final platformVersion = values.platformVersion;
      if (platform != null && platform.isNotEmpty) {
        result['uaPlatform'] = platformVersion == null || platformVersion.isEmpty
            ? platform
            : '$platform $platformVersion';
      }
    }
  } catch (_) {}

  return result;
}
