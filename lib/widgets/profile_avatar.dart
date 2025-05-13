import 'package:flutter/material.dart';
import '../services/profile_image_service.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final double fontSize;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.fontSize = 14,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final profileImageService = ProfileImageService();
    final effectiveBorderColor = borderColor ?? Theme.of(context).colorScheme.primary;
    
    Widget avatar = profileImageService.getProfileImage(
      name: name,
      radius: radius,
      fontSize: fontSize,
    );
    
    // Add border if requested
    if (showBorder) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: 2.0,
          ),
        ),
        child: avatar,
      );
    }
    
    // Add tap functionality if provided
    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }
    
    return avatar;
  }
}

// A version with a badge indicator (for online status, notifications, etc.)
class ProfileAvatarWithBadge extends StatelessWidget {
  final String name;
  final double radius;
  final double fontSize;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final Widget badge;
  final BadgePosition badgePosition;

  const ProfileAvatarWithBadge({
    super.key,
    required this.name,
    this.radius = 20,
    this.fontSize = 14,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    required this.badge,
    this.badgePosition = BadgePosition.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProfileAvatar(
          name: name,
          radius: radius,
          fontSize: fontSize,
          onTap: onTap,
          showBorder: showBorder,
          borderColor: borderColor,
        ),
        Positioned(
          top: badgePosition == BadgePosition.topRight || badgePosition == BadgePosition.topLeft ? -5 : null,
          bottom: badgePosition == BadgePosition.bottomRight || badgePosition == BadgePosition.bottomLeft ? -5 : null,
          right: badgePosition == BadgePosition.topRight || badgePosition == BadgePosition.bottomRight ? -5 : null,
          left: badgePosition == BadgePosition.topLeft || badgePosition == BadgePosition.bottomLeft ? -5 : null,
          child: badge,
        ),
      ],
    );
  }
}

enum BadgePosition {
  topRight,
  topLeft,
  bottomRight,
  bottomLeft,
} 