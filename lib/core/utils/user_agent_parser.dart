/// User-Agent metninden işletim sistemi, tarayıcı ve cihaz türünü çıkarır.
/// Paket kullanmadan, yaygın tarayıcılar için yeterli basit bir ayrıştırıcı.
class UserAgentParser {
  static Map<String, String> parse(String ua, {int maxTouchPoints = 0}) {
    final result = <String, String>{};

    // --- İşletim sistemi ---
    String? os;
    String? osVersion;
    final android = RegExp(r'Android\s([\d.]+)').firstMatch(ua);
    final ios = RegExp(r'(iPhone|iPad|iPod).*?OS\s([\d_]+)').firstMatch(ua);
    final windows = RegExp(r'Windows NT\s([\d.]+)').firstMatch(ua);
    final mac = RegExp(r'Mac OS X\s([\d_.]+)').firstMatch(ua);
    if (android != null) {
      os = 'Android';
      osVersion = android.group(1);
    } else if (ios != null) {
      os = ios.group(1) == 'iPad' ? 'iPadOS' : 'iOS';
      osVersion = ios.group(2)!.replaceAll('_', '.');
    } else if (ua.contains('Macintosh') && maxTouchPoints > 1) {
      // iPadOS 13+ masaüstü (Mac) user-agent'ı gönderir.
      os = 'iPadOS';
    } else if (windows != null) {
      os = 'Windows';
      osVersion = windows.group(1) == '10.0' ? '10/11' : windows.group(1);
    } else if (mac != null) {
      os = 'macOS';
      osVersion = mac.group(1)!.replaceAll('_', '.');
    } else if (ua.contains('CrOS')) {
      os = 'ChromeOS';
    } else if (ua.contains('Linux')) {
      os = 'Linux';
    }
    if (os != null) result['os'] = os;
    if (osVersion != null) result['osVersion'] = osVersion;

    // --- Tarayıcı (sıra önemli: Edge/Opera/Samsung UA'sında "Chrome" da geçer) ---
    const browsers = [
      ('Edge', r'Edg(?:A|iOS)?/([\d.]+)'),
      ('Opera', r'(?:OPR|OPT)/([\d.]+)'),
      ('Samsung Internet', r'SamsungBrowser/([\d.]+)'),
      ('Yandex', r'YaBrowser/([\d.]+)'),
      ('Firefox', r'(?:Firefox|FxiOS)/([\d.]+)'),
      ('Chrome', r'(?:Chrome|CriOS)/([\d.]+)'),
      ('Safari', r'Version/([\d.]+).*Safari'),
    ];
    for (final (name, pattern) in browsers) {
      final match = RegExp(pattern).firstMatch(ua);
      if (match != null) {
        result['browser'] = name;
        result['browserVersion'] = match.group(1)!;
        break;
      }
    }

    // --- Cihaz türü ve (varsa) modeli ---
    final isTablet = ua.contains('iPad') ||
        (os == 'iPadOS') ||
        (android != null && !ua.contains('Mobile'));
    result['deviceType'] = isTablet
        ? 'tablet'
        : (ua.contains('Mobi') || ua.contains('iPhone') ? 'mobile' : 'desktop');

    if (ua.contains('iPhone')) {
      result['deviceModel'] = 'iPhone';
    } else if (ua.contains('iPad') || os == 'iPadOS') {
      result['deviceModel'] = 'iPad';
    } else if (android != null) {
      // Ör. "Android 14; SM-S911B)" — Chrome yeni sürümlerde modeli "K"
      // olarak gizler; o durumda model tarayıcı ipuçlarından gelir.
      final model = RegExp(r'Android\s[\d.]+;\s([^;)]+)').firstMatch(ua);
      final value = model?.group(1)?.replaceAll(RegExp(r'\sBuild/.*'), '').trim();
      if (value != null && value.isNotEmpty && value != 'K') {
        result['deviceModel'] = value;
      }
    }

    return result;
  }
}
