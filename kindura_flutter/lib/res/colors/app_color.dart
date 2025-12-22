import 'package:flutter/material.dart';
import 'dart:ui';

class AppColor {
  static const Color black = Color(0xff000000);

  // Modern Professional Health App Colors (Ornament-inspired)
  static const Color primaryColor = Color(0xFF2563EB); // Professional blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color buttonColor = Color(0xFF2563EB);
  
  // Health-focused accent colors
  static const Color success = Color(0xFF10B981); // Green for healthy/normal
  static const Color warning = Color(0xFFF59E0B); // Amber for attention needed
  static const Color danger = Color(0xFFEF4444); // Red for critical/abnormal
  static const Color info = Color(0xFF06B6D4); // Cyan for information
  
  // Neutral colors for professional look
  static const Color surfaceLight = Color(0xFFFAFAFA); // Very light background
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards
  static const Color surfaceDark = Color(0xFFF8FAFC); // Subtle background
  
  // Text colors
  static const Color textPrimary = Color(0xFF1F2937); // Dark gray for primary text
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray for secondary text
  static const Color textMuted = Color(0xFF9CA3AF); // Light gray for muted text
  
  // Legacy peach color (keeping for backward compatibility)
  static const Color legacyPrimary = Color(0xFFF9A58A);

  static Color black9003f = fromHex('#3f000000');

  static Color yellowA200 = fromHex('#ffff00');

  static Color cyan5007 = fromHex('#07ccf0fa');

  static Color teal700 = fromHex('#037777');

  static Color teal901 = fromHex('#043434');

  static Color teal900 = fromHex('#0645A2');

  static Color lightBlueA700 = fromHex('#018cf5');

  static Color teal902 = fromHex('#044646');

  static Color teal900Ab = fromHex('#ab043434');

  static Color gray600 = fromHex('#757575');

  static Color gray402 = fromHex('#bdbdbd');

  static Color gray601 = fromHex('#7f8084');

  static Color gray403 = fromHex('#c1c1c1');

  static Color gray400 = fromHex('#c7c7c7');

  static Color gray401 = fromHex('#c4c4c4');

  static Color whiteA7000a = fromHex('#0affffff');

  static Color gray200 = fromHex('#e7e9ec');

  static Color gray201 = fromHex('#eeeeee');

  static Color bluegray401 = fromHex('#888888');

  static Color cyan5011 = fromHex('#11ccf0fa');

  static Color bluegray400 = fromHex('#84839c');

  static Color cyan50 = fromHex('#e0ffff');

  static Color black90019 = fromHex('#19000000');

  static Color whiteA700 = fromHex('#ffffff');

  static Color whiteA7009e = fromHex('#9effffff');

  static Color blueA7003f1 = fromHex('#3f2f66f6');

  static Color gray60019 = fromHex('#197e7e7e');

  static Color indigoA200 = fromHex('#5956e9');

  static Color gray50 = fromHex('#fafafa');

  static Color black900 = fromHex('#000000');

  static Color blueA7003f = fromHex('#3f246bfd');

  static Color gray501 = fromHex('#9f9f9f');

  static Color gray700 = fromHex('#616161');

  static Color gray502 = fromHex('#a8a7a7');

  static Color gray301 = fromHex('#e6e6e6');

  static Color gray500 = fromHex('#9e9e9e');

  static Color gray900 = fromHex('#10173b');

  static Color bluegray100 = fromHex('#d5d9e0');

  static Color gray101 = fromHex('#f4f6fa');

  static Color gray300 = fromHex('#e3e5e8');

  static Color gray100 = fromHex('#f6f7f8');

  static Color bluegray900 = fromHex('#1f1d46');

  static Color indigo100 = fromHex('#cac9df');

  static Color black90077 = fromHex('#77000000');

  static Color bluegray500 = fromHex('#737b8c');

  static Color gray50075 = fromHex('#759e9e9e');

  static Color cyan901 = fromHex('#005d5d');

  static Color cyan900 = fromHex('#025858');

  static Color teal900Ab1 = fromHex('#ab033333');

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
