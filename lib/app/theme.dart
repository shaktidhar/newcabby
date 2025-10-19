import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    colorSchemeSeed: const Color(0xFF2563EB),
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
