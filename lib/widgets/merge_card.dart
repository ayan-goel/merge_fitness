import 'package:flutter/material.dart';
import '../theme/app_styles.dart';

class MergeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final BorderRadius? borderRadius;

  const MergeCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.width,
    this.height,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? (isDarkMode ? AppStyles.lightCharcoal : Colors.white),
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: isDarkMode ? 1 : 0,
            ),
          ],
          border: border,
        ),
        child: child,
      ),
    );
  }
}

// Feature card for dashboard sections
class MergeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const MergeFeatureCard({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDarkMode ? AppStyles.primarySage : AppStyles.primarySage;
    
    return MergeCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? defaultIconColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor ?? defaultIconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppStyles.textLight : AppStyles.textDark,
            ),
          ),
          
          // Optional subtitle
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Stat card for displaying metrics
class MergeStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  const MergeStatCard({
    Key? key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? AppStyles.primarySage;
    
    return MergeCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: cardColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? AppStyles.textLight : AppStyles.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 