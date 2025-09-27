import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class SupplierApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  SupplierApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get all suppliers
  Future<List<Map<String, dynamic>>> getAllSuppliers({String? search}) async {
    try {
      final headers = await _getAuthHeaders();
      String url = '$baseUrl/suppliers';

      // Add search parameter if provided
      if (search != null) {
        url += '?search=$search';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load suppliers',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get supplier by ID
  Future<Map<String, dynamic>?> getSupplierById(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/suppliers/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException(
          message: 'Failed to load supplier',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Create new supplier
  Future<Map<String, dynamic>> createSupplier(
    Map<String, dynamic> supplierData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/suppliers'),
        headers: headers,
        body: json.encode(supplierData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create supplier',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update supplier
  Future<Map<String, dynamic>> updateSupplier(
    String id,
    Map<String, dynamic> supplierData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/suppliers/$id'),
        headers: headers,
        body: json.encode(supplierData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to update supplier',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete supplier
  Future<void> deleteSupplier(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/suppliers/$id'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete supplier',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get supplier statistics
  Future<Map<String, dynamic>> getSupplierStats() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/suppliers/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException(
          message: 'Failed to load supplier statistics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
