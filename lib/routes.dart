import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/authentication/authentication_bloc.dart';
import 'package:talabna/blocs/authentication/authentication_state.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/blocs/user_profile/user_profile_bloc.dart';
import 'package:talabna/blocs/user_profile/user_profile_event.dart';
import 'package:talabna/blocs/user_profile/user_profile_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/screens/auth/login_screen_new.dart';
import 'package:talabna/screens/auth/register_screen_new.dart';
import 'package:talabna/screens/auth/reset_password.dart';
import 'package:talabna/screens/banned_screen.dart';
import 'package:talabna/screens/home/home_screen.dart';
import 'package:talabna/screens/home/select_language.dart';
import 'package:talabna/screens/reel/reels_screen.dart';
import 'package:talabna/screens/reel/reels_state_manager.dart';
import 'package:talabna/screens/service_post/service_post_view.dart';
import 'package:talabna/services/service_post_deep_link_handler.dart';
import 'package:talabna/utils/debug_logger.dart';
import 'package:talabna/utils/deep_link_diagnostics.dart';

import 'core/deep_link_service.dart';
import 'core/navigation_service.dart';
import 'core/service_locator.dart';
import 'data/models/user.dart';

class Routes {
  // Route names
  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String language = '/language';
  static const String resetPassword = '/reset-password';
  static const String servicePost = '/service-post';
  static const String reels = '/reels';
  static const String banned = '/banned';

  // Navigation state management
  static bool _isNavigating = false;
  static final Map<String, DateTime> _navigationTimestamps = {};
  static Timer? _cleanupTimer;
  static final Set<String> _activeRoutes = {};
  static const int _navigationDebounceTime = 200; // ms
  static Map<String, dynamic>? _initialRouteArgs;

  // Reset navigation state
  static void resetNavigationState() {
    _navigationTimestamps.clear();
    _activeRoutes.clear();
    _isNavigating = false;
    DebugLogger.log('Navigation state reset', category: 'NAVIGATION');
  }

  // Release navigation lock
  static void releaseRouteLock() {
    _isNavigating = false;
    DebugLogger.log('Route lock released', category: 'NAVIGATION');
  }

  // Create route
  static PageRoute _createRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => page,
    );
  }

  // Empty route for blocking duplicate navigations
  static Route<dynamic> _createEmptyRoute(RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionDuration: const Duration(milliseconds: 0),
    );
  }

  // Check if navigation should be allowed
  static bool shouldAllowNavigation(String routePath, String routeId) {
    // Always allow home and login
    if (routePath == home || routePath == login) {
      return true;
    }

    final navigationId = '$routePath-$routeId';

    // Check if already active
    if (_activeRoutes.contains(navigationId)) {
      DebugLogger.log('Already navigating to: $navigationId',
          category: 'NAVIGATION');
      return false;
    }

    // Check debounce
    final lastNavTime = _navigationTimestamps[navigationId];
    if (lastNavTime != null) {
      final timeSince = DateTime.now().difference(lastNavTime).inMilliseconds;
      if (timeSince < _navigationDebounceTime) {
        DebugLogger.log(
            'Too soon to navigate to: $navigationId ($timeSince ms)',
            category: 'NAVIGATION');
        return false;
      }
    }

    // Allow navigation
    _navigationTimestamps[navigationId] = DateTime.now();
    _activeRoutes.add(navigationId);
    _startCleanupTimer();
    return true;
  }

  // Start cleanup timer
  static void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(seconds: 30), (_) {
      final now = DateTime.now();
      final keysToRemove = <String>[];
      final routesToRemove = <String>[];

      _navigationTimestamps.forEach((key, timestamp) {
        if (now.difference(timestamp).inSeconds > 60) {
          keysToRemove.add(key);
          routesToRemove.add(key);
        }
      });

      for (final key in keysToRemove) {
        _navigationTimestamps.remove(key);
      }

      for (final route in routesToRemove) {
        _activeRoutes.remove(route);
      }

      DebugLogger.log('Cleaned ${keysToRemove.length} navigation entries',
          category: 'NAVIGATION');
    });
  }

  // Process URL scheme paths
  static Route<dynamic> _handleUrlSchemePath(RouteSettings settings) {
    try {
      DebugLogger.log('Handling URL scheme: ${settings.name}',
          category: 'NAVIGATION');

      String path = settings.name!;

      // Parse the URI
      if (path.startsWith('talabna://')) {
        final uri = Uri.parse(path);
        final segments = uri.pathSegments;

        if (segments.isNotEmpty) {
          // Handle reels
          if (segments[0] == 'reels' && segments.length >= 2) {
            final postId = segments[1];
            return _handleReelsRoute({'postId': postId, 'isReel': true});
          }

          // Handle service posts
          else if (segments[0] == 'service-post' && segments.length >= 2) {
            final postId = segments[1];
            return _handleServicePostRoute({'postId': postId});
          }

          // Handle numeric IDs
          else if (segments.length == 1 && _isNumeric(segments[0])) {
            final postId = segments[0];

            if (path.toLowerCase().contains('reel')) {
              return _handleReelsRoute({'postId': postId, 'isReel': true});
            } else {
              return _handleServicePostRoute({'postId': postId});
            }
          }
        }
      }

      // Fallback
      return _errorRoute('Invalid URL scheme: ${settings.name}');
    } catch (e) {
      DebugLogger.log('Error in URL scheme: $e', category: 'NAVIGATION');
      return _errorRoute('Error handling URL: ${settings.name}');
    }
  }
  static void setInitialRouteArgs(Map<String, dynamic> args) {
    _initialRouteArgs = args;
    DebugLogger.log('Initial route args set: $args', category: 'NAVIGATION');
  }
// Method to get and clear initial route arguments
  static Map<String, dynamic>? getAndClearInitialRouteArgs() {
    final args = _initialRouteArgs;
    _initialRouteArgs = null;
    return args;
  }

  // Main route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    DeepLinkDiagnostics().addEvent('Route requested', details: 'Name: ${settings.name}');

    DebugLogger.log('Routing to: ${settings.name}', category: 'NAVIGATION');
    Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
    if (args == null &&
        (settings.name == Routes.reels || settings.name == Routes.servicePost) &&
        _initialRouteArgs != null) {
      args = getAndClearInitialRouteArgs();
      DebugLogger.log('Using stored initial route args: $args', category: 'NAVIGATION');
    }

    try {
      // Track navigation state
      bool wasNavigating = _isNavigating;
      _isNavigating = true;

      try {
        // Handle numeric path IDs
        if (settings.name != null &&
            settings.name!.startsWith('/') &&
            _isNumeric(settings.name!.substring(1))) {
          final postId = settings.name!.substring(1);

          // Check navigation debounce
          if (!shouldAllowNavigation('direct', postId)) {
            _isNavigating = wasNavigating;
            return _createEmptyRoute(settings);
          }

          DebugLogger.log('Direct post ID navigation: $postId',
              category: 'NAVIGATION');

          // Handle reel deep link
          if (settings.name!.toLowerCase().contains('reel')) {
            _isNavigating = wasNavigating;
            return _handleReelsRoute({'postId': postId, 'isReel': true});
          }

          // For regular IDs, determine type from preferences
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) {
              // Check preferences to determine content type
              SharedPreferences.getInstance().then((prefs) {
                final pendingType = prefs.getString('pending_deep_link_type');

                if (pendingType == DeepLinkService.TYPE_REELS) {
                  Navigator.of(context).pushReplacement(
                      _handleReelsRoute({'postId': postId, 'isReel': true}));
                } else {
                  Navigator.of(context).pushReplacement(
                      _handleServicePostRoute({'postId': postId}));
                }
              });

              // Show loading indicator
              return Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
            transitionDuration: const Duration(milliseconds: 100),
          );
        }

        // Handle URL scheme
        if (settings.name != null && settings.name!.startsWith('talabna://')) {
          _isNavigating = wasNavigating;
          return _handleUrlSchemePath(settings);
        }

        if (settings.name != null && settings.name!.contains('talbna.cloud/api/deep-link')) {
          try {
            DeepLinkDiagnostics().addEvent('Deep link URL detected', details: settings.name);
            final uri = Uri.parse(settings.name!);
            final segments = uri.pathSegments;

            DeepLinkDiagnostics().addEvent('Parsed URI segments', details: segments.toString());

            if (segments.length >= 4 &&
                segments[0] == 'api' &&
                segments[1] == 'deep-link') {

              final type = segments[2];
              final id = segments[3];

              DeepLinkDiagnostics().addEvent('Deep link extracted', details: 'Type: $type, ID: $id');

              // Redirect to appropriate handler based on type
              if (type == 'reels' || type == 'reel') {
                DeepLinkDiagnostics().addEvent('Handling as reels deep link', details: 'ID: $id');
                return _handleReelsRoute({'postId': id, 'isReel': true});
              } else if (type == 'service-post' || type == 'service_post' || type == 'post') {
                DeepLinkDiagnostics().addEvent('Handling as service post deep link', details: 'ID: $id');
                return _handleServicePostRoute({'postId': id});
              }
            }
          } catch (e) {
            DeepLinkDiagnostics().addEvent('Error parsing deep link URL', details: e.toString(), isError: true);
          }
        }

        if (settings.name?.startsWith('http') == true) {
          DeepLinkDiagnostics().addEvent('Unhandled URL route', details: settings.name, isError: true);
        }

        // Handle standard routes
        switch (settings.name) {
          case initial:
          case login:
            _isNavigating = wasNavigating;
            return _createRoute(const LoginScreenNew(), settings);

          case register:
            _isNavigating = wasNavigating;
            return _createRoute(RegisterScreenNew(), settings);

          case home:
            _isNavigating = wasNavigating;
            return _handleHomeRoute(args);

          case language:
            _isNavigating = wasNavigating;
            return _createRoute(const LanguageSelectionScreen(), settings);

          case resetPassword:
            _isNavigating = wasNavigating;
            return _createRoute(const ResetPasswordScreen(), settings);

          case servicePost:
            final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
            final postId = args?['postId'] as String?;
            final fromNotification = args?['fromNotification'] as bool? ?? false;

            if (postId == null) {
              _isNavigating = wasNavigating;
              return _createRoute(const HomeScreen(userId: 0), settings);
            }

            // Check if already navigating to this post - prevent duplicates
            if (!shouldAllowNavigation('service-post', postId)) {
              _isNavigating = wasNavigating;
              return _createEmptyRoute(settings);
            }

            // If coming from notification, add special logging
            if (fromNotification) {
              DebugLogger.log(
                  'Handling service post from notification: $postId',
                  category: 'NAVIGATION'
              );

              // Track this navigation with a unique source ID to improve analytics
              _navigationTimestamps['notification-post-$postId'] = DateTime.now();
              _activeRoutes.add('notification-post-$postId');

              // Auto cleanup after delay
              Timer(Duration(seconds: 10), () {
                _activeRoutes.remove('notification-post-$postId');
              });
            }

            _isNavigating = wasNavigating;
            return _handleServicePostRoute(args);

          case reels:
            final postId = args?['postId'] as String?;
            if (postId == null) {
              _isNavigating = wasNavigating;
              return _createRoute(const HomeScreen(userId: 0), settings);
            }

            // Check navigation debounce
            if (!shouldAllowNavigation('reels', postId)) {
              _isNavigating = wasNavigating;
              return _createEmptyRoute(settings);
            }

            _isNavigating = wasNavigating;
            return _handleReelsRoute(args);

          case banned:
            final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
            final banReason = args?['banReason'] as String?;
            return _createRoute(
              BannedScreen(
                banReason: banReason,
              ),
              settings,
            );

          default:
            _isNavigating = wasNavigating;
            return _errorRoute('Route not found: ${settings.name}');
        }
      } finally {
        // Reset navigation flag
        Future.delayed(Duration(milliseconds: 50), () {
          _isNavigating = false;
        });
      }
    } catch (e) {
      _isNavigating = false; // Release lock on error
      DebugLogger.log('Route error: $e', category: 'NAVIGATION');
      return _errorRoute('Error processing route: ${settings.name}');
    }
  }

  // Handle reels route
// Updated _handleReelsRoute with proper app initialization
  static Route<dynamic> _handleReelsRoute(Map<String, dynamic>? args) {
    final postId = args?['postId'] as String?;
    final userId = args?['userId'] as int?;
    final servicePost = args?['servicePost'] as ServicePost?;
    final isFromDeepLink = args?['isReel'] as bool? ?? false;

    if (postId == null) {
      return _errorRoute('postId is required for ReelsRoute');
    }

    // Ensure postId is numeric
    if (!_isNumeric(postId)) {
      return _errorRoute('Invalid postId format for Reels');
    }

    // Improved duplicate navigation detection
    if (ReelsStateManager().isScreenActive(postId) ||
        _navigationTimestamps.containsKey('reels-$postId') ||
        _activeRoutes.contains('reels-$postId')) {
      DebugLogger.log(
          'Reel $postId already active or navigating, blocking duplicate',
          category: 'NAVIGATION');
      return _createEmptyRoute(RouteSettings(name: reels, arguments: args));
    }

    // Use a unique route key for deep links
    final routeKey =
    isFromDeepLink ? 'reels-deeplink-$postId' : 'reels-$postId';

    // Track this navigation attempt
    _navigationTimestamps[routeKey] = DateTime.now();
    _activeRoutes.add(routeKey);

    // Auto-cleanup after delay
    Timer(Duration(seconds: 10), () {
      _activeRoutes.remove(routeKey);
    });

    DebugLogger.log('Creating route for REELS with ID: $postId',
        category: 'NAVIGATION');

    // Store category selection for HomeScreen coordination
    if (isFromDeepLink) {
      SharedPreferences.getInstance().then((prefs) async {
        // Set flag to indicate a direct deep link
        await prefs.setBool('direct_deeplink_active', true);

        // Store pending reel selection
        await prefs.setInt('pending_select_category', 7);
        await prefs.setString('pending_reel_id', postId);

        DebugLogger.log('Stored pending reel selection: $postId',
            category: 'NAVIGATION');
      });
    }

    // Define the getUserId method here as a local function
    Future<int> getUserId(BuildContext context) async {
      if (userId != null) {
        return userId;
      }

      // Try to get from authentication state
      if (context.read<AuthenticationBloc>().state is AuthenticationSuccess) {
        final authState =
        context.read<AuthenticationBloc>().state as AuthenticationSuccess;
        if (authState.userId != null) {
          return authState.userId!;
        }
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefUserId = prefs.getInt('userId');
      if (prefUserId != null) {
        return prefUserId;
      }

      // Default
      return 0;
    }

    // Create a unified MaterialPageRoute for all reel navigation with WillPopScope
    return MaterialPageRoute(
      settings: RouteSettings(name: reels, arguments: args),
      maintainState: true,
      builder: (context) {
        // **NEW** Ensure proper app initialization for deep links
        if (isFromDeepLink) {
          SharedPreferences.getInstance().then((prefs) {
            // Check if this is coming from a cold start deep link
            final isOpeningFromDeepLink = prefs.getBool('opening_from_deep_link') ?? false;

            if (isOpeningFromDeepLink) {
              // Ensure the app knows we're in a deep link flow
              final navigationService = serviceLocator<NavigationService>();
              navigationService.setOpeningFromDeepLink(true);

              // Make sure we set up a proper navigation stack with home as the base
              WidgetsBinding.instance.addPostFrameCallback((_) {
                navigationService.setupDeepLinkNavigationStack();
              });
            }
          });
        }

        // Initialize data in background
        Future.microtask(() async {
          try {
            // Get user ID
            final actualUserId = await getUserId(context);

            if (!context.mounted) return;

            // Pre-load the service post
            final servicePostBloc = context.read<ServicePostBloc>();

            // Check if we already have the post loaded
            bool needsLoading = true;
            if (servicePostBloc.state is ServicePostLoadSuccess) {
              try {
                final posts = (servicePostBloc.state as ServicePostLoadSuccess)
                    .servicePosts;
                final exists =
                posts.any((post) => post.id == int.parse(postId));
                needsLoading = !exists;
              } catch (e) {
                DebugLogger.log('Error checking existing post: $e',
                    category: 'NAVIGATION');
                needsLoading = true;
              }
            }

            // Load post if needed
            if (needsLoading) {
              DebugLogger.log('Loading reel post $postId from API',
                  category: 'NAVIGATION');
              servicePostBloc.add(GetServicePostByIdEvent(
                int.parse(postId),
                forceRefresh: false,
              ));
            } else {
              DebugLogger.log('Reel post $postId already loaded',
                  category: 'NAVIGATION');
            }

            // Load user profile data
            final userProfileBloc = context.read<UserProfileBloc>();
            userProfileBloc.add(UserProfileRequested(id: actualUserId));
          } catch (e) {
            DebugLogger.log('Error preparing reel data: $e',
                category: 'NAVIGATION');
          }
        });

        // Get any existing user data
        final userProfileBloc = context.read<UserProfileBloc>();
        User? existingUser;
        if (userProfileBloc.state is UserProfileLoadSuccess) {
          existingUser = (userProfileBloc.state as UserProfileLoadSuccess).user;
        }

        // Get any existing post data
        final servicePostBloc = context.read<ServicePostBloc>();
        ServicePost? existingPost;
        if (servicePostBloc.state is ServicePostLoadSuccess) {
          try {
            existingPost = (servicePostBloc.state as ServicePostLoadSuccess)
                .servicePosts
                .firstWhere((post) => post.id == int.parse(postId));
          } catch (_) {
            // Post not found in current state
            existingPost = null;
          }
        }

        // Initialize ReelStateManager for tracking
        ReelsStateManager().markReelActive(postId);

        // Make sure we have a valid navigation home path
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Create a home route that we can navigate back to
          final navigationService = serviceLocator<NavigationService>();
          navigationService.setRouteHistory('home', {'userId': userId ?? 0});
        });

        // Return the ReelsHomeScreen with WillPopScope at the root
        return WillPopScope(
          onWillPop: () async {
            // Handle back button press
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return false;
            } else {
              // If there's no route to pop to, go to home
              SharedPreferences.getInstance().then((prefs) {
                final userId = prefs.getInt('userId') ?? 0;

                // Clear deep link flags when leaving reel screen
                prefs.remove('opening_from_deep_link');
                prefs.remove('direct_deeplink_active');

                Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.home,
                      (route) => false,
                  arguments: {'userId': userId},
                );
              });
              return false;
            }
          },
          child: ReelsHomeScreen(
            userId: userId ?? (existingUser?.id ?? 0),
            servicePost: existingPost,
            user: existingUser ?? User(id: 0, name: '', userName: '', email: ''),
            postId: postId,
          ),
        );
      },
    );
  }

  // Update the _handleServicePostRoute method in your Routes class
  // Update this part in the _handleServicePostRoute method

  static Route<dynamic> _handleServicePostRoute(Map<String, dynamic>? args) {
    final postId = args?['postId'] as String?;
    final isFromDeepLink = args?['fromDeepLink'] as bool? ?? false;
    final isFromNotification = args?['fromNotification'] as bool? ?? false;

    if (postId == null) {
      return _errorRoute('postId is required for ServicePost route');
    }


    // Ensure postId is numeric
    if (!_isNumeric(postId)) {
      return _errorRoute('Invalid postId format');
    }

    // Track the source for better navigation management
    final String routeSource = isFromNotification ? 'notification' :
    isFromDeepLink ? 'deeplink' : 'normal';

    // Create a unique ID for this navigation attempt
    final String navId = '$routeSource-$postId';

    // Check if already navigating to this service post
    if (!shouldAllowNavigation('service-post', navId)) {
      DebugLogger.log('Already navigating to service post: $postId from $routeSource',
          category: 'NAVIGATION');
      return _createEmptyRoute(RouteSettings(name: servicePost, arguments: args));
    }

    // Return a PageRouteBuilder that will handle the service post loading
    return MaterialPageRoute(
        settings: RouteSettings(name: servicePost, arguments: args),
        builder: (context) {
          // Preload data
          final servicePostBloc = context.read<ServicePostBloc>();
          servicePostBloc.add(GetServicePostByIdEvent(
            int.parse(postId),
            forceRefresh: true,
          ));

          // Create back handler
          VoidCallback backHandler;
          if (isFromNotification) {
            backHandler = () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/notifications',
                    (route) => false,
                arguments: {'userID': _getUserIdFromContext(context)},
              );
            };
          } else if (isFromDeepLink) {
            backHandler = () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                home,
                    (route) => false,
                arguments: {'userId': _getUserIdFromContext(context)},
              );
            };
          } else {
            backHandler = () {
              Navigator.of(context).pop();
            };
          }

          // Return the service post wrapper with WillPopScope
          return WillPopScope(
            onWillPop: () async {
              backHandler();
              return false;
            },
            child: BlocBuilder<ServicePostBloc, ServicePostState>(
              builder: (context, state) {

                if (state is ServicePostLoadSuccess) {
                  ServicePost? post;
                  try {
                    post = state.servicePosts.firstWhere(
                          (p) => p.id == int.parse(postId),
                    );
                  } catch (e) {
                    post = null;
                  }

                  if (post != null) {
                    final userProfileBloc = context.read<UserProfileBloc>();
                    final userState = userProfileBloc.state;
                    User user;

                    if (userState is UserProfileLoadSuccess) {
                      user = userState.user;
                    } else {
                      user = User(id: _getUserIdFromContext(context), name: '', userName: '', email: '');
                    }

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(post.title ?? 'Service Post'),
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back),
                          onPressed: backHandler,
                        ),
                      ),
                      body: ServicePostCardView(
                        userProfileId: user.id,
                        servicePost: post,
                        canViewProfile: true,
                        user: user,
                        onPostDeleted: backHandler,
                        isFromDeepLink: isFromDeepLink,
                        noAppBar: true,
                      ),
                    );
                  }
                }

                // Loading state
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Loading Post'),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: backHandler,
                    ),
                  ),
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          );
        }
    );
  }

// Helper function to get userId from context
  static int _getUserIdFromContext(BuildContext context) {
    try {
      // Try to get from authentication bloc
      final authState = context.read<AuthenticationBloc>().state;
      if (authState is AuthenticationSuccess && authState.userId != null) {
        return authState.userId!;
      }

      // Try to get from user profile bloc
      final userProfileState = context.read<UserProfileBloc>().state;
      if (userProfileState is UserProfileLoadSuccess) {
        return userProfileState.user.id;
      }
    } catch (e) {
      DebugLogger.log('Error getting user ID: $e', category: 'NAVIGATION');
    }

    // Default fallback
    return 0;
  }
  // Helper to navigate to home from deep link
  static void _navigateToHomeFromDeepLink(BuildContext context, SharedPreferences? prefs) {
    if (context.mounted) {
      try {
        int userId = 0;

        // Try to get userId from various sources
        if (prefs != null) {
          userId = prefs.getInt('userId') ?? 0;
        }

        if (userId == 0) {
          // Try to get from authentication bloc
          final authState = BlocProvider.of<AuthenticationBloc>(context).state;
          if (authState is AuthenticationSuccess && authState.userId != null) {
            userId = authState.userId!;
          }
        }

        if (userId == 0) {
          // Try to get from navigation service history
          final navigationService = serviceLocator<NavigationService>();
          if (navigationService.hasRouteInHistory('home')) {
            final args = navigationService.getRouteHistoryArgs('home');
            userId = args?['userId'] as int? ?? 0;
          }
        }

        // If we have a userId, navigate to home
        if (userId > 0) {
          Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.home,
                  (route) => false,
              arguments: {'userId': userId}
          );
          DebugLogger.log('Navigated to home with userId: $userId from deep link',
              category: 'NAVIGATION');
        } else {
          // As a last resort, just try to go to login
          Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.login,
                  (route) => false
          );
          DebugLogger.log('Navigated to login from deep link (no userId found)',
              category: 'NAVIGATION');
        }
      } catch (e) {
        DebugLogger.log('Error navigating to home from deep link: $e',
            category: 'NAVIGATION_ERROR');

        // As a last resort, just try to go to login
        Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.login,
                (route) => false
        );
      }
    }
  }

  // Handle home route
  static Route<dynamic> _handleHomeRoute(Map<String, dynamic>? args) {
    final userId = args?['userId'] as int?;
    if (userId == null) {
      DebugLogger.log('❌ UserId is required for HomeScreen',
          category: 'NAVIGATION');
      return _errorRoute('UserId is required for HomeScreen');
    }

    // Reset all navigation state
    resetNavigationState();

    // Create home page
    final page = Builder(builder: (context) {
      // Clear any pending deep links
      DeepLinkService().clearPendingDeepLinks();
      return HomeScreen(userId: userId);
    });

    return _createRoute(page, RouteSettings(name: home, arguments: args));
  }

  // Error route
  static Route<dynamic> _errorRoute(String message) {
    DeepLinkDiagnostics().addEvent('Error route triggered', details: message, isError: true);

    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Navigate to diagnostic screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DeepLinkDiagnosticsScreen(),
                    ),
                  );
                },
                child: const Text('View Diagnostic Information'),
              ),
            ],
          ),
        ),
      ),
    );
  }
// In Routes class
  static bool _openingFromDeepLink = false;

  static void setOpeningFromDeepLink(bool value) {
    _openingFromDeepLink = value;
    DebugLogger.log('Routes openingFromDeepLink set to: $value',
        category: 'NAVIGATION');
  }

  static bool get isOpeningFromDeepLink => _openingFromDeepLink;
  // Handle post load failures
  static void _handlePostLoadFailure(BuildContext context, String postId,
      {bool isReel = false}) {
    final linkType =
    isReel ? DeepLinkService.TYPE_REELS : DeepLinkService.TYPE_SERVICE_POST;

    // Mark as invalid to prevent future attempts
    SharedPreferences.getInstance().then((prefs) {
      final invalidLinks = prefs.getStringList('invalid_deep_links') ?? [];

      if (!invalidLinks.contains('$linkType/$postId')) {
        invalidLinks.add('$linkType/$postId');
        prefs.setStringList('invalid_deep_links', invalidLinks);
        DebugLogger.log('Marked $linkType/$postId as invalid',
            category: 'NAVIGATION');
      }
    });

    // Clear pending deep links
    DeepLinkService().clearPendingDeepLinks();

    // Show error message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isReel ? 'Reel #$postId not found' : 'Post #$postId not found'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Go Home',
            onPressed: () {
              final authState =
                  BlocProvider.of<AuthenticationBloc>(context).state;
              if (authState is AuthenticationSuccess) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                    Routes.home, (route) => false,
                    arguments: {'userId': authState.userId});
              }
            },
          ),
        ),
      );

      // Auto-navigate back
      Future.delayed(Duration(milliseconds: 200), () {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  // Helper method for post not found screen
  static Widget _buildPostNotFoundScreen(BuildContext context, String type) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$type Not Found'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text('The requested $type could not be found'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation helper methods
  static void navigateToHome(BuildContext context, int userId) {
    // Reset navigation state
    resetNavigationState();

    // Clear pending deep links
    DeepLinkService().clearPendingDeepLinks();

    Navigator.of(context).pushNamedAndRemoveUntil(
      home,
          (route) => false,
      arguments: {'userId': userId},
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, login);
  }

  static void navigateToRegister(BuildContext context) {
    Navigator.pushReplacementNamed(context, register);
  }

  static void navigateToLanguage(BuildContext context) {
    Navigator.pushNamed(context, language);
  }

  static void navigateToResetPassword(BuildContext context) {
    Navigator.pushNamed(context, resetPassword);
  }

  static void navigateToServicePost(BuildContext context, String postId) {
    // Check if already navigating
    if (_activeRoutes.contains('service-post-$postId')) {
      DebugLogger.log('Already navigating to service post: $postId',
          category: 'NAVIGATION');
      return;
    }

    Navigator.pushNamed(
      context,
      servicePost,
      arguments: {'postId': postId},
    );
  }

  static void navigateToReels(BuildContext context, String postId, int userId) {
    // Check if already navigating
    if (_activeRoutes.contains('reels-$postId') ||
        ReelsStateManager().isScreenActive(postId)) {
      DebugLogger.log('Already navigating to reels: $postId',
          category: 'NAVIGATION');
      return;
    }

    // Store selection in preferences for better coordination with home screen
    SharedPreferences.getInstance().then((prefs) async {
      // Store that we need to select the reels category
      await prefs.setInt('pending_select_category', 7);
      await prefs.setString('pending_reel_id', postId);

      DebugLogger.log('Stored pending reel selection: $postId',
          category: 'NAVIGATION');

      // Navigate
      Navigator.pushNamed(
        context,
        reels,
        arguments: {'postId': postId, 'userId': userId},
      );
    }).catchError((e) {
      // Fallback to direct navigation
      DebugLogger.log('Error storing reel preference: $e',
          category: 'NAVIGATION');

      Navigator.pushNamed(
        context,
        reels,
        arguments: {'postId': postId, 'userId': userId},
      );
    });

    // Clear any pending deep links
    DeepLinkService().clearPendingDeepLinks();
  }

  // Check if string is numeric
  static bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return int.tryParse(str) != null;
  }
}