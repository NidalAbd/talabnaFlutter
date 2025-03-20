// Update SubCategoryMenu class to properly handle field names for serialization

import 'dart:convert';

import 'package:talabna/data/models/photos.dart';

class SubCategoryMenu {
  final int id;
  final dynamic name;
  final int categoriesId;
  final String? createdAt; // Changed from DateTime to String
  final String? updatedAt; // Changed from DateTime to String
  final int servicePostsCount;
  final List<Photo> photos;
  final bool isSuspended;

  SubCategoryMenu({
    required this.id,
    required this.name,
    required this.categoriesId,
    this.createdAt,
    this.updatedAt,
    this.servicePostsCount = 0,
    required this.photos,
    this.isSuspended = false,
  });

  factory SubCategoryMenu.fromJson(Map<String, dynamic> json) {
    // Handle potential null or invalid JSON
    int id;
    int categoriesId;
    int servicePostsCount;

    try {
      id = json['id'] ?? 0;

      // Check both camelCase and snake_case versions of the field name
      categoriesId = json['categoriesId'] ?? json['categories_id'] ?? 0;

      // Check both camelCase and snake_case versions of the field name
      servicePostsCount =
          json['servicePostsCount'] ?? json['service_posts_count'] ?? 0;
    } catch (e) {
      id = 0;
      categoriesId = 0;
      servicePostsCount = 0;
    }

    return SubCategoryMenu(
      id: id,
      name: parseNameField(json['name'] ?? {}),
      categoriesId: categoriesId,
      servicePostsCount: servicePostsCount,
      createdAt: parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDateTime(json['updatedAt'] ?? json['updated_at']),
      isSuspended: parseBoolField(json['isSuspended']),
      photos: parsePhotos(json['photos']),
    );
  }

  // Helper method to parse name field
  static dynamic parseNameField(dynamic nameField) {
    if (nameField == null) return {'en': ''};

    // If it's a map, return it as is
    if (nameField is Map) {
      return nameField;
    }

    // If it's a JSON string, try to parse
    if (nameField is String) {
      try {
        final parsedName = json.decode(nameField);
        if (parsedName is Map) {
          return parsedName;
        }
      } catch (e) {
        // If parsing fails, return the original string as a map with 'en' key
        return {'en': nameField};
      }
    }

    // Default fallback is to make a map with 'en' key
    return {'en': nameField.toString()};
  }

  // Helper method to parse date time string
  static String? parseDateTime(dynamic dateField) {
    if (dateField == null) return null;

    try {
      if (dateField is DateTime) {
        return dateField.toIso8601String();
      } else if (dateField is String) {
        // Validate it's a proper date string
        try {
          DateTime.parse(dateField);
          return dateField;
        } catch (e) {
          return dateField; // Return as is if it's not a valid date format
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to parse boolean fields
  static bool parseBoolField(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is int) return value == 1;

    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }

    return false;
  }

  // Helper method to parse photos
  static List<Photo> parsePhotos(dynamic photosField) {
    if (photosField == null) return [];

    try {
      if (photosField is List) {
        return photosField
            .map((photoJson) => Photo.fromJson(photoJson))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      // Include both formats to ensure compatibility when reading back
      'categoriesId': categoriesId,
      'categories_id': categoriesId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'servicePostsCount': servicePostsCount,
      'service_posts_count': servicePostsCount, // Add snake_case version too
      'isSuspended': isSuspended,
      'photos': photos.map((photo) => photo.toJson()).toList(),
    };
  }

  // Get display name that works with both String and Map
  String getDisplayName({String locale = 'en'}) {
    // If name is a Map
    if (name is Map) {
      // First try to get the requested locale
      final Map nameMap = name as Map;
      if (nameMap.containsKey(locale) && nameMap[locale] != null) {
        return nameMap[locale].toString();
      }

      // Then try English as fallback
      if (nameMap.containsKey('en') && nameMap['en'] != null) {
        return nameMap['en'].toString();
      }

      // Lastly, use first available value
      if (nameMap.isNotEmpty) {
        for (final value in nameMap.values) {
          if (value != null) {
            return value.toString();
          }
        }
      }

      // Nothing found
      return "Subcategory $id";
    }

    // If name is already a simple string, return it
    return name.toString();
  }
}

// Helper function to create a minimal SubCategoryMenu
SubCategoryMenu createSimpleSubCategoryMenu(
    int id, dynamic name, int categoryId) {
  return SubCategoryMenu(
    id: id,
    name: name,
    categoriesId: categoryId,
    photos: [],
  );
}
