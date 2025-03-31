import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/utils/constants.dart';

import '../../utils/debug_logger.dart';
import '../../utils/rate_limit_manager.dart';

class ServicePostRepository {
  static const String _baseUrl = Constants.apiBaseUrl;
  static const int _maxRetries = 3;
  static const int _initialBackoffMs = 1000;
  final Map<String, DateTime> _lastRequestTimes = {};
  static const int _minRequestInterval = 500; // milliseconds between requests

  Future<List<ServicePost>> getAllServicePosts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/service_posts'));
      if (response.statusCode == 200) {
        final List<ServicePost> servicePosts = [];
        final List<dynamic> data = jsonDecode(response.body);
        for (var element in data) {
          servicePosts.add(ServicePost.fromJson(element));
        }
        return servicePosts;
      } else {
        throw Exception('فشل في تحميل المنشورات');
      }
    } catch (e) {
      throw Exception('خطا الاتصال في الخادم - المنشورات');
    }
  }

  Future<List<ServicePost>> getServicePostsForReals({
    required int page,
    bool bypassRateLimit = false
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    // Define endpoint for rate limiting
    final endpoint = 'reels';

    // Check rate limiting unless bypassing
    if (!bypassRateLimit) {
      // Get instance of rate limit manager
      final rateLimitManager = RateLimitManager();

      // Check if we can make this request
      if (!rateLimitManager.canMakeRequest(endpoint)) {
        // Get time until next request is allowed
        final waitTime = rateLimitManager.timeUntilNextAllowed(endpoint);

        DebugLogger.log(
            'Rate limit applied, waiting ${waitTime.inSeconds} seconds before next reels request',
            category: 'SERVICE_POST'
        );

        // If the wait time is fairly short, just wait and then proceed
        if (waitTime.inSeconds < 5) {
          await Future.delayed(waitTime);
        } else {
          // Otherwise, throw a rate limit error that will be caught
          throw Exception('Too many requests. Please try again in ${waitTime.inSeconds} seconds.');
        }
      }

      // Record this request
      rateLimitManager.recordRequest(endpoint);
    }

    // Construct the correct URL
    final url = Uri.parse('$_baseUrl/api/service_posts/reels?page=$page');

    DebugLogger.log('Fetching reels from: ${url.toString()}', category: 'SERVICE_POST');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      DebugLogger.log('Reels request status: ${response.statusCode}', category: 'SERVICE_POST');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        if (!responseBody.containsKey('servicePosts') ||
            !responseBody['servicePosts'].containsKey('data')) {
          throw Exception('Invalid API response format');
        }

        final List<dynamic> data = responseBody['servicePosts']['data'];
        final List<ServicePost> servicePosts =
        data.map((e) => ServicePost.fromJson(e)).toList();

        DebugLogger.log('Successfully loaded ${servicePosts.length} reels', category: 'SERVICE_POST');
        return servicePosts;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      } else if (response.statusCode == 429) {
        // Handle rate limiting
        DebugLogger.log('Rate limit hit (429) for reels', category: 'SERVICE_POST');

        // Apply backoff to this endpoint
        final rateLimitManager = RateLimitManager();
        rateLimitManager.applyBackoff(endpoint, 0); // Start with attempt 0

        throw Exception('Too many requests. Please wait a moment before trying again.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('429') || e.toString().contains('Too Many Requests')) {
        // Apply backoff to this endpoint on errors too
        final rateLimitManager = RateLimitManager();
        rateLimitManager.applyBackoff(endpoint, 0);
      }

      DebugLogger.log('Error fetching reels: $e', category: 'SERVICE_POST');
      throw Exception('Failed to load reels: ${e.toString()}');
    }
  }

  Future<bool> updateDataSaverPreference(bool enabled) async {
    // Log the incoming value for debugging
    print('Updating data saver preference on server to: $enabled');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/api/data-saver/toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'enabled': enabled}),
      );

      print('Data saver toggle response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response and update local SharedPreferences to match server value
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Get the actual value from the server's response
        final bool serverStatus = responseData['data']['data_saver_enabled'];

        // Update local SharedPreferences to match the server's value
        await prefs.setBool('data_saver_enabled', serverStatus);

        // Return the value from the server (not our input)
        return serverStatus;
      } else {
        throw Exception('Failed to update data saver preference: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating data saver preference: $e');
      throw Exception('Failed to update data saver preference: $e');
    }
  }

// Add this to your ServicePostRepository class
  Future<List<ServicePost>> getServicePostsByCategory({
    required int categories,
    required int page,
    String? type,
    double? minPrice,
    double? maxPrice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final dataSaverEnabled = prefs.getBool('data_saver_enabled') ?? false;

    try {
      // Build the base URL
      var url = '$_baseUrl/api/service_posts/categories/$categories?page=$page&data_saver=${dataSaverEnabled ? 1 : 0}';

      // Add filters to the URL if provided
      if (type != null) {
        url += '&type=$type';
      }

      if (minPrice != null && maxPrice != null) {
        url += '&min_price=${minPrice.toInt()}&max_price=${maxPrice.toInt()}';
      }

      DebugLogger.log('Making API request to: $url', category: 'REPOSITORY');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        if (!responseBody.containsKey('servicePosts') ||
            !responseBody['servicePosts'].containsKey('data')) {
          throw Exception('Invalid API response format');
        }

        final List<dynamic> data = responseBody['servicePosts']['data'];
        final List<ServicePost> servicePosts =
        data.map((e) => ServicePost.fromJson(e)).toList();

        return servicePosts;
      } else {
        throw Exception('Failed to load service posts for this category: Status ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.log('Error fetching service posts: $e',
          category: 'SERVICE_POST');
      throw Exception('Failed to connect to server: $e');
    }
  }

// Modify this existing method to include data_saver parameter
  Future<List<ServicePost>> getServicePostsByUserFavourite(
      {required int userId, required int page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final dataSaverEnabled = prefs.getBool('data_saver_enabled') ?? false;

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/api/service_posts/users/$userId/favorite?page=$page&data_saver=${dataSaverEnabled ? 1 : 0}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> data = responseBody['servicePosts']['data'];
        final List<ServicePost> servicePosts =
        data.map((e) => ServicePost.fromJson(e)).toList();
        return servicePosts;
      } else {
        throw Exception('Failed to load favorite service posts for this user');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to connect to server');
    }
  }

// Update the getServicePostsByCategorySubCategory method in ServicePostRepository
  Future<List<ServicePost>> getServicePostsByCategorySubCategory({
    required int categories,
    required int subCategories,
    required int page,
    String? type,
    double? minPrice,
    double? maxPrice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final dataSaverEnabled = prefs.getBool('data_saver_enabled') ?? false;

    // Validate IDs to prevent 0 values
    if (categories <= 0) {
      DebugLogger.log('Invalid category ID: $categories, using default',
          category: 'REPOSITORY');
      categories = 1;
    }
    if (subCategories <= 0) {
      DebugLogger.log('Invalid subcategory ID: $subCategories, using default',
          category: 'REPOSITORY');
      subCategories = 1;
    }

    try {
      // Build the base URL
      var url = '$_baseUrl/api/service_posts/categories/$categories/sub_categories/$subCategories?page=$page&data_saver=${dataSaverEnabled ? 1 : 0}';

      // Add filters to the URL if provided
      if (type != null) {
        url += '&type=$type';
      }

      if (minPrice != null && maxPrice != null) {
        url += '&min_price=${minPrice.toInt()}&max_price=${maxPrice.toInt()}';
      }

      DebugLogger.log('Making API request to: $url', category: 'REPOSITORY');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Log the full URL and response for debugging
      print('🔍 API Request URL: $url');
      print('🔍 API Response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> data = responseBody['servicePosts']['data'];

        DebugLogger.log(
            'API Response contains ${data.length} posts for subcategory $subCategories',
            category: 'REPOSITORY');

        final List<ServicePost> servicePosts =
        data.map((e) => ServicePost.fromJson(e)).toList();
        return servicePosts;
      } else {
        throw Exception('Failed to load service posts for this category');
      }
    } catch (e) {
      DebugLogger.log('Error in getServicePostsByCategorySubCategory: $e',
          category: 'REPOSITORY');
      throw Exception('Failed to connect to server');
    }
  }

// Modify this existing method to include data_saver parameter
  Future<ServicePost> getServicePostById(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final dataSaverEnabled = prefs.getBool('data_saver_enabled') ?? false;

    DebugLogger.log('Fetching service post with ID: $id',
        category: 'SERVICE_POST');

    try {
      final url = '$_baseUrl/api/service_posts/$id?data_saver=${dataSaverEnabled ? 1 : 0}';
      DebugLogger.log('API URL: $url', category: 'SERVICE_POST');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      DebugLogger.log('API Response Status: ${response.statusCode}',
          category: 'SERVICE_POST');
      DebugLogger.log(
          'API Response Body: ${response.body.substring(0, 200)}...',
          category: 'SERVICE_POST');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        DebugLogger.log('Parsed JSON keys: ${json.keys.toList()}',
            category: 'SERVICE_POST');

        if (json.containsKey('servicePostShow')) {
          return ServicePost.fromJson(json['servicePostShow']);
        } else {
          throw Exception('API response missing servicePostShow key');
        }
      } else if (response.statusCode == 404) {
        throw Exception('هذا المنشور غير موجود');
      } else {
        throw Exception('فشل في تحميل المنشةر: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.log('Error fetching post: $e', category: 'SERVICE_POST');
      throw Exception('$eخطا الاتصال في الخادم - المنشورات ');
    }
  }

// Modify this existing method to include data_saver parameter
  Future<List<ServicePost>> getServicePostsByUserId(
      {required int userId, required int page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final dataSaverEnabled = prefs.getBool('data_saver_enabled') ?? false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/service_posts/user/$userId?page=$page&data_saver=${dataSaverEnabled ? 1 : 0}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> data = responseBody['servicePosts']['data'];
        final List<ServicePost> servicePosts =
        data.map((e) => ServicePost.fromJson(e)).toList();
        return servicePosts;
      } else {
        throw Exception('Failed to load service posts for this user');
      }
    } catch (e) {
      throw Exception('Failed to connect to server');
    }
  }

// New method to get current data saver status
  Future<bool> getDataSaverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('data_saver_enabled') ?? false;
  }

  // Future<List<ServicePost>> getServicePostsByCategory(
  //     {required int categories, required int page}) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');
  //
  //   try {
  //     final uri = Uri.parse(
  //         '$_baseUrl/api/service_posts/categories/$categories?page=$page');
  //     DebugLogger.log('Requesting URL: $uri', category: 'SERVICE_POST');
  //
  //     final response = await http.get(
  //       uri,
  //       headers: {'Authorization': 'Bearer $token'},
  //     );
  //
  //     DebugLogger.log('Status code: ${response.statusCode}',
  //         category: 'SERVICE_POST');
  //
  //     // Check for non-JSON responses
  //     final contentType = response.headers['content-type'] ?? '';
  //     if (!contentType.contains('application/json')) {
  //       DebugLogger.log('Server returned non-JSON response: ${contentType}',
  //           category: 'HTTP_ERROR');
  //
  //       final preview = response.body.length > 100
  //           ? response.body.substring(0, 100)
  //           : response.body;
  //
  //       DebugLogger.log('Response preview: $preview', category: 'HTTP_ERROR');
  //       throw Exception('Server returned invalid content type: $contentType');
  //     }
  //
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> responseBody = jsonDecode(response.body);
  //
  //       if (!responseBody.containsKey('servicePosts') ||
  //           !responseBody['servicePosts'].containsKey('data')) {
  //         throw Exception('Invalid API response format');
  //       }
  //
  //       final List<dynamic> data = responseBody['servicePosts']['data'];
  //       final List<ServicePost> servicePosts =
  //           data.map((e) => ServicePost.fromJson(e)).toList();
  //
  //       return servicePosts;
  //     } else {
  //       throw Exception(
  //           'Failed to load service posts for this category: Status ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     DebugLogger.log('Error fetching service posts: $e',
  //         category: 'SERVICE_POST');
  //     throw Exception('Failed to connect to server: $e');
  //   }
  // }
  //
  //
  // Future<List<ServicePost>> getServicePostsByUserFavourite(
  //     {required int userId, required int page}) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');
  //
  //   try {
  //     final response = await http.get(
  //       Uri.parse(
  //           '$_baseUrl/api/service_posts/users/$userId/favorite?page=$page'),
  //       headers: {'Authorization': 'Bearer $token'},
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> responseBody = jsonDecode(response.body);
  //       final List<dynamic> data = responseBody['servicePosts']['data'];
  //       final List<ServicePost> servicePosts =
  //           data.map((e) => ServicePost.fromJson(e)).toList();
  //       return servicePosts;
  //     } else {
  //       throw Exception('Failed to load favorite service posts for this user');
  //     }
  //   } catch (e) {
  //     print(e);
  //
  //     throw Exception('Failed to connect to server');
  //   }
  // }
  //
  // Future<List<ServicePost>> getServicePostsByUserId(
  //     {required int userId, required int page}) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');
  //
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$_baseUrl/api/service_posts/user/$userId?page=$page'),
  //       headers: {'Authorization': 'Bearer $token'},
  //     );
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> responseBody = jsonDecode(response.body);
  //       final List<dynamic> data = responseBody['servicePosts']['data'];
  //       final List<ServicePost> servicePosts =
  //           data.map((e) => ServicePost.fromJson(e)).toList();
  //       return servicePosts;
  //     } else {
  //       throw Exception('Failed to load service posts for this user');
  //     }
  //   } catch (e) {
  //     throw Exception('Failed to connect to server');
  //   }
  // }
  //
  // Future<List<ServicePost>> getServicePostsByCategorySubCategory({
  //   required int categories,
  //   required int subCategories,
  //   required int page,
  // }) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');
  //
  //   // Validate IDs to prevent 0 values
  //   if (categories <= 0) {
  //     DebugLogger.log('Invalid category ID: $categories, using default',
  //         category: 'REPOSITORY');
  //     categories = 1;
  //   }
  //   if (subCategories <= 0) {
  //     DebugLogger.log('Invalid subcategory ID: $subCategories, using default',
  //         category: 'REPOSITORY');
  //     subCategories = 1;
  //   }
  //
  //   try {
  //     final url =
  //         '$_baseUrl/api/service_posts/categories/$categories/sub_categories/$subCategories?page=$page';
  //     DebugLogger.log('Making API request to: $url', category: 'REPOSITORY');
  //
  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: {'Authorization': 'Bearer $token'},
  //     );
  //
  //     // Log the full URL and response for debugging
  //     print('🔍 API Request URL: $url');
  //     print('🔍 API Response: ${response.body}');
  //
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> responseBody = jsonDecode(response.body);
  //       final List<dynamic> data = responseBody['servicePosts']['data'];
  //
  //       DebugLogger.log(
  //           'API Response contains ${data.length} posts for subcategory $subCategories',
  //           category: 'REPOSITORY');
  //
  //       final List<ServicePost> servicePosts =
  //           data.map((e) => ServicePost.fromJson(e)).toList();
  //       return servicePosts;
  //     } else {
  //       throw Exception('Failed to load service posts for this category');
  //     }
  //   } catch (e) {
  //     DebugLogger.log('Error in getServicePostsByCategorySubCategory: $e',
  //         category: 'REPOSITORY');
  //     throw Exception('Failed to connect to server');
  //   }
  // }

  Future<bool> updateServicePostBadge(
      ServicePost servicePost, int servicePostID) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // Create a Map object
    Map<String, String> formData = {
      'haveBadge': servicePost.haveBadge ?? 'null',
      'badgeDuration': servicePost.badgeDuration.toString(),
    };
    // Encode formData as a query string
    String encodedFormData = Uri(queryParameters: formData).query;
    // Send the request
    try {
      final response = await http
          .put(
        Uri.parse('$_baseUrl/api/service_posts/ChangeBadge/$servicePostID'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: encodedFormData,
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 400) {
        throw Exception(response.body.toString());
        return true;
      } else {
        return false;
        throw Exception(
          'Error updating service post: ${response.reasonPhrase}. Response body: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error occurred: $e');
    }
  }

  Future<bool> updateServicePostCategory(
      ServicePost servicePost, int servicePostID) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // Create a Map object
    Map<String, String> formData = {
      'category': servicePost.category?.id.toString() ??
          'null', // ✅ Extract name instead of object
      'subCategory': servicePost.subCategory?.id.toString() ?? 'null',
    };

    // Encode formData as a query string
    String encodedFormData = Uri(queryParameters: formData).query;
    // Send the request
    try {
      final url = '$_baseUrl/api/service_posts/ChangeCategories/$servicePostID';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      print('🔵 [HTTP PUT Request]');
      print('➡️ URL: $url');
      print('📩 Headers: $headers');
      print('📝 Body: $encodedFormData');

      final response = await http
          .put(
        Uri.parse(url),
        headers: headers,
        body: encodedFormData,
      )
          .timeout(const Duration(seconds: 30));

      print('🔵 [Response Received]');
      print('✅ Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          '❌ Error updating service post: ${response.reasonPhrase}. Response body: ${response.body}',
        );
      }
    } catch (e) {
      return false;
      throw Exception('Error occurred: $e');
    }
  }

  Future<ServicePost> createServicePost(
      ServicePost servicePost, List<http.MultipartFile> imageFiles) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final request =
    http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/service_posts'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    request.fields['title'] = servicePost.title ?? 'null';
    request.fields['description'] = servicePost.description ?? 'null';
    request.fields['price'] = servicePost.price.toString();
    request.fields['locationLatitudes'] =
        servicePost.locationLatitudes.toString();
    request.fields['locationLongitudes'] =
        servicePost.locationLongitudes.toString();
    request.fields['userId'] = servicePost.userId.toString();
    request.fields['type'] = servicePost.type ?? 'null';
    request.fields['haveBadge'] = servicePost.haveBadge ?? 'null';
    request.fields['badgeDuration'] =
        servicePost.badgeDuration.toString() ?? 'null';
    request.fields['categories_id'] =
        servicePost.category?.id.toString() ?? 'null';
    request.fields['sub_categories_id'] =
        servicePost.subCategory!.id.toString() ?? 'null';
    if (imageFiles.isNotEmpty) {
      request.files.addAll(imageFiles);
    }

    print(imageFiles);
    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseMap = jsonDecode(responseBody);
        final Map<String, dynamic> servicePostData = responseMap['data'];

        print('Response: $servicePostData');

        // Create ServicePost from the 'data' section
        ServicePost servicePost = ServicePost.fromJson(servicePostData);

        // Additional logging if needed
        print('categories_id: ${servicePostData['categories_id']}');
        print('Service Post Category: ${servicePostData['category']}');

        return servicePost;
      } else if (response.statusCode == 400) {
        print(
          'error : $responseBody',
        );
        throw Exception(
          'error : $responseBody',
        );
      } else {
        print(
            'Error creating service post: ${response.reasonPhrase}. Response body: $responseBody');
        throw Exception(
            'Error creating service post: ${response.reasonPhrase}. Response body: $responseBody');
      }
    } catch (e) {
      print('Error occurred: $e');

      throw Exception('Error occurred: $e');
    }
  }

  Future<bool> updateServicePost(
      ServicePost servicePost,
      List<http.MultipartFile> imageFiles,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final request = http.MultipartRequest(
        'POST', Uri.parse('$_baseUrl/api/service_posts/${servicePost.id}'));

    // Add Authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Don't set Content-Type manually for MultipartRequest
    // request.headers['Content-Type'] = 'application/x-www-form-urlencoded';

    // Add form fields
    request.fields['_method'] = 'PUT'; // Simulate PUT request
    request.fields['id'] = servicePost.id.toString();
    request.fields['title'] = servicePost.title ?? '';
    request.fields['description'] = servicePost.description ?? '';
    request.fields['price'] = servicePost.price.toString();
    request.fields['locationLatitudes'] = servicePost.locationLatitudes.toString();
    request.fields['locationLongitudes'] = servicePost.locationLongitudes.toString();
    request.fields['userId'] = servicePost.userId.toString();
    request.fields['type'] = servicePost.type ?? '';

    // Use default values instead of 'null' strings
    request.fields['haveBadge'] = servicePost.haveBadge ?? 'عادي';
    request.fields['badgeDuration'] = (servicePost.badgeDuration ?? 0).toString();

    request.fields['categories_id'] = servicePost.category?.id.toString() ?? '';
    request.fields['sub_categories_id'] = servicePost.subCategory?.id.toString() ?? '';

    // Debug output
    print('Sending update request with fields:');
    request.fields.forEach((key, value) {
      print('  $key: $value');
    });

    // Add image files if provided
    if (imageFiles.isNotEmpty) {
      print('Adding ${imageFiles.length} image file(s)');
      for (var file in imageFiles) {
        request.files.add(file);
      }
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Update response status: ${response.statusCode}');
      print('Response body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 400) {
        print('Error 400: $responseBody');
        throw Exception('error : $responseBody');
      } else {
        print('Error updating service post: ${response.reasonPhrase}. Response body: $responseBody');
        throw Exception('Error updating service post: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error occurred: $e');
      throw Exception('Error occurred: $e');
    }
  }

  Future<void> deleteServicePost({required int servicePostId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/service_posts/$servicePostId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('هذا المنشور غير موجود');
      } else {
        throw Exception('خطا في حذف المنشور');
      }
    } catch (e) {
      throw Exception('خطا الاتصال في الخادم - المنشورات');
    }
  }

  Future<void> viewIncrementServicePost({required int servicePostId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/service_posts/incrementView/$servicePostId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('هذا المنشور غير موجود');
      } else {
        throw Exception('خطا في حذف المنشور');
      }
    } catch (e) {
      throw Exception('خطا الاتصال في الخادم - المنشورات');
    }
  }

  Future<bool> toggleFavoriteServicePost({required int servicePostId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/doFavourite/$servicePostId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_favorited'];
      } else {
        throw Exception('Error toggling favorite state');
      }
    } catch (e) {
      throw Exception('Server connection error - Posts');
    }
  }

  Future<bool> getFavourite({required int servicePostId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/getFavourite/$servicePostId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Return true if the response indicates that the post is favorited
        return true;
      } else if (response.statusCode == 404) {
        // Return false if the response indicates that the post is not favorited
        return false;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception('خطا الاتصال في الخادم - المنشورات');
    }
  }

  Future<bool> updateServicePostImage(List<http.MultipartFile> imageFiles,
      {required int servicePostImageId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final request = http.MultipartRequest(
          'POST',
          Uri.parse(
              '$_baseUrl/api/service_posts/updatePhoto/$servicePostImageId'));

      request.headers['Authorization'] = 'Bearer $token';

      if (imageFiles.isNotEmpty) {
        request.files.addAll(imageFiles);
      }

      final response = await request.send();
      print(response.statusCode);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception('خطا الاتصال في الخادم - المنشورات');
    }
  }

  Future<void> deleteServicePostImage({required int servicePostImageId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token not found in shared preferences');
    }

    try {
      final response = await http.delete(
        Uri.parse(
            '$_baseUrl/api/service_posts/deletePhoto/$servicePostImageId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        throw Exception('خطا في حذف الصورة');
      }
    } catch (e) {
      throw Exception('خطا الاتصال في الخادم - المنشورات');
    }
  }
}