import 'package:flutter_starter/app/core/models/user_response.dart';

class LoginData {
  final String? accessToken;
  final String? refreshToken;
  final UserResponse? user;
  final List<String>? roles;
  final List<String>? serviceTypes;
  final List<dynamic>? rbacPermissions;
  final String? riderId;
  final String? hubId;
  final String? merchantId;

  LoginData({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.roles,
    this.serviceTypes,
    this.rbacPermissions,
    this.riderId,
    this.hubId,
    this.merchantId,
  });

  LoginData copyWith({
    String? accessToken,
    String? refreshToken,
    UserResponse? user,
    List<String>? roles,
    List<String>? serviceTypes,
    List<dynamic>? rbacPermissions,
    String? riderId,
    String? hubId,
    String? merchantId,
  }) {
    return LoginData(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      roles: roles ?? this.roles,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      rbacPermissions: rbacPermissions ?? this.rbacPermissions,
      riderId: riderId ?? this.riderId,
      hubId: hubId ?? this.hubId,
      merchantId: merchantId ?? this.merchantId,
    );
  }

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      user:
      json['user'] != null ? UserResponse.fromJson(json['user']) : null,
      roles: json['roles'] == null
          ? []
          : List<String>.from(json['roles']),
      serviceTypes: json['service_types'] == null
          ? []
          : List<String>.from(json['service_types']),
      rbacPermissions: json['rbac_permissions'] == null
          ? []
          : List<dynamic>.from(json['rbac_permissions']),
      riderId: json['rider_id'] ?? json['riderId'],
      hubId: json['hub_id'] ?? json['hubId'],
      merchantId: json['merchant_id'] ?? json['merchantId'],
    );
  }
}
