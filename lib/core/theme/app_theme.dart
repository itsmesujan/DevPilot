import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF6C63FF);
  static const _accentColor = Color(0xFF00D4AA);
  static const _bgDark = Color(0xFF0D0D1A);
  static const _surfaceDark = Color(0xFF161628);
  static const _cardDark = Color(0xFF1E1E35);
  static const _borderDark = Color(0xFF2A2A45);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primaryColor,
          secondary: _accentColor,
          surface: _surfaceDark,
          onSurface: Colors.white,
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: _bgDark,
        cardColor: _cardDark,
        dividerColor: _borderDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white70),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _surfaceDark,
          selectedItemColor: _primaryColor,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cardDark,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Colors.white30),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _primaryColor),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _cardDark,
          selectedColor: _primaryColor.withAlpha(80),
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
          side: const BorderSide(color: _borderDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        useMaterial3: true,
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _primaryColor,
          secondary: _accentColor,
        ),
        useMaterial3: true,
      );
}
