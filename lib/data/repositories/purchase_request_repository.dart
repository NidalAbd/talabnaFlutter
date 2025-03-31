import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/models/point_balance.dart';
import 'package:talabna/data/models/purchase_request.dart';
import 'package:talabna/data/repositories/point_transaction_repository.dart';
import 'package:talabna/utils/constants.dart';

import '../../core/service_locator.dart';

class PurchaseRequestRepository {
  static const baseUrl = Constants.apiBaseUrl;

  Future<List<PurchaseRequest>> fetchPurchaseRequests(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/purchase-requests/user/$userId'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as List<dynamic>;
      final purchaseRequests = jsonResponse
          .map((json) => PurchaseRequest.fromJson(json))
          .toList(growable: false);
      return purchaseRequests;
    } else {
      throw Exception('حدث خطأ أثناء جلب طلبات الشراء');
    }
  }

  Future<void> createPurchaseRequest(PurchaseRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.post(
      Uri.parse('$baseUrl/api/purchase-requests'),
      body: jsonEncode(request.toJson()),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    } else {
      throw Exception('حدث خطأ أثناء إرسال طلب الشراء');
    }
  }

  Future<PurchaseRequest> addPointsForUsers({
    required int pointsRequested,
    required int fromUser,
    required int toUser,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Log request details for debugging
    print('Requesting URL: $baseUrl/api/talbna_points/transfer/$pointsRequested/fromUser/$fromUser/toUser/$toUser');

    final response = await http.get(
      Uri.parse('$baseUrl/api/talbna_points/transfer/$pointsRequested/fromUser/$fromUser/toUser/$toUser'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // Check if the response contains a purchase_request object
      if (jsonResponse.containsKey('purchase_request')) {
        // Parse the purchase request
        final purchaseRequest = PurchaseRequest.fromJson(jsonResponse['purchase_request']);

        // After successful transfer, refresh transaction data
        try {
          // Use the service locator to get the PointTransactionRepository
          if (serviceLocator.isRegistered<PointTransactionRepository>()) {
            final pointTransactionRepository = serviceLocator<PointTransactionRepository>();

            // This could be called asynchronously, no need to await
            pointTransactionRepository.getLastTransactions(fromUser);
            if (fromUser != toUser) {
              pointTransactionRepository.getTransactionsBetweenUsers(fromUser, toUser);
            }
          }
        } catch (e) {
          print('Error refreshing transaction data: $e');
          // Don't throw an exception here, as the main operation succeeded
        }

        return purchaseRequest;
      } else {
        // If no purchase request was returned, create a default one
        return PurchaseRequest(
          id: 0,
          userId: fromUser,
          pointsRequested: pointsRequested,
          pricePerPoint: 0,
          totalPrice: 0,
          status: 'approved',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } else {
      throw Exception('حدث خطأ أثناء تحويل النقاط');
    }
  }

  Future<PointBalance> getUserPointsBalance({required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/user/point/$userId'),
      headers: {
        "Content-Type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> json = jsonDecode(response.body);
      int pointBalance = 0;
      if (json['pointBalance'] != null) {
        if (json['pointBalance'] is int) {
          pointBalance = json['pointBalance'];
        } else if (json['pointBalance'] is String) {
          pointBalance = int.parse(json['pointBalance']);
        }
      }

      return PointBalance(userId: userId, totalPoint: pointBalance);
    } else {
      throw Exception("Failed to fetch user points balance");
    }
  }

  Future<void> cancelPurchaseRequest(int requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/purchase-requests/$requestId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('حدث خطأ أثناء إلغاء طلب الشراء');
      }
    } catch (e) {
      throw Exception('حدث خطأ ');
    }
  }
}
