import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF087E8B);
  static const Color accent = Color(0xFFF0AE45);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
