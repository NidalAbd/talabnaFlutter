import 'package:app_links/app_links.dart';
import 'package:talabna/core/service_locator.dart';
import 'package:talabna/utils/debug_logger.dart';

import 'navigation_service.dart';

class DeepLinkInitializer {
  // Initialize deep links
  static Future<void> initialize() async {
    try {
      DebugLogger.log('Initializing deep links', category: 'DEEPLINK');

      // Get navigation service
      final navigationService = serviceLocator<NavigationService>();

      // Create AppLinks instance
      final appLinks = AppLinks();

      // Get initial link that may have opened the app
      String? initialLink;
      try {
        initialLink = await appLinks.getInitialLinkString();
        if (initialLink != null) {
          DebugLogger.log('Initial deep link: $initialLink',
              category: 'DEEPLINK');
        }
      } catch (e) {
        DebugLogger.log('Error getting initial link: $e', category: 'DEEPLINK');
      }

      // Process initial link if available
      if (initialLink != null) {
        await navigationService.processDeepLink(initialLink);
      }

      // Listen for links while app is running
      appLinks.stringLinkStream.listen((String? link) {
        if (link != null) {
          DebugLogger.log('Received deep link: $link', category: 'DEEPLINK');
          navigationService.processDeepLink(link);
        }
      }, onError: (error) {
        DebugLogger.log('Deep link stream error: $error', category: 'DEEPLINK');
      });

      DebugLogger.log('Deep link initialization complete',
          category: 'DEEPLINK');
    } catch (e) {
      DebugLogger.log('Error initializing deep links: $e',
          category: 'DEEPLINK');
    }
  }
}
