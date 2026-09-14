import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/di/user_di.dart';
import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:flutter_starter/app/feature/auth/auth_models/auth_response.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

class SigninController extends GetxController {
  final GlobalKey<FormState> signInFormKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final RxBool isLoadingSignIn = false.obs;
  final RxBool isLoadingGoogleSignIn = false.obs;
  final RxBool isLoadingAppleSignIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedCredentials();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  final _authRepo = AuthRepo();
  RxBool rememberMe = true.obs;

  void _loadSavedCredentials() async {
    try {
      final savedEmail = CacheManager.getLoginEmail ?? '';
      final savedPassword = CacheManager.getLoginPassword ?? '';

      if (savedEmail.isNotEmpty) {
        emailController.text = savedEmail;
      }
      if (savedPassword.isNotEmpty) {
        passwordController.text = savedPassword;
      }

      // If there are saved credentials, enable remember me
      if (savedEmail.isNotEmpty || savedPassword.isNotEmpty) {
        rememberMe.value = true;
      }

      update();
    } catch (e) {
      // Handle error silently or show debug message
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> signIn() async {
    if (!signInFormKey.currentState!.validate()) {
      return;
    }

    isLoadingSignIn.value = true;

    try {
      if (emailController.text.isNotEmpty &&
          passwordController.text.isNotEmpty) {
        final params = {
          'identifier': emailController.text,
          'password': passwordController.text,
        };

        final response = await _authRepo.postLoginRepo(params);
        // Parse into BaseResponse<LoginData>
        final baseResponse = BaseResponse<LoginData>.fromJson(
          response!,
          (data) => LoginData.fromJson(data),
        );

        if (baseResponse.statusCode == 201) {
          final token = baseResponse.data!.accessToken;
          final user = baseResponse.data!.user;

          isLoadingSignIn.value = false;
          update();

          if (user?.isVerified == false) {
            // Navigate to OTP verification screen
            final email = emailController.text;
            Get.toNamed(
              AppRoutes.VerifyOtpScreen,
              arguments: ['fromCreateAccount', email, passwordController.text],
            );
            // Send OTP to the user's email
            final otpParams = {'email': user?.email};
            final otpResponse = await _authRepo.rePostSentOtpRepo(otpParams);

            if (otpResponse != null) {
              final otpBaseResponse = BaseResponse.fromJson(
                otpResponse,
                (data) => null,
              );

              if (otpBaseResponse.statusCode == 201) {
                showCustomSnackBar(
                  context: Get.context!,
                  title: 'warning'.tr,
                  description:
                      'Please verify your email to continue. OTP has been sent to your email.',
                  type: SnackBarType.Warning,
                );
              } else {
                showCustomSnackBar(
                  context: Get.context!,
                  title: 'Error',
                  description: 'Failed to send OTP. Please try again.',
                  type: SnackBarType.Failure,
                );
              }
            }
          } else {
            // Persist the session
            final refreshToken = baseResponse.data!.refreshToken;
            final roles = baseResponse.data!.roles;
            await Future.wait([
              CacheManager.setToken(token!),
              if (refreshToken != null)
                CacheManager.setRefreshToken(refreshToken),
              CacheManager.setUserData(jsonEncode(user?.toJson())),
              CacheManager.removeIsGuest(), // Clear guest mode on login
              if (roles != null && roles.isNotEmpty)
                CacheManager.setRoles(jsonEncode(roles)),
            ]);

            await Get.find<UserDi>().clearGuestMode();
            await Get.find<UserDi>().refreshUser();

            if (rememberMe.value) {
              await CacheManager.setLoginEmail(emailController.text);
              await CacheManager.setLoginPassword(passwordController.text);
            } else {
              // Clear saved credentials if remember me is unchecked
              await CacheManager.removeLoginEmail();
              await CacheManager.removeLoginPassword();
            }

            // User is verified, go to dashboard
            showCustomSnackBar(
              context: Get.context!,
              title: 'Success',
              description: 'Login successful',
              type: SnackBarType.Success,
            );

            // Closes the autofill context so the OS shows its "Save password?"
            // prompt. Without this nothing is ever stored, so there is no
            // credential for autofill to offer on the next login. Must run
            // before we navigate away and dispose the fields.
            TextInput.finishAutofillContext();

            Get.offAllNamed(AppRoutes.DashboardScreen);
          }
        } else {
          isLoadingSignIn.value = false;
          update();

          showCustomSnackBar(
            context: Get.context!,
            title: 'Authentication failed',
            description: 'Please check your credentials',
            //baseResponse.message,
            type: SnackBarType.Failure,
          );
        }
      } else {
        isLoadingSignIn.value = false;
        update();

        showCustomSnackBar(
          context: Get.context!,
          title: 'Error',
          description: 'Please fill in all fields',
          type: SnackBarType.Failure,
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Sign in failed. Please try again.',
      );
    } finally {
      isLoadingSignIn.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    isLoadingGoogleSignIn.value = true;

    try {
      // TODO: Implement Google sign in logic
      await Future.delayed(const Duration(seconds: 2));

      // Navigate to home screen after successful sign in
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Google sign in failed. Please try again.',
      );
    } finally {
      isLoadingGoogleSignIn.value = false;
    }
  }

  Future<void> signInWithApple() async {
    isLoadingAppleSignIn.value = true;

    try {
      // TODO: Implement Apple sign in logic
      await Future.delayed(const Duration(seconds: 2));

      // Navigate to home screen after successful sign in
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      isLoadingSignIn.value = false;
      update();

      showCustomSnackBar(
        context: Get.context!,
        title: 'Error',
        description: 'An error occurred: ${e.toString()}',
        type: SnackBarType.Failure,
      );
    } finally {
      isLoadingAppleSignIn.value = false;
    }
  }

  Future<void> skipSignIn() async {
    try {
      // Set guest mode in cache
      await CacheManager.setIsGuest(true);

      await Get.find<UserDi>().setGuestMode(true);

      // Navigate to dashboard as guest
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      // If setting guest mode fails, still navigate to dashboard
      Get.offAllNamed(AppRoutes.DashboardScreen);
    }
  }
}
