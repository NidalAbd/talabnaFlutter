import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/authentication/authentication_bloc.dart';
import 'package:talabna/blocs/authentication/authentication_state.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_event.dart';
import 'package:talabna/core/navigation_service.dart';
import 'package:talabna/core/service_locator.dart';
import 'package:talabna/routes.dart';
import 'package:talabna/screens/service_post/service_post_view.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../blocs/service_post/service_post_state.dart';
import '../blocs/user_profile/user_profile_state.dart';
import '../data/models/service_post.dart';
import '../data/models/user.dart';

class ServicePostDeepLinkHandler {
  // Singleton pattern
  static final ServicePostDeepLinkHandler _instance = ServicePostDeepLinkHandler._internal();
  factory ServicePostDeepLinkHandler() => _instance;
  ServicePostDeepLinkHandler._internal();

  // Track active deep links to prevent duplicate processing
  static final Set<String> _activeDeepLinks = {};

  // Track recently viewed posts to prevent duplicate notifications
  static final Set<String> _recentlyViewedPosts = {};

  // Check if a deep link is already being processed
  bool isProcessingDeepLink(String postId) {
    return _activeDeepLinks.contains('service-post-$postId');
  }

  // Check if a post was recently viewed (useful for notification throttling)
  bool wasPostRecentlyViewed(String postId) {
    return _recentlyViewedPosts.contains(postId);
  }

  // Handle deep link navigation to a service post
// Update this method in the ServicePostDeepLinkHandler class

  // Update this method in the ServicePostDeepLinkHandler class

  Future<bool> handleServicePostDeepLink(
      BuildContext context,
      String postId, {
        bool isFromDeepLink = true,
        bool isFromNotification = false,
        bool clearOnComplete = true,
      }) async {
    try {
      // Create a source-specific link ID
      final String source = isFromNotification ? 'notification' :
      isFromDeepLink ? 'deeplink' : 'normal';
      final linkId = 'service-post-$source-$postId';

      // Prevent duplicate processing
      if (_activeDeepLinks.contains(linkId)) {
        DebugLogger.log('Already processing service post $postId from $source',
            category: 'NAVIGATION');
        return false;
      }

      // Mark as active
      _activeDeepLinks.add(linkId);
      DebugLogger.log('Started processing service post $postId from $source',
          category: 'NAVIGATION');

      // Track for analytics and throttling
      _recentlyViewedPosts.add(postId);

      // Ensure post ID is valid
      if (!_isNumeric(postId)) {
        DebugLogger.log('Invalid post ID format: $postId', category: 'NAVIGATION');
        _activeDeepLinks.remove(linkId);
        return false;
      }

      // Get user ID - first check authentication state
      int userId = 0;

      try {
        // Check auth state
        final authState = context.read<AuthenticationBloc>().state;
        if (authState is AuthenticationSuccess && authState.userId != null) {
          userId = authState.userId!;
        } else {
          // Fallback to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getInt('userId') ?? 0;
        }
      } catch (e) {
        // If any error, try SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getInt('userId') ?? 0;
      }

      // No authenticated user, redirect to login and store deep link
      if (userId == 0) {
        DebugLogger.log('No authenticated user, redirecting to login',
            category: 'NAVIGATION');

        // Store deep link for processing after login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_deep_link_type', 'service-post');
        await prefs.setString('pending_deep_link_id', postId);
        await prefs.setBool('opening_from_deep_link', true);

        // Navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.login,
              (route) => false,
        );

        _activeDeepLinks.remove(linkId);
        return true;
      }

      // Preload service post data
      _preloadServicePostData(context, postId, userId);

      // Set up navigation stack based on source
      if (isFromDeepLink) {
        _setupNavigationStack(userId);
      }

      // Clear any existing flags if from deep link
      if (isFromDeepLink) {
        await _clearDeepLinkFlags();
      }

      // Create the back handler based on source
      VoidCallback backHandler;
      if (isFromNotification) {
        backHandler = () {
          // Go back to notification screen
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/notifications',
                (route) => false,
            arguments: {'userID': userId},
          );
        };
      } else if (isFromDeepLink) {
        backHandler = () {
          // Go back to home
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.home,
                (route) => false,
            arguments: {'userId': userId},
          );
        };
      } else {
        // Normal back navigation
        backHandler = () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // Fallback to home if can't pop
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.home,
                  (route) => false,
              arguments: {'userId': userId},
            );
          }
        };
      }

      // Here's the crucial change: We replace the current screen with our new route
      // rather than creating a new route
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Make sure context is still valid
        if (context.mounted) {
          // Use a try-catch to handle potential navigation errors
          try {
            // Get the current navigator state safely
            final navigator = Navigator.maybeOf(context);
            if (navigator != null) {
              navigator.pushReplacement(
                MaterialPageRoute(
                  settings: RouteSettings(
                    name: Routes.servicePost,
                    arguments: {
                      'postId': postId,
                      'fromDeepLink': isFromDeepLink,
                      'fromNotification': isFromNotification,
                    },
                  ),
                  builder: (context) => WillPopScope(
                    onWillPop: () async {
                      backHandler();
                      return false;
                    },
                    child: BlocProvider.value(
                      value: context.read<ServicePostBloc>(),
                      child: _ServicePostDeepLinkWrapper(
                        postId: postId,
                        userId: userId,
                        onBack: backHandler,
                        isFromDeepLink: isFromDeepLink,
                        isFromNotification: isFromNotification,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              // Fallback if navigator is not available
              DebugLogger.log(
                  'Navigator not available for service post navigation: $postId',
                  category: 'NAVIGATION_ERROR'
              );
            }
          } catch (e) {
            DebugLogger.log(
                'Navigation error for service post: $e',
                category: 'NAVIGATION_ERROR'
            );
          }
        } else {
          DebugLogger.log(
              'Context no longer mounted for service post navigation: $postId',
              category: 'NAVIGATION_ERROR'
          );
        }
      });

      // Auto-cleanup active link after delay
      if (clearOnComplete) {
        Future.delayed(Duration(seconds: 5), () {
          _activeDeepLinks.remove(linkId);
          DebugLogger.log('Cleared processing flag for service post $postId from $source',
              category: 'NAVIGATION');
        });
      }

      return true;
    } catch (e) {
      DebugLogger.log('Error handling service post navigation: $e',
          category: 'NAVIGATION_ERROR');
      _activeDeepLinks.remove('service-post-$postId');
      return false;
    }
  }

  // Check if a string is numeric
  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return int.tryParse(str) != null;
  }

  // Preload service post data for faster display
  void _preloadServicePostData(BuildContext context, String postId, int userId) {
    try {
      // Load service post
      context.read<ServicePostBloc>().add(GetServicePostByIdEvent(
        int.parse(postId),
        forceRefresh: true,
      ));

      // Load user profile
      context.read<UserProfileBloc>().add(UserProfileRequested(id: userId));

      DebugLogger.log('Preloaded data for service post $postId',
          category: 'NAVIGATION');
    } catch (e) {
      DebugLogger.log('Error preloading service post data: $e',
          category: 'NAVIGATION_ERROR');
    }
  }

  // Set up navigation stack for proper back handling
  void _setupNavigationStack(int userId) {
    try {
      final navigationService = serviceLocator<NavigationService>();
      navigationService.setRouteHistory('home', {'userId': userId});
      DebugLogger.log('Set up navigation stack with home route',
          category: 'NAVIGATION');
    } catch (e) {
      DebugLogger.log('Error setting up navigation stack: $e',
          category: 'NAVIGATION_ERROR');
    }
  }

  // Clear deep link flags to prevent duplicates
  Future<void> _clearDeepLinkFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_deep_link_type');
      await prefs.remove('pending_deep_link_id');
      await prefs.remove('opening_from_deep_link');
      await prefs.remove('direct_deeplink_active');

      DebugLogger.log('Cleared deep link flags', category: 'NAVIGATION');
    } catch (e) {
      DebugLogger.log('Error clearing deep link flags: $e',
          category: 'NAVIGATION_ERROR');
    }
  }
}

// Wrapper widget to handle service post display
class _ServicePostDeepLinkWrapper extends StatefulWidget {
  final String postId;
  final int userId;
  final VoidCallback onBack;
  final bool isFromDeepLink;
  final bool isFromNotification;

  const _ServicePostDeepLinkWrapper({
    Key? key,
    required this.postId,
    required this.userId,
    required this.onBack,
    this.isFromDeepLink = false,
    this.isFromNotification = false,
  }) : super(key: key);

  @override
  _ServicePostDeepLinkWrapperState createState() => _ServicePostDeepLinkWrapperState();
}

class _ServicePostDeepLinkWrapperState extends State<_ServicePostDeepLinkWrapper> {
  late ServicePostBloc _servicePostBloc;
  late UserProfileBloc _userProfileBloc;
  ServicePost? _cachedServicePost;
  User? _cachedUser;
  bool _hasAttemptedRefresh = false;

  @override
  void initState() {
    super.initState();
    _servicePostBloc = context.read<ServicePostBloc>();
    _userProfileBloc = context.read<UserProfileBloc>();

    // Ensure we have the latest data
    _refreshData();
  }

  void _refreshData() {
    _hasAttemptedRefresh = true;

    // Log that we're attempting to refresh
    DebugLogger.log('Refreshing data for post ID: ${widget.postId}',
        category: 'NAVIGATION');

    // Load service post with forced refresh
    _servicePostBloc.add(GetServicePostByIdEvent(
      int.parse(widget.postId),
      forceRefresh: true, // Force refresh to ensure we get the latest data
    ));

    // Load user profile
    _userProfileBloc.add(UserProfileRequested(id: widget.userId));
  }

  ServicePost? _getServicePostById(int postId) {
    // If we've already found the post, return the cached version
    if (_cachedServicePost != null) {
      return _cachedServicePost;
    }

    final state = _servicePostBloc.state;

    // Check if state has loaded posts
    if (state is ServicePostLoadSuccess) {
      DebugLogger.log(
          'Found ${state.servicePosts.length} posts in state, looking for ID: $postId',
          category: 'NAVIGATION'
      );

      // For single-post requests, the servicePosts array will contain just one post
      if (state.servicePosts.length == 1 && state.event == 'GetServicePostByIdEvent') {
        final post = state.servicePosts.first;

        // Cache the post so we don't lose it if state changes
        _cachedServicePost = post;

        DebugLogger.log(
            'Found and cached post with ID: ${post.id}',
            category: 'NAVIGATION'
        );
        return post;
      }

      try {
        // Try to find by exact ID match
        final post = state.servicePosts.firstWhere(
              (post) => post.id == postId,
        );

        // Cache the post so we don't lose it if state changes
        _cachedServicePost = post;

        DebugLogger.log(
            'Found and cached post with ID: ${post.id}',
            category: 'NAVIGATION'
        );
        return post;
      } catch (e) {
        DebugLogger.log('No post with exact ID: $postId, error: $e',
            category: 'NAVIGATION');

        // If this is first attempt, try refreshing data again
        if (_hasAttemptedRefresh) {
          // Already attempted refresh, don't try again
        } else {
          // Try refreshing data again
          _refreshData();
        }
      }
    } else {
      // Log the actual state for debugging
      DebugLogger.log('ServicePostBloc is not in LoadSuccess state: ${state.runtimeType}',
          category: 'NAVIGATION');
    }

    return null;
  }

  // Extract user from UserProfileBloc state
  User? _getCurrentUser() {
    // If we've already found the user, return the cached version
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final state = _userProfileBloc.state;

    // Check if state has loaded user
    if (state is UserProfileLoadSuccess) {
      // Cache the user so we don't lose it if state changes
      _cachedUser = state.user;
      return state.user;
    }

    return null;
  }

// Update this part of the _ServicePostDeepLinkWrapperState class
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserProfileBloc, dynamic>(
      builder: (context, userState) {
        return BlocBuilder<ServicePostBloc, dynamic>(
          builder: (context, servicePostState) {
            // Extract data using helper methods
            final servicePost = _getServicePostById(int.parse(widget.postId));
            final user = _getCurrentUser();

            // If we have both the data we need, show the post view with custom wrapper
            if (servicePost != null && user != null) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(servicePost.title ?? 'Service Post'),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                  ),
                ),
                body: ServicePostCardView(
                  userProfileId: widget.userId,
                  servicePost: servicePost,
                  canViewProfile: true,
                  user: user,
                  onPostDeleted: widget.onBack,
                  isFromDeepLink: widget.isFromDeepLink,
                  noAppBar: true, // Set this to true to prevent duplicate app bar
                ),
              );
            }

            // Otherwise show a loading screen
            return Scaffold(
              appBar: AppBar(
                title: Text('Loading Post'),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading post #${widget.postId}...'),
                    if (servicePostState is ServicePostOperationFailure)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load post',
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshData,
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}