import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../app_release.dart';

class ClientInfo {
  const ClientInfo._();

  static Future<Map<String, dynamic>> collect() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final info = <String, dynamic>{
      'appVersion': AppRelease.version,
      'releaseName': AppRelease.name,
      'releaseDate': AppRelease.deployedAt,
      'platform': _platformName(),
      'connectedAt': now,
      'updatedAt': now,
    };

    final plugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        info['browserName'] = web.browserName.name;
        info['userAgent'] = web.userAgent ?? '';
        info['webPlatform'] = web.platform ?? '';
        info['vendor'] = web.vendor ?? '';
      } else if (Platform.isAndroid) {
        final android = await plugin.androidInfo;
        info['deviceModel'] = android.model;
        info['deviceBrand'] = android.brand;
        info['androidVersion'] = android.version.release;
        info['sdkInt'] = android.version.sdkInt;
      } else if (Platform.isIOS) {
        final ios = await plugin.iosInfo;
        info['deviceModel'] = ios.utsname.machine;
        info['iosVersion'] = ios.systemVersion;
        info['deviceName'] = ios.name;
      } else if (Platform.isWindows) {
        final windows = await plugin.windowsInfo;
        info['windowsBuild'] = windows.buildNumber;
        info['computerName'] = windows.computerName;
      } else if (Platform.isLinux) {
        final linux = await plugin.linuxInfo;
        info['linuxVersion'] = linux.version;
        info['prettyName'] = linux.prettyName;
      } else if (Platform.isMacOS) {
        final mac = await plugin.macOsInfo;
        info['macOsVersion'] = mac.osRelease;
        info['model'] = mac.model;
      }
    } catch (_) {
      info['clientInfoError'] = 'collect_failed';
    }

    return info;
  }

  static String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    return 'unknown';
  }
}
