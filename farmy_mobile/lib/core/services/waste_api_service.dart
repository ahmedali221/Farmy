import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/authentication/services/token_service.dart';
import '../constants/api_constants.dart';

class WasteApiService {
  static const String _baseUrl = ApiConstants.baseUrl;
  final TokenService _tokenService;

  WasteApiService({required TokenService tokenService})
    : _tokenService = tokenService;

  /// Get authorization headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> getWasteByDate(String date) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/waste/by-date?date=$date'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load waste data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching waste data: $e');
    }
  }

  Future<Map<String, dynamic>> getWasteSummary(
    String startDate,
    String endDate,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/waste/summary?startDate=$startDate&endDate=$endDate',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load waste summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching waste summary: $e');
    }
  }

  Future<Map<String, dynamic>> upsertWaste({
    required String date,
    required String chickenType,
    double overDistributionQuantity = 0,
    double overDistributionNetWeight = 0,
    double otherWasteQuantity = 0,
    double otherWasteNetWeight = 0,
    String notes = '',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/waste/upsert'),
        headers: headers,
        body: json.encode({
          'date': date,
          'chickenType': chickenType,
          'overDistributionQuantity': overDistributionQuantity,
          'overDistributionNetWeight': overDistributionNetWeight,
          'otherWasteQuantity': otherWasteQuantity,
          'otherWasteNetWeight': otherWasteNetWeight,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to upsert waste: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error upserting waste: $e');
    }
  }
}
