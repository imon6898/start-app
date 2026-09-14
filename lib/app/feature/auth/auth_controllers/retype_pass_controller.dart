import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/widgets/custom_snack_bar.dart';

class RetypePassController extends GetxController {
  final GlobalKey<FormState> resetPassFormKey = GlobalKey<FormState>();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final RxBool isLoadingResetPass = false.obs;

  // Get arguments from navigation
  String email = "";
  String phone = "";
  String? countryCode;
  String otp = "";

  @override
  void onInit() {
    super.onInit();
    _getArguments();
  }

  final _authRepo = AuthRepo();

  @override
  void onClose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void _getArguments() {
    final arguments = Get.arguments;
    if (arguments is Map<String, dynamic>) {
      email = arguments['email'] ?? "";
      phone = arguments['phone'] ?? "";
      countryCode = arguments['countryCode'];
      otp = arguments['otp'] ?? "";
    }
  }

  Future<void> resetPassword() async {
    if (!resetPassFormKey.currentState!.validate()) {
      return;
    }

    // Check if passwords match
    if (newPasswordController.text != confirmPasswordController.text) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Passwords do not match',
      );
      return;
    }

    isLoadingResetPass.value = true;

    try {
      Map<String, dynamic> params = {
        'email': email.isNotEmpty ? email : null,
        'otp': otp,
        'password': newPasswordController.text,
        'confirm_password': confirmPasswordController.text,
      };

      final response = await _authRepo.postResetPasswordRepo(params);

      if (response != null && response['status'] == true) {
        final message = response['data']?['message'] ??
            response['message'] ??
            'Password reset successfully. Please login with your new password.';

        // Pop back to the existing SigninScreen already in the stack.
        // Using Get.offAllNamed causes a duplicate-GlobalKey crash because the
        // old SigninScreen (at the bottom of the stack) and the newly pushed one
        // briefly coexist in the same widget tree.
        Get.until((route) => route.settings.name == AppRoutes.SigninScreen);

        // Show snackbar after navigation so the context is the live SigninScreen.
        await Future.delayed(const Duration(milliseconds: 100));
        if (Get.context != null) {
          showCustomSnackBar(
            context: Get.context!,
            type: SnackBarType.Success,
            title: 'Success',
            description: message,
          );
        }
      } else {
        final errorMessage = response?['data']?['message'] ??
            response?['message'] ??
            'Failed to reset password. Please try again.';
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
        description: 'Something went wrong. Please try again.',
      );
    } finally {
      isLoadingResetPass.value = false;
    }
  }
}
