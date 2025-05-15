import 'package:flutter/material.dart';
import '../theme/app_styles.dart';

class MergeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showLogo;
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const MergeAppBar({
    Key? key,
    this.title,
    this.actions,
    this.showLogo = true,
    this.centerTitle = true,
    this.leading,
    this.bottom,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: centerTitle,
      elevation: 0,
      backgroundColor: Theme.of(context).brightness == Brightness.light 
          ? AppStyles.offWhite
          : AppStyles.darkCharcoal,
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).brightness == Brightness.light
                    ? AppStyles.slateGray
                    : AppStyles.textLight,
                size: 22,
              ),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : leading,
      title: _buildTitle(context),
      actions: actions,
      bottom: bottom,
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (!showLogo && title != null) {
      // Text only title
      return Text(
        title!,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.light
              ? AppStyles.slateGray
              : AppStyles.textLight,
          fontWeight: FontWeight.w500,
          fontSize: 18,
          letterSpacing: 0.5,
        ),
      );
    } else if (showLogo && title == null) {
      // Logo only
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          const SizedBox(width: 12),
          Text(
            'MERGE FITNESS',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppStyles.slateGray
                  : AppStyles.textLight,
              fontWeight: FontWeight.w500,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    } else if (showLogo && title != null) {
      // Logo and text
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          const SizedBox(width: 12),
          Text(
            title!,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppStyles.slateGray
                  : AppStyles.textLight,
              fontWeight: FontWeight.w500,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }
    
    // Default: just logo with MERGE FITNESS text
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(width: 12),
        Text(
          'MERGE FITNESS',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? AppStyles.slateGray
                : AppStyles.textLight,
            fontWeight: FontWeight.w500,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Image.asset(
        'assets/images/mergelogo.png',
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(bottom != null 
      ? kToolbarHeight + bottom!.preferredSize.height 
      : kToolbarHeight);
} 