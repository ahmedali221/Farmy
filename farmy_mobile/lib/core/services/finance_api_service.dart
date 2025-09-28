import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class FinanceApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  FinanceApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> createFinancialRecord({
    required DateTime date,
    required String type, // 'daily' or 'monthly'
    double? revenue,
    double? expenses,
    double? netProfit,
    double? outstandingDebts,
    String? employeeId,
    String? source,
    String? notes,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = <String, dynamic>{
        'date': date.toIso8601String(),
        'type': type,
        if (employeeId != null && employeeId.isNotEmpty) 'employee': employeeId,
        if (source != null) 'source': source,
        if (notes != null) 'notes': notes,
        if (revenue != null) 'revenue': revenue,
        if (expenses != null) 'expenses': expenses,
        if (netProfit != null) 'netProfit': netProfit,
        if (outstandingDebts != null) 'outstandingDebts': outstandingDebts,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/finances'),
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Failed to create financial record',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  Future<List<Map<String, dynamic>>> getDailyFinancialReports() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/finances/daily'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          message: 'Failed to load daily finance reports',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  Future<Map<String, dynamic>> getMonthlySummary({
    required int month,
    required int year,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/finances/monthly?month=$month&year=$year'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          message: 'Failed to load monthly finance summary',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
