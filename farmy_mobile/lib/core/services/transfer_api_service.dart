import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

class TransferApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  TransferApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> createTransfer({
    required String fromUser,
    required String toUser,
    required double amount,
    String? note,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/transfers'),
        headers: headers,
        body: json.encode({
          'fromUser': fromUser,
          'toUser': toUser,
          'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      final dynamic errorData = json.decode(response.body);
      throw ApiException(
        message: (errorData is Map<String, dynamic>)
            ? (errorData['message'] ?? 'Failed to create transfer')
            : 'Failed to create transfer',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }

  Future<List<Map<String, dynamic>>> listTransfers({String? userId}) async {
    try {
      final headers = await _getAuthHeaders();
      final query = userId != null && userId.isNotEmpty
          ? '?userId=$userId'
          : '';
      final response = await http.get(
        Uri.parse('$baseUrl/transfers$query'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw ApiException(
        message: 'Failed to load transfers',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', statusCode: 0);
    }
  }
}
