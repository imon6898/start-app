import 'package:logistics/app/services/domain/api_const.dart';
import 'package:logistics/app/services/domain/api_service.dart';

/// Abstract class for Auth API Service
abstract class AuthApiService {
  Future postSignin(String url,Map<String, dynamic> params);
  Future postSentOtp(String url,Map<String, dynamic> params);
  Future rePostSentOtp(String url,Map<String, dynamic> params);
  Future postVerifyOtp(String url,Map<String, dynamic> params);
  Future postResetPassword(String url,Map<String, dynamic> params);
  Future postRegistration(String url,Map<String, dynamic> params);
  Future postGoogleSignIn(String url,Map<String, dynamic> params);
  Future postAppleSignIn(String url,Map<String, dynamic> params);
}




/// Implementation of AuthApiService
class AuthImpl extends AuthApiService {
  @override
  Future postSignin(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postSentOtp(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future rePostSentOtp(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postVerifyOtp(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postResetPassword(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postRegistration(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postGoogleSignIn(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future postAppleSignIn(String url, Map<String, dynamic> params) async {
    dynamic response = await ApiService().post(url, params);
    return response;
  }
}







/// Repository for Auth
class AuthRepo {
  final AuthApiService authApiService = AuthImpl();

  Future<dynamic>? postLoginRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postSignin(ApiConstant.loginUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? postSentOtpRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postSentOtp(ApiConstant.sentOtpUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? rePostSentOtpRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.rePostSentOtp(
      ApiConstant.reSentOtpUri,
      params,
    );
    return responseData = responseData.data;
  }


  Future<dynamic>? postVerifyOtpRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postVerifyOtp(ApiConstant.verifyOtpUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? postResetPasswordRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postResetPassword(ApiConstant.resetPasswordUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? postRegistrationRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postRegistration(ApiConstant.signupUserUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? postGoogleSignInRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postGoogleSignIn(ApiConstant.googleSignInUri, params);
    return responseData = responseData.data;
  }

  Future<dynamic>? postAppleSignInRepo(Map<String, dynamic> params) async {
    dynamic responseData = await authApiService.postAppleSignIn(ApiConstant.appleSignInUri, params);
    return responseData = responseData.data;
  }
}
