/// API Configuration Constants
class ApiConstants {
  // Base URL for API requests
  // Use 10.0.2.2 for Android emulator to access host machine
  // Use localhost for web/desktop development
  // Use actual IP for physical device testing
  static const String baseUrl =
      // 'https://farmy-c9hb-git-main-ahmed-alis-projects-588ffe47.vercel.app/api';
      'http://172.20.10.2:6000/api';
  // 'http://192.168.8.128:6000/api';
  // "http://127.0.0.1:3000/api";

  // Alternative URLs for different environments
  static const String localhostUrl = 'http://localhost:3000/api';
  static const String networkUrl = 'http://192.168.1.5:3000/api';
  static const String vercelUrl =
      'https://farmy-c9hb-git-main-ahmed-alis-projects-588ffe47.vercel.app/api';

  // HTTP timeout configuration
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Common headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
