import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/screens/profile/user_followers_screen.dart';
import 'package:talabna/screens/profile/user_following_screen.dart';
import 'package:talabna/screens/profile/user_info_widget.dart';

import '../../blocs/other_users/user_profile_bloc.dart';
import '../../blocs/other_users/user_profile_event.dart';
import '../../blocs/other_users/user_profile_state.dart';
import '../../data/models/user.dart';
import '../../provider/language.dart';
import '../../utils/photo_image_helper.dart';
import '../interaction_widget/report_tile.dart';
import '../service_post/other_post_screen.dart';
import 'add_point_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.fromUser,
    required this.toUser,
    required this.user,
  });

  final int fromUser;
  final int toUser;
  final User user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late OtherUserProfileBloc _userProfileBloc;
  final Language _language = Language();

  // Simple animation parameters
  bool _isCollapsed = false;
  final double _headerHeight = 300.0;
  final double _collapsedHeight = 120.0; // Height for collapsed state with app bar and tab bar

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Defer bloc operations until after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _userProfileBloc = BlocProvider.of<OtherUserProfileBloc>(context);
        _userProfileBloc.add(OtherUserProfileRequested(id: widget.toUser));
      }
    });
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

  void _setClipboardData(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          content: Text('ID copied to clipboard'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<OtherUserProfileBloc, OtherUserProfileState>(
        builder: (BuildContext context, OtherUserProfileState state) {
          if (state is OtherUserProfileLoadInProgress) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is OtherUserProfileLoadSuccess) {
            final user = state.user;
            return NotificationListener<ScrollUpdateNotification>(
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

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        UserPostScreen(userID: user.id, user: user),
                        UserFollowerScreen(userID: user.id, user: widget.user),
                        UserFollowingScreen(userID: user.id, user: widget.user),
                        UserInfoWidget(userId: user.id, user: user),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else if (state is OtherUserProfileLoadFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Error: ${state.error}',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted) {
                        _userProfileBloc
                            .add(OtherUserProfileRequested(id: widget.toUser));
                      }
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Text('No user profile data found.'),
            );
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
                  Container(
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
                  const SizedBox(width: 12),

                  // Username
                  Expanded(
                    child: Text(
                      user.userName ?? 'Profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
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

        // Profile content
        Positioned(
          top: 70,  // Positioned below app bar
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevent overflow
            children: [
              // Profile Image
              Hero(
                tag: 'profile_image_${user.id}',
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: CachedNetworkImageProvider(
                    ProfileImageHelper.getProfileImageUrl(user.photos?.first),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Username
              Text(
                user.userName ?? 'User Name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
                const SizedBox(width: 32),
                _buildStatColumn('Followers', user.followersCount ?? 0),
                const SizedBox(width: 32),
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
            child: Image.network(
              ProfileImageHelper.getProfileImageUrl(user.photos?.first),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
            ),
          ),
      ],
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
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
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
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
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return ReportTile(
                        type: 'user',
                        userId: widget.fromUser,
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(_language.tConvertPointsText()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddPointScreen(
                        fromUserID: widget.fromUser,
                        toUserId: widget.toUser,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}