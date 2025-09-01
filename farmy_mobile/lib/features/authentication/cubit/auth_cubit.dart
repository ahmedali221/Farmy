import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/login_request.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final TokenService _tokenService;

  AuthCubit({
    required AuthService authService,
    required TokenService tokenService,
  }) : _authService = authService,
       _tokenService = tokenService,
       super(const AuthState.initial());

  /// Initialize authentication state on app start
  Future<void> initialize() async {
    emit(const AuthState.loading());

    try {
      final isAuthenticated = await _tokenService.isAuthenticated();

      if (isAuthenticated) {
        final user = await _tokenService.getUser();
        final token = await _tokenService.getToken();

        if (user != null && token != null) {
          // Validate token with server
          final validatedUser = await _authService.validateToken(token);

          if (validatedUser != null) {
            emit(AuthState.authenticated(validatedUser));
          } else {
            // Token is invalid, clear local data
            await _tokenService.clearAuthData();
            emit(const AuthState.unauthenticated());
          }
        } else {
          emit(const AuthState.unauthenticated());
        }
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (e) {
      // If initialization fails, assume unauthenticated
      emit(const AuthState.unauthenticated());
    }
  }

  /// Login with username and password
  Future<void> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      emit(const AuthState.error('Username and password are required'));
      return;
    }

    emit(const AuthState.loading());

    try {
      final loginRequest = LoginRequest(
        username: username.trim(),
        password: password,
      );

      final loginResponse = await _authService.login(loginRequest);

      // Save authentication data locally
      await _tokenService.saveAuthData(loginResponse.token, loginResponse.user);

      emit(AuthState.authenticated(loginResponse.user));
    } catch (e) {
      String errorMessage = 'Login failed';

      if (e is AuthException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'Network error: Please check your connection';
      }

      emit(AuthState.error(errorMessage));
    }
  }

  /// Logout user
  Future<void> logout() async {
    emit(const AuthState.loading());

    try {
      final token = await _tokenService.getToken();

      // Attempt server-side logout if token exists
      if (token != null) {
        await _authService.logout(token);
      }
    } catch (e) {
      // Ignore server-side logout errors
    } finally {
      // Always clear local data
      await _tokenService.clearAuthData();
      emit(const AuthState.unauthenticated());
    }
  }

  /// Clear error state
  void clearError() {
    if (state is AuthError) {
      emit(const AuthState.unauthenticated());
    }
  }

  /// Get current user
  User? get currentUser {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      return currentState.user;
    }
    return null;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => state is AuthAuthenticated;

  /// Check if user is admin
  bool get isAdmin => currentUser?.isAdmin ?? false;

  /// Check if user is employee
  bool get isEmployee => currentUser?.isEmployee ?? false;
}
