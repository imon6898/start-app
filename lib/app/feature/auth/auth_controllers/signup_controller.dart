import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logistics/app/core/di/user_di.dart';
import 'package:logistics/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:logistics/app/routes/app_routes.dart';
import 'package:logistics/app/services/data/cache_manager.dart';
import 'package:logistics/app/widgets/custom_phone_text_field.dart';
import 'package:logistics/app/widgets/custom_snack_bar.dart';

class SignupController extends GetxController {
  /// Used by `signup_screen.dart`. NOT used by `user_registration_info_screen.dart`,
  /// which has its own local form key. Validation in `createNewAccount` is done
  /// by the calling screen — it can't safely run here because both screens
  /// share this controller but only one is ever mounted at a time.
  final GlobalKey<FormState> createNewAccountFormKey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController firstNameCtr = TextEditingController();
  final TextEditingController lastNameCtr = TextEditingController();
  final TextEditingController emailRegCtr = TextEditingController();
  final TextEditingController mobileNumberCtr = TextEditingController();
  final TextEditingController addressRegCtr = TextEditingController();
  final TextEditingController passwordRegCtr = TextEditingController();
  final TextEditingController confirmPasswordRegCtr = TextEditingController();

  // Loading states
  final RxBool isLoadingCreateNewAccount = false.obs;
  final RxBool isLoadingSignIn = false.obs;
  final RxBool isLoadingGoogleSignIn = false.obs;
  final RxBool isLoadingAppleSignIn = false.obs;

  // Terms and conditions
  final RxBool isAccept = false.obs;
  final RxBool showTermsError = false.obs;

  // Country selection
  Country? selectedCountry;

  // Location picker
  final Rx<LatLng> selectedLocation = Rx<LatLng>(const LatLng(0.0, 0.0));
  final RxBool isMapInteracting = false.obs;

  @override
  void onInit() {
    super.onInit();
    selectedCountry = CountryData.getDefaultCountry();
  }

  final _authRepo = AuthRepo();

  @override
  void onClose() {
    // Dispose all controllers
    firstNameCtr.dispose();
    lastNameCtr.dispose();
    emailRegCtr.dispose();
    mobileNumberCtr.dispose();
    addressRegCtr.dispose();
    passwordRegCtr.dispose();
    confirmPasswordRegCtr.dispose();
    super.onClose();
  }

  void toggleAcceptTerms() {
    isAccept.value = !isAccept.value;
  }

  void updateSelectedCountry(Country country) {
    selectedCountry = country;
    update();
  }

  Future<void> createNewAccount({required String fromPage}) async {
    // Form validation happens in the screen before calling this. The screen's
    // own GlobalKey<FormState> is the one attached to the Form widget.

    // Check if passwords match
    if (passwordRegCtr.text != confirmPasswordRegCtr.text) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Passwords do not match',
      );
      return;
    }

    isLoadingCreateNewAccount.value = true;

    try {
      final phoneWithCode =
          '${selectedCountry?.dialCode ?? ''}${mobileNumberCtr.text}';
      Map<String, dynamic> params = {
        'first_name': firstNameCtr.text,
        'last_name': lastNameCtr.text,
        'email': emailRegCtr.text,
        'phone': phoneWithCode,
        'address': addressRegCtr.text,
        'password': passwordRegCtr.text,
        'confirm_password': confirmPasswordRegCtr.text,
        'agreement': true,
        'profile_type': 'USER',
      };

      final response = await _authRepo.postRegistrationRepo(params);

      if (response != null) {
        // Show success message
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Success,
          title: 'Success',
          description:
              'Account created successfully. Please verify your email.',
        );

        // Navigate to OTP verification screen
        // Registration endpoint already sends OTP automatically — no resend call needed
        Get.toNamed(
          AppRoutes.VerifyOtpScreen,
          arguments: [
            "fromCreateAccount",
            emailRegCtr.text,          // index 1: email
            phoneWithCode,             // index 2: phone (with dial code)
            selectedCountry?.code,     // index 3: countryCode
            passwordRegCtr.text,       // index 4: password (for auto-login after OTP)
          ],
        );
      } else {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Error',
          description: 'Failed to create account. Please try again.',
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Failed to create account. Please try again.',
      );
    } finally {
      isLoadingCreateNewAccount.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    if (!isAccept.value) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Accept Terms',
        description: 'Please accept terms and conditions',
      );
      return;
    }

    isLoadingGoogleSignIn.value = true;

    try {
      // TODO: Implement Google sign-up logic
      await Future.delayed(const Duration(seconds: 2));

      // Show success message
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Success,
        title: 'Success',
        description: 'Account created with Google successfully',
      );

      // Navigate to dashboard
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Google sign-up failed. Please try again.',
      );
    } finally {
      isLoadingGoogleSignIn.value = false;
    }
  }

  Future<void> signInWithApple() async {
    if (!isAccept.value) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Accept Terms',
        description: 'Please accept terms and conditions',
      );
      return;
    }

    isLoadingAppleSignIn.value = true;

    try {
      // TODO: Implement Apple sign-up logic
      await Future.delayed(const Duration(seconds: 2));

      // Show success message
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Success,
        title: 'Success',
        description: 'Account created with Apple successfully',
      );

      // Navigate to dashboard
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Apple sign-up failed. Please try again.',
      );
    } finally {
      isLoadingAppleSignIn.value = false;
    }
  }
}
