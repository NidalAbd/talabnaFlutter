import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/utils/constants.dart';

class UserContactRepository {
  static const String _baseUrl = Constants.apiBaseUrl;

  Future<User> getUserProfileById({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(Uri.parse('$_baseUrl/api/user/profile/$id'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = jsonDecode(response.body);
      if (jsonData.containsKey('userData') && jsonData['userData'] != null) {
        return User.fromJson(jsonData['userData']);
      } else {
        throw Exception('JSON response does not contain userData');
      }
    } else if (response.statusCode == 404) {
      throw Exception('هذا الملف الشخصي غير موجود');
    } else {
      throw Exception('فشل في تحميل الملف الشخصي');
    }
  }
}
