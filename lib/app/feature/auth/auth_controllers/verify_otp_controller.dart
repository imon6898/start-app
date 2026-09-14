import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logistics/app/core/di/user_di.dart';
import 'package:logistics/app/core/models/base_response.dart';
import 'package:logistics/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:logistics/app/feature/auth/auth_models/auth_response.dart';
import 'package:logistics/app/routes/app_routes.dart';
import 'package:logistics/app/services/data/cache_manager.dart';
import 'package:logistics/app/widgets/custom_snack_bar.dart';

class VerifyOtpController extends GetxController {
  final GlobalKey<FormState> verifyOtpFormKey = GlobalKey<FormState>();
  final TextEditingController verificationCodeCtr = TextEditingController();

  final RxBool isLoadingVerifyOtp = false.obs;
  final RxBool isLoadingResendOtp = false.obs;

  final RxInt countdownTime = 60.obs; // 60 seconds countdown
  final RxBool canResend = false.obs;

  Timer? _timer;

  String formattedTime = "01:00";

  @override
  void onInit() {
    super.onInit();
    _getArguments();
    startCountdown();
  }

  final _authRepo = AuthRepo();

  // Get arguments from navigation
  String fromPage = "";
  String email = "";
  String phone = "";
  String? countryCode;
  String password = "";

  void _getArguments() {
    final arguments = Get.arguments;
    if (arguments is List && arguments.length >= 4) {
      fromPage = arguments[0] ?? "";
      email = arguments[1] ?? "";
      phone = arguments[2] ?? "";
      countryCode = arguments[3];
      password = arguments.length >= 5 ? arguments[4] ?? "" : "";
    }
  }

  @override
  void onClose() {
    verificationCodeCtr.dispose();
    _timer?.cancel();
    super.onClose();
  }

  void startCountdown() {
    canResend.value = false;
    countdownTime.value = 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdownTime.value > 0) {
        countdownTime.value--;
        updateFormattedTime();
      } else {
        timer.cancel();
        canResend.value = true;
      }
    });
  }

  void updateFormattedTime() {
    int minutes = countdownTime.value ~/ 60;
    int seconds = countdownTime.value % 60;
    formattedTime =
        "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    update();
  }

  Future<void> verifyOtp({required String fromPage}) async {
    if (!verifyOtpFormKey.currentState!.validate()) {
      return;
    }

    isLoadingVerifyOtp.value = true;

    try {
      Map<String, dynamic> params = {
        'otp': verificationCodeCtr.text,
        'email': email.isNotEmpty ? email : null,
        'phone': phone.isNotEmpty ? phone : null,
        'country_code': countryCode,
      };

      final response = await _authRepo.postVerifyOtpRepo(params);

      if (response != null && response['status'] == true) {
        // Show success message
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Success,
          title: 'Success',
          description: 'OTP verified successfully',
        );

        // Navigate based on fromPage
        if (fromPage == "fromForgot") {
          // Navigate to reset password screen
          Get.toNamed(
            AppRoutes.RetypePassScreen,
            arguments: {
              'email': email,
              'phone': phone,
              'countryCode': countryCode,
              'otp': verificationCodeCtr.text, // Pass the verified OTP
            },
          );
        } else if (fromPage == "fromCreateAccount") {
          // For registration flow, logic the user and update UserDi
          await _loginAfterRegistration();
        } else {
          // Navigate to dashboard for regular verification
          Get.offAllNamed(AppRoutes.SigninScreen);
        }
      } else {
        // Show error message from response or default
        final errorMessage =
            response?['message'] ?? 'Invalid OTP. Please try again.';
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Error',
          description: errorMessage,
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Invalid OTP. Please try again.',
      );
    } finally {
      isLoadingVerifyOtp.value = false;
    }
  }

  Future<void> _loginAfterRegistration() async {
    try {
      final loginParams = {'identifier': email, 'password': password};
      final loginResponse = await _authRepo.postLoginRepo(loginParams);

      if (loginResponse == null) {
        _navigateToSignin('Account verified! Please login to continue.');
        return;
      }

      // Parse using the same BaseResponse<LoginData> as signin
      final baseResponse = BaseResponse<LoginData>.fromJson(
        loginResponse,
        (json) => LoginData.fromJson(json as Map<String, dynamic>),
      );

      if (baseResponse.data == null || baseResponse.data!.accessToken == null) {
        _navigateToSignin('Account verified! Please login to continue.');
        return;
      }

      final loginData = baseResponse.data!;
      final token = loginData.accessToken!;
      final user = loginData.user;
      final roles = loginData.roles;
      final riderId = loginData.riderId ??
          ((roles != null && roles.contains('rider')) ? user?.id : null);
      final hubId = loginData.hubId;

      // Save all auth data to cache (same as signin controller)
      await Future.wait([
        CacheManager.setToken(token),
        if (loginData.refreshToken != null)
          CacheManager.setRefreshToken(loginData.refreshToken!),
        if (user != null)
          CacheManager.setUserData(jsonEncode(user.toJson())),
        CacheManager.removeIsGuest(),
        if (riderId != null) CacheManager.setRiderId(riderId),
        if (hubId != null) CacheManager.setHubId(hubId),
        if (roles != null && roles.isNotEmpty)
          CacheManager.setRoles(jsonEncode(roles)),
      ]);

      // Refresh UserDi
      if (Get.isRegistered<UserDi>()) {
        await Get.find<UserDi>().clearGuestMode();
        await Get.find<UserDi>().refreshUser();
      } else {
        Get.put(UserDi(), permanent: true);
        await Get.find<UserDi>().refreshUser();
      }

      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Success,
        title: 'Welcome!',
        description: 'Registration completed successfully.',
      );

      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      _navigateToSignin('Account verified! Please login to continue.');
    }
  }

  void _navigateToSignin(String message) {
    showCustomSnackBar(
      context: Get.context!,
      type: SnackBarType.Warning,
      title: 'Login Required',
      description: message,
    );
    Get.offAllNamed(AppRoutes.SigninScreen);
  }

  Future<void> resendOtp(BuildContext context, String email) async {
    isLoadingResendOtp.value = true;

    try {
      Map<String, dynamic> params = {
        'email': email.isNotEmpty ? email : this.email,
        'phone': phone.isNotEmpty ? phone : null,
        'country_code': countryCode,
      };

      final response = await _authRepo.rePostSentOtpRepo(params);

      if (response != null && response['status'] == true) {
        // Restart countdown
        startCountdown();

        // Clear OTP field
        verificationCodeCtr.clear();

        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Success,
          title: 'Success',
          description: 'OTP resent successfully',
        );
      } else {
        // Show error message from response or default
        final errorMessage =
            response?['message'] ?? 'Failed to resend OTP. Please try again.';
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Error',
          description: errorMessage,
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Failed to resend OTP. Please try again.',
      );
    } finally {
      isLoadingResendOtp.value = false;
    }
  }
}
