import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class LoadingApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  LoadingApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Create new loading (التحميل)
  ///
  /// Required fields:
  /// - chickenType: ID of the chicken type (النوع)
  /// - supplier: ID of the supplier (المورد)
  /// - quantity: Number of units (العدد)
  /// - grossWeight: Gross weight in kg (الوزن القائم)
  /// - loadingPrice: Price per kg entered by user (سعر التحميل)
  /// - notes: Optional notes (ملاحظات)
  ///
  /// Auto calculated fields:
  /// - netWeight: Net weight = grossWeight - (quantity * 8)
  /// - totalLoading: Total loading = netWeight * loadingPrice
  Future<Map<String, dynamic>> createLoading(
    Map<String, dynamic> loadingData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/loadings'),
        headers: headers,
        body: json.encode(loadingData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create loading',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get all loadings
  Future<List<Map<String, dynamic>>> getAllLoadings() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/loadings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load loadings',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get loadings by current user
  Future<List<Map<String, dynamic>>> getLoadingsByUser() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/loadings/user'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load user loadings',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get loadings by specific supplier
  Future<List<Map<String, dynamic>>> getLoadingsBySupplier(
    String supplierId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/loadings/supplier/$supplierId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load supplier loadings',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get loading by ID
  Future<Map<String, dynamic>?> getLoadingById(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/loadings/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException(
          message: 'Failed to load loading',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update loading
  Future<Map<String, dynamic>> updateLoading(
    String id,
    Map<String, dynamic> loadingData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/loadings/$id'),
        headers: headers,
        body: json.encode(loadingData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to update loading',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete loading
  Future<void> deleteLoading(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/loadings/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete loading',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete all loadings
  Future<void> deleteAllLoadings() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/loadings/all'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete all loadings',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get loading statistics
  Future<Map<String, dynamic>> getLoadingStats({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      String url = '$baseUrl/loadings/stats';

      if (startDate != null && endDate != null) {
        url += '?startDate=$startDate&endDate=$endDate';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException(
          message: 'Failed to load loading statistics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
