import 'package:flutter_starter/app/core/models/user_response.dart';

/// Payload returned by login / verify-OTP. Add your own claims as needed.
class LoginData {
  final String? accessToken;
  final String? refreshToken;
  final UserResponse? user;
  final List<String>? roles;
  final List<dynamic>? permissions;

  LoginData({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.roles,
    this.permissions,
  });

  LoginData copyWith({
    String? accessToken,
    String? refreshToken,
    UserResponse? user,
    List<String>? roles,
    List<dynamic>? permissions,
  }) {
    return LoginData(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
    );
  }

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      user: json['user'] != null ? UserResponse.fromJson(json['user']) : null,
      roles: json['roles'] == null ? [] : List<String>.from(json['roles']),
      permissions: json['permissions'] == null
          ? []
          : List<dynamic>.from(json['permissions']),
    );
  }
}
