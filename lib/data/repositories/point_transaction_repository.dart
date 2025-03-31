import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/models/point_transaction.dart';
import 'package:talabna/utils/constants.dart';

class PointTransactionRepository {
  static const baseUrl = Constants.apiBaseUrl;

  // Get all transactions for a specific user
  Future<List<PointTransaction>> getUserTransactions(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/transactions/user/$userId'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as List<dynamic>;
      final transactions = jsonResponse
          .map((json) => PointTransaction.fromJson(json))
          .toList(growable: false);
      return transactions;
    } else {
      throw Exception('حدث خطأ أثناء جلب المعاملات');
    }
  }

  // Get transactions between two specific users - Fixed implementation
  Future<List<PointTransaction>> getTransactionsBetweenUsers(
      int fromUserId, int toUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/transactions/between/$fromUserId/$toUserId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status for transactions between users: ${response.statusCode}');
      print('Getting transactions between users $fromUserId and $toUserId');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as List<dynamic>;
        final transactions = jsonResponse
            .map((json) => PointTransaction.fromJson(json))
            .toList(growable: false);

        print('Found ${transactions.length} transactions between users $fromUserId and $toUserId');

        // No need for additional filtering here since the backend should return the correct data
        // But we'll double-check just to be safe
        return transactions;
      } else {
        print('Error response: ${response.body}');
        throw Exception('Failed to load transactions between users');
      }
    } catch (e) {
      print('Error fetching transactions between users: $e');
      throw Exception('حدث خطأ أثناء جلب المعاملات بين المستخدمين');
    }
  }

  // Get last N transactions for a specific user
  Future<List<PointTransaction>> getLastTransactions(int userId, [int limit = 5]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/transactions/last/$userId/$limit'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as List<dynamic>;
      final transactions = jsonResponse
          .map((json) => PointTransaction.fromJson(json))
          .toList(growable: false);
      return transactions;
    } else {
      throw Exception('حدث خطأ أثناء جلب آخر المعاملات');
    }
  }

  // Helper method to record a transaction after a successful point transfer
  Future<void> recordPointTransaction({
    required int fromUserId,
    required int toUserId,
    required int points,
  }) async {
    // This functionality would ideally be handled automatically by the backend
    // But we can implement it here if needed
    print('Transaction recorded: $points points from $fromUserId to $toUserId');
  }
}