import 'package:flutter/material.dart';
import '../theme/app_styles.dart';

enum MergeButtonType {
  primary,
  secondary,
  outline,
  text,
}

enum MergeButtonSize {
  small,
  medium,
  large,
}

class MergeButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final MergeButtonType type;
  final MergeButtonSize size;
  final IconData? icon;
  final bool iconLeading;
  final bool isLoading;
  final bool fullWidth;
  final double? width;
  final Color? color;

  const MergeButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = MergeButtonType.primary,
    this.size = MergeButtonSize.medium,
    this.icon,
    this.iconLeading = true,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine button theme based on type
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = color ?? AppStyles.primarySage;
    
    // Button sizing
    EdgeInsetsGeometry buttonPadding;
    double fontSize;
    double iconSize;
    
    switch (size) {
      case MergeButtonSize.small:
        buttonPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        fontSize = 14;
        iconSize = 18;
        break;
      case MergeButtonSize.large:
        buttonPadding = const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
        fontSize = 18;
        iconSize = 24;
        break;
      case MergeButtonSize.medium:
      default:
        buttonPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
        fontSize = 16;
        iconSize = 20;
        break;
    }
    
    // Child widget (with loading indicator or text + icon)
    Widget child;
    
    if (isLoading) {
      child = SizedBox(
        height: size == MergeButtonSize.small ? 16 : 20,
        width: size == MergeButtonSize.small ? 16 : 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: type == MergeButtonType.primary 
              ? Colors.white 
              : buttonColor,
        ),
      );
    } else {
      if (icon != null) {
        if (iconLeading) {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );
        } else {
          child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: iconSize),
            ],
          );
        }
      } else {
        child = Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        );
      }
    }
    
    // Determine the appropriate button widget based on type
    Widget button;
    
    switch (type) {
      case MergeButtonType.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode 
                ? AppStyles.lightCharcoal 
                : Colors.grey.shade100,
            foregroundColor: buttonColor,
            elevation: 0,
            padding: buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        );
        break;
      case MergeButtonType.outline:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: buttonColor,
            side: BorderSide(color: buttonColor, width: 1.5),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        );
        break;
      case MergeButtonType.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: buttonColor,
            padding: buttonPadding,
          ),
          child: child,
        );
        break;
      case MergeButtonType.primary:
      default:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            elevation: 1,
            shadowColor: buttonColor.withOpacity(0.3),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        );
        break;
    }
    
    // Wrap in a container with specific width if needed
    if (fullWidth || width != null) {
      return SizedBox(
        width: fullWidth ? double.infinity : width,
        child: button,
      );
    }
    
    return button;
  }
} 