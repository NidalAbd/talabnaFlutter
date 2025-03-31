import 'dart:convert';

import 'package:talabna/data/models/photos.dart';

import 'categories.dart';

class ServicePost {
  final int? id;
  final int? userId;
  final String? userName;
  final Photo? userPhoto;
  String? email;
  String? phones;
  String? watsNumber;
  final String? title;
  final String? description;
  final Category? category;
  final SubCategory? subCategory;
  double? price;
  final String? priceCurrencyCode;
  final Map<String, String>? priceCurrencyName;
  final double? locationLatitudes;
  final double? locationLongitudes;
  final double? distance;
  final String? type;
  final String? country;
  final String? haveBadge;
  final int? badgeDuration;
  final DateTime? badgeExpiresAt; // Added field for badge expiration
  int? favoritesCount;
  final int? commentsCount;
  final int? reportCount;
  final int? viewCount;
  bool? isFavorited;
  final bool? isFollowed;
  final String? state;
  final int? categoriesId;
  final int? subCategoriesId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Photo>? photos;

  ServicePost({
    this.userName,
    this.userPhoto,
    this.phones,
    this.watsNumber,
    this.email,
    this.id,
    this.userId,
    this.title,
    this.description,
    this.category,
    this.subCategory,
    this.country,
    this.price,
    this.priceCurrencyCode,
    this.priceCurrencyName,
    this.locationLatitudes,
    this.locationLongitudes,
    this.distance,
    this.isFollowed,
    this.type,
    this.haveBadge,
    this.badgeDuration,
    this.badgeExpiresAt, // Added to constructor
    this.favoritesCount,
    this.reportCount,
    this.commentsCount,
    this.viewCount,
    this.isFavorited,
    this.state,
    this.categoriesId,
    this.subCategoriesId,
    this.createdAt,
    this.updatedAt,
    this.photos,
  });

  factory ServicePost.fromJson(Map<String, dynamic> json) {
    try {
      // Handle photos with try-catch
      List<Photo>? photosList;
      try {
        photosList = (json['photos'] as List<dynamic>?)
            ?.map((photoJson) => Photo.fromJson(photoJson))
            .toList() ??
            [];
      } catch (e) {
        print('Error parsing photos: $e');
        photosList = [];
      }

      // Handle currency name with try-catch
      Map<String, String>? currencyNameMap;
      try {
        if (json['price_currency_name'] is String &&
            json['price_currency_name'] != null) {
          currencyNameMap = Map<String, String>.from(
              jsonDecode(json['price_currency_name']));
        } else if (json['price_currency_name'] != null) {
          currencyNameMap = Map<String, String>.from(json['price_currency_name']);
        }
      } catch (e) {
        print('Error parsing price_currency_name: $e');
        currencyNameMap = null;
      }

      // Parse all other fields with individual try-catch blocks
      int? id;
      try {
        id = json['id'] ?? 0;
      } catch (e) {
        print('Error parsing id: $e');
        id = 0;
      }

      int? userId;
      try {
        userId = json['user_id'] ?? 0;
      } catch (e) {
        print('Error parsing user_id: $e');
        userId = 0;
      }

      String? userName;
      try {
        userName = json['user_name'] ?? '';
      } catch (e) {
        print('Error parsing user_name: $e');
        userName = '';
      }

      Photo? userPhoto;
      try {
        userPhoto = json['user_photo'] is Map<String, dynamic>
            ? Photo.fromJson(json['user_photo'])
            : (json['user_photo'] is String && json['user_photo'] != null
            ? Photo(src: json['user_photo'], isExternal: true)
            : null);
      } catch (e) {
        print('Error parsing user_photo: $e');
        userPhoto = null;
      }

      String? email;
      try {
        email = json['email'] ?? '';
      } catch (e) {
        print('Error parsing email: $e');
        email = '';
      }

      String? watsNumber;
      try {
        watsNumber = json['WatsNumber'] ?? '';
      } catch (e) {
        print('Error parsing WatsNumber: $e');
        watsNumber = '';
      }

      String? phones;
      try {
        phones = json['phones'] ?? '';
      } catch (e) {
        print('Error parsing phones: $e');
        phones = '';
      }

      String? title;
      try {
        title = json['title'] ?? '';
      } catch (e) {
        print('Error parsing title: $e');
        title = '';
      }

      String? description;
      try {
        description = json['description'] ?? '';
      } catch (e) {
        print('Error parsing description: $e');
        description = '';
      }

      Category? category;
      try {
        category = json['category'] is Map<String, dynamic>
            ? Category.fromJson(json['category'])
            : null;
      } catch (e) {
        print('Error parsing category: $e');
        category = null;
      }

      SubCategory? subCategory;
      try {
        if (json['sub_category'] is Map<String, dynamic>) {
          subCategory = SubCategory.fromJson(json['sub_category']);
        } else if (json['sub_category'] is String) {
          subCategory = SubCategory(
              id: 0,
              name: {'ar': json['sub_category']},
              categoryId: 0
          );
        } else {
          // Not a map or string, create a default SubCategory
          subCategory = SubCategory(
              id: json['sub_categories_id'] ?? 0,
              name: {'ar': 'Unknown', 'en': 'Unknown'},
              categoryId: json['categories_id'] ?? 0
          );
        }
      } catch (e) {
        print('Error parsing sub_category: $e');
        print('sub_category value: ${json['sub_category']}');
        // Create a default SubCategory as fallback
        subCategory = SubCategory(
            id: json['sub_categories_id'] ?? 0,
            name: {'ar': 'Error', 'en': 'Error'},
            categoryId: json['categories_id'] ?? 0
        );
      }

      String? country;
      try {
        country = json['country'] ?? '';
      } catch (e) {
        print('Error parsing country: $e');
        country = '';
      }

      double? price;
      try {
        price = (json['price'] ?? 0).toDouble();
      } catch (e) {
        print('Error parsing price: $e');
        price = 0.0;
      }

      String? priceCurrencyCode;
      try {
        priceCurrencyCode = json['price_currency_code'];
      } catch (e) {
        print('Error parsing price_currency_code: $e');
        priceCurrencyCode = null;
      }

      double? locationLatitudes;
      try {
        locationLatitudes =
            double.tryParse(json['location_latitudes']?.toString() ?? '') ?? 0.0;
      } catch (e) {
        print('Error parsing location_latitudes: $e');
        locationLatitudes = 0.0;
      }

      double? locationLongitudes;
      try {
        locationLongitudes =
            double.tryParse(json['location_longitudes']?.toString() ?? '') ?? 0.0;
      } catch (e) {
        print('Error parsing location_longitudes: $e');
        locationLongitudes = 0.0;
      }

      double? distance;
      try {
        distance = (json['distance'] is int
            ? json['distance'].toDouble()
            : json['distance']) ??
            0.0;
      } catch (e) {
        print('Error parsing distance: $e');
        distance = 0.0;
      }

      String? type;
      try {
        type = json['type'] ?? '';
      } catch (e) {
        print('Error parsing type: $e');
        type = '';
      }

      String? haveBadge;
      try {
        haveBadge = json['have_badge'] ?? '';
      } catch (e) {
        print('Error parsing have_badge: $e');
        haveBadge = '';
      }

      int? badgeDuration;
      try {
        badgeDuration =
            int.tryParse(json['badge_duration']?.toString() ?? '') ?? 0;
      } catch (e) {
        print('Error parsing badge_duration: $e');
        badgeDuration = 0;
      }

      DateTime? badgeExpiresAt;
      try {
        badgeExpiresAt = json['badge_expires_at'] != null
            ? DateTime.tryParse(json['badge_expires_at'].toString())
            : null;
      } catch (e) {
        print('Error parsing badge_expires_at: $e');
        badgeExpiresAt = null;
      }

      int? favoritesCount;
      try {
        favoritesCount = json['favorites_count'] ?? 0;
      } catch (e) {
        print('Error parsing favorites_count: $e');
        favoritesCount = 0;
      }

      int? commentsCount;
      try {
        commentsCount = json['comments_count'] ?? 0;
      } catch (e) {
        print('Error parsing comments_count: $e');
        commentsCount = 0;
      }

      int? reportCount;
      try {
        reportCount = json['report_count'] ?? 0;
      } catch (e) {
        print('Error parsing report_count: $e');
        reportCount = 0;
      }

      int? viewCount;
      try {
        viewCount = json['view_count'] ?? 0;
      } catch (e) {
        print('Error parsing view_count: $e');
        viewCount = 0;
      }

      bool? isFavorited;
      try {
        isFavorited = json['is_favorited'] ?? false;
      } catch (e) {
        print('Error parsing is_favorited: $e');
        isFavorited = false;
      }

      bool? isFollowed;
      try {
        isFollowed = json['is_followed'] ?? false;
      } catch (e) {
        print('Error parsing is_followed: $e');
        isFollowed = false;
      }

      String? state;
      try {
        state = json['state'] ?? '';
      } catch (e) {
        print('Error parsing state: $e');
        state = '';
      }

      int? categoriesId;
      try {
        categoriesId = json['categories_id'] ?? 0;
      } catch (e) {
        print('Error parsing categories_id: $e');
        categoriesId = 0;
      }

      int? subCategoriesId;
      try {
        subCategoriesId = json['sub_categories_id'] ?? 0;
      } catch (e) {
        print('Error parsing sub_categories_id: $e');
        subCategoriesId = 0;
      }

      DateTime? createdAt;
      try {
        createdAt = json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null;
      } catch (e) {
        print('Error parsing created_at: $e');
        createdAt = null;
      }

      DateTime? updatedAt;
      try {
        updatedAt = json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null;
      } catch (e) {
        print('Error parsing updated_at: $e');
        updatedAt = null;
      }

      return ServicePost(
        id: id,
        userId: userId,
        userName: userName,
        userPhoto: userPhoto,
        email: email,
        watsNumber: watsNumber,
        phones: phones,
        title: title,
        description: description,
        category: category,
        subCategory: subCategory,
        country: country,
        price: price,
        priceCurrencyCode: priceCurrencyCode,
        priceCurrencyName: currencyNameMap,
        locationLatitudes: locationLatitudes,
        locationLongitudes: locationLongitudes,
        distance: distance,
        type: type,
        haveBadge: haveBadge,
        badgeDuration: badgeDuration,
        badgeExpiresAt: badgeExpiresAt,
        favoritesCount: favoritesCount,
        commentsCount: commentsCount,
        reportCount: reportCount,
        viewCount: viewCount,
        isFavorited: isFavorited,
        isFollowed: isFollowed,
        state: state,
        categoriesId: categoriesId,
        subCategoriesId: subCategoriesId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        photos: photosList,
      );
    } catch (e) {
      print('Error in ServicePost.fromJson: $e');
      // Return a minimal object to avoid crashes
      return ServicePost(
        id: 0,
        title: 'Error parsing post',
        description: 'An error occurred while parsing this post',
      );
    }
  }
  // Get currency code with fallback
  String getCurrencyCode() => priceCurrencyCode ?? "USD";

  // Helper method to get the currency name with fallback
  String getCurrencyName(String lang) {
    if (priceCurrencyName == null)
      return lang == 'ar' ? 'دولار امريكي' : 'US Dollar';
    return priceCurrencyName![lang] ??
        priceCurrencyName!['en'] ??
        (lang == 'ar' ? 'دولار امريكي' : 'US Dollar');
  }

  // Format price with currency
  String getFormattedPrice(String lang) => "$price ${getCurrencyName(lang)}";

  // Check if badge is still valid based on server-provided expiration date
  bool isBadgeValid() {
    if (haveBadge == 'عادي') return false;
    if (badgeExpiresAt == null)
      return true; // If no expiration date, assume valid
    return badgeExpiresAt!.isAfter(DateTime.now());
  }

  // Get remaining time until badge expires as a formatted string
  String getRemainingBadgeTime(String lang) {
    if (haveBadge == 'عادي' || badgeExpiresAt == null) {
      return lang == 'ar' ? 'لا توجد شارة' : 'No badge';
    }

    final now = DateTime.now();

    // If already expired
    if (badgeExpiresAt!.isBefore(now)) {
      return lang == 'ar' ? 'منتهية الصلاحية' : 'Expired';
    }

    // Calculate remaining time
    final difference = badgeExpiresAt!.difference(now);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (lang == 'ar') {
      return '$days يوم، $hours ساعة، $minutes دقيقة';
    } else {
      return '$days days, $hours hours, $minutes minutes';
    }
  }

  // Get badge type in the requested language
  String getBadgeType(String lang) {
    switch (haveBadge) {
      case 'ذهبي':
        return lang == 'ar' ? 'ذهبي' : 'Gold';
      case 'ماسي':
        return lang == 'ar' ? 'ماسي' : 'Diamond';
      default:
        return lang == 'ar' ? 'عادي' : 'Normal';
    }
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'sub_category': subCategory,
        'categories_id': categoriesId,
        'sub_categories_id': subCategoriesId,
        'country': country,
        'price': price,
        'price_currency_code': priceCurrencyCode,
        'price_currency_name': priceCurrencyName,
        'location_latitudes': locationLatitudes,
        'location_longitudes': locationLongitudes,
        'type': type,
        'have_badge': haveBadge,
        'badge_duration': badgeDuration,
        'photos': photos?.map((photo) => photo.toJson()).toList(),
      };
}
