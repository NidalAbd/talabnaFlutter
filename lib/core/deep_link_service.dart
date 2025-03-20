import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/utils/debug_logger.dart';
import '../blocs/service_post/service_post_bloc.dart';
import '../blocs/service_post/service_post_event.dart';
import '../core/service_locator.dart';
import 'navigation_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;

  DeepLinkService._internal();

  // Link types
  static const String TYPE_SERVICE_POST = 'service-post';
  static const String TYPE_REELS = 'reels';
  static const String TYPE_USER = 'user';
  static const String TYPE_CATEGORY = 'category';

  // State management
  bool _isInitialized = false;
  bool _appReady = false;
  bool _isProcessingDeepLink = false;

  // Link handling
  StreamSubscription<Uri>? _deepLinkSubscription;
  String? _initialLink;
  bool _initialLinkProcessed = false;
  final List<Map<String, String>> _pendingDeepLinks = [];

  // Timers and locks
  Timer? _processingLockTimer;
  Timer? _queueProcessingTimer;

  // AppLinks instance
  final AppLinks _appLinks = AppLinks();

  // Public getters
  bool get isProcessingDeepLink => _isProcessingDeepLink;

  String? get initialLink => _initialLink;

  // Initialize deep link service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      DebugLogger.log('Initializing DeepLinkService', category: 'DEEPLINK');

      // Get initial link that opened the app
      try {
        Uri? initialUri = await _appLinks.getInitialLink();
        _initialLink = initialUri.toString();

        if (_initialLink != null) {
          DebugLogger.log('Initial deep link: $_initialLink',
              category: 'DEEPLINK');

          // Debug link info
          _debugLinkInfo(_initialLink!);

          // Safely process the initial link data
          final linkData = _processLinkData(_initialLink!);
          if (linkData != null) {
            // Store in SharedPreferences for persistence
            await _storeDeepLinkData(linkData['type']!, linkData['id']!);

            // Mark as direct deep link to prevent lock releases
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('direct_deeplink_active', true);

            // Preload content for better performance
            if (linkData['type'] == TYPE_REELS) {
              _preloadContent(linkData['id']!);
            }
          }
        }
      } catch (e) {
        DebugLogger.log('Error getting initial link: $e', category: 'DEEPLINK');
      }

      // Listen for deep links when app is running
      _deepLinkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleIncomingLink(uri.toString());
      }, onError: (error) {
        DebugLogger.log('Deep link error: $error', category: 'DEEPLINK');
      });

      _isInitialized = true;

      // Start queue processor for pending links
      _startQueueProcessor(initialDelay: Duration(milliseconds: 500));

      DebugLogger.log('DeepLinkService initialization complete',
          category: 'DEEPLINK');
    } catch (e) {
      DebugLogger.log('Error initializing deep links: $e',
          category: 'DEEPLINK');
    }
  }

  // Debug helper for link information
  void _debugLinkInfo(String link) {
    try {
      Uri uri = Uri.parse(link);
      DebugLogger.log('URI scheme: ${uri.scheme}', category: 'DEEPLINK');
      DebugLogger.log('URI host: ${uri.host}', category: 'DEEPLINK');
      DebugLogger.log('URI path: ${uri.path}', category: 'DEEPLINK');
      DebugLogger.log('URI segments: ${uri.pathSegments}',
          category: 'DEEPLINK');
    } catch (e) {
      DebugLogger.log('Error parsing link URI: $e', category: 'DEEPLINK');
    }
  }

  // Handle incoming deep links
  void _handleIncomingLink(String? link) {
    if (link == null) return;

    DebugLogger.log('Runtime deep link received: $link', category: 'DEEPLINK');
    _debugLinkInfo(link);

    final linkData = _processLinkData(link);
    if (linkData != null) {
      final type = linkData['type'];
      final id = linkData['id'];

      if (type != null && id != null) {
        // Store for persistence
        _storeDeepLinkData(type, id);

        // Process or queue based on app state
        if (_appReady && !_isProcessingDeepLink) {
          // App is ready, notify navigation service
          final navigationService = serviceLocator<NavigationService>();
          navigationService.processDeepLink('$type/$id');
        } else {
          // Queue for later processing
          _pendingDeepLinks.add({'type': type, 'id': id});
          DebugLogger.log('App not ready, queued navigation: $type/$id',
              category: 'DEEPLINK');
        }
      }
    }
  }

  // Process and extract link data
  Map<String, String>? _processLinkData(String link) {
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
      // Handle https://talbna.cloud/api/deep-link/* URLs
      else if (link.startsWith('https://talbna.cloud/api/deep-link/')) {
        final pathSegments = uri.pathSegments;
        // "/api/deep-link/reels/123" -> ["api", "deep-link", "reels", "123"]
        if (pathSegments.length >= 4 &&
            pathSegments[0] == 'api' &&
            pathSegments[1] == 'deep-link') {
          type = pathSegments[2];
          id = pathSegments[3];
        }
      }
      // Handle other URLs
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
        } else if (type == 'user' || type == 'profile') {
          type = TYPE_USER;
        } else if (type == 'category' || type == 'cat') {
          type = TYPE_CATEGORY;
        }
      }

      if (type != null && id != null) {
        DebugLogger.log('Extracted deep link data: type=$type, id=$id',
            category: 'DEEPLINK');
        return {'type': type, 'id': id};
      }

      return null;
    } catch (e) {
      DebugLogger.log('Error processing link data: $e', category: 'DEEPLINK');
      return null;
    }
  }

  // Preload content for better performance
  void _preloadContent(String id) {
    try {
      if (serviceLocator.isRegistered<ServicePostBloc>()) {
        final servicePostBloc = serviceLocator<ServicePostBloc>();

        // Start loading content early
        DebugLogger.log('Preloading content for ID: $id', category: 'DEEPLINK');
        servicePostBloc.add(GetServicePostByIdEvent(
          int.parse(id),
          forceRefresh: false,
        ));
      }
    } catch (e) {
      // Just log errors, don't interrupt flow
      DebugLogger.log('Error preloading content: $e', category: 'DEEPLINK');
    }
  }

  // Store pending deep link
  Future<void> storePendingDeepLink(String type, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_deep_link_type', type);
    await prefs.setString('pending_deep_link_id', id);

    // If this is a reels deep link, mark it for processing
    if (type == TYPE_REELS) {
      await prefs.setInt('pending_select_category', 7);
      await prefs.setString('pending_reel_id', id);
    }

    DebugLogger.log('Stored pending deep link: $type/$id',
        category: 'DEEPLINK');
  }

  // Store deep link data for persistence
  Future<void> _storeDeepLinkData(String type, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_deep_link_type', type);
      await prefs.setString('pending_deep_link_id', id);

      // Special handling for reels
      if (type == TYPE_REELS) {
        await prefs.setInt('pending_select_category', 7); // 7 = reels category
        await prefs.setString('pending_reel_id', id);
        await prefs.setBool('direct_deeplink_active', true);
      }

      DebugLogger.log('Stored deep link data: $type/$id', category: 'DEEPLINK');
    } catch (e) {
      DebugLogger.log('Error storing deep link data: $e', category: 'DEEPLINK');
    }
  }

  // Process queue of pending links
  void _startQueueProcessor({Duration? initialDelay}) {
    _queueProcessingTimer?.cancel();

    // Use default or provided delay
    final delay = initialDelay ?? Duration(seconds: 2);

    // First check sooner for better UX
    Timer(delay, () {
      _processNextPendingLink();

      // Then regular interval checks
      _queueProcessingTimer = Timer.periodic(Duration(seconds: 2), (_) {
        _processNextPendingLink();
      });
    });
  }

  // Process next link in queue
  void _processNextPendingLink() {
    if (!_appReady || _isProcessingDeepLink || _pendingDeepLinks.isEmpty) {
      return;
    }

    final linkData = _pendingDeepLinks.removeAt(0);
    final navigationService = serviceLocator<NavigationService>();
    navigationService.processDeepLink('${linkData['type']}/${linkData['id']}');
  }

  // Check for pending deep links
  Future<void> checkPendingDeepLinks() async {
    if (!_appReady || _isProcessingDeepLink) {
      return;
    }

    try {
      // Set processing flag
      _isProcessingDeepLink = true;

      // First check initial link
      if (_initialLink != null && !_initialLinkProcessed) {
        _initialLinkProcessed = true;
        final navigationService = serviceLocator<NavigationService>();
        navigationService.processDeepLink(_initialLink!);
        return;
      }

      // Then check stored links
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('pending_deep_link_type');
      final id = prefs.getString('pending_deep_link_id');

      if (type != null && id != null) {
        // Clear before processing to prevent duplicates
        await prefs.remove('pending_deep_link_type');
        await prefs.remove('pending_deep_link_id');

        final navigationService = serviceLocator<NavigationService>();
        navigationService.processDeepLink('$type/$id');
      } else {
        // Release lock if nothing to process
        _isProcessingDeepLink = false;
      }
    } catch (e) {
      DebugLogger.log('Error checking pending links: $e', category: 'DEEPLINK');
      _isProcessingDeepLink = false;
    }
  }

  // Mark app as ready to process links
  void setAppReady() {
    _appReady = true;
    DebugLogger.log('Deep link handler ready for navigation',
        category: 'DEEPLINK');

    // Process any pending links with slight delay
    Future.delayed(Duration(milliseconds: 300), () {
      checkPendingDeepLinks();
    });
  }

  // Clear all pending deep links
  Future<void> clearPendingDeepLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_deep_link_type');
      await prefs.remove('pending_deep_link_id');
      await prefs.remove('pending_select_category');
      await prefs.remove('pending_reel_id');
      await prefs.setBool('direct_deeplink_active', false);

      _pendingDeepLinks.clear();
      DebugLogger.log('Cleared all pending deep links', category: 'DEEPLINK');
    } catch (e) {
      DebugLogger.log('Error clearing deep links: $e', category: 'DEEPLINK');
    }
  }

  // Helper to check if string is numeric
  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return int.tryParse(str) != null;
  }

  // Clean up resources
  void dispose() {
    _deepLinkSubscription?.cancel();
    _processingLockTimer?.cancel();
    _queueProcessingTimer?.cancel();
  }
}
