import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:flutter_starter/app/core/enums/enums.dart';
import 'package:flutter_starter/app/core/models/user_response.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';

class UserDi extends GetxController {
  UserResponse? userData;
  bool _isLoading = false;
  bool _isGuest = false;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
  }

  /// Check if the current user is a guest
  bool get isGuest => _isGuest || CacheManager.isGuest;

  /// Check if the user is logged in (not a guest and has valid data)
  bool get isLoggedIn =>
      !isGuest &&
      userData != null &&
      CacheManager.token != null &&
      CacheManager.token!.isNotEmpty;

  /// Role-specific getters
  String? get riderId => CacheManager.riderId;
  String? get hubId => CacheManager.hubId;
  String? get merchantId => CacheManager.merchantId;
  List<String> get roles => CacheManager.rolesList;

  bool get isRider => roles.contains('rider');
  bool get isMerchant => roles.contains('merchant');
  bool get isHubAdmin => roles.contains('hub_admin');
  bool get isUser => roles.isEmpty || roles.contains('user');

  /// Get the primary role for the user
  String get primaryRole {
    if (isMerchant) return 'merchant';
    if (isRider) return 'rider';
    if (isHubAdmin) return 'hub_admin';
    return 'user';
  }

  UserType get userType {
    if (isGuest) return UserType.guest;
    if (userData == null) return UserType.unknown;
    return _getUserType(userData!.toJson());
  }

  // Add this method to UserDi
  UserType _getUserType(Map<String, dynamic> user) {
    final bool? isVendor = user['is_vendor'] as bool?;

    // Check if user is vendor based on is_vendor field
    if (isVendor == true) {
      return UserType.vendor;
    } else if (isVendor == false) {
      return UserType.user;
    } else {
      return UserType.unknown;
    }
  }

  Future<void> _loadUserData() async {
    _isLoading = true;
    try {
      final rawData = CacheManager.userData;
      if (rawData != null && rawData.isNotEmpty) {
        try {
          userData = UserResponse.fromJson(jsonDecode(rawData));
          await CacheManager.setUserType(userType.toString().split('.').last);
          log("Successfully loaded user data from cache");
        } catch (e) {
          log("Error parsing cached user data: $e");
          userData = null;
        }
      } else {
        log("No cached user data found");
        userData = null;
      }
    } catch (e) {
      log("Error loading user data: $e");
      userData = null;
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> refreshUser() async {
    log("Refreshing user data in UserDi...");
    await _loadUserData();
    log("UserDi refresh complete: ${userData?.toJson()}");
  }

  UserResponse get getUserData {
    if (_isLoading) {
      log("Warning: getUserData called while still loading");
      return UserResponse();
    }
    return userData ?? UserResponse();
  }

  bool get isUserDataLoaded => !_isLoading && userData != null;

  /// Set guest mode
  Future<void> setGuestMode(bool value) async {
    _isGuest = value;
    await CacheManager.setIsGuest(value);
    if (value) {
      await CacheManager.setUserType(UserType.guest.toString().split('.').last);
    }
    log("Guest mode set to: $value");
    update();
  }

  /// Clear guest mode (when user logs in)
  Future<void> clearGuestMode() async {
    _isGuest = false;
    await CacheManager.removeIsGuest();
    log("Guest mode cleared");
    update();
  }

  /// Clear all user data (for logout)
  Future<void> clearUserData() async {
    userData = null;
    _isGuest = false;
    await Future.wait([
      CacheManager.removeToken(),
      CacheManager.removeRefreshToken(),
      CacheManager.removeUserData(),
      CacheManager.removeUserType(),
      CacheManager.removeIsGuest(),
      CacheManager.removeRiderId(),
      CacheManager.removeHubId(),
      CacheManager.removeMerchantId(),
      CacheManager.removeRoles(),
    ]);
    log("User data cleared");
    update();
  }
}
