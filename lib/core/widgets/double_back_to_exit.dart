import 'dart:async';

import 'package:flutter/material.dart';

/// Kök ekranlar için: ilk geri tuşunda uyarı gösterir ve ekranda kalır;
/// 2 saniye içinde tekrar basılırsa geri gitmeye (önceki web sayfasına /
/// uygulamadan çıkmaya) izin verir.
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({
    super.key,
    required this.child,
    this.message = 'Çıkmak için tekrar geri tuşuna bas',
    this.window = const Duration(seconds: 2),
  });

  final Widget child;
  final String message;
  final Duration window;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  bool _exitArmed = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleBlockedBack() {
    setState(() {
      _exitArmed = true;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(widget.message),
          duration: widget.window,
          behavior: SnackBarBehavior.floating,
        ),
      );
    _timer?.cancel();
    _timer = Timer(widget.window, () {
      if (mounted) {
        setState(() {
          _exitArmed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Süre dolmadan ikinci basışta canPop=true olur ve geri olayı
      // tarayıcıya/sisteme iletilir.
      canPop: _exitArmed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBlockedBack();
        }
      },
      child: widget.child,
    );
  }
}
