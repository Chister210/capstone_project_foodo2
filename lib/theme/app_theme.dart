import 'package:flutter/material.dart';

class AppTheme {
  // Color scheme
  static const Color donorGreen = Color(0xFF43A047);
  static const Color receiverOrange = Color(0xFFFB8C00);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDarkGray = Color(0xFF424242);
  static const Color accentYellow = Color(0xFFFBC02D);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFF9E9E9E);

  // Theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: donorGreen,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: donorGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: donorGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: donorGreen,
          side: const BorderSide(color: donorGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: donorGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: donorGreen),
        ),
        contentPadding: const EdgeInsets.all(16),
        filled: true,
        fillColor: lightGray,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: backgroundWhite,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDarkGray,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Text styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textDarkGray,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textDarkGray,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textDarkGray,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textDarkGray,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textDarkGray,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: mediumGray,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 10,
    color: mediumGray,
  );

  // Button styles
  static ButtonStyle get donorButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: donorGreen,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  static ButtonStyle get receiverButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: receiverOrange,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  static ButtonStyle get accentButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accentYellow,
    foregroundColor: textDarkGray,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  // Container decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: backgroundWhite,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get softCardDecoration => BoxDecoration(
    color: backgroundWhite,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 5,
        offset: const Offset(0, 1),
      ),
    ],
  );

  // Spacing
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;

  // Border radius
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;
}
