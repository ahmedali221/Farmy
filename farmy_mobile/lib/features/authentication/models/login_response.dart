import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'login_response.g.dart';

@JsonSerializable()
class LoginResponse {
  final String token;
  final User user;
  final String? message;

  const LoginResponse({
    required this.token,
    required this.user,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginResponse &&
        other.token == token &&
        other.user == user &&
        other.message == message;
  }

  @override
  int get hashCode => token.hashCode ^ user.hashCode ^ message.hashCode;

  @override
  String toString() {
    return 'LoginResponse(token: [HIDDEN], user: $user, message: $message)';
  }
}