import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/user.dart';

class AuthService {
  // Use API constants for base URL
  static const String baseUrl = ApiConstants.baseUrl;

  /// Login user with username and password
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        // Extract token from response
        final token = responseData['token'] as String;

        // Check if user data is provided in response
        if (responseData.containsKey('user') && responseData['user'] != null) {
          final userData = responseData['user'] as Map<String, dynamic>;
          final user = User.fromJson(userData).copyWith(token: token);

          return LoginResponse(
            token: token,
            user: user,
            message: responseData['message'] as String?,
          );
        } else {
          // If no user data in response, decode from JWT token
          final user = _decodeUserFromToken(token);

          return LoginResponse(
            token: token,
            user: user,
            message: responseData['message'] as String?,
          );
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          message: errorData['message'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      // Print detailed error for debugging
      print('Auth Service Error: $e');
      print('Error type: ${e.runtimeType}');

      throw AuthException(
        message: 'Network error: Unable to connect to server. Details: $e',
        statusCode: 0,
      );
    }
  }

  /// Validate token with server
  Future<User?> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(responseData['user']).copyWith(token: token);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Logout user (if server-side logout is needed)
  Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      // Ignore logout errors as we'll clear local data anyway
    }
  }

  /// Decode user information from JWT token
  User _decodeUserFromToken(String token) {
    try {
      // Split JWT token into parts
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT token format');
      }

      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if needed for base64 decoding
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
        default:
          throw Exception('Invalid base64 string');
      }
      final decoded = utf8.decode(base64.decode(normalizedPayload));
      final payloadData = jsonDecode(decoded) as Map<String, dynamic>;

      // Extract user information from JWT payload
      return User(
        id: payloadData['id'] as String,
        username: payloadData['username'] as String? ?? 'Unknown',
        role: payloadData['role'] as String,
        token: token,
      );
    } catch (e) {
      // Fallback user if token decoding fails
      return User(
        id: 'unknown',
        username: 'Unknown User',
        role: 'employee',
        token: token,
      );
    }
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  final int statusCode;

  const AuthException({required this.message, required this.statusCode});

  @override
  String toString() => 'AuthException: $message (Status: $statusCode)';
}
