import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class EmployeeExpenseApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  EmployeeExpenseApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> createExpense(
    String employeeId,
    String name,
    double value, {
    String note = '',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/employee-expenses'),
        headers: headers,
        body: json.encode({
          'user': employeeId,
          'name': name,
          'value': value,
          'note': note,
        }),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create expense',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  Future<List<Map<String, dynamic>>> listByEmployee(String employeeId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/employee-expenses/user/$employeeId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load employee expenses',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/employee-expenses/$id'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to delete expense',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
