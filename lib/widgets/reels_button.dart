import 'package:flutter/material.dart';
import 'package:talabna/data/models/category_menu.dart';
import 'package:talabna/data/models/user.dart';

/// A customized button for reels category navigation
class ReelsButton extends StatelessWidget {
  final CategoryMenu reelsCategory;
  final User user;
  final Color primaryColor;
  final VoidCallback onTap;

  const ReelsButton({
    Key? key,
    required this.reelsCategory,
    required this.user,
    required this.primaryColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        width: 40,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
