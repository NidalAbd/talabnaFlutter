import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/core/service_locator.dart';

class FontSizeService {
  // Keys for shared preferences
  static const String _postDescriptionFontSizeKey = 'post_description_font_size';

  // Default font sizes
  static const double defaultDescriptionFontSize = 14.0;

  // Minimum and maximum font sizes
  static const double minFontSize = 12.0;
  static const double maxFontSize = 24.0;

  // Get the current description font size
  static Future<double> getDescriptionFontSize() async {
    final prefs = serviceLocator<SharedPreferences>();
    return prefs.getDouble(_postDescriptionFontSizeKey) ?? defaultDescriptionFontSize;
  }

  // Set a new description font size
  static Future<bool> setDescriptionFontSize(double size) async {
    final prefs = serviceLocator<SharedPreferences>();
    // Ensure the size is within allowed bounds
    double newSize = size.clamp(minFontSize, maxFontSize);
    return await prefs.setDouble(_postDescriptionFontSizeKey, newSize);
  }

  // Increase font size by 1 point
  static Future<double> increaseFontSize() async {
    double currentSize = await getDescriptionFontSize();
    double newSize = (currentSize + 1).clamp(minFontSize, maxFontSize);
    await setDescriptionFontSize(newSize);
    return newSize;
  }

  // Decrease font size by 1 point
  static Future<double> decreaseFontSize() async {
    double currentSize = await getDescriptionFontSize();
    double newSize = (currentSize - 1).clamp(minFontSize, maxFontSize);
    await setDescriptionFontSize(newSize);
    return newSize;
  }

  // Reset to default
  static Future<double> resetFontSize() async {
    await setDescriptionFontSize(defaultDescriptionFontSize);
    return defaultDescriptionFontSize;
  }
}