import 'package:equatable/equatable.dart';
import '../models/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];

  // Factory constructors for different states
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;
}

/// Initial state when the app starts
class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  String toString() => 'AuthInitial';
}

/// Loading state during authentication operations
class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  String toString() => 'AuthLoading';
}

/// Authenticated state with user data
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];

  @override
  String toString() => 'AuthAuthenticated(user: $user)';
}

/// Unauthenticated state
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  String toString() => 'AuthUnauthenticated';
}

/// Error state with error message
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'AuthError(message: $message)';
}