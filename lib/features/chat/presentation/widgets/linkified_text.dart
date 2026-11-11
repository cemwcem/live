import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/url_detector.dart';

/// Metindeki web adreslerini tıklanabilir link olarak gösterir;
/// tıklanınca link yeni sekmede açılır.
/// [trailing] metnin sonuna eklenecek ek span'lar içindir (ör. saat alanı boşluğu).
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkColor = const Color(0xFF0A58CA),
    this.trailing = const [],
  });

  final String text;
  final TextStyle? style;
  final Color linkColor;
  final List<InlineSpan> trailing;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openLink(String url) async {
    final uri = UrlDetector.toUri(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in UrlDetector.linkPattern.allMatches(text)) {
      final linkEnd = UrlDetector.trimmedEnd(text, match.start, match.end);
      if (linkEnd <= match.start) {
        continue;
      }
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = text.substring(match.start, linkEnd);
      final recognizer = TapGestureRecognizer()..onTap = () => _openLink(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ),
      );
      lastEnd = linkEnd;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [..._buildSpans(), ...widget.trailing],
      ),
    );
  }
}
