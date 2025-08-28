import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String username;
  final String role;
  final String? token;

  const User({
    required this.id,
    required this.username,
    required this.role,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? username,
    String? role,
    String? token,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      token: token ?? this.token,
    );
  }

  bool get isAdmin => role == 'manager';
  bool get isEmployee => role == 'employee';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.username == username &&
        other.role == role &&
        other.token == token;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        username.hashCode ^
        role.hashCode ^
        token.hashCode;
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, role: $role, token: ${token != null ? '[HIDDEN]' : 'null'})';
  }
}