import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/routes.dart';
import 'package:talabna/utils/debug_logger.dart';

/// Central service for handling all navigation in the app
/// This includes both deep links and internal navigation
class NavigationService {
  // Singleton pattern
  static final NavigationService _instance = NavigationService._internal();

  factory NavigationService() => _instance;

  NavigationService._internal();

  // Deep link types
  static const String TYPE_SERVICE_POST = 'service-post';
  static const String TYPE_REELS = 'reels';

  // Navigation key for routing
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // State tracking
  bool _isProcessingDeepLink = false;
  bool _appReady = false;
  int? _preAuthenticatedUserId;
  final List<_PendingNavigation> _pendingNavigations = [];
  Timer? _processingLockTimer;
  Timer? _queueProcessingTimer;

  // Deep link state getters
  bool get isProcessingDeepLink => _isProcessingDeepLink;

  bool get isAppReady => _appReady;

  // Initialize the service with navigator key
  void initialize(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    DebugLogger.log('Navigation service initialized with navigator key',
        category: 'NAVIGATION');

    // Start queue processor
    _startQueueProcessor();
  }

  // Set app as ready to process deep links
  void setAppReady() {
    _appReady = true;
    DebugLogger.log('App marked ready for navigation', category: 'NAVIGATION');

    // Process any pending navigations
    Future.delayed(Duration(milliseconds: 300), () {
      _processNextPendingNavigation();
    });
  }

  // Set pre-authenticated user ID
  void setPreAuthenticated(int userId) {
    _preAuthenticatedUserId = userId;
    DebugLogger.log('Pre-authenticated with user ID: $userId',
        category: 'NAVIGATION');

    // Check for pending navigations if app is ready
    if (_appReady) {
      Future.delayed(Duration(milliseconds: 300), () {
        _processNextPendingNavigation();
      });
    }
  }

  // Start periodic queue processor
  void _startQueueProcessor() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (!_isProcessingDeepLink) {
        _processNextPendingNavigation();
      }
    });
  }

  // Force release navigation locks
  void forceReleaseLocks() {
    _isProcessingDeepLink = false;
    _processingLockTimer?.cancel();
    DebugLogger.log('Navigation locks forcefully released',
        category: 'NAVIGATION');
  }

  // Process a deep link string
  Future<bool> processDeepLink(String link) async {
    DebugLogger.log('Processing deep link: $link', category: 'NAVIGATION');

    final linkData = _extractLinkData(link);
    if (linkData == null) {
      DebugLogger.log('Could not extract data from link: $link',
          category: 'NAVIGATION');
      return false;
    }

    final type = linkData.type;
    final id = linkData.id;

    DebugLogger.log('Extracted deep link data: type=$type, id=$id',
        category: 'NAVIGATION');

    // Store in SharedPreferences for persistence
    await _storeDeepLinkData(type, id);

    // Handle based on app readiness
    if (_appReady && !_isProcessingDeepLink) {
      return await _navigateToContent(type, id);
    } else {
      // Queue for later processing
      _pendingNavigations
          .add(_PendingNavigation(type: type, id: id, isDeepLink: true));
      DebugLogger.log('App not ready, queued navigation: $type/$id',
          category: 'NAVIGATION');
      return true;
    }
  }

  // Extract link data from a deep link
  _LinkData? _extractLinkData(String link) {
    try {
      Uri uri = Uri.parse(link);
      String? type;
      String? id;

      // Handle talabna:// scheme
      if (link.startsWith('talabna://')) {
        final pathSegments = uri.pathSegments;

        if (pathSegments.isNotEmpty) {
          if (pathSegments.length >= 2) {
            // Handle talabna://reels/123 format
            type = pathSegments[0];
            id = pathSegments[1];
          } else if (pathSegments.length == 1 && _isNumeric(pathSegments[0])) {
            // Handle talabna://123 format (just an ID)
            type = link.toLowerCase().contains('reel')
                ? TYPE_REELS
                : TYPE_SERVICE_POST;
            id = pathSegments[0];
          }
        }
      }
      // Handle regular URLs
      else if (uri.pathSegments.isNotEmpty) {
        for (final segment in uri.pathSegments) {
          if (_isNumeric(segment)) {
            id = segment;
            type = link.toLowerCase().contains('reel')
                ? TYPE_REELS
                : TYPE_SERVICE_POST;
            break;
          }
        }
      }

      // Normalize the type
      if (type != null) {
        if (type == 'reels' || type == 'reel') {
          type = TYPE_REELS;
        } else if (type == 'service-post' ||
            type == 'service_post' ||
            type == 'post') {
          type = TYPE_SERVICE_POST;
        }
      }

      if (type != null && id != null) {
        return _LinkData(type: type, id: id);
      }

      return null;
    } catch (e) {
      DebugLogger.log('Error extracting link data: $e', category: 'NAVIGATION');
      return null;
    }
  }

  // Store deep link data in SharedPreferences
  Future<void> _storeDeepLinkData(String type, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_deep_link_type', type);
      await prefs.setString('pending_deep_link_id', id);

      // Special storage for reels
      if (type == TYPE_REELS) {
        await prefs.setInt(
            'pending_select_category', 7); // 7 is the reels category
        await prefs.setString('pending_reel_id', id);
        await prefs.setBool('direct_deeplink_active', true);
      }

      DebugLogger.log('Stored deep link data: $type/$id',
          category: 'NAVIGATION');
    } catch (e) {
      DebugLogger.log('Error storing deep link data: $e',
          category: 'NAVIGATION');
    }
  }

  // Clear stored deep link data
  Future<void> clearPendingDeepLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_deep_link_type');
      await prefs.remove('pending_deep_link_id');
      await prefs.remove('pending_select_category');
      await prefs.remove('pending_reel_id');
      await prefs.setBool('direct_deeplink_active', false);

      DebugLogger.log('Cleared deep link data', category: 'NAVIGATION');
    } catch (e) {
      DebugLogger.log('Error clearing deep link data: $e',
          category: 'NAVIGATION');
    }
  }

  // Navigate to a specific content
  Future<bool> _navigateToContent(String type, String id) async {
    if (_navigatorKey.currentState == null) {
      DebugLogger.log('Navigator key not valid', category: 'NAVIGATION');
      return false;
    }

    // Set processing flag
    _isProcessingDeepLink = true;
    _setProcessingLockTimeout();

    try {
      // Get user ID
      final int userId = _preAuthenticatedUserId ?? await _getUserIdFromPrefs();

      // Ensure Routes is not processing the same navigation
      Routes.resetNavigationState();

      // Handle based on content type
      if (type == TYPE_REELS) {
        DebugLogger.log('Navigating to reel: $id', category: 'NAVIGATION');

        // If we're on the home screen, store info and let it handle the navigation
        if (_navigatorKey.currentState!.canPop()) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_reel_id', id);
          await prefs.setInt('pending_select_category', 7);
          await prefs.setBool('direct_deeplink_active', true);

          // Schedule release of lock
          Future.delayed(Duration(milliseconds: 500), () {
            _isProcessingDeepLink = false;
          });

          return true;
        }

        // Direct navigation to reels screen
        // We need to use the home route first, then let it handle reels navigation
        _navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
          arguments: {'userId': userId},
        );

        return true;
      } else if (type == TYPE_SERVICE_POST) {
        DebugLogger.log('Navigating to service post: $id',
            category: 'NAVIGATION');

        // Navigate to service post screen
        _navigatorKey.currentState!.pushNamed(
          '/service-post',
          arguments: {'postId': id, 'fromDeepLink': true},
        );

        return true;
      }

      return false;
    } catch (e) {
      DebugLogger.log('Error navigating to content: $e',
          category: 'NAVIGATION');
      return false;
    } finally {
      // Reset processing flag after delay
      _processingLockTimer?.cancel();
      _processingLockTimer = Timer(Duration(milliseconds: 800), () {
        _isProcessingDeepLink = false;
      });
    }
  }

  // Process next pending navigation
  void _processNextPendingNavigation() {
    if (!_appReady || _isProcessingDeepLink || _pendingNavigations.isEmpty) {
      return;
    }

    final navigation = _pendingNavigations.removeAt(0);
    _navigateToContent(navigation.type, navigation.id);
  }

  // Set a timeout for the processing lock
  void _setProcessingLockTimeout() {
    _processingLockTimer?.cancel();
    _processingLockTimer = Timer(Duration(seconds: 5), () {
      if (_isProcessingDeepLink) {
        _isProcessingDeepLink = false;
        DebugLogger.log('Navigation processing lock timed out',
            category: 'NAVIGATION');
      }
    });
  }

  // Get user ID from SharedPreferences
  Future<int> _getUserIdFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('userId') ?? 0;
    } catch (e) {
      DebugLogger.log('Error getting user ID from prefs: $e',
          category: 'NAVIGATION');
      return 0;
    }
  }

  // Helper method to check if string is numeric
  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return int.tryParse(str) != null;
  }

  // Navigation methods that use Routes

  // Navigate to home screen
  void navigateToHome(BuildContext context, int userId) {
    Routes.navigateToHome(context, userId);
  }

  // Navigate to home with route replacement
  void navigateToHomeAndRemoveUntil(BuildContext context, int userId) {
    if (_navigatorKey.currentState != null) {
      _navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'userId': userId},
      );
    } else {
      // Fallback to the regular method
      Routes.navigateToHome(context, userId);
    }
  }

  // Navigate to login screen
  void navigateToLogin(BuildContext context) {
    Routes.navigateToLogin(context);
  }

  // Navigate to register screen
  void navigateToRegister(BuildContext context) {
    Routes.navigateToRegister(context);
  }

  // Navigate to language selection screen
  void navigateToLanguage(BuildContext context) {
    Routes.navigateToLanguage(context);
  }

  // Navigate to reset password screen
  void navigateToResetPassword(BuildContext context) {
    Routes.navigateToResetPassword(context);
  }

  // Navigate to service post screen
  void navigateToServicePost(BuildContext context, String postId) {
    Routes.navigateToServicePost(context, postId);
  }

  // Navigate to reels screen
  void navigateToReels(BuildContext context, String postId, int userId) {
    Routes.navigateToReels(context, postId, userId);
  }

  // Clean up resources
  void dispose() {
    _processingLockTimer?.cancel();
    _queueProcessingTimer?.cancel();
  }
}

// Helper classes
class _LinkData {
  final String type;
  final String id;

  _LinkData({required this.type, required this.id});
}

class _PendingNavigation {
  final String type;
  final String id;
  final bool isDeepLink;

  _PendingNavigation(
      {required this.type, required this.id, this.isDeepLink = false});
}
