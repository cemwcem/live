import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/session_storage.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_hydrate());
    return ThemeMode.light;
  }

  Future<void> _hydrate() async {
    final isDark = await SessionStorage.readIsDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleDarkMode() async {
    final isDark = state == ThemeMode.dark;
    final nextIsDark = !isDark;
    state = nextIsDark ? ThemeMode.dark : ThemeMode.light;
    await SessionStorage.saveIsDarkMode(nextIsDark);
  }
}
