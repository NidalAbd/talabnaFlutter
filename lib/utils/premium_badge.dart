import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../provider/language.dart';
import '../screens/profile/purchase_request_screen.dart';

class PremiumBadge extends StatelessWidget {
  final String badgeType;
  final double size;
  final bool showText;
  final double fontSize;
  final int userID;

  PremiumBadge({
    super.key,
    required this.badgeType,
    this.size = 20,
    this.showText = true,
    this.fontSize = 14,
    required this.userID,
  });

  final Language _language = Language();

  String _getLocalizedBadgeText() {
    final bool isArabic = _language.getLanguage() == 'ar';

    if (badgeType == 'ذهبي') {
      return isArabic ? 'ذهبي' : 'Golden';
    } else if (badgeType == 'ماسي') {
      return isArabic ? 'ماسي' : 'Diamond';
    } else {
      return badgeType;
    }
  }

  void _navigateToPurchase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseRequestScreen(
          userID: userID,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (badgeType == 'عادي') {
      return const SizedBox.shrink();
    }

    final isPremiumGold = badgeType == 'ذهبي';
    final isPremiumDiamond = badgeType == 'ماسي';

    // Enhanced color palette
    final Color primaryColor = isPremiumGold
        ? const Color(0xFFFFD700) // Gold
        : const Color(0xFF00CCFF); // Diamond blue

    final Color secondaryColor = isPremiumGold
        ? const Color(0xFFFF9D00) // Deep gold
        : const Color(0xFF0088FF); // Deep blue

    final Color glowColor = isPremiumGold
        ? const Color(0xFFFFF0B3).withOpacity(0.7) // Light gold glow
        : const Color(0xFFB3F0FF).withOpacity(0.7); // Light blue glow

    final TextStyle badgeTextStyle = TextStyle(
      color: primaryColor,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      letterSpacing: 0.5,
      shadows: [
        Shadow(
          color: secondaryColor.withOpacity(0.8),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToPurchase(context),
        borderRadius: BorderRadius.circular(30),
        splashColor: glowColor.withOpacity(0.3),
        highlightColor: glowColor.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showText) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.1),
                        primaryColor.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getLocalizedBadgeText(),
                    style: badgeTextStyle,
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Enhanced badge icon
              AnimatedPremiumIcon(
                isPremiumGold: isPremiumGold,
                size: size,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                glowColor: glowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedPremiumIcon extends StatefulWidget {
  final bool isPremiumGold;
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;

  const AnimatedPremiumIcon({
    Key? key,
    required this.isPremiumGold,
    required this.size,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
  }) : super(key: key);

  @override
  State<AnimatedPremiumIcon> createState() => _AnimatedPremiumIconState();
}

class _AnimatedPremiumIconState extends State<AnimatedPremiumIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
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
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: Container(
            height: widget.size * 1.5,
            width: widget.size * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: widget.size * 1.2,
                  height: widget.size * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor
                            .withOpacity(_opacityAnimation.value * 0.8),
                        blurRadius: widget.size / 2,
                        spreadRadius: widget.size / 8,
                      ),
                    ],
                  ),
                ),

                // Animated background
                Opacity(
                  opacity: _opacityAnimation.value * 0.7,
                  child: Container(
                    width: widget.size * 1.1,
                    height: widget.size * 1.1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.primaryColor.withOpacity(0.7),
                          widget.secondaryColor.withOpacity(0.1),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Icon with scale animation
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Base icon
                        Icon(
                          widget.isPremiumGold
                              ? Icons.stars_rounded
                              : Icons.diamond_rounded,
                          color: widget.primaryColor,
                          size: widget.size,
                        ),

                        // Shine overlay
                        ClipOval(
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.8),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            blendMode: BlendMode.srcATop,
                            child: Container(
                              color: Colors.white.withOpacity(0.3),
                              height: widget.size,
                              width: widget.size,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Particle effects
                if (widget.isPremiumGold)
                  ...List.generate(5, (index) {
                    final angle = index * (math.pi * 2 / 5);
                    final distance = widget.size * 0.7 * _scaleAnimation.value;
                    final offset = Offset(
                      math.cos(angle + _controller.value * math.pi) * distance,
                      math.sin(angle + _controller.value * math.pi) * distance,
                    );

                    return Positioned(
                      left: widget.size * 0.75 + offset.dx,
                      top: widget.size * 0.75 + offset.dy,
                      child: Opacity(
                        opacity: _opacityAnimation.value * 0.4,
                        child: Container(
                          width: widget.size * 0.1,
                          height: widget.size * 0.1,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.primaryColor,
                          ),
                        ),
                      ),
                    );
                  })
                else
                  ...List.generate(3, (index) {
                    final angle = index * (math.pi * 2 / 3);
                    final distance =
                        widget.size * 0.6 * _opacityAnimation.value;
                    final offset = Offset(
                      math.cos(angle + _controller.value * math.pi * 2) *
                          distance,
                      math.sin(angle + _controller.value * math.pi * 2) *
                          distance,
                    );

                    return Positioned(
                      left: widget.size * 0.75 + offset.dx,
                      top: widget.size * 0.75 + offset.dy,
                      child: Transform.rotate(
                        angle: _controller.value * math.pi,
                        child: Opacity(
                          opacity: 0.6 - (_controller.value * 0.3),
                          child: Icon(
                            Icons.star,
                            color: widget.primaryColor,
                            size: widget.size * 0.2,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
