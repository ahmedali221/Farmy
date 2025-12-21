import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class EmployeeApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  EmployeeApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Create a distribution record
  Future<Map<String, dynamic>> createDistribution(
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/distributions'),
        headers: headers,
        body: json.encode(data),
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

  /// Get daily total net weight for distributions
  Future<Map<String, dynamic>> getDailyDistributionNetWeight({
    DateTime? date,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final q = date != null ? '?date=${date.toIso8601String()}' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/distributions/daily-net-weight$q'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to fetch daily net weight',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Upsert daily stock record (manager only)
  Future<Map<String, dynamic>> upsertDailyStock({
    required DateTime date,
    required double netDistributionWeight,
    required double adminAdjustment,
    String? notes,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = {
        'date': date.toIso8601String(),
        'netDistributionWeight': netDistributionWeight,
        'adminAdjustment': adminAdjustment,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/stocks/upsert'),
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to save daily stock',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get weekly stocks
  Future<List<Map<String, dynamic>>> getWeeklyStocks() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/stocks/week'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load weekly stocks',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get all users with employee role
  Future<List<Map<String, dynamic>>> getAllEmployeeUsers() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/employees/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load employee users',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get all users (employees + managers) - for transfer selection
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/employees/users/all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load all users',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Get employee by ID
  Future<Map<String, dynamic>?> getEmployeeById(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/employees/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException(
          message: 'Failed to load employee',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Create new employee user
  Future<Map<String, dynamic>> createEmployeeUser(
    Map<String, dynamic> userData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/employees/users'),
        headers: headers,
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create employee user',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Update employee user
  Future<Map<String, dynamic>> updateEmployeeUser(
    String id,
    Map<String, dynamic> userData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/employees/users/$id'),
        headers: headers,
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to update employee user',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Delete employee user
  Future<void> deleteEmployeeUser(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/employees/users/$id'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete employee user',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  /// Add daily log to employee
  Future<Map<String, dynamic>> addDailyLog(
    String employeeId,
    Map<String, dynamic> logData,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/employees/$employeeId/daily-logs'),
        headers: headers,
        body: json.encode(logData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to add daily log',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
