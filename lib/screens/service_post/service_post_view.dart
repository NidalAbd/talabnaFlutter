import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:talabna/blocs/other_users/user_profile_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/blocs/user_contact/user_contact_bloc.dart';
import 'package:talabna/blocs/user_contact/user_contact_event.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/interaction_widget/location_button.dart';
import 'package:talabna/screens/profile/user_contact_buttons.dart';
import 'package:talabna/screens/widgets/image_grid.dart';
import 'package:talabna/screens/widgets/service_post_action.dart';
import 'package:talabna/screens/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/comments/comment_bloc.dart';
import '../../blocs/user_profile/user_profile_bloc.dart';
import '../../blocs/user_profile/user_profile_event.dart';
import '../../provider/language.dart';
import '../../utils/debug_logger.dart';
import '../../utils/photo_image_helper.dart';
import '../../utils/premium_badge.dart';
import '../../utils/share_utils.dart';
import '../reel/like_button.dart';
import '../widgets/comment_sheet.dart';
import 'auto_direction_text.dart';

class ServicePostCardView extends StatefulWidget {
  const ServicePostCardView({
    super.key,
    required this.userProfileId,
    required this.onPostDeleted,
    required this.servicePost,
    required this.canViewProfile,
    required this.user,
    this.showTextOnRight = false,
    this.interactionIconSize = 24.0,
  });

  final Function onPostDeleted;
  final int userProfileId;
  final ServicePost servicePost;
  final bool canViewProfile;
  final User user;
  final bool showTextOnRight;
  final double interactionIconSize;

  @override
  State<ServicePostCardView> createState() => _ServicePostCardViewState();
}

class _ServicePostCardViewState extends State<ServicePostCardView> {
  late ServicePostBloc _servicePostBloc;
  late OtherUserProfileBloc _userProfileBloc;
  late UserContactBloc _userContactBloc;
  late UserProfileBloc _userCurrentProfileBloc;
  late CommentBloc _commentBloc;
  final Language language = Language();
  static final Set<int> _incrementedPostIds = {};

  @override
  void initState() {
    super.initState();
    _servicePostBloc = BlocProvider.of<ServicePostBloc>(context);
    _userProfileBloc = BlocProvider.of<OtherUserProfileBloc>(context);
    _userCurrentProfileBloc = context.read<UserProfileBloc>()
      ..add(UserProfileRequested(id: widget.user.id));
    _userContactBloc = BlocProvider.of<UserContactBloc>(context)
      ..add(UserContactRequested(user: widget.servicePost.userId!));
    _commentBloc = BlocProvider.of<CommentBloc>(context);

    // Only increment view count once per post per app session
    if (!_incrementedPostIds.contains(widget.servicePost.id)) {
      _incrementedPostIds.add(widget.servicePost.id!);
      _servicePostBloc.add(
          ViewIncrementServicePostEvent(servicePostId: widget.servicePost.id!));
      DebugLogger.log(
          'Incrementing view count for servicePost.id: ${widget.servicePost.id}',
          category: 'SERVICE_POST');
    } else {
      DebugLogger.log(
          'View already incremented for post ${widget.servicePost.id}, skipping',
          category: 'SERVICE_POST');
    }
  }

  String formatTimeDifference(DateTime? postDate) {
    if (postDate == null) {
      return language.getUnknownTimeText();
    }
    Duration difference = DateTime.now().difference(postDate);
    if (difference.inSeconds < 60) {
      return language.getTimeAgoText(difference.inSeconds, 'second');
    } else if (difference.inMinutes < 60) {
      return language.getTimeAgoText(difference.inMinutes, 'minute');
    } else if (difference.inHours < 24) {
      return language.getTimeAgoText(difference.inHours, 'hour');
    } else if (difference.inDays < 30) {
      return language.getTimeAgoText(difference.inDays, 'day');
    } else if (difference.inDays < 365) {
      return language.getTimeAgoText((difference.inDays / 30).round(), 'month');
    } else {
      return language.getTimeAgoText((difference.inDays / 365).round(), 'year');
    }
  }

  Future<void> _shareServicePost() async {
    // Use the helper method for service posts specifically
    await ShareUtils.shareServicePost(widget.servicePost.id!,
        title: widget.servicePost.title);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[50],
      appBar: _buildAppBar(colorScheme),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(colorScheme),
            _buildPostContent(colorScheme),
            Divider(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              thickness: 0.5,
              height: 1,
            ),
            _buildInteractionRow(colorScheme),
            Divider(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              thickness: 0.5,
              height: 1,
            ),
            _buildContactSection(colorScheme),
            if (widget.servicePost.categoriesId != 7 &&
                widget.servicePost.locationLatitudes != null &&
                widget.servicePost.locationLongitudes != null)
              _buildLocationSection(colorScheme),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      scrolledUnderElevation: 1,
      centerTitle: false,
      title: Row(
        children: [
          Expanded(
            child: AutoDirectionText(
              text: widget.servicePost.title ?? '',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.servicePost.haveBadge != 'عادي')
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: PremiumBadge(
                badgeType: widget.servicePost.haveBadge ?? 'عادي',
                size: 18,
                userID: widget.userProfileId,
              ),
            ),
        ],
      ),
      actions: [
        ServicePostAction(
          key: Key('servicePost_${widget.servicePost.id}'),
          servicePostUserId: widget.servicePost.userId,
          userProfileId: widget.userProfileId,
          servicePostId: widget.servicePost.id,
          onPostDeleted: widget.onPostDeleted,
          servicePost: widget.servicePost,
          user: widget.user,
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

  Widget _buildPostHeader(ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: AutoDirectionText(
                        text: widget.servicePost.userName ??
                            language.getUnknownUserText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatTimeDifference(widget.servicePost.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (widget.servicePost.distance != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 2,
                        height: 2,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        "${widget.servicePost.distance!.clamp(0, 999).toInt()} km",
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildPostContent(ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    // Detect if description is primarily Arabic
    final isDescriptionArabic = widget.servicePost.description != null &&
        widget.servicePost.description!.isNotEmpty &&
        isArabicText(widget.servicePost.description!);

    // Detect if title is primarily Arabic
    final isTitleArabic = widget.servicePost.title != null &&
        widget.servicePost.title!.isNotEmpty &&
        isArabicText(widget.servicePost.title!);

    return Container(
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: Column(
        crossAxisAlignment: isDescriptionArabic
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (widget.servicePost.description != null &&
              widget.servicePost.description!.isNotEmpty)
            Directionality(
              textDirection:
                  isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  widget.servicePost.description ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                    height: 1.3,
                  ),
                  textAlign:
                      isDescriptionArabic ? TextAlign.right : TextAlign.left,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildTagsRow(isDarkMode, isDescriptionArabic),
          ),
          if (widget.servicePost.photos != null &&
              widget.servicePost.photos!.isNotEmpty)
            Hero(
              tag: 'photo_${widget.servicePost.id}',
              child: ImageGrid(
                imageUrls: widget.servicePost.photos!
                    .map((photo) => '${photo.src}')
                    .toList(),
              ),
            ),
        ],
      ),
    );
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
      color: isDarkMode
          ? Colors.grey.shade800.withOpacity(0.3)
          : Colors.grey.shade100,
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
      final subcategoryName =
          widget.servicePost.subCategory!.name[isArabic ? 'ar' : 'en'] ??
              widget.servicePost.subCategory!.name['en'] ??
              'Unknown';

      tags.add(_buildTag(
        label: subcategoryName,
        decoration: tagDecoration,
        style: tagTextStyle,
      ));
    }
    if (widget.servicePost.type != null &&
        widget.servicePost.type!.isNotEmpty) {
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
        label:
            "${widget.servicePost.price} ${widget.servicePost.priceCurrencyCode}",
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
          textDirection:
              isDescriptionArabic ? TextDirection.rtl : TextDirection.ltr,
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

  Widget _buildInteractionRow(ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // VIEWS with count
          _buildCountButton(
            icon: Icons.remove_red_eye_outlined,
            count: formatNumber(widget.servicePost.viewCount ?? 0),
            color: textColor,
            onTap: () {}, // Views are typically not interactive
          ),

          CommentModalBottomSheet(
            iconSize: 22,
            userProfileBloc: _userCurrentProfileBloc,
            commentBloc: _commentBloc,
            servicePost: widget.servicePost,
            user: widget.user,
          ),

          // LIKES with count
          LikeButton(
            showCountOnRight: true,
            isFavorite: widget.servicePost.isFavorited ?? false,
            favoritesCount: widget.servicePost.favoritesCount ?? 0,
            onToggleFavorite: () async {
              final completer = Completer<bool>();

              // Create a stream subscription to listen for the result
              StreamSubscription? subscription;
              subscription = _servicePostBloc.stream.listen((state) {
                if (state is ServicePostFavoriteToggled &&
                    state.servicePostId == widget.servicePost.id) {
                  completer.complete(state.isFavorite);
                  subscription?.cancel();
                } else if (state is ServicePostOperationFailure &&
                    state.event == 'ToggleFavoriteServicePostEvent') {
                  completer.complete(false);
                  subscription?.cancel();
                }
              });

              // Dispatch the toggle event
              _servicePostBloc.add(ToggleFavoriteServicePostEvent(
                  servicePostId: widget.servicePost.id!));

              return completer.future;
            },
          ),

          // SHARE (icon only)
          _buildIconButton(
            icon: Icons.share_outlined,
            color: textColor,
            onTap: _shareServicePost,
          ),

          // REPORT (icon only)
          _buildIconButton(
            icon: Icons.flag_outlined,
            color: textColor,
            onTap: () {
              // Report functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCountButton({
    required IconData icon,
    required String count,
    required Color? color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color? color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildContactSection(ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.contact_phone,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                language.contactDetails(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          UserContactButtons(
            key: Key('UserContactButtons_${widget.servicePost.id}'),
            userId: widget.servicePost.userId!,
            servicePostBloc: _servicePostBloc,
            userContactBloc: _userContactBloc,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(ColorScheme colorScheme) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  language.getUserLocationText(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LocationButtonWidget(
              locationLatitudes: widget.servicePost.locationLatitudes!,
              locationLongitudes: widget.servicePost.locationLongitudes!,
              width: 15,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: GestureDetector(
              onTap: () {
                final url =
                    'https://www.google.com/maps/search/?api=1&query=${widget.servicePost.locationLatitudes},${widget.servicePost.locationLongitudes}';
                launchUrl(Uri.parse(url));
              },
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.servicePost.locationLatitudes!,
                      widget.servicePost.locationLongitudes!),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('user-location'),
                    position: LatLng(widget.servicePost.locationLatitudes!,
                        widget.servicePost.locationLongitudes!),
                    infoWindow:
                        InfoWindow(title: language.getUserLocationText()),
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
