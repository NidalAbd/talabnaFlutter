import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/core/service_locator.dart';
import 'package:talabna/routes.dart';
import 'package:talabna/utils/debug_logger.dart';

import 'navigation_service.dart';

class DeepLinkInitializer {
  // Initialize deep links
  static Future<bool> initialize() async {
    try {
      DebugLogger.log('Initializing deep links', category: 'DEEPLINK');

      // Get navigation service
      final navigationService = serviceLocator<NavigationService>();

      // Create AppLinks instance
      final appLinks = AppLinks();

      // Get initial link that may have opened the app
      String? initialLink;
      try {
        final Uri? initialUri = await appLinks.getInitialLink();
        initialLink = initialUri?.toString();
        if (initialLink != null) {
          DebugLogger.log('Initial deep link: $initialLink',
              category: 'DEEPLINK');

          // Store deep link info in shared preferences for persistence
          await _storeDeepLinkInfo(initialLink);

          // Return true to indicate app was opened with deep link
          return true;
        }
      } catch (e) {
        DebugLogger.log('Error getting initial link: $e', category: 'DEEPLINK');
      }

      // Listen for links while app is running
      appLinks.uriLinkStream.listen((Uri uri) {
        final link = uri.toString();
        DebugLogger.log('Received deep link: $link', category: 'DEEPLINK');

        // Process the link with special handling to prevent loading screen flashing
        _processDynamicLink(link);
      }, onError: (error) {
        DebugLogger.log('Deep link stream error: $error', category: 'DEEPLINK');
      });

      DebugLogger.log('Deep link initialization complete',
          category: 'DEEPLINK');

      return false; // No initial deep link
    } catch (e) {
      DebugLogger.log('Error initializing deep links: $e',
          category: 'DEEPLINK');
      return false;
    }
  }

  // Store deep link information for persistence
  static Future<void> _storeDeepLinkInfo(String link) async {
    try {
      final linkData = _extractLinkData(link);
      if (linkData != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_deep_link_type', linkData['type']!);
        await prefs.setString('pending_deep_link_id', linkData['id']!);

        // Set flag to indicate direct deep link
        await prefs.setBool('direct_deeplink_active', true);

        // Special handling for reels
        if (linkData['type'] == 'reels') {
          await prefs.setInt('pending_select_category', 7); // 7 = reels category
          await prefs.setString('pending_reel_id', linkData['id']!);
        }

        DebugLogger.log('Stored deep link: ${linkData['type']}/${linkData['id']}',
            category: 'DEEPLINK');
      }
    } catch (e) {
      DebugLogger.log('Error storing deep link info: $e', category: 'DEEPLINK');
    }
  }

  // Process a dynamic link without navigation state issues
  static void _processDynamicLink(String link) {
    try {
      final linkData = _extractLinkData(link);
      if (linkData == null) return;

      // Store for persistence
      _storeDeepLinkInfo(link);

      // Get navigator context
      final NavigationService navigationService = serviceLocator<NavigationService>();
      final NavigatorState? navigator = navigationService.navigatorKey.currentState;

      if (navigator == null) {
        DebugLogger.log('No valid navigator for deep link', category: 'DEEPLINK');
        return;
      }

      // Process based on link type
      if (linkData['type'] == 'service-post') {
        // Special handling to prevent navigation issues
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigator.pushNamedAndRemoveUntil(
            '/service-post',
                (route) => false, // Clear all routes
            arguments: {
              'postId': linkData['id'],
              'fromDeepLink': true,
              'preventAutoNavigateBack': true, // New flag to prevent auto-back
            },
          );
        });
      } else if (linkData['type'] == 'reels') {
        // Handle reels links
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigator.pushNamedAndRemoveUntil(
            '/reels',
                (route) => false, // Clear all routes
            arguments: {
              'postId': linkData['id'],
              'isReel': true,
              'fromDeepLink': true,
            },
          );
        });
      }
    } catch (e) {
      DebugLogger.log('Error processing dynamic link: $e', category: 'DEEPLINK');
    }
  }

  // Extract type and ID from a link
  static Map<String, String>? _extractLinkData(String link) {
    try {
      Uri uri = Uri.parse(link);
      String? type;
      String? id;

      // Handle talabna:// scheme
      if (link.startsWith('talabna://')) {
        if (uri.pathSegments.isNotEmpty) {
          if (uri.host == 'service-post' && uri.pathSegments.length >= 1) {
            type = 'service-post';
            id = uri.pathSegments[0];
          } else if (uri.host == 'reels' && uri.pathSegments.length >= 1) {
            type = 'reels';
            id = uri.pathSegments[0];
          } else if (uri.pathSegments.length == 1 && _isNumeric(uri.pathSegments[0])) {
            // Handle talabna://123 format (just an ID)
            type = link.toLowerCase().contains('reel') ? 'reels' : 'service-post';
            id = uri.pathSegments[0];
          }
        }
      }
      // Handle https://talbna.cloud/api/deep-link/* URLs
      else if (link.contains('talbna.cloud/api/deep-link/')) {
        final pathSegments = uri.pathSegments;
        // "/api/deep-link/reels/123" -> ["api", "deep-link", "reels", "123"]
        if (pathSegments.length >= 4 &&
            pathSegments[0] == 'api' &&
            pathSegments[1] == 'deep-link') {
          type = pathSegments[2];
          id = pathSegments[3];
        }
      }
      // Handle direct numeric IDs
      else if (uri.pathSegments.isNotEmpty) {
        for (final segment in uri.pathSegments) {
          if (_isNumeric(segment)) {
            id = segment;
            type = link.toLowerCase().contains('reel') ? 'reels' : 'service-post';
            break;
          }
        }
      }

      // Normalize the type
      if (type != null) {
        if (type == 'reels' || type == 'reel') {
          type = 'reels';
        } else if (type == 'service-post' ||
            type == 'service_post' ||
            type == 'post') {
          type = 'service-post';
        }
      }

      if (type != null && id != null) {
        return {'type': type, 'id': id};
      }

      return null;
    } catch (e) {
      DebugLogger.log('Error extracting link data: $e', category: 'DEEPLINK');
      return null;
    }
  }

  // Helper to check if string is numeric
  static bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return int.tryParse(str) != null;
  }
}