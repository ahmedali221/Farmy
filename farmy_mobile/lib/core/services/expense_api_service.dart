import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import 'api_exception.dart';

class ExpenseApiService {
  static const String baseUrl =
      'https://farmy-3b980tcc5-ahmed-alis-projects-588ffe47.vercel.app/api';
  final TokenService _tokenService;

  ExpenseApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  Future<Map<String, String>> getHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, String>> _headers() async => getHeaders();

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (res.statusCode == 201) return json.decode(res.body);
    throw ApiException(
      message: 'Failed to create expense',
      statusCode: res.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> getExpensesByOrder(String orderId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/expenses/order/$orderId'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw ApiException(
      message: 'Failed to load expenses',
      statusCode: res.statusCode,
    );
  }
}
