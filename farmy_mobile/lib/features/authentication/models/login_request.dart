import 'package:json_annotation/json_annotation.dart';

part 'login_request.g.dart';

@JsonSerializable()
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginRequest &&
        other.username == username &&
        other.password == password;
  }

  @override
  int get hashCode => username.hashCode ^ password.hashCode;

  @override
  String toString() {
    return 'LoginRequest(username: $username, password: [HIDDEN])';
  }
}