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
import 'package:talabna/screens/home/home_screen.dart';
import 'package:talabna/screens/home/select_language.dart';
import 'package:talabna/screens/reel/reels_screen.dart';
import 'package:talabna/screens/reel/reels_state_manager.dart';
import 'package:talabna/screens/service_post/service_post_view.dart';
import 'package:talabna/utils/debug_logger.dart';
import 'package:talabna/utils/deep_link_diagnostics.dart';

import 'core/deep_link_service.dart';
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

  // Navigation state management
  static bool _isNavigating = false;
  static final Map<String, DateTime> _navigationTimestamps = {};
  static Timer? _cleanupTimer;
  static final Set<String> _activeRoutes = {};
  static const int _navigationDebounceTime = 200; // ms

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

  // Main route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    DeepLinkDiagnostics().addEvent('Route requested', details: 'Name: ${settings.name}');

    DebugLogger.log('Routing to: ${settings.name}', category: 'NAVIGATION');

    final args = settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      DebugLogger.log('Route args: $args', category: 'NAVIGATION');
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
            final postId = args?['postId'] as String?;
            if (postId == null) {
              _isNavigating = wasNavigating;
              return _createRoute(const HomeScreen(userId: 0), settings);
            }

            // Check navigation debounce
            if (!shouldAllowNavigation('service-post', postId)) {
              _isNavigating = wasNavigating;
              return _createEmptyRoute(settings);
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

    // Get the userId safely - first from args, then from SharedPreferences
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

    // Create a unified MaterialPageRoute for all reel navigation
    return MaterialPageRoute(
      settings: RouteSettings(name: reels, arguments: args),
      maintainState: true,
      builder: (context) {
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

        // Return the ReelsHomeScreen
        return ReelsHomeScreen(
          userId: userId ?? (existingUser?.id ?? 0),
          servicePost: existingPost,
          user: existingUser ?? User(id: 0, name: '', userName: '', email: ''),
          // Minimal user data
          postId: postId,
        );
      },
    );
  }

  // Handle service post route
  static Route<dynamic> _handleServicePostRoute(Map<String, dynamic>? args) {
    final postId = args?['postId'] as String?;
    if (postId == null) {
      return _errorRoute('postId is required for ServicePost route');
    }

    // Ensure postId is numeric
    if (!_isNumeric(postId)) {
      return _errorRoute('Invalid postId format');
    }

    // Track active route
    String routeId = 'service-post-$postId';
    _activeRoutes.add(routeId);

    // Auto-cleanup
    Timer(Duration(seconds: 10), () {
      _activeRoutes.remove(routeId);
    });

    DebugLogger.log('Creating route for SERVICE POST: $postId',
        category: 'NAVIGATION');

    // Create page route
    return PageRouteBuilder(
      settings: RouteSettings(name: servicePost, arguments: args),
      pageBuilder: (context, animation, secondaryAnimation) {
        // Check for invalid links
        SharedPreferences.getInstance().then((prefs) {
          final invalidLinks = prefs.getStringList('invalid_deep_links') ?? [];
          if (invalidLinks.contains('service-post/$postId')) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Post #$postId not available')));
              Future.delayed(Duration(milliseconds: 100), () {
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              });
            }
            return;
          }

          // Load service post
          context.read<ServicePostBloc>().add(GetServicePostByIdEvent(
                int.parse(postId),
                forceRefresh: false,
              ));

          // Check authentication
          final token = prefs.getString('auth_token');
          final userId = prefs.getInt('userId');
          if (token == null || token.isEmpty || userId == null) {
            // Store deep link and navigate to login
            DeepLinkService().storePendingDeepLink(
                DeepLinkService.TYPE_SERVICE_POST, postId);
            Future.delayed(Duration(milliseconds: 100), () {
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(Routes.login);
              }
            });
            return;
          }

          // Load user profile
          context.read<UserProfileBloc>().add(UserProfileRequested(id: userId));
        });

        // Clear any pending deep links
        DeepLinkService().clearPendingDeepLinks();

        // Return the ServicePostView with error handling
        return BlocConsumer<ServicePostBloc, ServicePostState>(
          listener: (context, state) {
            if (state is ServicePostLoadFailure) {
              _handlePostLoadFailure(context, postId);
            }
          },
          builder: (context, servicePostState) {
            return BlocBuilder<UserProfileBloc, UserProfileState>(
              builder: (context, userProfileState) {
                // Success state - both loaded
                if (servicePostState is ServicePostLoadSuccess &&
                    userProfileState is UserProfileLoadSuccess) {
                  ServicePost? servicePost;
                  try {
                    servicePost = servicePostState.servicePosts
                        .firstWhere((post) => post.id == int.parse(postId));
                  } catch (_) {
                    // Post not found
                    servicePost = null;
                  }

                  if (servicePost != null) {
                    DebugLogger.log('Successfully loaded service post: $postId',
                        category: 'NAVIGATION');

                    return ServicePostCardView(
                      userProfileId: userProfileState.user.id,
                      servicePost: servicePost,
                      canViewProfile: true,
                      user: userProfileState.user,
                      onPostDeleted: () {
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    );
                  }

                  // Post not found
                  return _buildPostNotFoundScreen(context, 'Post');
                }

                // Loading state
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Loading Post...'),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            );
          },
        );
      },
      transitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
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
