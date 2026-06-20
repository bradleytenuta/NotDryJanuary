import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryGold = Color(0xFFFFB300); // Warm amber beer gold
  static const Color primaryDarkGold = Color(0xFFD97706); // Darker amber gold
  static const Color backgroundSlate = Color(0xFF0F172A); // Rich dark slate background
  static const Color surfaceSlate = Color(0xFF1E293B); // Card/Container surface slate
  static const Color borderSlate = Color(0xFF334155); // Border slate

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryGold,
      scaffoldBackgroundColor: backgroundSlate,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: primaryDarkGold,
        surface: surfaceSlate,
        onSurface: Color(0xFFF8FAFC),
        outline: borderSlate,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundSlate,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryGold),
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceSlate,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSlate, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSlate,
        disabledColor: surfaceSlate,
        selectedColor: primaryGold.withOpacity(0.2),
        secondarySelectedColor: primaryGold.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: primaryGold, fontWeight: FontWeight.bold),
        side: const BorderSide(color: borderSlate, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSlate,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSlate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSlate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: MaterialStateProperty.all(surfaceSlate),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: borderSlate),
            ),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent, // To support custom blur & rounded corners
        elevation: 0,
        dragHandleColor: primaryGold,
        dragHandleSize: Size(36, 4),
        showDragHandle: true,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: primaryGold,
      ),
    );
  }
}
