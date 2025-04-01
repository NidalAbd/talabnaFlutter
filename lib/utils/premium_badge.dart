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
    this.size = 40,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color primaryColor = isPremiumGold
        ? const Color(0xFFF86800) // Gold
        : const Color(0xFF00CCFF); // Diamond blue

    final Color secondaryColor = isPremiumGold
        ? const Color(0xFFFF9D00) // Deep gold
        : const Color(0xFF0088FF); // Deep blue

    final Color textColor = isDarkMode
        ? primaryColor
        : isPremiumGold ? const Color(0xFFFFAF00) : const Color(0xFF0066CC);

    final Color backgroundColor = isDarkMode
        ? Theme.of(context).cardColor.withOpacity(0.2)
        : primaryColor.withOpacity(0.1);

    final TextStyle badgeTextStyle = TextStyle(
      color: textColor,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      letterSpacing: 0.5,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToPurchase(context),
        borderRadius: BorderRadius.circular(16),
        splashColor: primaryColor.withOpacity(0.2),
        highlightColor: primaryColor.withOpacity(0.1),
        child: AnimatedBadgeBorder(
          badgeType: badgeType,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          backgroundColor: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              _getLocalizedBadgeText(),
              style: badgeTextStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedBadgeBorder extends StatefulWidget {
  final Widget child;
  final String badgeType;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const AnimatedBadgeBorder({
    Key? key,
    required this.child,
    required this.badgeType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  State<AnimatedBadgeBorder> createState() => _AnimatedBadgeBorderState();
}

class _AnimatedBadgeBorderState extends State<AnimatedBadgeBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Very slow animation for elegant movement
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Start from a specific position and loop continuously
    _controller.forward(from: 0.0);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.forward(from: 0.0); // Restart from the beginning
      }
    });
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
        return CustomPaint(
          painter: AnimatedBorderPainter(
            progress: _controller.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            badgeType: widget.badgeType,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class AnimatedBorderPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final String badgeType;

  AnimatedBorderPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.badgeType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isPremiumGold = badgeType == 'ذهبي';

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Draw border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = primaryColor.withOpacity(0.6);

    canvas.drawRRect(rrect, borderPaint);

    // Calculate positions for particles
    final position1 = _getPositionOnBorder(size.width, size.height, 16, progress);

    // Draw main particle
    _drawParticle(canvas, position1.x, position1.y, primaryColor, secondaryColor, isPremiumGold);

    // If it's a diamond badge, add a second particle at a different position
    if (!isPremiumGold) {
      final position2 = _getPositionOnBorder(size.width, size.height, 16, (progress + 0.5) % 1.0);
      _drawParticle(canvas, position2.x, position2.y, primaryColor, secondaryColor, isPremiumGold);
    }
  }

  void _drawParticle(Canvas canvas, double x, double y, Color color, Color secondColor, bool isGold) {
    // Main particle
    final particlePaint = Paint()
      ..color = isGold ? secondColor : color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 2.8, particlePaint);

    // Glowing effect
    final glowPaint = Paint()
      ..color = isGold ? secondColor.withOpacity(0.4) : color.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    canvas.drawCircle(Offset(x, y), 4.5, glowPaint);

    // Trail effect - draw multiple smaller circles behind main particle
    final trailLength = isGold ? 0.03 : 0.04;
    final trailSegments = 5;

    for (int i = 1; i <= trailSegments; i++) {
      // Calculate position for this trail segment
      final trailProgress = (progress - (i * trailLength / trailSegments));
      if (trailProgress < 0) continue; // Skip if it would wrap around

      final trailPos = _getPositionOnBorder(
          lastSize.width,
          lastSize.height,
          16,
          trailProgress % 1.0
      );

      final trailOpacity = (1 - (i / trailSegments)) * 0.4;
      final trailSize = 2.5 * (1 - (i / trailSegments));

      final trailPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isGold ?
        secondColor.withOpacity(trailOpacity) :
        color.withOpacity(trailOpacity);

      canvas.drawCircle(Offset(trailPos.x, trailPos.y), trailSize, trailPaint);
    }
  }

  // Keep track of the last size to ensure consistent trail calculations
  Size lastSize = Size.zero;

  Point _getPositionOnBorder(double width, double height, double radius, double progress) {
    // Save the size for trail calculations
    lastSize = Size(width, height);

    // Calculate the perimeter of the rounded rectangle
    final double straightHorizontal = width - 2 * radius;
    final double straightVertical = height - 2 * radius;
    final double cornerArc = math.pi * radius / 2;

    // Total perimeter
    final double perimeter = 2 * straightHorizontal +
        2 * straightVertical +
        4 * cornerArc;

    // Distance along the perimeter based on progress
    double distance = perimeter * progress;

    // ===== TOP EDGE (left to right) =====
    if (distance <= straightHorizontal) {
      return Point(radius + distance, 0);
    }
    distance -= straightHorizontal;

    // ===== TOP-RIGHT CORNER =====
    if (distance <= cornerArc) {
      final angle = distance / radius;
      return Point(
          width - radius + math.sin(angle) * radius,
          radius - math.cos(angle) * radius
      );
    }
    distance -= cornerArc;

    // ===== RIGHT EDGE (top to bottom) =====
    if (distance <= straightVertical) {
      return Point(width, radius + distance);
    }
    distance -= straightVertical;

    // ===== BOTTOM-RIGHT CORNER =====
    if (distance <= cornerArc) {
      final angle = distance / radius;
      return Point(
          width - radius + math.cos(angle) * radius,
          height - radius + math.sin(angle) * radius
      );
    }
    distance -= cornerArc;

    // ===== BOTTOM EDGE (right to left) =====
    if (distance <= straightHorizontal) {
      return Point(width - radius - distance, height);
    }
    distance -= straightHorizontal;

    // ===== BOTTOM-LEFT CORNER =====
    if (distance <= cornerArc) {
      final angle = distance / radius;
      return Point(
          radius - math.sin(angle) * radius,
          height - radius + math.cos(angle) * radius
      );
    }
    distance -= cornerArc;

    // ===== LEFT EDGE (bottom to top) =====
    if (distance <= straightVertical) {
      return Point(0, height - radius - distance);
    }
    distance -= straightVertical;

    // ===== TOP-LEFT CORNER =====
    final angle = distance / radius;
    return Point(
        radius - math.cos(angle) * radius,
        radius - math.sin(angle) * radius
    );
  }

  @override
  bool shouldRepaint(covariant AnimatedBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);
}