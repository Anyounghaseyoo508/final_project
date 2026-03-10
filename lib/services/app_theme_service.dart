import 'package:flutter/material.dart';

class AppThemeService {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static void setDarkMode(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;
}
