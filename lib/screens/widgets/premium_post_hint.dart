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

    // Theme detection
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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

    // Theme-adaptive colors
    final Color primaryColor = isPremiumGold
        ? const Color(0xFFF86800) // Gold
        : const Color(0xFF00CCFF); // Diamond blue

    final Color secondaryColor = isPremiumGold
        ? const Color(0xFFFF9D00) // Deep gold
        : const Color(0xFF0088FF); // Deep blue

    // Ensuring good contrast in both modes
    final Color textPrimaryColor = isDarkMode
        ? primaryColor
        : isPremiumGold ? const Color(0xFFFFAF00) : const Color(0xFF0066CC);

    final Color backgroundColor = isDarkMode
        ? Theme.of(context).cardColor.withOpacity(0.2)
        : primaryColor.withOpacity(0.1);

    final Color borderColor = isDarkMode
        ? primaryColor.withOpacity(0.5)
        : primaryColor.withOpacity(0.3);

    final Color textSecondaryColor = isDarkMode
        ? Colors.grey[300]!
        : Colors.grey[800]!;

    // Background colors
    final Color containerBgColor = isDarkMode
        ? Theme.of(context).cardColor.withOpacity(0.2)
        : Colors.white;

    final Color headerBgColor = isDarkMode
        ? primaryColor.withOpacity(0.15)
        : primaryColor.withOpacity(0.1);

    final Color previewBgColor = isDarkMode
        ? Theme.of(context).cardColor
        : Colors.white;

    final Color placeholderColor = isDarkMode
        ? Colors.grey[700]!
        : Colors.grey[200]!;

    return Card(
      elevation: isDarkMode ? 2 : 1,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: primaryColor.withOpacity(isDarkMode ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: containerBgColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: headerBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPremiumGold ? Icons.stars_rounded : Icons.diamond_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hintTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
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
                  color: textSecondaryColor,
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
                color: previewBgColor,
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 6,
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
                      // User avatar with Material Design elevation
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: isDarkMode ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: isDarkMode
                              ? Colors.grey[700]
                              : Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isArabic ? 'اسم المستخدم' : 'Username',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.grey[200]
                              : Colors.grey[800],
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

                  const SizedBox(height: 12),

                  // Post title placeholder - more rounded for Material Design 3
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Post content placeholder
                  Column(
                    children: List.generate(
                      3,
                          (index) => Container(
                        width: double.infinity,
                        height: 10,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Benefit callout with Material chip design
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDarkMode
                    ? primaryColor.withOpacity(0.15)
                    : primaryColor.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility,
                    size: 18,
                    color: textPrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'المنشورات المميزة تحصل على مشاهدات أكثر بنسبة 5x!'
                          : 'Premium posts get 5x more views!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}