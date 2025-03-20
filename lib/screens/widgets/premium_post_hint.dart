import 'package:flutter/material.dart';

import '../../provider/language.dart';
import '../../utils/premium_badge.dart';

class PremiumPostHint extends StatelessWidget {
  final String selectedBadgeType;
  final int userID;
  final Language language = Language();

  PremiumPostHint({
    super.key,
    required this.selectedBadgeType,
    required this.userID,
  });

  @override
  Widget build(BuildContext context) {
    // Only show for premium badge types
    if (selectedBadgeType == 'عادي') {
      return const SizedBox.shrink();
    }

    final isArabic = language.getLanguage() == 'ar';
    final isPremiumGold = selectedBadgeType == 'ذهبي';
    final isPremiumDiamond = selectedBadgeType == 'ماسي';

    // Text content based on language and badge type
    final String hintTitle = isArabic
        ? 'كيف سيظهر منشورك المميز'
        : 'How your premium post will appear';

    final String badgeTypeText = isArabic
        ? (isPremiumGold ? 'ذهبي' : 'ماسي')
        : (isPremiumGold ? 'Golden' : 'Diamond');

    final String hintDescription = isArabic
        ? 'سيظهر منشورك بشارة $badgeTypeText مميزة كما هو موضح أدناه، مما يزيد من ظهوره ويجذب المزيد من المشاهدات.'
        : 'Your post will be displayed with a premium $badgeTypeText badge as shown below, increasing its visibility and attracting more views.';

    // Theme colors
    final Color primaryColor = isPremiumGold
        ? const Color(0xFFFFD700) // Gold
        : const Color(0xFF00CCFF); // Diamond blue

    final Color secondaryColor = isPremiumGold
        ? const Color(0xFFFF9D00) // Deep gold
        : const Color(0xFF0088FF); // Deep blue

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.05),
            primaryColor.withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPremiumGold ? Icons.stars_rounded : Icons.diamond_rounded,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hintTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              hintDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.start,
            ),
          ),

          // Preview of how it will look
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post preview header
                Row(
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'اسم المستخدم' : 'Username',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    // Import and use the actual PremiumBadge widget
                    PremiumBadge(
                      badgeType: selectedBadgeType,
                      userID: userID,
                      size: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Post title placeholder
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                const SizedBox(height: 8),

                // Post content placeholder
                Column(
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: double.infinity,
                      height: 10,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Benefit callout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 20,
                  color: secondaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'المنشورات المميزة تحصل على مشاهدات أكثر بنسبة 5x!'
                        : 'Premium posts get 5x more views!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
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
