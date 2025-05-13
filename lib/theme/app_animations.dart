import 'package:flutter/material.dart';
import 'app_styles.dart';

/// A collection of reusable animations for the app
class AppAnimations {
  // Prevent instantiation
  AppAnimations._();
  
  /// Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
    double beginOpacity = 0.0,
    double endOpacity = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginOpacity, end: endOpacity),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Slide in animation
  static Widget slideIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOutCubic,
    Offset beginOffset = const Offset(0, 0.1),
    Offset endOffset = Offset.zero,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: beginOffset, end: endOffset),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return FractionalTranslation(
          translation: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Scale animation
  static Widget scale({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
    double beginScale = 0.95,
    double endScale = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginScale, end: endScale),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Combined fade and slide animation
  static Widget fadeSlide({
    required Widget child,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
    Offset beginOffset = const Offset(0, 0.1),
    double beginOpacity = 0.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: beginOpacity + (1 - beginOpacity) * value,
          child: FractionalTranslation(
            translation: Offset(
              beginOffset.dx * (1 - value),
              beginOffset.dy * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  /// Staggered list animation
  static List<Widget> staggeredList({
    required List<Widget> children,
    Duration initialDelay = Duration.zero,
    Duration staggerDuration = const Duration(milliseconds: 50),
    Duration itemAnimationDuration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutQuint,
    Offset beginOffset = const Offset(0, 0.1),
    double beginOpacity = 0.0,
  }) {
    final animatedWidgets = <Widget>[];
    
    for (int i = 0; i < children.length; i++) {
      final itemDelay = initialDelay + (staggerDuration * i);
      
      animatedWidgets.add(
        AnimatedBuilder(
          animation: AlwaysStoppedAnimation(0), // Dummy animation
          builder: (context, _) {
            return FutureBuilder(
              future: Future.delayed(itemDelay),
              builder: (context, snapshot) {
                final hasCompleted = snapshot.connectionState == ConnectionState.done;
                
                return fadeSlide(
                  beginOffset: beginOffset,
                  beginOpacity: beginOpacity,
                  duration: itemAnimationDuration,
                  curve: curve,
                  child: hasCompleted ? children[i] : SizedBox(
                    height: (children[i] as Widget).key != null ? null : 0,
                    child: hasCompleted ? children[i] : null,
                  ),
                );
              },
            );
          },
        ),
      );
    }
    
    return animatedWidgets;
  }
  
  /// Pulse animation
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    double minScale = 0.97,
    double maxScale = 1.03,
  }) {
    return _PulseAnimationWidget(
      child: child,
      duration: duration,
      minScale: minScale,
      maxScale: maxScale,
    );
  }
  
  /// Shimmer loading effect
  static Widget shimmerLoading({
    required Widget child,
    Color baseColor = const Color(0xFF2C2C2C),
    Color highlightColor = const Color(0xFF3D3D3D),
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return _ShimmerLoadingWidget(
      child: child,
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: duration,
    );
  }
}

/// Pulse animation widget
class _PulseAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  
  const _PulseAnimationWidget({
    required this.child,
    required this.duration,
    required this.minScale,
    required this.maxScale,
  });
  
  @override
  State<_PulseAnimationWidget> createState() => _PulseAnimationWidgetState();
}

class _PulseAnimationWidgetState extends State<_PulseAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(
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
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmer loading effect widget
class _ShimmerLoadingWidget extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;
  
  const _ShimmerLoadingWidget({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    required this.duration,
  });
  
  @override
  State<_ShimmerLoadingWidget> createState() => _ShimmerLoadingWidgetState();
}

class _ShimmerLoadingWidgetState extends State<_ShimmerLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
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
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.3, 0.5, 0.7],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Gradient transform helper for shimmer effect
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  
  const _SlidingGradientTransform({required this.slidePercent});
  
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
} 