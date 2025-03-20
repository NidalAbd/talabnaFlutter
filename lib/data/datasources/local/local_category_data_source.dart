import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/datasources/category_data_source.dart';
import 'package:talabna/data/models/categories_selected_menu.dart';
import 'package:talabna/data/models/category_menu.dart';
import 'package:talabna/utils/debug_logger.dart';

class LocalCategoryDataSource implements CategoryDataSource {
  final SharedPreferences sharedPreferences;

  // Static in-memory cache for fast access during app lifetime
  static Map<String, dynamic> _memoryCache = {};
  static Map<String, DateTime> _memoryCacheTimestamps = {};

  LocalCategoryDataSource({required this.sharedPreferences});

  @override
  Future<List<CategoryMenu>> getCategoryMenu() async {
    final cacheKey = 'cached_category_menu';

    // OPTIMIZATION: First check memory cache (fastest)
    if (_memoryCache.containsKey(cacheKey)) {
      DebugLogger.log('Retrieved category menu from in-memory cache',
          category: 'DATA_SOURCE');
      final cachedData = _memoryCache[cacheKey] as List<dynamic>;
      return cachedData.map((data) => CategoryMenu.fromJson(data)).toList();
    }

    try {
      final jsonString = sharedPreferences.getString(cacheKey);
      if (jsonString != null) {
        final List<dynamic> categoriesJson = json.decode(jsonString);
        final categories = categoriesJson.map((json) {
          // Convert the sanitized JSON back to CategoryMenu
          final sanitizedJson = _sanitizeCategoryMenuJson(json);
          return CategoryMenu.fromJson(sanitizedJson);
        }).toList();

        // OPTIMIZATION: Update memory cache
        _memoryCache[cacheKey] = categoriesJson;
        _memoryCacheTimestamps[cacheKey] = DateTime.now();

        DebugLogger.log(
            'Retrieved ${categories.length} category menu items from local storage',
            category: 'DATA_SOURCE');
        return categories;
      }
      return [];
    } catch (e) {
      DebugLogger.log('Error retrieving category menu from local storage: $e',
          category: 'DATA_SOURCE');
      return [];
    }
  }

  @override
  Future<List<SubCategoryMenu>> getSubCategoriesMenu(int categoryId) async {
    final cacheKey = 'cached_subcategory_menu_$categoryId';

    // OPTIMIZATION: First check memory cache (fastest)
    if (_memoryCache.containsKey(cacheKey)) {
      DebugLogger.log(
          'Retrieved subcategory menu for category $categoryId from in-memory cache',
          category: 'DATA_SOURCE');
      final cachedData = _memoryCache[cacheKey] as List<dynamic>;
      return cachedData
          .map((data) => SubCategoryMenu.fromJson(data))
          .where((item) => item != null)
          .cast<SubCategoryMenu>()
          .toList();
    }

    try {
      final jsonString = sharedPreferences.getString(cacheKey);
      if (jsonString != null) {
        final List<dynamic> subcategoriesJson = json.decode(jsonString);
        final subcategories = subcategoriesJson
            .map((json) {
              try {
                // Add try-catch for each individual conversion
                final sanitizedJson = _sanitizeSubCategoryMenuJson(json);
                return SubCategoryMenu.fromJson(sanitizedJson);
              } catch (e) {
                DebugLogger.log('Error parsing subcategory menu item: $e',
                    category: 'DATA_SOURCE');
                // Return null for items that can't be parsed
                return null;
              }
            })
            .where((item) => item != null) // Filter out null items
            .cast<SubCategoryMenu>() // Cast to expected type
            .toList();

        // OPTIMIZATION: Update memory cache
        _memoryCache[cacheKey] = subcategoriesJson;
        _memoryCacheTimestamps[cacheKey] = DateTime.now();

        DebugLogger.log(
            'Retrieved ${subcategories.length} subcategory menu items for category $categoryId from local storage',
            category: 'DATA_SOURCE');
        return subcategories;
      }
      return [];
    } catch (e) {
      DebugLogger.log(
          'Error retrieving subcategory menu from local storage: $e',
          category: 'DATA_SOURCE');
      // Return empty list on error instead of throwing
      return [];
    }
  }

  Future<void> cacheCategoryMenu(List<CategoryMenu> categories) async {
    try {
      final sanitizedCategories = categories.map((c) {
        // First convert to JSON
        final originalJson = c.toJson();
        // Then sanitize for storage
        final storableJson = _sanitizeForStorage(originalJson);
        // Finally, properly structure the data
        return _sanitizeCategoryMenuJson(storableJson);
      }).toList();

      final String jsonString = json.encode(sanitizedCategories);
      await sharedPreferences.setString('cached_category_menu', jsonString);
      await sharedPreferences.setInt('cached_category_menu_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      // OPTIMIZATION: Update memory cache
      _memoryCache['cached_category_menu'] = sanitizedCategories;
      _memoryCacheTimestamps['cached_category_menu'] = DateTime.now();

      DebugLogger.log(
          'Cached ${categories.length} category menu items to local storage',
          category: 'DATA_SOURCE');
    } catch (e) {
      DebugLogger.log('Error caching category menu to local storage: $e',
          category: 'DATA_SOURCE');
    }
  }

  Future<void> cacheSubCategoriesMenu(
      int categoryId, List<SubCategoryMenu> subcategories) async {
    try {
      // Try to load existing cached data first
      List<SubCategoryMenu> existingItems = [];
      try {
        existingItems = await getSubCategoriesMenu(categoryId);
      } catch (e) {
        // Ignore errors when getting existing items
        DebugLogger.log('Error loading existing subcategories: $e',
            category: 'DATA_SOURCE');
      }

      // Create a map of existing items by ID for quick lookup
      final Map<int, SubCategoryMenu> existingMap = {
        for (var item in existingItems) item.id: item
      };

      // Prepare a list for the final items
      final List<SubCategoryMenu> finalItems = [];

      // Process each new item from the API
      for (final newItem in subcategories) {
        if (existingMap.containsKey(newItem.id)) {
          // If we have this subcategory in cache
          final existingItem = existingMap[newItem.id]!;

          // Only use the existing servicePostsCount if it's higher
          // This preserves the highest known count
          final int finalCount =
              existingItem.servicePostsCount > newItem.servicePostsCount
                  ? existingItem.servicePostsCount
                  : newItem.servicePostsCount;

          // Create a new item with all the latest data but preserved count
          final mergedItem = SubCategoryMenu(
              id: newItem.id,
              name: newItem.name,
              categoriesId: newItem.categoriesId,
              // Ensure we keep the category ID
              createdAt: newItem.createdAt,
              updatedAt: newItem.updatedAt,
              servicePostsCount: finalCount,
              // Use the higher count
              photos: newItem.photos,
              isSuspended: newItem.isSuspended);

          finalItems.add(mergedItem);
        } else {
          // For new items, ensure category ID is properly set
          final verifiedItem = SubCategoryMenu(
              id: newItem.id,
              name: newItem.name,
              categoriesId:
                  newItem.categoriesId != 0 ? newItem.categoriesId : categoryId,
              // Use provided categoryId as fallback
              createdAt: newItem.createdAt,
              updatedAt: newItem.updatedAt,
              servicePostsCount: newItem.servicePostsCount,
              photos: newItem.photos,
              isSuspended: newItem.isSuspended);
          finalItems.add(verifiedItem);
        }
      }

      // Sanitize and save the merged data
      final sanitizedSubcategories = finalItems.map((s) {
        // First convert to JSON
        final originalJson = s.toJson();
        // Then sanitize for storage
        final storableJson = _sanitizeForStorage(originalJson);
        // Finally, properly structure the data
        return _sanitizeSubCategoryMenuJson(storableJson);
      }).toList();

      final String jsonString = json.encode(sanitizedSubcategories);
      await sharedPreferences.setString(
          'cached_subcategory_menu_$categoryId', jsonString);
      await sharedPreferences.setInt(
          'cached_subcategory_menu_${categoryId}_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      // OPTIMIZATION: Update memory cache
      _memoryCache['cached_subcategory_menu_$categoryId'] =
          sanitizedSubcategories;
      _memoryCacheTimestamps['cached_subcategory_menu_$categoryId'] =
          DateTime.now();

      DebugLogger.log(
          'Cached ${finalItems.length} subcategory menu items for category $categoryId to local storage',
          category: 'DATA_SOURCE');
    } catch (e) {
      DebugLogger.log('Error caching subcategory menu to local storage: $e',
          category: 'DATA_SOURCE');
    }
  }

  bool isCacheValid(String key, {int maxAgeMinutes = 60}) {
    // OPTIMIZATION: First check memory cache
    if (_memoryCacheTimestamps.containsKey(key)) {
      final lastUpdate = _memoryCacheTimestamps[key]!;
      final now = DateTime.now();
      if (now.difference(lastUpdate).inMinutes <= maxAgeMinutes) {
        return true;
      }
    }

    // Then check shared preferences
    final timestamp = sharedPreferences.getInt('${key}_timestamp');
    if (timestamp == null) return false;

    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(lastUpdate).inMinutes <= maxAgeMinutes;
  }

  // OPTIMIZATION: Get cache age
  Duration? getCacheAge(String key) {
    final timestamp = sharedPreferences.getInt('${key}_timestamp');
    if (timestamp == null) return null;

    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(lastUpdate);
  }

  // OPTIMIZATION: Preload common categories into memory cache
  Future<void> preloadCommonCaches() async {
    try {
      DebugLogger.log('Preloading common caches into memory',
          category: 'DATA_SOURCE');
      final stopwatch = Stopwatch()..start();

      // Preload categories
      await getCategoryMenu();

      // Preload categories for the most common categories (1-5)
      for (int i = 1; i <= 5; i++) {
        // Don't await these to load in parallel
        getSubCategoriesMenu(i);
      }

      stopwatch.stop();
      DebugLogger.log(
          'Preloaded common caches into memory in ${stopwatch.elapsedMilliseconds}ms',
          category: 'DATA_SOURCE');
    } catch (e) {
      DebugLogger.log('Error preloading caches: $e', category: 'DATA_SOURCE');
    }
  }

  // OPTIMIZATION: Clear memory cache
  void clearMemoryCache() {
    _memoryCache.clear();
    _memoryCacheTimestamps.clear();
    DebugLogger.log('Cleared in-memory cache', category: 'DATA_SOURCE');
  }

  Future<void> clearAllCache() async {
    try {
      DebugLogger.log('Clearing all cache data...', category: 'DATA_SOURCE');

      // Get all keys from SharedPreferences
      final keys = sharedPreferences.getKeys();

      // Filter cache-related keys
      final cacheKeys = keys
          .where((key) =>
              key.startsWith('cached_') ||
              key.endsWith('_timestamp') ||
              key.contains('category') ||
              key.contains('service_post'))
          .toList();

      // Remove each key
      for (final key in cacheKeys) {
        await sharedPreferences.remove(key);
      }

      // Also clear memory cache
      clearMemoryCache();

      DebugLogger.log('Cleared ${cacheKeys.length} cache entries',
          category: 'DATA_SOURCE');
    } catch (e) {
      DebugLogger.log('Error clearing cache: $e', category: 'DATA_SOURCE');
    }
  }

  Map<String, dynamic> _sanitizeForStorage(Map<String, dynamic> json) {
    // Create a new map to hold the sanitized values
    final sanitized = <String, dynamic>{};

    // Process each entry in the JSON map
    json.forEach((key, value) {
      if (value == null) {
        // Null values are fine
        sanitized[key] = null;
      } else if (value is DateTime) {
        // Convert DateTime to ISO string
        sanitized[key] = value.toIso8601String();
      } else if (value is List) {
        // Recursively process lists
        sanitized[key] = _sanitizeListForStorage(value);
      } else if (value is Map) {
        // Recursively process maps
        if (key == 'name') {
          // Special handling for name field to ensure it's properly formatted
          sanitized[key] = value;
        } else {
          // For other maps, sanitize them recursively
          sanitized[key] =
              _sanitizeForStorage(Map<String, dynamic>.from(value));
        }
      } else {
        // Primitive values like String, int, bool are already serializable
        sanitized[key] = value;

        // Special handling for categoriesId and servicePostsCount
        if (key == 'categoriesId') {
          sanitized['categories_id'] = value; // Add snake_case version too
        } else if (key == 'servicePostsCount') {
          sanitized['service_posts_count'] =
              value; // Add snake_case version too
        }
      }
    });

    return sanitized;
  }

  // Helper method to sanitize lists
  List _sanitizeListForStorage(List list) {
    return list.map((item) {
      if (item == null) {
        return null;
      } else if (item is DateTime) {
        return item.toIso8601String();
      } else if (item is List) {
        return _sanitizeListForStorage(item);
      } else if (item is Map) {
        return _sanitizeForStorage(Map<String, dynamic>.from(item));
      } else {
        return item;
      }
    }).toList();
  }

  // Sanitization methods to handle potential serialization issues

  Map<String, dynamic> _sanitizeCategoryMenuJson(Map<String, dynamic> json) {
    // Make sure we have a valid JSON object
    final sanitized = Map<String, dynamic>.from(json);

    // Ensure the id field is never null
    if (sanitized['id'] == null) {
      sanitized['id'] = 0; // Default ID if missing
    }

    // Ensure other fields used in fromJson have proper defaults
    if (sanitized['created_at'] == null) {
      sanitized['created_at'] = DateTime.now().toIso8601String();
    }
    if (sanitized['updated_at'] == null) {
      sanitized['updated_at'] = DateTime.now().toIso8601String();
    }
    if (sanitized['isSuspended'] == null) sanitized['isSuspended'] = false;
    if (sanitized['photos'] == null) sanitized['photos'] = [];

    // Apply other sanitization logic
    final result = _sanitizeJson(
        sanitized, ['name', 'isSuspended', 'createdAt', 'updatedAt', 'photos']);

    // Ensure datetime fields are handled properly
    if (result['createdAt'] is DateTime) {
      result['createdAt'] = (result['createdAt'] as DateTime).toIso8601String();
    }
    if (result['updatedAt'] is DateTime) {
      result['updatedAt'] = (result['updatedAt'] as DateTime).toIso8601String();
    }

    return result;
  }

  Map<String, dynamic> _sanitizeSubCategoryMenuJson(Map<String, dynamic> json) {
    // Make sure we have a valid JSON object
    final sanitized = Map<String, dynamic>.from(json);

    // Ensure required integer fields are not null with default values
    if (sanitized['id'] == null) sanitized['id'] = 0;

    // Handle both versions of the categoriesId field
    if (sanitized['categoriesId'] == null &&
        sanitized['categories_id'] != null) {
      sanitized['categoriesId'] = sanitized['categories_id'];
    } else if (sanitized['categoriesId'] == null) {
      sanitized['categoriesId'] = 0;
    }
    // Always include both versions for compatibility
    sanitized['categories_id'] = sanitized['categoriesId'];

    // Handle both versions of the servicePostsCount field
    if (sanitized['servicePostsCount'] == null &&
        sanitized['service_posts_count'] != null) {
      sanitized['servicePostsCount'] = sanitized['service_posts_count'];
    } else if (sanitized['servicePostsCount'] == null) {
      sanitized['servicePostsCount'] = 0;
    }
    // Always include both versions for compatibility
    sanitized['service_posts_count'] = sanitized['servicePostsCount'];

    // Apply other sanitization
    final result = _sanitizeJson(sanitized, [
      'id',
      'name',
      'categoriesId',
      'categories_id',
      'createdAt',
      'updatedAt',
      'servicePostsCount',
      'service_posts_count',
      'photos',
      'isSuspended'
    ]);

    // Ensure datetime fields are converted to strings
    if (result['createdAt'] is DateTime) {
      result['createdAt'] = (result['createdAt'] as DateTime).toIso8601String();
    }
    if (result['updatedAt'] is DateTime) {
      result['updatedAt'] = (result['updatedAt'] as DateTime).toIso8601String();
    }

    return result;
  }

  // Generic JSON sanitization method
  Map<String, dynamic> _sanitizeJson(
      Map<String, dynamic> json, List<String> keysToPreserve) {
    final sanitizedJson = <String, dynamic>{};

    json.forEach((key, value) {
      if (keysToPreserve.contains(key)) {
        // Handle specific type conversions
        if (value is double) {
          sanitizedJson[key] = value.toString();
        } else if (value is List) {
          sanitizedJson[key] = value.map((item) {
            if (item is double) return item.toString();
            if (item is DateTime) return item.toIso8601String();
            return item;
          }).toList();
        } else if (value is DateTime) {
          sanitizedJson[key] = value.toIso8601String();
        } else {
          sanitizedJson[key] = value;
        }
      }
    });

    return sanitizedJson;
  }
}
