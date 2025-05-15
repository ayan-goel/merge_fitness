import 'package:flutter/material.dart';

/// A collection of reusable styles for the app
class AppStyles {
  // Prevent instantiation
  AppStyles._();
  
  // Brand Colors - Updated to match the MERGE logo style
  static const Color primarySage = Color(0xFF7D9D8C); // Soft sage green
  static const Color mutedBlue = Color(0xFF6C8CA8); // Muted blue
  static const Color taupeBrown = Color(0xFFA89680); // Taupe brown
  static const Color slateGray = Color(0xFF616A73); // Slate gray for text
  static const Color offWhite = Color(0xFFF8F6F2); // Off-white/soft beige for backgrounds
  static const Color darkCharcoal = Color(0xFF292A2D); // Dark charcoal for dark mode backgrounds
  static const Color lightCharcoal = Color(0xFF3D3F43); // Light charcoal for surfaces in dark mode
  static const Color subtleAccent = Color(0xFF9FB1A4); // Subtle accent color
  static const Color textDark = Color(0xFF414141); // Dark text for light mode
  static const Color textLight = Color(0xFFEFEFEF); // Light text for dark mode
  static const Color errorRed = Color(0xFFCB8A90); // Muted red for errors
  static const Color successGreen = Color(0xFF7A9D78); // Muted green for success
  static const Color warningAmber = Color(0xFFCFB28E); // Muted amber for warnings
  static const Color dividerGrey = Color(0xFF4A4D52); // Muted gray for dividers in dark mode
  static const Color softGold = Color(0xFFD6B678); // Soft gold accent color
  
  // Shadows - Softer shadows for a more elegant look
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primarySage.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  // Gradients - More subtle and refined
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primarySage, Color(0xFF5B7D6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [taupeBrown, Color(0xFF8C7A64)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF292A2D), Color(0xFF1F2022)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Card styles - More rounded with softer shadows
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: offWhite,
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
  );
  
  static BoxDecoration get cardDecorationDark => BoxDecoration(
    color: lightCharcoal,
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
  );
  
  static BoxDecoration get cardDecorationHover => BoxDecoration(
    color: offWhite,
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
    border: Border.all(color: primarySage.withOpacity(0.3), width: 1.5),
  );
  
  // Button styles - More rounded with consistent padding
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primarySage,
    foregroundColor: Colors.white,
    elevation: 1,
    shadowColor: primarySage.withOpacity(0.2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );
  
  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primarySage,
    side: const BorderSide(color: primarySage, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );
  
  // Text input styles - More rounded with subtle fill
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDarkMode = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: isDarkMode ? lightCharcoal : Colors.grey.shade50,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: slateGray.withOpacity(0.3),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: slateGray.withOpacity(0.3),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primarySage,
          width: 1.5,
        ),
      ),
      labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
      hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
    );
  }
  
  // Status indicators - More subtle with rounded corners
  static BoxDecoration statusDecoration(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3), width: 1),
    );
  }
  
  // Animation durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // Common padding values - Increased for more breathing room
  static const EdgeInsets screenPadding = EdgeInsets.all(20.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);
  static const EdgeInsets itemSpacing = EdgeInsets.symmetric(vertical: 12.0);
  static const EdgeInsets sectionSpacing = EdgeInsets.symmetric(vertical: 28.0);
  
  // Common border radius values - More rounded for a softer look
  static BorderRadius get defaultBorderRadius => BorderRadius.circular(16);
  static BorderRadius get largeBorderRadius => BorderRadius.circular(24);
  static BorderRadius get smallBorderRadius => BorderRadius.circular(12);
} 