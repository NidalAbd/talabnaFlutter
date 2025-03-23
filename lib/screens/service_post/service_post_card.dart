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
import '../../main.dart';
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

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut)
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
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final shadowColor = isDarkMode ? Colors.black54 : Colors.black12;
    final isArabic = language.getLanguage() == 'ar';

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
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          color: cardColor,
          shadowColor: shadowColor,
          child: InkWell(
            onTap: () => _navigateToPostDetails(context),
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
      height: 20,
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
    final textColor = isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
    final defaultIconColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor ?? defaultIconColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
    return '${difference.inDays}d ago';
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

  Widget _buildHeader(bool isDarkMode, bool isAppArabic) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'avatar_${widget.servicePost.userId}',
            child: UserAvatar(
              imageUrl: ProfileImageHelper.getProfileImageUrl(
                widget.servicePost.userPhoto,
              ),
              radius: 18,
              fromUser: widget.userProfileId,
              toUser: widget.servicePost.userId!,
              canViewProfile: widget.canViewProfile,
              user: widget.user,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: AutoDirectionText(
                        text: widget.servicePost.userName ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.servicePost.haveBadge != 'عادي')
                      const SizedBox(width: 4),
                    if (widget.servicePost.haveBadge != 'عادي')
                      PremiumBadge(
                        badgeType: widget.servicePost.haveBadge ?? 'عادي',
                        size: 14,
                        userID: widget.userProfileId,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 10,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatTimeDifference(widget.servicePost.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    if (widget.servicePost.distance != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 2,
                        height: 2,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.location_on,
                        size: 10,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "${widget.servicePost.distance!.clamp(0, 999).toInt()} km",
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

// Updated _buildDescription method for ServicePostCard
  Widget _buildDescription(bool isDarkMode, bool isAppArabic) {
    // Adjust max lines based on data saver mode
    final maxLinesWhenCollapsed = _dataSaverEnabled ? 6 : 3;
    final hasLongText = widget.servicePost.description != null &&
        widget.servicePost.description!.split('\n').length >
            maxLinesWhenCollapsed;
    final accent = Theme.of(context).primaryColor;

    // Detect if description is primarily Arabic
    final isDescriptionArabic = widget.servicePost.description != null &&
        widget.servicePost.description!.isNotEmpty &&
        isArabicText(widget.servicePost.description!);

    return Column(
      crossAxisAlignment: isDescriptionArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          child: Row(
            textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
            children: [
              if (widget.servicePost.title != null &&
                  widget.servicePost.title!.isNotEmpty) ...[
                Expanded(
                  child: Text(
                    widget.servicePost.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isDescriptionArabic ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
            ],
          ),
        ),
        Directionality(
          textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            child: Text(
              widget.servicePost.description ?? "",
              maxLines: _isExpanded ? 100 : maxLinesWhenCollapsed,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
                height: 1.2,
              ),
              textAlign: isDescriptionArabic ? TextAlign.right : TextAlign.left,
            ),
          ),
        ),
        if (hasLongText)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Text(
                    _isExpanded ? (isDescriptionArabic ? 'عرض أقل' : 'Show less') :
                    (isDescriptionArabic ? 'عرض المزيد' : 'Show more'),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 14,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
        // Add the tags row here
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildTagsRow(isDarkMode, isDescriptionArabic),
        ),
      ],
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
// Updated _buildHeader method for ServicePostCard
  Widget _buildMedia() {
    if (widget.servicePost.photos == null ||
        widget.servicePost.photos!.isEmpty) {
      return const SizedBox.shrink();
    }

    // No extra spacing - directly connect to the content
    return Hero(
      tag: 'photo_${widget.servicePost.id}',
      child: ImageGrid(
        imageUrls: widget.servicePost.photos!
            .map((photo) => '${photo.src}')
            .toList() ?? [],
        uniqueId: 'post_${widget.servicePost.id}',
        maxHeight: 350, // Slightly reduced height
        onVideoReelsTap: _openVideoInReels, // Add reels navigation callback
      ),
    );
  }

  // New method to handle opening videos in reels mode
  void _openVideoInReels(String videoUrl) {
    // Extract post ID from the current post
    final postId = widget.servicePost.id.toString();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ReelsHomeScreen(
              userId: widget.userProfileId,
              user: widget.user,
              postId: postId, // Pass the post ID to open directly in reels
              servicePost: widget.servicePost, // Pass the full post if needed
            ),
      ),
    );
  }

  Widget _buildFooter(bool isDarkMode) {
    final dividerColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    final backgroundColor = isDarkMode
        ? Colors.grey.shade900.withOpacity(0.3)
        : Colors.grey.shade50;

    // Always show the interaction row
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
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 11),
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
            icon: Icons.favorite_border_outlined,
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