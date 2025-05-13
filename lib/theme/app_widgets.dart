import 'package:flutter/material.dart';
import 'app_styles.dart';

/// A collection of reusable widgets for the app
class AppWidgets {
  // Prevent instantiation
  AppWidgets._();
  
  /// Stylized section header with optional action button
  static Widget sectionHeader({
    required String title,
    VoidCallback? onActionPressed,
    String actionLabel = 'View All',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppStyles.textWhite,
              letterSpacing: 0.15,
            ),
          ),
          if (onActionPressed != null)
            TextButton(
              onPressed: onActionPressed,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
  
  /// Styled card with hover effect
  static Widget styledCard({
    required Widget child,
    double elevation = 4,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
    bool hasHoverEffect = false,
  }) {
    final decoration = hasHoverEffect 
        ? AppStyles.cardDecorationHover 
        : AppStyles.cardDecoration;
    
    final card = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    
    return card;
  }
  
  /// Animated progress indicator
  static Widget circularProgressIndicator({
    double size = 40,
    Color? color,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppStyles.primaryBlue,
        ),
        strokeWidth: 3,
      ),
    );
  }
  
  /// Skeleton loading placeholder for cards
  static Widget skeletonCard({
    required double height,
    double? width,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppStyles.surfaceCharcoal,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppStyles.surfaceCharcoal,
            AppStyles.surfaceCharcoal.withOpacity(0.5),
            AppStyles.surfaceCharcoal,
          ],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }
  
  /// Status badge (success, warning, error, info)
  static Widget statusBadge({
    required String label,
    required StatusType type,
    bool isOutlined = false,
  }) {
    Color color;
    switch (type) {
      case StatusType.success:
        color = AppStyles.successGreen;
        break;
      case StatusType.warning:
        color = AppStyles.warningAmber;
        break;
      case StatusType.error:
        color = AppStyles.errorRed;
        break;
      case StatusType.info:
        color = AppStyles.primaryBlue;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: isOutlined
          ? BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.5),
            )
          : BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
      child: Text(
        label,
        style: TextStyle(
          color: isOutlined ? color : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// Action button with icon and label
  static Widget actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppStyles.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// Empty state placeholder with icon and text
  static Widget emptyState({
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppStyles.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Gradient background container
  static Widget gradientBackground({
    required Widget child,
    Gradient? gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppStyles.darkGradient,
      ),
      child: child,
    );
  }
  
  /// Pulsating dot indicator (for live status, etc.)
  static Widget pulsatingDot({
    required Color color,
    double size = 10,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: _PulsatingDot(color: color, size: size),
    );
  }
}

/// Status type enum for status badges
enum StatusType {
  success,
  warning,
  error,
  info,
}

/// Pulsating dot animation
class _PulsatingDot extends StatefulWidget {
  final Color color;
  final double size;
  
  const _PulsatingDot({
    required this.color,
    required this.size,
  });
  
  @override
  State<_PulsatingDot> createState() => _PulsatingDotState();
}

class _PulsatingDotState extends State<_PulsatingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: widget.size * _animation.value,
                spreadRadius: widget.size * (_animation.value - 0.6),
              ),
            ],
          ),
        );
      },
    );
  }
} 