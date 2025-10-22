import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class InventoryApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  InventoryApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get all chicken types (shared endpoint for both managers and employees)
  /// [date] - optional date filter in YYYY-MM-DD format
  Future<List<Map<String, dynamic>>> getAllChickenTypes({String? date}) async {
    try {
      final headers = await _getAuthHeaders();

      // Build URL with optional date query parameter
      String url = '$baseUrl/chicken-types';
      if (date != null) {
        url += '?date=$date';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to load chicken types',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get daily inventory by date (manager only)
  Future<Map<String, dynamic>> getDailyInventoryByDate(String date) async {
    try {
      final headers = await _getAuthHeaders();
      final url = '$baseUrl/stocks/by-date?date=$date';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to load daily inventory',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get daily profit and components
  Future<Map<String, dynamic>> getDailyProfit(String date) async {
    try {
      final headers = await _getAuthHeaders();
      final url = '$baseUrl/stocks/profit?date=$date';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to load daily profit',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get total profit history (sum of all daily profits)
  /// [startDate] and [endDate] are optional - if not provided, calculates from all time
  Future<Map<String, dynamic>> getTotalProfitHistory({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      String url = '$baseUrl/stocks/total-profit';

      // Add query parameters if provided
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      if (queryParams.isNotEmpty) {
        url +=
            '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message:
                errorData['message'] ?? 'Failed to load total profit history',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Upsert daily inventory values using admin inputs
  /// Calculates result using: (netLoadingWeight - netDistributionWeight) - adminAdjustment
  Future<Map<String, dynamic>> upsertDailyInventory({
    required String date,
    required num adminAdjustment,
    String? notes,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = {
        'date': DateTime.parse(date).toIso8601String(),
        'adminAdjustment': adminAdjustment,
        if (notes != null) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/stocks/upsert'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to update daily inventory',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get chicken type by ID (manager only)
  Future<Map<String, dynamic>?> getChickenTypeById(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/managers/chicken-types/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException(
          message: 'Failed to load chicken type',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Create new chicken type (manager only)
  /// chickenTypeData should include: name, price (EGP per kilo), stock, date (optional)
  Future<Map<String, dynamic>> createChickenType(
    Map<String, dynamic> chickenTypeData,
  ) async {
    try {
      final headers = await _getAuthHeaders();

      // Prepare data for API - include date if provided
      final apiData = Map<String, dynamic>.from(chickenTypeData);

      // If date is provided, format it properly for the backend
      if (apiData.containsKey('date')) {
        // Convert date to ISO format that backend expects
        final dateStr = apiData['date'] as String;
        final date = DateTime.parse(dateStr);
        apiData['date'] = date.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/managers/chicken-types'),
        headers: headers,
        body: json.encode(apiData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to create chicken type',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update chicken type (manager only)
  /// chickenTypeData should include: name, price (EGP per kilo), stock, date (optional)
  Future<Map<String, dynamic>> updateChickenType(
    String id,
    Map<String, dynamic> chickenTypeData,
  ) async {
    try {
      final headers = await _getAuthHeaders();

      // Prepare data for API - include date if provided
      final apiData = Map<String, dynamic>.from(chickenTypeData);

      // If date is provided, format it properly for the backend
      if (apiData.containsKey('date')) {
        // Convert date to ISO format that backend expects
        final dateStr = apiData['date'] as String;
        final date = DateTime.parse(dateStr);
        apiData['date'] = date.toIso8601String();
      }

      final response = await http.put(
        Uri.parse('$baseUrl/managers/chicken-types/$id'),
        headers: headers,
        body: json.encode(apiData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to update chicken type',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete chicken type (manager only)
  Future<void> deleteChickenType(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/managers/chicken-types/$id'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return; // Success
      } else {
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            message: errorData['message'] ?? 'Failed to delete chicken type',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw ApiException(
            message:
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unexpected response'}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update stock for chicken type (manager only)
  Future<Map<String, dynamic>> updateStock(String id, int newStock) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/managers/chicken-types/$id'),
        headers: headers,
        body: json.encode({'stock': newStock}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to update stock',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
