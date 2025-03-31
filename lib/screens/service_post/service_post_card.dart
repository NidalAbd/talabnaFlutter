import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/other_users/user_profile_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/service_post/service_post_view.dart';
import 'package:talabna/screens/widgets/user_avatar.dart';
import 'package:talabna/utils/premium_badge.dart';
import '../../blocs/font_size/font_size_bloc.dart';
import '../../blocs/font_size/font_size_state.dart';
import '../../provider/language.dart';
import '../../utils/photo_image_helper.dart';
import '../reel/reels_screen.dart';
import '../widgets/image_grid.dart';
import 'auto_direction_text.dart';

class ServicePostCard extends StatefulWidget {
  const ServicePostCard({
    super.key,
    this.onPostDeleted,
    required this.servicePost,
    required this.canViewProfile,
    required this.userProfileId,
    required this.user,
  });

  final ServicePost servicePost;
  final Function? onPostDeleted;
  final bool canViewProfile;
  final int userProfileId;
  final User user;

  @override
  State<ServicePostCard> createState() => _ServicePostCardState();
}

class _ServicePostCardState extends State<ServicePostCard> with SingleTickerProviderStateMixin {
  late ServicePostBloc _servicePostBloc;
  late OtherUserProfileBloc _userProfileBloc;
  bool _isExpanded = false;
  bool _dataSaverEnabled = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Language language = Language();

  @override
  void initState() {
    super.initState();
    _servicePostBloc = BlocProvider.of<ServicePostBloc>(context);
    _userProfileBloc = BlocProvider.of<OtherUserProfileBloc>(context);
    _checkDataSaverMode();

    // Animation setup with smoother timing
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkDataSaverMode() {
    final state = _servicePostBloc.state;
    if (state is ServicePostLoadSuccess) {
      setState(() {
        _dataSaverEnabled = state.dataSaverEnabled ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isArabic = language.getLanguage() == 'ar';
    final theme = Theme.of(context);

    return BlocListener<ServicePostBloc, ServicePostState>(
      listener: (context, state) {
        if (state is ServicePostLoadSuccess) {
          if ((state.dataSaverEnabled ?? false) != _dataSaverEnabled) {
            setState(() {
              _dataSaverEnabled = state.dataSaverEnabled ?? false;
            });
          }
        }
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          color: isDarkMode
              ? Colors.grey.shade800.withOpacity(0.5)
              : Color(0xFFF8F8F8),
          elevation: 5,
          shadowColor: isDarkMode
              ? Colors.black38
              : theme.colorScheme.primary.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.grey.shade800.withOpacity(0.5)
                  : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
          child: InkWell(
            onTap: () => _navigateToPostDetails(context),
            borderRadius: BorderRadius.circular(16),
            splashColor: theme.primaryColor.withOpacity(0.1),
            highlightColor: theme.primaryColor.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDarkMode, isArabic),
                if (widget.servicePost.description != null &&
                    widget.servicePost.description!.isNotEmpty)
                  _buildDescription(isDarkMode, isArabic),
                if (!_dataSaverEnabled && widget.servicePost.photos != null &&
                    widget.servicePost.photos!.isNotEmpty)
                  _buildMedia(),
                _buildFooter(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      height: 16, // Slightly smaller
      width: 1,
      color: color,
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? iconColor,
    required bool isDarkMode,
  }) {
    final theme = Theme.of(context);
    final textColor = isDarkMode
        ? Colors.grey.shade300
        : Colors.grey.shade700;
    final defaultIconColor = isDarkMode
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor ?? defaultIconColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPostDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ServicePostCardView(
              key: Key('servicePost_${widget.servicePost.id}'),
              onPostDeleted: widget.onPostDeleted ?? (_) {},
              userProfileId: widget.userProfileId,
              servicePost: widget.servicePost,
              canViewProfile: widget.canViewProfile,
              user: widget.user,
            ),
      ),
    );
  }

  String _formatTimeDifference(DateTime? date) {
    if (date == null) return 'Unknown time';
    Duration difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  String formatNumber(int number) {
    if (number >= 1000000000) {
      final double formattedNumber = number / 1000000000;
      const String suffix = 'B';
      return '${formattedNumber.toStringAsFixed(1)}$suffix';
    } else if (number >= 1000000) {
      final double formattedNumber = number / 1000000;
      const String suffix = 'M';
      return '${formattedNumber.toStringAsFixed(1)}$suffix';
    } else if (number >= 1000) {
      final double formattedNumber = number / 1000;
      const String suffix = 'K';
      return '${formattedNumber.toStringAsFixed(1)}$suffix';
    } else {
      return number.toString();
    }
  }

  Widget _buildTitleBadge(bool isDarkMode) {
    final isRequest = widget.servicePost.type == 'طلب';
    final isArabic = language.getLanguage() == 'ar';

    final Color badgeColor = isRequest
        ? Colors.orangeAccent
        : Colors.greenAccent;

    final Color textColor = Colors.black87;

    // Show only the current language text based on app language setting
    final String badgeText = isRequest
        ? (isArabic ? 'طلب' : 'Request')
        : (isArabic ? 'عرض' : 'Offer');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRequest ? Icons.campaign_rounded : Icons.volunteer_activism_rounded,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildHeader(bool isDarkMode, bool isAppArabic) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User avatar with enhanced shadow
          Hero(
            tag: 'avatar_${widget.servicePost.userId}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: UserAvatar(
                imageUrl: ProfileImageHelper.getProfileImageUrl(
                  widget.servicePost.userPhoto,
                ),
                radius: 20, // Slightly larger
                fromUser: widget.userProfileId,
                toUser: widget.servicePost.userId!,
                canViewProfile: widget.canViewProfile,
                user: widget.user,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username and badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: AutoDirectionText(
                        text: widget.servicePost.userName ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (widget.servicePost.haveBadge != 'عادي')
                      PremiumBadge(
                        badgeType: widget.servicePost.haveBadge ?? 'عادي',
                        size: 22,
                        userID: widget.userProfileId,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Time and location info
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: theme.colorScheme.secondary.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeDifference(widget.servicePost.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    if (widget.servicePost.distance != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: theme.colorScheme.secondary.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.servicePost.distance!.clamp(0, 999).toInt()} km",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                    // Add post type badge (request/offer)

                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(bool isDarkMode, bool isArabic) {
    final theme = Theme.of(context);
    // Get font size from bloc
    final fontSizeState = context.watch<FontSizeBloc>().state;
    final descriptionFontSize = fontSizeState is FontSizeLoaded
        ? fontSizeState.descriptionFontSize
        : 14.0; // slightly larger fallback for better readability

    // Adjust max lines based on data saver mode
    final maxLinesWhenCollapsed = _dataSaverEnabled ? 6 : 4; // Show one more line
    final hasLongText = widget.servicePost.description != null &&
        widget.servicePost.description!.split('\n').length >
            maxLinesWhenCollapsed;
    final accent = theme.colorScheme.primary;

    // Detect if description is primarily Arabic
    final isDescriptionArabic = widget.servicePost.description != null &&
        widget.servicePost.description!.isNotEmpty &&
        isArabicText(widget.servicePost.description!);

    return Column(
      crossAxisAlignment: isDescriptionArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Title row with enhanced styling
        if (widget.servicePost.title != null && widget.servicePost.title!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Expanded(
                  child: Text(
                    widget.servicePost.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16, // Slightly larger title
                      color: isDarkMode ? theme.colorScheme.onSurface : theme.colorScheme.onSurface,
                      letterSpacing: isDescriptionArabic ? 0 : -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isDescriptionArabic ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
            ),
          ),

        // Description text with enhanced styling
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Directionality(
            textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Text(
              widget.servicePost.description ?? "",
              maxLines: _isExpanded ? 100 : maxLinesWhenCollapsed,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: descriptionFontSize,
                color: isDarkMode
                    ? theme.colorScheme.onSurface.withOpacity(0.9)
                    : theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.4, // Improved line height for readability
                letterSpacing: isDescriptionArabic ? 0 : 0.1,
              ),
              textAlign: isDescriptionArabic ? TextAlign.right : TextAlign.left,
            ),
          ),
        ),

        // Show more/less button with enhanced styling
        if (hasLongText)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Text(
                      _isExpanded ? (isDescriptionArabic ? 'عرض أقل' : 'Show less') :
                      (isDescriptionArabic ? 'عرض المزيد' : 'Show more'),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Tags row with improved styling
        _buildTagsRow(isDarkMode, isDescriptionArabic),
      ],
    );
  }

  Widget _buildTagsRow(bool isDarkMode, bool isDescriptionArabic) {
    // Get the appropriate language based on app settings
    final isArabic = language.getLanguage() == 'ar';

    // Text style for tags
    final tagTextStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
    );

    // Container style for tags
    final tagDecoration = BoxDecoration(
      color: isDarkMode ? Colors.grey.shade800.withOpacity(0.3) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
        width: 0.5,
      ),
    );

    // Build a list of available tags
    List<Widget> tags = [];

    // Subcategory
    if (widget.servicePost.subCategory != null) {
      final subcategoryName = widget.servicePost.subCategory!.name[isArabic ? 'ar' : 'en'] ??
          widget.servicePost.subCategory!.name['en'] ?? 'Unknown';

      tags.add(_buildTag(
        label: subcategoryName,
        decoration: tagDecoration,
        style: tagTextStyle,
      ));
    }
    if (widget.servicePost.type != null && widget.servicePost.type!.isNotEmpty) {
      final String typeText = isArabic
          ? (widget.servicePost.type == 'طلب' ? 'طلب' : 'عرض')
          : (widget.servicePost.type == 'طلب' ? 'Request' : 'Offer');

      tags.add(_buildTag(
        label: typeText,
        decoration: tagDecoration,
        style: tagTextStyle,
      ));
    }
    if (widget.servicePost.price != null) {
      tags.add(_buildTag(
        label: "${widget.servicePost.price} ${widget.servicePost.priceCurrencyCode}",
        decoration: tagDecoration,
        style: tagTextStyle,
      ));
    }
    // Return a horizontal scrollable row of tags
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            for (int i = 0; i < tags.length; i++) ...[
              tags[i],
              if (i < tags.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

// Helper method to build an individual tag
  Widget _buildTag({
    required String label,
    required BoxDecoration decoration,
    required TextStyle style,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: style,
          ),
        ],
      ),
    );
  }

  bool isArabicText(String text) {
    if (text.isEmpty) return false;

    // Check the first few non-whitespace characters
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Arabic Unicode block ranges from 0x0600 to 0x06FF
    final firstChar = trimmed.codeUnitAt(0);
    return firstChar >= 0x0600 && firstChar <= 0x06FF;
  }

  Widget _buildMedia() {
    if (widget.servicePost.photos == null ||
        widget.servicePost.photos!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Enhanced styling for media display
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Hero(
        tag: 'list_photo_${widget.servicePost.id}',
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          child: ImageGrid(
            imageUrls: widget.servicePost.photos!
                .map((photo) => '${photo.src}')
                .toList() ?? [],
            uniqueId: 'post_${widget.servicePost.id}',
            maxHeight: 320, // Adjusted height for better proportion
            onVideoReelsTap: _openVideoInReels,
          ),
        ),
      ),
    );
  }

  // Method to handle opening videos in reels mode
  void _openVideoInReels(String videoUrl) {
    // Extract post ID from the current post
    final postId = widget.servicePost.id.toString();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReelsHomeScreen(
          userId: widget.userProfileId,
          user: widget.user,
          postId: postId,
          servicePost: widget.servicePost,
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDarkMode) {
    final theme = Theme.of(context);
    final dividerColor = isDarkMode
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    // Enhanced background for better visual separation
    final backgroundColor = isDarkMode
        ? theme.cardColor.withOpacity(0.5)
        : Color(0xFFE1E1E1);

    // Always show the interaction row with improved styling
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: dividerColor,
            width: 0.5,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInteractionButton(
            icon: Icons.remove_red_eye_outlined,
            label: formatNumber(widget.servicePost.viewCount ?? 0),
            isDarkMode: isDarkMode,
          ),
          _buildDivider(dividerColor),
          _buildInteractionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: formatNumber(widget.servicePost.commentsCount ?? 0),
            isDarkMode: isDarkMode,
          ),
          _buildDivider(dividerColor),
          _buildInteractionButton(
            icon: Icons.favorite_border_rounded,
            label: formatNumber(widget.servicePost.favoritesCount ?? 0),
            iconColor: widget.servicePost.isFavorited == true
                ? Colors.redAccent
                : null,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}