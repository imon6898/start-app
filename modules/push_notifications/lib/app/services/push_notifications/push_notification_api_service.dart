import 'package:flutter_starter/app/services/domain/api_service.dart';
import 'package:flutter_starter/app/services/push_notifications/push_notification_api_const.dart';

/// Abstract class for Push Notification API Service
abstract class PushApiService {
  Future<dynamic> registerDevice(String url, {Map<String, dynamic>? params});
  Future<dynamic> unregisterDevice(String url, {Map<String, dynamic>? params});
}

/// Implementation of PushApiService
class PushImpl extends PushApiService {
  @override
  Future<dynamic> registerDevice(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future<dynamic> unregisterDevice(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }
}

/// Repository for Push Notifications
class PushRepo {
  final PushApiService pushApiService = PushImpl();

  /// Sends the current FCM token so the backend can target this device.
  Future<dynamic> registerDevice(Map<String, dynamic> params) async {
    final dynamic response = await pushApiService.registerDevice(
      PushApiConst.registerDeviceUri,
      params: params,
    );
    // ApiService returns null when there is no connection.
    return response?.data;
  }

  /// Removes the token on logout.
  Future<dynamic> unregisterDevice(Map<String, dynamic> params) async {
    final dynamic response = await pushApiService.unregisterDevice(
      PushApiConst.unregisterDeviceUri,
      params: params,
    );
    return response?.data;
  }
}
