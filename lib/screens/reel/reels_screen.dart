import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/blocs/comments/comment_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_event.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/screens/reel/reels_state_manager.dart';
import 'package:talabna/screens/widgets/comment_sheet.dart';
import 'package:talabna/screens/widgets/contact_sheet.dart';
import 'package:talabna/utils/constants.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/models/photos.dart';
import '../../utils/debug_logger.dart';
import '../../utils/photo_image_helper.dart';
import '../../utils/premium_badge.dart';
import '../../utils/share_utils.dart';
import 'like_button.dart';

class ReelsHomeScreen extends StatefulWidget {
  const ReelsHomeScreen(
      {super.key,
      required this.userId,
      this.servicePost,
      required this.user,
      this.postId});

  final int userId;
  final User user;
  final ServicePost? servicePost;
  final String? postId;

  @override
  State<ReelsHomeScreen> createState() => _ReelsHomeScreenState();
}

// Changed from SingleTickerProviderStateMixin to TickerProviderStateMixin
class _ReelsHomeScreenState extends State<ReelsHomeScreen>
    with TickerProviderStateMixin {
  // BLoC instances
  late UserProfileBloc _userProfileBloc;
  late ServicePostBloc _servicePostBloc;
  late CommentBloc _commentBloc;

  // Animation controllers
  late AnimationController _navigationAnimationController;

  // Page control variables
  int _currentPage = 1;
  List<ServicePost> _servicePosts = [];
  late PageController _pageController;
  bool _hasReachedMax = false;
  int _currentPostIndex = 0;
  bool _isLoadingNextPage = false;
  DateTime? _lastPageLoadTime;

  // Video control
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, int> _mediaIndices = {};
  final ValueNotifier<Duration> _videoProgress = ValueNotifier(Duration.zero);
  bool _isUserChangingSlider = false;
  final Map<int, bool> _videoLoadings = {};
  final Map<int, List<VoidCallback>> _videoListeners = {};

  // UI settings
  final double _iconSize = 32;
  final bool _autoPlay = true;
  final ScrollPhysics _pageScrollPhysics = const BouncingScrollPhysics();
  bool _isPreloadingNextPage = false;


// In ReelsHomeScreen class:

  @override
  void initState() {
    super.initState();

    // Initialize Blocs
    _userProfileBloc = context.read<UserProfileBloc>()
      ..add(UserProfileRequested(id: widget.userId));
    _commentBloc = context.read<CommentBloc>();

    // Initialize ServicePostBloc
    _servicePostBloc = context.read<ServicePostBloc>();

    // IMPORTANT: If a specific postId is provided (deep link case),
    // fetch that specific post first
    if (widget.postId != null) {
      // Fetch this specific post
      _servicePostBloc.add(GetServicePostByIdEvent(int.parse(widget.postId!),
          forceRefresh: true));

      // Also load the general reels feed to have more videos to swipe
      Timer(Duration(milliseconds: 200), () {
        _servicePostBloc.add(GetServicePostsRealsEvent(page: _currentPage));
      });

      // Mark screen as active with this specific postId
      ReelsStateManager().markReelActive(widget.postId!);
      ReelsStateManager().markScreenInitialized(widget.postId!);
      DebugLogger.log(
          'Reel screen initialized for specific ID: ${widget.postId}',
          category: 'REELS');

      // Clear any deep link flags from SharedPreferences
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('pending_reel_id');
        prefs.remove('pending_select_category');
        prefs.setBool('direct_deeplink_active', false);
        prefs.setBool('deeplink_handler_active', false);
      });
    } else {
      // No specific post ID, load general reels feed
      _servicePostBloc.add(GetServicePostsRealsEvent(page: _currentPage));
    }

    // Initialize controllers
    _pageController = PageController()..addListener(_onScrollReelPost);
    _navigationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Video progress update timer
    _initVideoProgressTimer();

    // Schedule a check for preloading videos
    Timer(Duration(milliseconds: 300), () {
      if (mounted) {
        _checkAndPreloadVideosForCurrentPost();
      }
    });
  }

  void _initVideoProgressTimer() {
    Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      // Check if PageController is attached to a page view
      if (!_pageController.hasClients) {
        return; // Skip this update cycle if PageController isn't attached yet
      }

      // Now it's safe to access _pageController.page
      final currentPage = _pageController.page?.round() ?? 0;
      if (currentPage >= _servicePosts.length) return;

      final post = _servicePosts[currentPage];
      final mediaIndex = _mediaIndices[post.id!] ?? 0;

      if (mediaIndex >= post.photos!.length) return;

      final media = post.photos![mediaIndex];

      if (!_isUserChangingSlider &&
          media.isVideo == true &&
          _videoControllers[media.id!]?.value.isInitialized == true) {
        _videoProgress.value = _videoControllers[media.id!]!.value.position;
      }
    });
  }

  void _loadNextPage() {
    // Exit early if already reached max or loading is in progress
    if (_hasReachedMax || _isLoadingNextPage) {
      DebugLogger.log(
          'Skipping next page load: hasReachedMax=$_hasReachedMax, isLoading=$_isLoadingNextPage',
          category: 'REELS');
      return;
    }

    // Implement debounce to prevent rapid firing
    final now = DateTime.now();
    if (_lastPageLoadTime != null &&
        now.difference(_lastPageLoadTime!).inMilliseconds < 1000) {
      DebugLogger.log('Debouncing next page load (< 1sec since last load)',
          category: 'REELS');
      return; // Prevent loading more than once per second
    }

    _lastPageLoadTime = now;
    _isLoadingNextPage = true;

    DebugLogger.log('Loading reels page: ${_currentPage + 1}',
        category: 'REELS');
    _currentPage += 1;
    _servicePostBloc.add(GetServicePostsRealsEvent(page: _currentPage));

    // Reset loading flag after a timeout
    Future.delayed(Duration(seconds: 2), () {
      _isLoadingNextPage = false;
    });
  }

  void _onScrollReelPost() {
    // Check if PageController is attached to a page view
    if (!_pageController.hasClients) {
      return;
    }

    final currentPage = _pageController.page?.round() ?? 0;

    if (_servicePosts.isNotEmpty) {
      _handlePageChange(currentPage);
    }

    // Better end-detection with threshold
    if (!_hasReachedMax &&
        !_isLoadingNextPage &&
        _pageController.hasClients &&
        _pageController.position.pixels >
            _pageController.position.maxScrollExtent - 500) {
      DebugLogger.log(
          'Scroll position near end: ${_pageController.position.pixels.toInt()} / ${_pageController.position.maxScrollExtent.toInt()}',
          category: 'REELS');

      _loadNextPage();
    }
  }

  Future<void> _handleRefresh() async {
    DebugLogger.log('Refreshing reels feed', category: 'REELS');

    // Reset state
    _currentPage = 1;
    _hasReachedMax = false;
    _isLoadingNextPage = false;
    _lastPageLoadTime = null;

    // Clean up controllers to prevent memory leaks
    _disposeAllVideoControllers();

    // Reset data
    if (mounted) {
      setState(() {
        _servicePosts.clear();
        _mediaIndices.clear();
      });
    }

    // Load first page
    _servicePostBloc.add(GetServicePostsRealsEvent(page: _currentPage));

    // Return to the first page
    if (_pageController.hasClients) {
      _pageController.jumpTo(0);
    }

    // Return completed future for RefreshIndicator
    return Future.value();
  }

  // Then add the _preloadNextPage method:
  void _preloadNextPage() {
    // Exit early if already reached max, loading is in progress, or already preloading
    if (_hasReachedMax || _isLoadingNextPage || _isPreloadingNextPage) {
      return;
    }

    // Only preload if we have at least some posts loaded
    if (_servicePosts.isEmpty) return;

    _isPreloadingNextPage = true;
    int preloadPage = _currentPage + 1;

    DebugLogger.log('Preloading reels page: $preloadPage', category: 'REELS');
    _servicePostBloc.add(GetServicePostsRealsEvent(
        page: preloadPage,
        preloadOnly: true
    ));

    // Reset preloading flag after a timeout
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        _isPreloadingNextPage = false;
      }
    });
  }

  void _showRateLimitMessage(String message) {
    // Extract seconds from the message if available
    int seconds = 0;
    final regex = RegExp(r'(\d+)\s*seconds');
    final match = regex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      seconds = int.tryParse(match.group(1) ?? '0') ?? 0;
    }

    // If we have a valid countdown, show a countdown timer
    if (seconds > 0 && seconds < 60) {
      // Create a counter
      int remaining = seconds;

      // Show initial message
      final snackBar = SnackBar(
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Set up timer if not already running
            Timer.periodic(Duration(seconds: 1), (timer) {
              if (remaining <= 0) {
                timer.cancel();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                return;
              }

              setState(() {
                remaining--;
              });
            });

            return Text('Rate limit reached. Retrying in $remaining seconds...');
          },
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: seconds + 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else {
      // Regular error message for non-countdown cases
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  void _handleReelPostLoadSuccess(
      List<ServicePost> servicePosts, bool hasReachedMax, bool isPreloadOnly) {
    // If this is a preload-only update and we already have posts,
    // just add to internal cache in the bloc but don't update UI
    if (isPreloadOnly && _servicePosts.isNotEmpty) {
      DebugLogger.log(
          'Received preloaded page with ${servicePosts.length} posts (caching only)',
          category: 'REELS');
      _isPreloadingNextPage = false;
      return;
    }

    setState(() {
      // Set flag to prevent further loading
      _hasReachedMax = hasReachedMax;

      // If we receive an empty list or API indicates max reached, stop loading
      if (servicePosts.isEmpty || hasReachedMax) {
        DebugLogger.log(
            'Reached maximum reels: hasReachedMax=$hasReachedMax, posts=${servicePosts.length}',
            category: 'REELS');
        _hasReachedMax = true;
      }

      // Add to existing posts without duplicates
      List<ServicePost> newPosts = [];
      for (var post in servicePosts) {
        // Check for duplicates to prevent looping
        if (!_servicePosts.any((p) => p.id == post.id)) {
          newPosts.add(post);
        }
      }

      // If no new posts were added, we've reached the maximum
      if (newPosts.isEmpty && servicePosts.isNotEmpty) {
        _hasReachedMax = true;
        DebugLogger.log('No new reels found, setting hasReachedMax=true',
            category: 'REELS');
      } else {
        _servicePosts.addAll(newPosts);
      }

      final previousMediaIndices = Map.from(_mediaIndices);

      // If we're coming from a deep link with a specific post ID
      if (widget.postId != null) {
        final int postId = int.parse(widget.postId!);
        final bool foundPost = _servicePosts.any((post) => post.id == postId);

        // If the specific post is found, request more posts for swiping
        if (foundPost && !_hasReachedMax) {
          // When in a single-post view, preload next page to allow continued swiping
          Timer(Duration(milliseconds: 300), () {
            _preloadNextPage();
          });
        }
      }

      // Initialize media indices for all posts
      for (var post in newPosts) {
        if (!previousMediaIndices.containsKey(post.id)) {
          _mediaIndices[post.id!] = 0;
        }
      }

      // Clean up unused controllers
      previousMediaIndices.keys
          .where((id) => !_servicePosts.any((post) => post.id == id))
          .toList()
          .forEach((id) => _disposeVideoPlayerController(id));

      // Refresh the UI
      if (_pageController.hasClients) {
        // Find the correct page index if this is a deep link
        if (widget.postId != null) {
          int pageIndex = 0;
          for (int i = 0; i < _servicePosts.length; i++) {
            if (_servicePosts[i].id == int.parse(widget.postId!)) {
              pageIndex = i;
              break;
            }
          }

          // Ensure we're on the right page
          _currentPostIndex = pageIndex;
          _pageController.jumpToPage(pageIndex);

          // Schedule playback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handlePageChange(_currentPostIndex);
          });
        }
      }
    });
  }

  void _checkAndPreloadVideosForCurrentPost() {
    if (_servicePosts.isEmpty || _currentPostIndex >= _servicePosts.length)
      return;

    final post = _servicePosts[_currentPostIndex];
    if (post.photos == null || post.photos!.isEmpty) return;

    final mediaIndex = _mediaIndices[post.id!] ?? 0;
    if (mediaIndex >= post.photos!.length) return;

    final media = post.photos![mediaIndex];
    if (media.isVideo == true) {
      // This will initialize the controller if needed
      _getVideoPlayerController(media);

      // Schedule playback after a short delay
      Timer(Duration(milliseconds: 100), () {
        if (mounted &&
            _videoControllers[media.id!]?.value.isInitialized == true) {
          _videoControllers[media.id!]?.play();
        }
      });
    }
  }

  Future<bool> _onWillPop() async {
    // Mark as inactive before popping
    if (widget.postId != null) {
      ReelsStateManager().markReelInactive(widget.postId!);
    }

    // Use a fade transition when popping
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }

    return false;
  }

  @override
  void dispose() {
    // Mark this screen as disposed when leaving
    if (widget.postId != null) {
      // Clear any pending navigation data
      ReelsStateManager().markReelInactive(widget.postId!);
      ReelsStateManager().markScreenDisposed(widget.postId!);
      DebugLogger.log('Reel screen disposed for ID: ${widget.postId}',
          category: 'REELS');

      // Clear any stored data for this reel
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getString('pending_reel_id') == widget.postId) {
          prefs.remove('pending_reel_id');
          prefs.remove('pending_select_category');
          prefs.setBool('direct_deeplink_active', false);
          DebugLogger.log('Cleared pending reel data for ${widget.postId}',
              category: 'REELS');
        }
      });
    } else {
      // For general reels feed (no specific postId)
      DebugLogger.log('General reels screen disposed', category: 'REELS');
    }

    // Always release navigation locks when disposing
    ReelsStateManager().releaseNavigationLock();

    // Clean up other resources
    _navigationAnimationController.dispose();
    _pageController.dispose();
    _disposeAllVideoControllers();
    super.dispose();
  }

  void _disposeAllVideoControllers() {
    for (var controller in _videoControllers.values) {
      controller.setLooping(false);
      controller.pause();
      controller.dispose();
    }
    _videoControllers.clear();
    _videoListeners.clear();
    _videoLoadings.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(isDarkMode),
        body: BlocListener<ServicePostBloc, ServicePostState>(
          listenWhen: (previous, current) => true,
          bloc: _servicePostBloc,
          listener: (context, state) {
            if (state is ServicePostLoadSuccess) {
              // If we have a specific postId from deep link, handle it differently
              if (widget.postId != null && state.event == 'GetServicePostByIdEvent') {
                // Try to find the specific post
                ServicePost? specificPost;
                try {
                  specificPost = state.servicePosts.firstWhere(
                          (post) => post.id == int.parse(widget.postId!));
                } catch (e) {
                  specificPost = null;
                }

                if (specificPost != null) {
                  // We found the post, now display just this one
                  _handleReelPostLoadSuccess([specificPost], true, false);

                  // Mark as valid for future deep links
                  ReelsStateManager().markPostAsValid(widget.postId!);
                } else {
                  // Post not found in the feed, show normal feed
                  _handleReelPostLoadSuccess(
                      state.servicePosts,
                      state.hasReachedMax,
                      state.preloadOnly ?? false
                  );
                }
              } else if (state.event == 'GetServicePostsForReals') {
                // No specific post, handle normally
                _handleReelPostLoadSuccess(
                    state.servicePosts,
                    state.hasReachedMax,
                    state.preloadOnly ?? false
                );
              }
            }  else if (state is ServicePostLoadFailure) {
              // Special handling for rate limiting errors
              if (state.errorMessage.contains('Rate limit') ||
                  state.errorMessage.contains('429') ||
                  state.errorMessage.contains('Too Many Requests')) {
                // Show rate limit message with possible countdown
                _showRateLimitMessage(state.errorMessage);
              } else {
                // Regular error
                _showErrorSnackBar(state.errorMessage);
              }
            }
          },
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.lightPrimaryColor,
            child: _buildReelsPageView(),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(true),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
            onPressed: _handleRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildReelsPageView() {
    // If no posts yet, show loading indicator with better appearance
    if (_servicePosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.lightPrimaryColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading reels...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
      );
    }

    // If we have the specific post from a deep link, find its index
    int initialPage = 0;
    if (widget.postId != null) {
      try {
        final int postId = int.parse(widget.postId!);
        for (int i = 0; i < _servicePosts.length; i++) {
          if (_servicePosts[i].id == postId) {
            initialPage = i;
            break;
          }
        }
      } catch (e) {
        DebugLogger.log('Error parsing postId: $e', category: 'REELS');
      }
    }

    // If the page controller hasn't been set up with the right initial page
    if (!_pageController.hasClients) {
      _pageController = PageController(initialPage: initialPage);
      _pageController.addListener(_onScrollReelPost);
      _currentPostIndex = initialPage;

      // Ensure we're playing the right video after building
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePageChange(initialPage);
      });
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _servicePosts.length,
      scrollDirection: Axis.vertical,
      physics: _pageScrollPhysics,
      itemBuilder: (context, index) {
        ServicePost post = _servicePosts[index];
        if (post.photos == null || post.photos!.isEmpty) {
          return const SizedBox.shrink();
        }

        int mediaIndex = _mediaIndices[post.id!] ?? 0;
        mediaIndex = min(mediaIndex, post.photos!.length - 1);
        Photo media = post.photos![mediaIndex];

        return _buildReelContent(post, media, mediaIndex);
      },
    );
  }

  Widget _buildReelContent(ServicePost post, Photo media, int mediaIndex) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main Media Content
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (media.isVideo == true) {
              _toggleVideoPlayback(media);
            }
          },
          onHorizontalDragEnd: (details) {
            int currentPostId = post.id!;
            if (details.primaryVelocity! > 0) {
              _showPreviousMedia(currentPostId);
            } else if (details.primaryVelocity! < 0) {
              _showNextMedia(currentPostId);
            }
          },
          child: Container(
            color: Colors.black,
            child: media.isVideo == true
                ? _buildVideoDisplay(media)
                : _buildImageDisplay(media),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Video Progress Bar (conditionally shown for videos)
        if (media.isVideo!) _buildVideoProgressBar(media),

        // Media Counter for multiple media
        if (post.hasMultipleMedia) _buildMediaCounter(post, mediaIndex),

        // Side Action Buttons
        _buildSideActionButtons(post, media),

        // User Info and Post Description
        _buildUserInfoAndDescription(post),
      ],
    );
  }

  Widget _buildVideoProgressBar(Photo media) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder(
        valueListenable: _videoProgress,
        builder: (context, value, child) {
          double maxSeconds =
              _videoControllers[media.id!]?.value.isInitialized == true
                  ? _videoControllers[media.id!]!
                      .value
                      .duration
                      .inSeconds
                      .toDouble()
                  : 0.0;
          double currentSeconds =
              min(_videoProgress.value.inSeconds.toDouble(), maxSeconds);

          return SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.lightPrimaryColor,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: currentSeconds,
              min: 0.0,
              max: maxSeconds,
              onChanged: (double newValue) {
                setState(() {
                  _isUserChangingSlider = true;
                  _videoProgress.value = Duration(seconds: newValue.toInt());
                });
              },
              onChangeEnd: (double newValue) {
                setState(() {
                  _isUserChangingSlider = false;
                  _videoControllers[media.id!]?.seekTo(_videoProgress.value);
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaCounter(ServicePost post, int mediaIndex) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          post.photos!.length,
          (index) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == mediaIndex
                  ? AppTheme.lightPrimaryColor
                  : Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideActionButtons(ServicePost post, Photo media) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          _buildUserAvatarWithFollowButton(post),
          const SizedBox(height: 10),
          _buildLikeButton(post),
          _buildCommentButton(post),
          const SizedBox(height: 10),
          _buildContactButton(post),
          const SizedBox(height: 10),
          _buildShareButton(post),
        ],
      ),
    );
  }

  Widget _buildUserAvatarWithFollowButton(ServicePost post) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.lightPrimaryColor,
              width: 2,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            backgroundImage: CachedNetworkImageProvider(
              ProfileImageHelper.getProfileImageUrl(post.userPhoto),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLikeButton(ServicePost post) {
    return Column(
      children: [
        LikeButton(
          isFavorite: post.isFavorited ?? false,
          favoritesCount: post.favoritesCount ?? 0,
          onToggleFavorite: () async {
            final completer = Completer<bool>();

            // Create a stream subscription to listen for the result
            StreamSubscription? subscription;
            subscription = _servicePostBloc.stream.listen((state) {
              if (state is ServicePostFavoriteToggled &&
                  state.servicePostId == post.id) {
                completer.complete(state.isFavorite);
                subscription?.cancel();
              } else if (state is ServicePostOperationFailure &&
                  state.event == 'ToggleFavoriteServicePostEvent') {
                completer.complete(false);
                subscription?.cancel();
              }
            });

            // Dispatch the toggle event
            _servicePostBloc
                .add(ToggleFavoriteServicePostEvent(servicePostId: post.id!));

            return completer.future;
          },
        ),
      ],
    );
  }

  Widget _buildCommentButton(ServicePost post) {
    return Column(
      children: [
        CommentModalBottomSheet(
          iconSize: _iconSize,
          userProfileBloc: _userProfileBloc,
          commentBloc: _commentBloc,
          servicePost: post,
          user: widget.user,
        ),
      ],
    );
  }

  Widget _buildContactButton(ServicePost post) {
    return Column(
      children: [
        ContactModalBottomSheet(
          iconSize: _iconSize,
          userProfileBloc: _userProfileBloc,
          userId: widget.userId,
          servicePost: post,
        ),
      ],
    );
  }

  Widget _buildShareButton(ServicePost post) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.share_rounded,
              size: 28,
              color: Colors.white,
            ),
            onPressed: () async {
              // Use the helper method for reels specifically
              await ShareUtils.shareReel(post.id!, title: post.title);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoAndDescription(ServicePost post) {
    return Positioned(
      left: 16,
      right: 80, // Make room for side action buttons
      bottom: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Text(
                '@${post.userName ?? 'username'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (post.description != null && post.description!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                post.description!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          PremiumBadge(
            badgeType: post.haveBadge ?? 'عادي',
            userID: widget.userId,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoDisplay(Photo media) {
    return VisibilityDetector(
      key: Key('video_${media.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        final controller = _videoControllers[media.id];
        if (controller != null && controller.value.isInitialized) {
          if (info.visibleFraction > 0.5) {
            controller.play();
          } else {
            controller.pause();
          }
        }
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoControllers[media.id!]?.value.isInitialized == true
              ? _videoControllers[media.id!]!.value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_getVideoPlayerController(media)),
              if (_videoLoadings[media.id!] != true)
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              if (_videoControllers[media.id!]?.value.isInitialized == true &&
                  !_videoControllers[media.id!]!.value.isPlaying)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                    onPressed: () => _toggleVideoPlayback(media),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageDisplay(Photo media) {
    String imageUrl = media.src!.startsWith('http')
        ? media.src!
        : '${Constants.apiBaseUrl}/${media.src!}';

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(
          color: AppTheme.lightPrimaryColor,
          strokeWidth: 3,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 50,
          ),
        ),
      ),
    );
  }

  void _toggleVideoPlayback(Photo media) {
    if (_videoControllers[media.id!]!.value.isPlaying) {
      _videoControllers[media.id!]?.pause();
    } else {
      _videoControllers[media.id!]?.play();
    }
    setState(() {}); // Update UI to show play/pause button
  }

  VideoPlayerController _getVideoPlayerController(Photo photo) {
    if (photo.id == null) {
      // Better error logging and fallback
      DebugLogger.log('Invalid photo data: missing ID',
          category: 'REELS_ERROR');
      throw ArgumentError('Photo must have a non-null ID.');
    }

    // Ensure URL isn't null or empty
    String videoUrl = '';
    if (photo.src != null && photo.src!.isNotEmpty) {
      videoUrl = photo.src!.startsWith('http')
          ? photo.src!
          : '${Constants.apiBaseUrl}/${photo.src!}';
    } else {
      // Log error but don't crash
      DebugLogger.log('Invalid video source for ID: ${photo.id}',
          category: 'REELS_ERROR');
      // Return empty controller
      return VideoPlayerController.asset('assets/placeholder.mp4');
    }

    VideoPlayerController? controller = _videoControllers[photo.id];

    if (controller == null) {
      _videoLoadings[photo.id!] = false; // Video is loading
      controller = VideoPlayerController.network(videoUrl)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _videoLoadings[photo.id!] = true; // Video has loaded
            });
            if (_autoPlay && _currentPostIndex < _servicePosts.length) {
              final currentPost = _servicePosts[_currentPostIndex];
              final currentMediaIndex = _mediaIndices[currentPost.id] ?? 0;
              if (currentMediaIndex < currentPost.photos!.length) {
                final currentMedia = currentPost.photos![currentMediaIndex];
                if (currentMedia.id == photo.id) {
                  controller?.play();
                }
              }
            }
            controller?.setLooping(true);
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('Video initialization error: $error');
          }
          if (mounted) {
            setState(() {
              _videoLoadings[photo.id!] = false;
            });
          }
        });

      // Listeners
      final List<VoidCallback> listeners = [
        // Error listener
        () {
          if (controller!.value.hasError && kDebugMode) {
            print('Video player error: ${controller.value.errorDescription}');
          }
        },

        // Loop listener
        () {
          if (controller!.value.position >=
              controller.value.duration - const Duration(milliseconds: 300)) {
            controller.seekTo(Duration.zero);
            controller.play();
          }
        },

        // Progress listener
        () {
          if (!_isUserChangingSlider && mounted) {
            _videoProgress.value = controller!.value.position;
          }
        }
      ];

      // Add all listeners
      for (var listener in listeners) {
        controller.addListener(listener);
      }

      // Store listeners for cleanup
      _videoListeners[photo.id!] = listeners;
      _videoControllers[photo.id!] = controller;
    }

    return controller;
  }

  void _pauseAllVideos() {
    for (var controller in _videoControllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void _handlePageChange(int pageIndex) {
    if (_servicePosts.isEmpty ||
        pageIndex < 0 ||
        pageIndex >= _servicePosts.length) {
      return;
    }

    _currentPostIndex = pageIndex;
    final currentPost = _servicePosts[pageIndex];

    if (currentPost.photos == null || currentPost.photos!.isEmpty) {
      return;
    }

    final currentMediaIndex = _mediaIndices[currentPost.id] ?? 0;
    if (currentMediaIndex < 0 ||
        currentMediaIndex >= currentPost.photos!.length) {
      return;
    }

    final currentMedia = currentPost.photos![currentMediaIndex];

    // Pause all videos first
    _pauseAllVideos();

    // Play current video if applicable
    if (currentMedia.isVideo == true &&
        _videoControllers[currentMedia.id!] != null &&
        _videoControllers[currentMedia.id!]!.value.isInitialized) {
      _videoControllers[currentMedia.id!]?.play();
    }
  }

  void _showPreviousMedia(int postId) {
    // Check if we can go to previous media (index > 0)
    if (_mediaIndices.containsKey(postId) && _mediaIndices[postId]! > 0) {
      int currentMediaIndex = _mediaIndices[postId]!;
      final post = _servicePosts.firstWhere((post) => post.id == postId);

      // Handle current media
      final currentMedia = post.photos![currentMediaIndex];
      if (currentMedia.isVideo == true) {
        _pauseAndResetVideo(currentMedia.id!);
      }

      // Update index (DECREASE to go to previous media)
      setState(() {
        _mediaIndices[postId] = currentMediaIndex - 1;
      });

      // Handle previous media (use the new index)
      final newIndex = _mediaIndices[postId]!;
      if (newIndex >= 0 && newIndex < post.photos!.length) {
        final newMedia = post.photos![newIndex];
        if (newMedia.isVideo == true) {
          _prepareAndPlayVideo(newMedia.id!);
        }
      }
    }
  }

  void _showNextMedia(int postId) {
    // Only proceed if the post exists in our data
    if (!_mediaIndices.containsKey(postId)) return;

    final post = _servicePosts.firstWhere((post) => post.id == postId);
    int currentMediaIndex = _mediaIndices[postId]!;
    int totalMediaCount = post.photos!.length;

    // Check if we can go to next media
    if (currentMediaIndex < totalMediaCount - 1) {
      // Handle current media
      final currentMedia = post.photos![currentMediaIndex];
      if (currentMedia.isVideo == true) {
        _pauseAndResetVideo(currentMedia.id!);
      }

      // Update index
      setState(() {
        _mediaIndices[postId] = currentMediaIndex + 1;
      });

      // Handle next media (use the new index)
      final newIndex = _mediaIndices[postId]!;
      if (newIndex >= 0 && newIndex < post.photos!.length) {
        final newMedia = post.photos![newIndex];
        if (newMedia.isVideo == true) {
          _prepareAndPlayVideo(newMedia.id!);
        }
      }
    }
  }

  void _pauseAndResetVideo(int mediaId) {
    final controller = _videoControllers[mediaId];
    if (controller != null && controller.value.isInitialized) {
      controller.pause();
      controller.seekTo(Duration.zero);
    }
  }

  void _prepareAndPlayVideo(int mediaId) {
    final controller = _videoControllers[mediaId];
    if (controller != null && controller.value.isInitialized) {
      controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  void _disposeVideoPlayerController(int id) {
    VideoPlayerController? controller = _videoControllers[id];
    List<VoidCallback>? listeners = _videoListeners[id];

    if (controller != null) {
      if (listeners != null) {
        for (var listener in listeners) {
          controller.removeListener(listener);
        }
      }
      controller.setLooping(false);
      controller.pause();
      controller.dispose();
      _videoControllers.remove(id);
      _videoListeners.remove(id);
      _videoLoadings.remove(id);
    }
  }

  void _showErrorSnackBar(String message) {
    // Clean up the error message to be more user friendly
    String displayMessage = message;
    bool isRateLimit = false;

    if (message.contains('429') || message.contains('Too Many Requests') ||
        message.contains('Rate limit')) {
      // Rate limiting error
      isRateLimit = true;

      // Don't clean up the message if it already contains timing information
      if (!message.contains('seconds')) {
        displayMessage = 'Too many requests. Please try again in a moment.';
      } else {
        // Keep the original message with timing information
        displayMessage = message;
      }
    } else if (message.contains('SocketException') || message.contains('Connection failed')) {
      // Network error
      displayMessage = 'Network connection issue. Please check your internet connection.';
    } else if (message.contains('timeout')) {
      // Timeout error
      displayMessage = 'Connection timed out. Please try again.';
    } else if (message.contains('No reels found') || message.contains('No posts')) {
      // No content error
      displayMessage = 'No reels available at the moment. Try again later.';
    } else if (message.length > 100) {
      // Truncate very long error messages
      displayMessage = 'Error loading content. Please try again.';
    }

    // Show rate limit messages differently
    if (isRateLimit) {
      _showRateLimitMessage(displayMessage);
      return;
    }

    // Show regular error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _handleRefresh,
        ),
      ),
    );
  }

  void _scheduleRetryAfterRateLimit() {
    // Wait for 3 seconds before retrying
    Timer(Duration(seconds: 3), () {
      if (mounted) {
        _handleRefresh();
      }
    });
  }

  // Helper method to format count numbers (e.g., 1000 -> 1K)
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }
}

// Extension for ServicePost to check if it has multiple media
extension ServicePostExtension on ServicePost {
  bool get hasMultipleMedia => photos != null && photos!.length > 1;
}
