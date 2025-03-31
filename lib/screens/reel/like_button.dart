import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../app_theme.dart';

class LikeButton extends StatefulWidget {
  final bool isFavorite;
  final int favoritesCount;
  final Future<bool> Function() onToggleFavorite;
  final double iconSize;
  final double textSize; // Added custom text size parameter
  final Color likedColor;
  final Color? unlikedColor;
  final bool showBurstEffect;
  final bool showCountOnRight;
  final bool showCount;
  final String countText;
  final bool showCountText;
  final Duration debounceTimeout;
  final double buttonWidth; // Added custom button width
  final double buttonHeight; // Added custom button height

  const LikeButton({
    super.key,
    required this.isFavorite,
    required this.favoritesCount,
    required this.onToggleFavorite,
    required this.iconSize,
    this.textSize = 15, // Default text size
    this.likedColor = Colors.red,
    this.unlikedColor,
    this.showBurstEffect = true,
    this.showCountOnRight = false,
    this.showCount = true,
    this.countText = 'likes',
    this.showCountText = false,
    this.debounceTimeout = const Duration(milliseconds: 500),
    this.buttonWidth = 0, // 0 means auto-size
    this.buttonHeight = 0, // 0 means auto-size
  });

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;
  late bool _isFavorite;
  late int _favoritesCount;
  bool _isProcessing = false;
  DateTime? _lastToggleTime;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _favoritesCount = widget.favoritesCount;

    // Create animation controller with better curve for mobile
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale animation - smoother bounce effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_animationController);

    // Burst animation - separate timing for particles
    _burstAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutQuart),
      ),
    );

    // If initially favorited, set animation to end state
    if (_isFavorite) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle external state changes
    if (oldWidget.isFavorite != widget.isFavorite) {
      debugPrint('🔄 LikeButton: External update - isFavorite changed from ${oldWidget.isFavorite} to ${widget.isFavorite}');

      setState(() {
        _isFavorite = widget.isFavorite;
      });

      // Only animate if the widget caused the change
      if (!_isProcessing) {
        if (_isFavorite) {
          _animationController.forward(from: 0.0);
          debugPrint('▶️ LikeButton: External animation - forward');
        } else {
          _animationController.reverse(from: 1.0);
          debugPrint('◀️ LikeButton: External animation - reverse');
        }
      }
    }

    if (oldWidget.favoritesCount != widget.favoritesCount) {
      debugPrint('🔄 LikeButton: External update - count changed from ${oldWidget.favoritesCount} to ${widget.favoritesCount}');

      setState(() {
        _favoritesCount = widget.favoritesCount;
      });
    }
  }

  Future<void> _handleLikeToggle() async {
    // Prevent rapid toggling by implementing debounce
    final now = DateTime.now();
    if (_isProcessing ||
        (_lastToggleTime != null &&
            now.difference(_lastToggleTime!) < widget.debounceTimeout)) {
      return;
    }

    _lastToggleTime = now;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Save the current state before toggling
      final wasLiked = _isFavorite;

      // Optimistically update UI immediately for better responsiveness
      setState(() {
        _isFavorite = !wasLiked;
        _favoritesCount += _isFavorite ? 1 : -1;
      });

      // Animate based on new state
      if (_isFavorite) {
        _animationController.forward(from: 0.0);
      } else {
        _animationController.reverse(from: 1.0);
      }

      // Call the toggle favorite function provided by the parent
      // This returns the NEW state, not a success/failure indicator
      final newState = await widget.onToggleFavorite();

      // Update to match the server state
      if (_isFavorite != newState) {
        // Server returned a different state than we expected
        setState(() {
          // Update favorite state to match server
          _isFavorite = newState;
          // Adjust count based on the new state
          _favoritesCount = widget.favoritesCount;

          // Update animation to match
          if (_isFavorite) {
            _animationController.forward(from: 0.0);
          } else {
            _animationController.reverse(from: 1.0);
          }
        });
      }
    } catch (e) {
      // Log the error
      debugPrint('Like toggle failed: $e');

      // In case of error, revert to the original state from widget props
      setState(() {
        _isFavorite = widget.isFavorite;
        _favoritesCount = widget.favoritesCount;
      });
    } finally {
      // Add a small delay before allowing another toggle
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  // Heart icon builder with animation
  Widget _buildHeartIcon(Color unlikedColor) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: widget.iconSize * 1.2,
          height: widget.iconSize * 1.2,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Particle/burst effect
              if (widget.showBurstEffect && _isFavorite)
                CustomPaint(
                  size: Size(widget.iconSize * 1.5, widget.iconSize * 1.5),
                  painter: HeartBurstPainter(
                    progress: _burstAnimation.value,
                    color: widget.likedColor,
                  ),
                ),

              // Scaled heart icon with smoother transitions
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: widget.iconSize,
                  color: _isFavorite ? widget.likedColor : unlikedColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountText(Color unlikedColor) {
    if (!widget.showCount) return const SizedBox.shrink();

    final countString = _formatCount(_favoritesCount);

    // Combine count and text if showCountText is true
    final displayText = widget.showCountText
        ? '$countString ${widget.countText}'
        : countString;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.5),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        displayText,
        key: ValueKey<String>(displayText),
        style: TextStyle(
          color: _isFavorite ? widget.likedColor : unlikedColor,
          fontSize: widget.textSize, // Use the custom text size
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveUnlikedColor = widget.unlikedColor ?? theme.iconTheme.color;

    // Create base content depending on orientation
    Widget content;

    // Horizontal layout (count on right)
    if (widget.showCountOnRight) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeartIcon(effectiveUnlikedColor!),
          const SizedBox(width: 4),
          _buildCountText(effectiveUnlikedColor),
        ],
      );
    } else {
      // Vertical layout (count below)
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeartIcon(effectiveUnlikedColor!),
          const SizedBox(height: 4),
          _buildCountText(effectiveUnlikedColor),
        ],
      );
    }

    // Apply custom sizing if specified
    if (widget.buttonWidth > 0 || widget.buttonHeight > 0) {
      final effectiveWidth = widget.buttonWidth > 0 ? widget.buttonWidth : null;
      final effectiveHeight = widget.buttonHeight > 0 ? widget.buttonHeight : null;

      return GestureDetector(
        onTap: _handleLikeToggle,
        child: Container(
          width: effectiveWidth,
          height: effectiveHeight,
          alignment: Alignment.center,
          child: content,
        ),
      );
    }

    // Default sizing (auto)
    return GestureDetector(
      onTap: _handleLikeToggle,
      child: content,
    );
  }
}

class HeartBurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int particleCount;
  final Random _random = Random();

  HeartBurstPainter({
    required this.progress,
    required this.color,
    this.particleCount = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.5;

    // Create more organic burst effect with varied particles
    for (int i = 0; i < particleCount; i++) {
      // Randomize particle angle
      final angle =
          (i * (360 / particleCount) + _random.nextDouble() * 30) * (pi / 180);

      // Randomize distance from center based on progress
      final distance =
          maxRadius * progress * (0.7 + _random.nextDouble() * 0.3);

      // Calculate position
      final particleX = center.dx + distance * cos(angle);
      final particleY = center.dy + distance * sin(angle);

      // Randomize opacity and size for more organic look
      final opacity = (1.0 - progress) * (0.6 + _random.nextDouble() * 0.4);
      final particleSize =
          (4.0 * (1.0 - progress)) * (0.5 + _random.nextDouble() * 0.5);

      // Create particle
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      // Randomly draw circles or heart-like shapes
      if (_random.nextBool()) {
        canvas.drawCircle(Offset(particleX, particleY), particleSize, paint);
      } else {
        // Draw small rectangle for variety
        canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(particleX, particleY),
                width: particleSize * 2,
                height: particleSize,
              ),
              Radius.circular(particleSize / 2),
            ),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeartBurstPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}