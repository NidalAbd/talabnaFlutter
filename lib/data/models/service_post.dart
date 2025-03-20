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
    return ServicePost(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? '',
      userPhoto: json['user_photo'] is Map<String, dynamic>
          ? Photo.fromJson(json['user_photo'])
          : (json['user_photo'] is String && json['user_photo'] != null
              ? Photo(src: json['user_photo'], isExternal: true)
              : null),
      email: json['email'] ?? '',
      watsNumber: json['WatsNumber'] ?? '',
      phones: json['phones'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] is Map<String, dynamic>
          ? Category.fromJson(json['category'])
          : null,
      subCategory: json['sub_category'] is Map<String, dynamic>
          ? SubCategory.fromJson(json['sub_category'])
          : SubCategory(
              id: 0, name: {'ar': json['sub_category']}, categoryId: 0),
      country: json['country'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      priceCurrencyCode: json['price_currency_code'],
      priceCurrencyName: json['price_currency_name'] is String &&
              json['price_currency_name'] != null
          ? Map<String, String>.from(jsonDecode(json['price_currency_name']))
          : (json['price_currency_name'] != null
              ? Map<String, String>.from(json['price_currency_name'])
              : null),
      locationLatitudes:
          double.tryParse(json['location_latitudes']?.toString() ?? '') ?? 0.0,
      locationLongitudes:
          double.tryParse(json['location_longitudes']?.toString() ?? '') ?? 0.0,
      distance: (json['distance'] is int
              ? json['distance'].toDouble()
              : json['distance']) ??
          0.0,
      type: json['type'] ?? '',
      haveBadge: json['have_badge'] ?? '',
      badgeDuration:
          int.tryParse(json['badge_duration']?.toString() ?? '') ?? 0,
      // Parse badge expiration date if available
      badgeExpiresAt: json['badge_expires_at'] != null
          ? DateTime.parse(json['badge_expires_at'])
          : null,
      favoritesCount: json['favorites_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      reportCount: json['report_count'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      isFavorited: json['is_favorited'] ?? false,
      isFollowed: json['is_followed'] ?? false,
      state: json['state'] ?? '',
      categoriesId: json['categories_id'] ?? 0,
      subCategoriesId: json['sub_categories_id'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((photoJson) => Photo.fromJson(photoJson))
              .toList() ??
          [],
    );
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
