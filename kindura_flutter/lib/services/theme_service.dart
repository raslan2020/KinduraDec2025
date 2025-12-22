import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends GetxController {
  static ThemeService get to => Get.find<ThemeService>();

  final _isDarkMode = false.obs;
  bool get isDarkMode => _isDarkMode.value;

  static const String _themeKey = 'is_dark_mode';

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode.value = prefs.getBool(_themeKey) ?? false;
    _updateTheme();
  }

  Future<void> toggleTheme() async {
    _isDarkMode.value = !_isDarkMode.value;
    await _saveThemeToPrefs();
    _updateTheme();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode.value = value;
    await _saveThemeToPrefs();
    _updateTheme();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode.value);
  }

  void _updateTheme() {
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: MaterialColor(0xFF2563EB, {
        50: Color(0xFFEFF6FF),
        100: Color(0xFFDBEAFE),
        200: Color(0xFFBFDBFE),
        300: Color(0xFF93C5FD),
        400: Color(0xFF60A5FA),
        500: Color(0xFF3B82F6),
        600: Color(0xFF2563EB),
        700: Color(0xFF1D4ED8),
        800: Color(0xFF1E40AF),
        900: Color(0xFF1E3A8A),
      }),
      primaryColor: Color(0xFF2563EB),
      scaffoldBackgroundColor: Color(0xFFFAFAFA),
      cardColor: Colors.white,
      canvasColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2937),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1F2937)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Urbanist',
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF2563EB),
        unselectedItemColor: Color(0xFF9CA3AF),
      ),
      textTheme: _getTextTheme(false),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
      dividerColor: Color(0xFFE5E7EB),
      fontFamily: 'Urbanist',
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: MaterialColor(0xFF3B82F6, {
        50: Color(0xFF1E3A5F),
        100: Color(0xFF1E40AF),
        200: Color(0xFF1D4ED8),
        300: Color(0xFF2563EB),
        400: Color(0xFF3B82F6),
        500: Color(0xFF60A5FA),
        600: Color(0xFF93C5FD),
        700: Color(0xFFBFDBFE),
        800: Color(0xFFDBEAFE),
        900: Color(0xFFEFF6FF),
      }),
      primaryColor: Color(0xFF3B82F6),
      scaffoldBackgroundColor: Color(0xFF0F172A),
      cardColor: Color(0xFF1E293B),
      canvasColor: Color(0xFF1E293B),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFFF1F5F9),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF1F5F9),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Urbanist',
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E293B),
        selectedItemColor: Color(0xFF3B82F6),
        unselectedItemColor: Color(0xFF64748B),
      ),
      textTheme: _getTextTheme(true),
      cardTheme: CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        hintStyle: TextStyle(color: Color(0xFF64748B)),
      ),
      dividerColor: Color(0xFF334155),
      fontFamily: 'Urbanist',
    );
  }

  static TextTheme _getTextTheme(bool isDark) {
    final textColor = isDark ? Color(0xFFF1F5F9) : Color(0xFF1F2937);
    final secondaryColor = isDark ? Color(0xFF94A3B8) : Color(0xFF6B7280);
    final mutedColor = isDark ? Color(0xFF64748B) : Color(0xFF9CA3AF);

    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
        fontFamily: 'Urbanist',
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Urbanist',
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Urbanist',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textColor,
        fontFamily: 'Urbanist',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
        fontFamily: 'Urbanist',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: mutedColor,
        fontFamily: 'Urbanist',
      ),
    );
  }
}

// Extension to easily access theme colors based on current theme
extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get backgroundColor => isDarkMode ? Color(0xFF0F172A) : Color(0xFFFAFAFA);
  Color get surfaceColor => isDarkMode ? Color(0xFF1E293B) : Colors.white;
  Color get cardBorderColor => isDarkMode ? Color(0xFF334155) : Color(0xFFE5E7EB);
  Color get textPrimaryColor => isDarkMode ? Color(0xFFF1F5F9) : Color(0xFF1F2937);
  Color get textSecondaryColor => isDarkMode ? Color(0xFF94A3B8) : Color(0xFF6B7280);
  Color get textMutedColor => isDarkMode ? Color(0xFF64748B) : Color(0xFF9CA3AF);
  Color get primaryColor => isDarkMode ? Color(0xFF3B82F6) : Color(0xFF2563EB);
  Color get navBarColor => isDarkMode ? Color(0xFF1A1A2E) : Color(0xFF1A1A2E);
}
