import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1976D2), // Blue as primary
        brightness: Brightness.light,
        background: Colors.white,
        surface: Colors.white,
        onBackground: Colors.black87,
        onSurface: Colors.black87,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Scaffold Theme
      scaffoldBackgroundColor: Colors.white,

      // Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
        bodySmall: TextStyle(color: Colors.black87),
        labelLarge: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(color: Colors.black87),
        labelSmall: TextStyle(color: Colors.black87),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: Colors.black87),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          side: const BorderSide(color: Color(0xFF1976D2)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        leadingAndTrailingTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: Colors.grey[300],
        thickness: 1,
        space: 1,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100],
        selectedColor: const Color(0xFF1976D2),
        labelStyle: const TextStyle(color: Colors.black87, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF1976D2),
        linearTrackColor: Colors.grey,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1976D2),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white,
        indicatorColor: Color.fromARGB(255, 248, 250, 251),
        dividerColor: Colors.white,
        labelStyle: TextStyle(color: Colors.white),
        unselectedLabelStyle: TextStyle(color: Colors.white),
        overlayColor: MaterialStatePropertyAll(Colors.white24),
      ),
      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(color: Colors.black87, fontSize: 16),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[800],
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Expansion Tile Theme
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: Colors.black87,
        iconColor: Colors.black87,
        collapsedTextColor: Colors.black87,
        collapsedIconColor: Colors.black87,
      ),
    );
  }

  // Custom color constants for maintaining visual hierarchy
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color secondaryBlue = Color(0xFF42A5F5);
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);

  // Card background colors for visual hierarchy
  static const Color cardBackground = Colors.white;
  static const Color cardBackgroundLight = Color(0xFFF8F9FA);
  static const Color cardBackgroundAccent = Color(0xFFE3F2FD);

  // Text colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF424242);
  static const Color textTertiary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
}
