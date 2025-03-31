// The key difference is how the collapsed/expanded states are managed
// In ProfileScreen, you're using AnimatedContainer with custom scroll detection
// But in OtherProfileScreen, you're using SliverAppBar

// Here's the fix to make OtherProfileScreen behave like ProfileScreen:

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_theme.dart';
import '../../blocs/other_users/user_profile_bloc.dart';
import '../../blocs/other_users/user_profile_event.dart';
import '../../blocs/other_users/user_profile_state.dart';
import '../../blocs/user_action/user_action_bloc.dart';
import '../../blocs/user_action/user_action_event.dart';
import '../../blocs/user_action/user_action_state.dart';
import '../../data/models/user.dart';
import '../../provider/language.dart';
import '../../utils/photo_image_helper.dart';
import '../interaction_widget/report_tile.dart';
import '../profile/add_point_screen.dart';
import '../profile/user_followers_screen.dart';
import '../profile/user_following_screen.dart';
import '../profile/user_info_widget.dart';
import '../service_post/other_user_post_screen.dart';
import '../widgets/error_widget.dart';

class OtherProfileScreen extends StatefulWidget {
  const OtherProfileScreen({
    super.key,
    required this.fromUser,
    required this.toUser,
    required this.user,
    required this.isOtherProfile,
  });

  final bool isOtherProfile;
  final int fromUser;
  final int toUser;
  final User user;

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen>
    with SingleTickerProviderStateMixin {
  final Language _language = Language();
  late final TabController _tabController;
  late OtherUserProfileBloc _userProfileBloc;
  late UserActionBloc _userActionBloc;

  // Simple animation parameters
  bool _isCollapsed = false;
  final double _headerHeight = 300.0;
  final double _collapsedHeight = 120.0; // Height for collapsed state with app bar and tab bar

  bool isFollowing = false;
  bool isHimSelf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize user profile bloc
    _userProfileBloc = context.read<OtherUserProfileBloc>()
      ..add(OtherUserProfileRequested(id: widget.toUser));

    // Initialize user action bloc
    _userActionBloc = context.read<UserActionBloc>();
    _userActionBloc.add(GetUserFollow(user: widget.toUser));

    // Check if the profile belongs to the current user
    isHimSelf = widget.fromUser == widget.toUser;
  }

  // Simplified scroll processor
  void _processScroll(ScrollUpdateNotification notification) {
    final scrollPosition = notification.metrics.pixels;
    final isScrollingDown = notification.scrollDelta != null && notification.scrollDelta! > 0;
    final isScrollingUp = notification.scrollDelta != null && notification.scrollDelta! < 0;

    // Collapse header when scrolling down past threshold
    if (isScrollingDown && scrollPosition > 50 && !_isCollapsed) {
      setState(() {
        _isCollapsed = true;
      });
    }

    // Expand header when scrolling back to top
    else if (isScrollingUp && scrollPosition < 10 && _isCollapsed) {
      setState(() {
        _isCollapsed = false;
      });
    }
  }

  // Safe method to show a snackbar that checks context and mounted state
  void _showSnackBar(String message) {
    if (mounted && context.mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars(); // Clear any existing snackbars first

      Future.microtask(() {
        if (mounted && context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  void _setClipboardData(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _showSnackBar('Copied to clipboard');
    }
  }

  // Toggle follow status when user interacts with profile elements
  void _toggleFollow() {
    if (!isHimSelf) {
      context.read<UserActionBloc>().add(
        ToggleUserMakeFollowEvent(user: widget.toUser),
      );
    }
  }

  String _getLocationText(User user) {
    // Use the app's current locale or default to English
    final String currentLang = Localizations.localeOf(context).languageCode;
    final List<String> locationParts = [];

    if (user.city != null) {
      try {
        locationParts.add(user.city!.getName(currentLang));
      } catch (e) {
        // Fallback if getName method fails
        locationParts.add(user.city.toString());
      }
    }

    if (user.country != null) {
      try {
        locationParts.add(user.country!.getCountryName(currentLang));
      } catch (e) {
        // Fallback if getName method fails
        locationParts.add(user.country.toString());
      }
    }

    return locationParts.join(', ');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserActionBloc, UserActionState>(
      listener: (context, state) {
        if (state is UserFollowUnFollowToggled && mounted) {
          setState(() {
            isFollowing = state.isFollower;
          });

          final message = state.isFollower
              ? 'You are now following the user'
              : 'You have unfollowed the user';

          _showSnackBar(message);
        } else if (state is GetFollowUserSuccess) {
          setState(() {
            isFollowing = state.followSuccess;
          });
        }
      },
      child: BlocBuilder<OtherUserProfileBloc, OtherUserProfileState>(
        builder: (context, state) {
          if (state is OtherUserProfileLoadInProgress) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (state is OtherUserProfileLoadSuccess) {
            final user = state.user;
            return Scaffold(
              body: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  _processScroll(notification);
                  return false;
                },
                child: Column(
                  children: [
                    // Header section
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      height: _isCollapsed ? _collapsedHeight : _headerHeight,
                      width: double.infinity,
                      child: _isCollapsed
                          ? _buildCollapsedHeader(user)
                          : _buildExpandedHeader(user),
                    ),

                    // Tab content (takes remaining screen space)
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          OtherUserPostScreen(userID: user.id, user: widget.user, primary: false),
                          UserFollowerScreen(userID: user.id, user: user, primary: false),
                          UserFollowingScreen(userID: user.id, user: user, primary: false),
                          UserInfoWidget(userId: user.id, user: user),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is OtherUserProfileLoadFailure) {
            return ErrorCustomWidget.show(context, message: state.error);
          } else {
            return ErrorCustomWidget.show(context,
                message: 'No user profile data found.');
          }
        },
      ),
    );
  }

  // Collapsed header with app bar and tab bar
  Widget _buildCollapsedHeader(User user) {
    return Material(
      color: Theme.of(context).primaryColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status bar space
          SizedBox(height: MediaQuery.of(context).padding.top),

          SizedBox(
            height: 40, // Standard app bar height
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    iconSize: 24,
                  ),

                  // Profile photo
                  GestureDetector(
                    onTap: isHimSelf ? null : _toggleFollow,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            ProfileImageHelper.getProfileImageUrl(user.photos?.first),
                          ),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Username
                  Expanded(
                    child: GestureDetector(
                      onTap: isHimSelf ? null : _toggleFollow,
                      child: Row(
                        children: [
                          Text(
                            user.userName ?? 'Profile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Follow indicator
                          if (!isHimSelf)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                isFollowing ? Icons.check_circle : Icons.add_circle_outline,
                                color: isFollowing ? Colors.green : Colors.blue,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // More options button
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showMoreOptions(context, user),
                  ),
                ],
              ),
            ),
          ),

          // Spacer
          const Spacer(),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: _language.tPostsText()),
              Tab(text: _language.tFollowersText()),
              Tab(text: _language.tFollowingText()),
              Tab(text: _language.tOverviewText()),
            ],
          ),
        ],
      ),
    );
  }

  // Expanded header with profile details
  Widget _buildExpandedHeader(User user) {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: _buildProfileBackground(user),
        ),

        // Status bar space + app bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            height: 56.0 + MediaQuery.of(context).padding.top,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMoreOptions(context, user),
                ),
              ],
            ),
          ),
        ),

        // Profile content - center aligned
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Image
              GestureDetector(
                onTap: isHimSelf ? null : _toggleFollow,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Profile image
                    Hero(
                      tag: 'profile_image_${user.id}',
                      child: CircleAvatar(
                        radius: 45,
                        backgroundImage: CachedNetworkImageProvider(
                          ProfileImageHelper.getProfileImageUrl(user.photos?.first),
                        ),
                        onBackgroundImageError: (exception, stackTrace) =>
                        const AssetImage('assets/images/placeholder.png'),
                      ),
                    ),

                    // Follow indicator overlay
                    if (!isHimSelf)
                      AnimatedOpacity(
                        opacity: 0.6,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFollowing
                                ? Colors.black.withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                          ),
                          child: Icon(
                            isFollowing ? Icons.check : Icons.person_add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Username
              GestureDetector(
                onTap: isHimSelf ? null : _toggleFollow,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.userName ?? 'User Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Only show follow icon if not viewing own profile
                    if (!isHimSelf)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          isFollowing ? Icons.check_circle : Icons.add_circle_outline,
                          color: isFollowing ? Colors.green : Colors.blue,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),

              // Location info (city and country)
              if (user.city != null || user.country != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            _getLocationText(user),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Stats row positioned just above the tab bar
        Positioned(
          bottom: 48, // Position above tab bar
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn('Posts', user.servicePostsCount ?? 0),
                const SizedBox(width: 20),
                _buildStatColumn('Followers', user.followersCount ?? 0),
                const SizedBox(width: 20),
                _buildStatColumn('Following', user.followingCount ?? 0),
              ],
            ),
          ),
        ),

        // Tab bar at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black26,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: _language.tPostsText()),
                Tab(text: _language.tFollowersText()),
                Tab(text: _language.tFollowingText()),
                Tab(text: _language.tOverviewText()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBackground(User user) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred background image
        if (user.photos != null && user.photos!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: CachedNetworkImage(
              imageUrl:
              ProfileImageHelper.getProfileImageUrl(user.photos!.first),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
              placeholder: (context, url) => Container(
                color: Colors.grey[800],
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            color: Colors.grey[800],
          ),
      ],
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return InkWell(
      onTap: () {
        // Navigate to appropriate tab based on stat
        if (label == 'Posts') {
          _tabController.animateTo(0);
        } else if (label == 'Followers') {
          _tabController.animateTo(1);
        } else if (label == 'Following') {
          _tabController.animateTo(2);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4,),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, User user) {
    if (mounted && context.mounted) {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Wrap(
            children: [
              ListTile(
                onLongPress: () => _setClipboardData(user.id.toString()),
                leading: const Icon(Icons.perm_identity),
                title: Text(
                  user.id.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: Text(_language.tReportText()),
                onTap: () {
                  Navigator.pop(context);
                  if (mounted && context.mounted) {
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext context) {
                        return Container(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.lightPrimaryColor.withOpacity(0.8)
                              : AppTheme.darkPrimaryColor.withOpacity(0.8),
                          child: ReportTile(
                            type: 'user',
                            userId: widget.fromUser,
                          ),
                        );
                      },
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(_language.tConvertPointsText()),
                onTap: () {
                  Navigator.pop(context);
                  if (mounted && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddPointScreen(
                          fromUserID: widget.fromUser,
                          toUserId: widget.toUser,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }
}