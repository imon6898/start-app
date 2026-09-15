import 'package:flutter_starter/app/feature/auth/auth_logic/social_auth_api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Social Auth API Service
abstract class SocialAuthApiService {
  Future postGoogleSignIn(String url, Map<String, dynamic> params);
  Future postAppleSignIn(String url, Map<String, dynamic> params);
}

/// Implementation of SocialAuthApiService
class SocialAuthImpl extends SocialAuthApiService {
  @override
  Future postGoogleSignIn(String url, Map<String, dynamic> params) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postAppleSignIn(String url, Map<String, dynamic> params) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }
}

/// Repository for Social Auth
class SocialAuthRepo {
  final SocialAuthApiService socialAuthApiService = SocialAuthImpl();

  /// Sends the Google id_token. The backend must verify it with Google before
  /// it trusts the identity or issues a session.
  Future<dynamic>? postGoogleSignInRepo(Map<String, dynamic> params) async {
    dynamic responseData = await socialAuthApiService.postGoogleSignIn(
      SocialAuthApiConst.googleSignInUri,
      params,
    );
    return responseData = responseData.data;
  }

  /// Sends the Apple authorization_code (+ identity_token and nonce). The
  /// backend must redeem the code with Apple within 5 minutes.
  Future<dynamic>? postAppleSignInRepo(Map<String, dynamic> params) async {
    dynamic responseData = await socialAuthApiService.postAppleSignIn(
      SocialAuthApiConst.appleSignInUri,
      params,
    );
    return responseData = responseData.data;
  }
}
