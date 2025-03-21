import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/utils/constants.dart';

import '../models/photos.dart';

class UniqueConstraintException implements Exception {
  final String message;
  final String? field;

  UniqueConstraintException({required this.message, this.field});

  @override
  String toString() => message;
}

class UserProfileRepository {
  static const String _baseUrl = Constants.apiBaseUrl;

  Future<User> getUserProfileById(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/profile/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("HTTP Response Status: ${response.statusCode}");
      print("HTTP Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);

        if (!jsonData.containsKey('userData') || jsonData['userData'] == null) {
          print("Error: JSON response does not contain 'userData'");
          throw Exception('JSON response does not contain userData');
        }

        try {
          return User.fromJson(jsonData['userData']);
        } catch (e) {
          print("Error parsing userData: $e");
          throw Exception('Failed to parse userData: $e');
        }
      } else if (response.statusCode == 404) {
        print("Error: User profile not found (404)");
        throw Exception('هذا الملف الشخصي غير موجود');
      } else {
        print(
            "Error: Failed to load profile, status code: ${response.statusCode}");
        throw Exception('فشل في تحميل الملف الشخصي');
      }
    } catch (e) {
      print("Unexpected error: $e");
      throw Exception('خطأ غير متوقع: $e');
    }
  }

  Future<List<User>> getFollowerByUserId(
      {required int userId, int page = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
        Uri.parse('$_baseUrl/api/user/follower/$userId?page=$page'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<User> userFollower =
          (data["data"] as List).map((e) => User.fromJson(e)).toList();
      return userFollower;
    } else if (response.statusCode == 404) {
      throw Exception('هذا الملف الشخصي غير موجود');
    } else {
      throw Exception('فشل في تحميل المتابعين');
    }
  }

  Future<List<User>> getFollowingByUserId(
      {required int userId, int page = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/user/following/$userId?page=$page'),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<User> userFollowing =
            (data["data"] as List).map((e) => User.fromJson(e)).toList();
        return userFollowing;
      } else if (response.statusCode == 404) {
        throw Exception('هذا الملف الشخصي غير موجود');
      } else {
        throw Exception('فشل في تحميل المتابعين');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال بالخادم - المتابعين');
    }
  }

  Future<User> updateUserProfile(User user, [BuildContext? context]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    print('Updating user profile - ID: ${user.id}');
    print('Phone: ${user.phones}');
    print('WhatsApp: ${user.watsNumber}');

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/users/${user.id}'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token'
            },
            body: jsonEncode(user.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing response JSON: $e');
        throw Exception('خطا في تحليل استجابة الخادم: ${response.body}');
      }

      // Check for errors first regardless of status code
      if (responseData['status'] == 'error') {
        // Check for validation errors or unique constraint violations
        if (responseData['error_type'] == 'unique_constraint' ||
            responseData['error_type'] == 'validation') {
          String errorMessage;
          String? field = responseData['field'] as String?;

          try {
            // Try to parse the message as JSON if it's a string
            final dynamic messageData = responseData['message'];
            if (messageData is String) {
              try {
                final messageJson = jsonDecode(messageData);
                final isArabic = context != null &&
                    Localizations.localeOf(context).languageCode == 'ar';
                errorMessage = isArabic ? messageJson['ar'] : messageJson['en'];
              } catch (e) {
                // If parsing fails, use the message directly
                errorMessage = messageData;
              }
            } else {
              // If message is not a string, convert to string
              errorMessage = messageData.toString();
            }
          } catch (e) {
            // Default error message
            errorMessage = 'Error with ${field ?? "field"}';
          }

          throw UniqueConstraintException(message: errorMessage, field: field);
        } else {
          // Generic error
          throw Exception(
              responseData['message'] as String? ?? 'Error updating profile');
        }
      }

      // If we've reached here, it's a success response
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          if (responseData.containsKey('user')) {
            final jsonData = user.toJson();
            print('Sending user data to server: ${jsonEncode(jsonData)}');
            return User.fromJson(responseData['user']);
          } else if (responseData['status'] == 'success') {
            return user; // Return original if no user data returned
          } else {
            return User.fromJson(responseData);
          }
        } catch (e) {
          print('Error creating User from response: $e');
          return user;
        }
      } else {
        // If it's not a success status code but didn't have error status
        throw Exception('Unexpected response: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('خطا في الاتصال بالإنترنت - يرجى التحقق من اتصالك');
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال - يرجى المحاولة لاحقًا');
    } on FormatException {
      throw Exception('خطا في تنسيق البيانات');
    } catch (e) {
      if (e is UniqueConstraintException) {
        rethrow;
      }
      print('General exception during profile update: $e');
      throw Exception('خطا الاتصال في الخادم - الملف الشخصي: $e');
    }
  }

  Future<void> updateUserEmail(
      User user, String newEmail, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/${user.id}/change-email'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({'email': newEmail, 'password': password}),
      );
      print(jsonEncode({'email': newEmail, 'password': password}));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('password is incorrect.');
      } else {
        throw Exception('Failed to update email.');
      }
    } catch (e) {
      print(e);
      throw Exception(e);
    }
  }

  Future<void> updateUserPassword(
      User user, String oldPassword, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/${user.id}/change-password'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(
            {'old_password': oldPassword, 'new_password': newPassword}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Old password is incorrect.');
      } else {
        throw Exception('Failed to update password , status code error.');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

// Update profile photo
  Future<void> updateUserProfilePhoto(User user, File photo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final stream = http.ByteStream(photo.openRead());
      final length = await photo.length();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/user/${user.id}/update-profile-photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      final multipartFile = http.MultipartFile('photo', stream, length,
          filename: basename(photo.path));
      request.files.add(multipartFile);
      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(await response.stream.bytesToString());
        print('dwd ${responseBody['photo']}');

        if (responseBody['photo'] != null) {
          Photo updatedPhoto = Photo.fromJson(responseBody['photo']);
          user.photos?.add(updatedPhoto);
        }
        return;
      } else {
        throw Exception('Failed to update profile photo.');
      }
    } catch (e) {
      throw Exception('Failed to update profile photo.');
    }
  }
}
