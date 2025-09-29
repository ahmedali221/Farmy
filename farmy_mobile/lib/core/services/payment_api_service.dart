import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class PaymentApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  PaymentApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get payments collected by a user (raw list)
  Future<List<Map<String, dynamic>>> getPaymentsByUser(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load user payments',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get daily grouped payments for a user
  /// Returns: [{ date: 'YYYY-MM-DD', totalPaid: number, count: number, payments: [ ... ] }]
  Future<List<Map<String, dynamic>>> getUserDailyCollections(
    String userId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/user/$userId?groupBy=day'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load user daily collections',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Create new payment
  Future<Map<String, dynamic>> createPayment(
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/payments'),
        headers: headers,
        body: json.encode(paymentData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create payment',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get payment by ID
  Future<Map<String, dynamic>?> getPaymentById(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException(
          message: 'Failed to load payment',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get all payments
  Future<List<Map<String, dynamic>>> getAllPayments() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load payments',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get payments by order ID
  Future<List<Map<String, dynamic>>> getPaymentsByOrder(String orderId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/order/$orderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load payments for order',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get payment summary for order
  Future<Map<String, dynamic>> getPaymentSummary(String orderId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/summary/$orderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to load payment summary',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get user collections summary
  Future<List<Map<String, dynamic>>> getUserCollectionsSummary() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/summary/user'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        final dynamic errorData = json.decode(response.body);
        throw ApiException(
          message: (errorData is Map<String, dynamic>)
              ? (errorData['message'] ?? 'Failed to load user collections')
              : 'Failed to load user collections',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update payment
  Future<Map<String, dynamic>> updatePayment(
    String id,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/payments/$id'),
        headers: headers,
        body: json.encode(paymentData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to update payment',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete payment by ID
  Future<void> deletePayment(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/payments/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        try {
          final dynamic errorData = json.decode(response.body);
          throw ApiException(
            message: (errorData is Map<String, dynamic>)
                ? (errorData['message'] ?? 'Failed to delete payment')
                : 'Failed to delete payment',
            statusCode: response.statusCode,
          );
        } catch (_) {
          // Non-JSON error (e.g., HTML 404 page); surface generic error with status
          throw ApiException(
            message: 'Failed to delete payment',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
