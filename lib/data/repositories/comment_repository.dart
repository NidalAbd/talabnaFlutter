import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/models/comment.dart';

import '../../utils/constants.dart';

class CommentRepository {
  static const String _baseUrl = Constants.apiBaseUrl;

  Future<List<Comments>> fetchComments(
      {required int postId, int page = 1, int maxRetries = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.get(
            Uri.parse('$_baseUrl/api/commentsForPost/$postId?page=$page'),
            headers: {
              'Authorization': 'Bearer $token'
            }).timeout(Duration(seconds: 10), // Add a timeout
            onTimeout: () {
          throw TimeoutException(
              'The connection has timed out, please try again.');
        });

        switch (response.statusCode) {
          case 200:
            final Map<String, dynamic> data = jsonDecode(response.body);
            final List<Comments> comments = (data["data"] as List)
                .map((e) => Comments.fromJson(e))
                .toList();
            return comments;

          case 404:
            throw Exception('Post not found');

          case 429: // Too Many Requests
            // Exponential backoff
            int delay = (pow(2, attempt) * 1000).toInt();
            print('Rate limited. Waiting for $delay ms before retry.');
            await Future.delayed(Duration(milliseconds: delay));
            continue; // Try again

          default:
            print(
                'Failed to load comments. Status Code: ${response.statusCode}. Response body: ${response.body}');
            throw Exception('Failed to load comments');
        }
      } on SocketException {
        // No internet connection
        if (attempt == maxRetries - 1) {
          throw Exception('No internet connection');
        }
      } on TimeoutException {
        // Connection timeout
        if (attempt == maxRetries - 1) {
          throw Exception('Connection timed out');
        }
      } catch (e) {
        // For any other unexpected errors
        if (attempt == maxRetries - 1) {
          rethrow;
        }
      }
    }

    throw Exception('Failed to load comments after multiple attempts');
  }

  Future<Comments> addComment(Comments comment, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/comments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(comment.toJson()),
    );
    print(response.statusCode);
    if (response.statusCode == 201) {
      // Assuming the response body is empty and only the status code indicates success
      return comment; // Return the original comment object
    } else {
      throw Exception(
          'Failed to add comment. Status Code: ${response.statusCode}');
    }
  }

  Future<Comments> updateComment(Comments comment, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.put(
      Uri.parse('$_baseUrl/api/comments/${comment.id}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(comment.toJson()),
    );

    if (response.statusCode == 200) {
      return Comments.fromJson(json.decode(response.body));
    } else {
      throw Exception(
          'Failed to update comment. Status Code: ${response.statusCode}');
    }
  }

  Future<void> deleteComment(int commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/comments/$commentId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 204 || response.statusCode == 200) {
      // Comment deleted successfully
    } else {
      throw Exception(
          'Failed to delete comment. Status Code: ${response.statusCode}');
    }
  }
}
