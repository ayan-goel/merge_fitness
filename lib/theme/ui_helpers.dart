import 'package:flutter/material.dart';
import 'app_styles.dart';

/// UI Helper functions for the app
class UIHelpers {
  // Prevent instantiation
  UIHelpers._();
  
  /// Get a gradient based on workout status
  static LinearGradient getWorkoutStatusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const LinearGradient(
          colors: [Color(0xFF7A9D78), Color(0xFF8FAF8D)], // Muted greens
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'in progress':
        return const LinearGradient(
          colors: [Color(0xFFCFB28E), Color(0xFFDBBE9A)], // Muted gold/amber
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'skipped':
        return const LinearGradient(
          colors: [Color(0xFFCB8A90), Color(0xFFD6A3A7)], // Muted red
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default: // assigned
        return const LinearGradient(
          colors: [Color(0xFF6C8CA8), Color(0xFF9BB0C4)], // Muted blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
  
  /// Get a color based on BMI category
  static Color getBmiCategoryColor(double bmi) {
    if (bmi < 18.5) {
      return AppStyles.mutedBlue; // Underweight
    } else if (bmi < 25) {
      return AppStyles.successGreen; // Normal
    } else if (bmi < 30) {
      return AppStyles.warningAmber; // Overweight
    } else {
      return AppStyles.errorRed; // Obese
    }
  }
  
  /// Format a duration to a readable string
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
  
  /// Add a subtle glass effect to a container
  static BoxDecoration glassEffect({
    Color baseColor = AppStyles.lightCharcoal,
    double opacity = 0.7,
    double borderRadius = 16,
    Color? borderColor,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      color: baseColor.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(
              color: borderColor.withOpacity(0.3),
              width: borderWidth,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  /// Create a premium gradient button
  static ElevatedButtonStyle premiumButton({
    Gradient? gradient,
    double elevation = 4,
    double borderRadius = 12,
  }) {
    return ElevatedButton.styleFrom(
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      elevation: elevation,
    ).copyWith(
      backgroundColor: MaterialStateProperty.all(Colors.transparent),
    );
  }
  
  /// Wrap child with a gradient background
  static Widget gradientButton({
    required Widget child,
    required VoidCallback onPressed,
    Gradient? gradient,
    double borderRadius = 12,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: premiumButton(
        gradient: gradient,
        borderRadius: borderRadius,
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient ?? AppStyles.primaryGradient,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
  
  /// Create a modern divider with a subtle gradient
  static Widget modernDivider({
    Color? color,
    double thickness = 1,
    double height = 24,
  }) {
    return Container(
      height: thickness,
      margin: EdgeInsets.symmetric(vertical: height / 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (color ?? AppStyles.slateGray).withOpacity(0.01),
            color ?? AppStyles.slateGray,
            (color ?? AppStyles.slateGray).withOpacity(0.01),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
  
  /// Create a badge with a number
  static Widget numberBadge({
    required int number,
    Color? color,
    double size = 24,
    double fontSize = 12,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? AppStyles.mutedBlue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Create a trainer avatar
  static Widget trainerAvatar({
    String? imageUrl,
    double size = 50,
    String? initials,
    Color? backgroundColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: backgroundColor == null
            ? AppStyles.primaryGradient
            : null,
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AppStyles.mutedBlue).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      initials ?? 'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.4,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                initials ?? 'T',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              ),
            ),
    );
  }
  
  /// Create a modern, subtle badge label
  static Widget badgeLabel({
    required String label,
    Color? color,
    bool outline = false,
    EdgeInsetsGeometry? padding,
  }) {
    final badgeColor = color ?? AppStyles.mutedBlue;
    
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: outline
          ? BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: badgeColor,
                width: 1.5,
              ),
            )
          : BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: badgeColor.withOpacity(0.3),
                width: 1,
              ),
            ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
} 