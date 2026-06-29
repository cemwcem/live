import 'dart:convert';
import 'dart:io';

void main() {
  final projectRoot = Directory.current;

  final releaseFile = File('${projectRoot.path}/release.json');
  if (!releaseFile.existsSync()) {
    stderr.writeln('Hata: release.json bulunamadı. Proje kökünde olmalıdır.');
    exit(1);
  }

  final release = jsonDecode(releaseFile.readAsStringSync()) as Map<String, dynamic>;
  final version = release['version'] as String;
  final releaseName = release['releaseName'] as String;

  final now = DateTime.now();
  final deployedAt =
      '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';

  final versionJson = {
    'appVersion': version,
    'releaseName': releaseName,
    'deployedAt': deployedAt,
  };
  File('${projectRoot.path}/web/version.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(versionJson)}\n');

  File('${projectRoot.path}/lib/core/app_release.dart').writeAsStringSync(
    'class AppRelease {\n'
    '  const AppRelease._();\n'
    '\n'
    "  static const String name = '$releaseName';\n"
    "  static const String version = '$version';\n"
    "  static const String deployedAt = '$deployedAt';\n"
    '}\n',
  );

  print('Release hazırlandi: $version ($releaseName) - $deployedAt');
}

String _pad(int n) => n.toString().padLeft(2, '0');
