import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class DistributionApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  DistributionApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Create a new distribution record
  ///
  /// Required fields:
  /// - customer: ID of the customer (العميل)
  /// - chickenType: ID of the chicken type (نوع الفراخ)
  /// - sourceLoading: ID of the source loading order (طلب التحميل المصدر)
  /// - quantity: Number of units (الكمية)
  /// - grossWeight: Gross weight in kg (الوزن القائم)
  /// - price: Price per kg (سعر الكيلو)
  /// - distributionDate: Distribution date (تاريخ التوزيع)
  ///
  /// Auto-calculated by backend (do NOT send from frontend):
  /// - emptyWeight = quantity * 8
  /// - netWeight = max(0, grossWeight - emptyWeight)
  /// - totalAmount = netWeight * price
  Future<Map<String, dynamic>> createDistribution(
    Map<String, dynamic> distributionData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/distributions'),
        headers: headers,
        body: json.encode(distributionData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create distribution',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get all distributions
  Future<List<Map<String, dynamic>>> getAllDistributions() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/distributions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load distributions',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distributions by date range
  Future<List<Map<String, dynamic>>> getDistributionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/distributions/date-range?start=${startDate.toIso8601String()}&end=${endDate.toIso8601String()}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load distributions by date range',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distributions by customer ID
  Future<List<Map<String, dynamic>>> getDistributionsByCustomer(
    String customerId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/distributions/customer/$customerId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load distributions by customer',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distributions by employee ID
  Future<List<Map<String, dynamic>>> getDistributionsByEmployee(
    String employeeId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/distributions/employee/$employeeId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load distributions by employee',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distribution by ID
  ///
  /// Returns a Map containing:
  /// - All standard distribution fields
  /// - outstandingBeforeDistribution: Customer's outstanding debts before this distribution
  /// - outstandingAfterDistribution: Customer's outstanding debts after this distribution
  Future<Map<String, dynamic>> getDistributionById(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/distributions/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw ApiException(
          message: 'Distribution not found',
          statusCode: response.statusCode,
        );
      } else {
        throw ApiException(
          message: 'Failed to load distribution',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update distribution by ID
  Future<Map<String, dynamic>> updateDistribution(
    String id,
    Map<String, dynamic> distributionData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/distributions/$id'),
        headers: headers,
        body: json.encode(distributionData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to update distribution',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete distribution by ID
  Future<void> deleteDistribution(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/distributions/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete distribution',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete all distributions
  Future<void> deleteAllDistributions() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/distributions/all'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete all distributions',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get available loadings for distribution
  ///
  /// Parameters:
  /// - date: The distribution date
  /// - chickenType: The chicken type ID
  Future<List<Map<String, dynamic>>> getAvailableLoadings(
    DateTime date,
    String chickenType,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/distributions/available-loadings?date=${date.toIso8601String()}&chickenType=$chickenType',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load available loadings',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get chicken types that have loadings on a specific date
  ///
  /// Parameters:
  /// - date: The distribution date
  Future<List<Map<String, dynamic>>> getAvailableChickenTypes(
    DateTime date,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/distributions/available-chicken-types?date=${date.toIso8601String()}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load available chicken types',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get available quantities for a specific chicken type on a date
  ///
  /// Parameters:
  /// - date: The distribution date
  /// - chickenType: The chicken type ID
  Future<Map<String, dynamic>> getAvailableQuantities(
    DateTime date,
    String chickenType,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/distributions/available-quantities?date=${date.toIso8601String()}&chickenType=$chickenType',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException(
          message: 'Failed to load available quantities',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distribution shortages for a specific date
  ///
  /// Parameters:
  /// - date: The distribution date
  Future<Map<String, dynamic>> getDistributionShortages(DateTime date) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/distributions/distribution-shortages?date=${date.toIso8601String()}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException(
          message: 'Failed to load distribution shortages',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get daily net weight for distributions
  Future<Map<String, dynamic>> getDailyNetWeight(DateTime date) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/distributions/daily-net-weight?date=${date.toIso8601String()}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException(
          message: 'Failed to load daily net weight',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distributions by date
  Future<List<Map<String, dynamic>>> getDistributionsByDate(String date) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/distributions/by-date?date=$date'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load distributions by date',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get distribution statistics
  Future<Map<String, dynamic>> getDistributionStatistics() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/distributions/statistics'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException(
          message: 'Failed to load distribution statistics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
