import 'package:flutter/material.dart';

/// A collection of reusable styles for the app
class AppStyles {
  // Prevent instantiation
  AppStyles._();
  
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color softGold = Color(0xFFE6C170);
  static const Color deepPlum = Color(0xFF9C27B0);
  static const Color backgroundCharcoal = Color(0xFF121212);
  static const Color surfaceCharcoal = Color(0xFF1E1E1E);
  static const Color cardCharcoal = Color(0xFF252525);
  static const Color inputFieldCharcoal = Color(0xFF2C2C2C);
  static const Color dividerGrey = Color(0xFF3D3D3D);
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color textGrey = Color(0xFFAAAAAA);
  static const Color errorRed = Color(0xFFCF6679);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFB74D);
  
  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, Color(0xFF0C47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [softGold, Color(0xFFBC8F2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Card styles
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surfaceCharcoal,
    borderRadius: BorderRadius.circular(16),
    boxShadow: cardShadow,
  );
  
  static BoxDecoration get cardDecorationHover => BoxDecoration(
    color: cardCharcoal,
    borderRadius: BorderRadius.circular(16),
    boxShadow: cardShadow,
    border: Border.all(color: primaryBlue.withOpacity(0.3), width: 1.5),
  );
  
  // Button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: primaryBlue.withOpacity(0.3),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    side: const BorderSide(color: primaryBlue, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  // Text input styles
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: inputFieldCharcoal,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      labelStyle: const TextStyle(color: textGrey),
      hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
    );
  }
  
  // Status indicators
  static BoxDecoration statusDecoration(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.5), width: 1),
    );
  }
  
  // Animation durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // Common padding values
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets itemSpacing = EdgeInsets.symmetric(vertical: 8.0);
  static const EdgeInsets sectionSpacing = EdgeInsets.symmetric(vertical: 24.0);
  
  // Common border radius values
  static BorderRadius get defaultBorderRadius => BorderRadius.circular(12);
  static BorderRadius get largeBorderRadius => BorderRadius.circular(24);
  static BorderRadius get smallBorderRadius => BorderRadius.circular(8);
} 