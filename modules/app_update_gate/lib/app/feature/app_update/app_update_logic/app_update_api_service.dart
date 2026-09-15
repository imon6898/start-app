import 'package:flutter_starter/app/feature/app_update/app_update_models/app_update_info.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

import 'app_update_api_const.dart';

/// Abstract class for App Update API Service
abstract class AppUpdateApiService {
  Future getVersionGate(String url, {Map<String, dynamic>? params});
}

/// Implementation of AppUpdateApiService
class AppUpdateImpl extends AppUpdateApiService {
  @override
  Future getVersionGate(String url, {Map<String, dynamic>? params}) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }
}

/// Repository for App Update
class AppUpdateRepo {
  final AppUpdateApiService appUpdateApiService = AppUpdateImpl();

  /// Null means "could not decide" — the caller must let the user through.
  Future<AppUpdateInfo?> fetchVersionGate({
    required String platform,
    required String currentVersion,
    required String buildNumber,
  }) async {
    final dynamic response = await appUpdateApiService.getVersionGate(
      AppUpdateApiConst.versionGateUri,
      params: {
        'platform': platform,
        'current_version': currentVersion,
        'build_number': buildNumber,
      },
    );

    final dynamic body = response?.data;
    if (body is! Map) return null;

    // Accepts the BaseResponse envelope or a bare object.
    final dynamic payload = body['data'] ?? body;
    if (payload is! Map) return null;

    return AppUpdateInfo.fromJson(Map<String, dynamic>.from(payload));
  }
}
