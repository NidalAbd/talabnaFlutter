import 'package:share_plus/share_plus.dart';
import 'package:talabna/utils/constants.dart';
import 'package:talabna/utils/debug_logger.dart';

class ShareUtils {
  // Constants for link types
  static const String TYPE_REELS = "reels";
  static const String TYPE_SERVICE_POST = "service-post";
  static const String TYPE_POST = "post";

  // Main sharing method with type parameter
  static Future<void> shareContent(int postId,
      {String? title, required String type}) async {
    try {
      // Create deep link URL for app users
      String deepLink;
      if (type == TYPE_REELS) {
        deepLink = 'talabna://reels/$postId';
      } else {
        deepLink = 'talabna://service-post/$postId';
      }

      // Create web URL that will be recognized as a clickable link
      String webUrl = '${Constants.apiBaseUrl}/api/deep-link/$type/$postId';

      // Format the title for sharing
      String contentType = type == TYPE_REELS ? 'reel' : 'post';
      String postTitle =
          title != null && title.isNotEmpty ? title : 'this $contentType';

      // Build share text with the link on its own line so it's recognized as clickable
      String shareText = 'Check out $postTitle\n\n$webUrl';

      await Share.share(
        shareText,
        subject: title ?? 'Shared $contentType from Talabna',
      );

      DebugLogger.log('Shared $type with ID: $postId, Title: $title',
          category: 'SHARE');
    } catch (e) {
      DebugLogger.log('Error sharing $type: $e', category: 'SHARE');
    }
  }

  // Helper methods for specific content types
  static Future<void> shareReel(int postId, {String? title}) async {
    await shareContent(postId, title: title, type: TYPE_REELS);
  }

  static Future<void> shareServicePost(int postId, {String? title}) async {
    await shareContent(postId, title: title, type: TYPE_SERVICE_POST);
  }

  static Future<void> sharePost(int postId, {String? title}) async {
    await shareContent(postId, title: title, type: TYPE_POST);
  }
}
