import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/models/country.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

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
        title: 'Error'.tr,
        description: 'Passwords do not match.'.tr,
      );
      return;
    }

    isLoadingCreateNewAccount.value = true;

    try {
      final phoneWithCode =
          '${selectedCountry?.dialCode ?? ''}${mobileNumberCtr.text}';
      final Map<String, dynamic> params = {
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
          title: 'Success'.tr,
          description:
              'Account created successfully. Please verify your email.'.tr,
        );

        // Navigate to OTP verification screen
        // Registration endpoint already sends OTP automatically — no resend call needed
        Get.toNamed(
          AppRoutes.VerifyOtpScreen,
          arguments: [
            'fromCreateAccount',
            emailRegCtr.text, // index 1: email
            phoneWithCode, // index 2: phone (with dial code)
            selectedCountry?.code, // index 3: countryCode
            passwordRegCtr.text, // index 4: password (for auto-login after OTP)
          ],
        );
      } else {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Error'.tr,
          description: 'Failed to create account. Please try again.'.tr,
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error'.tr,
        description: 'Failed to create account. Please try again.'.tr,
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
        title: 'Accept terms'.tr,
        description: 'Please accept terms'.tr,
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
        title: 'Success'.tr,
        description: 'Account created successfully'.tr,
      );

      // Navigate to dashboard
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error'.tr,
        description: 'Google sign in failed. Please try again.'.tr,
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
        title: 'Accept terms'.tr,
        description: 'Please accept terms'.tr,
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
        title: 'Success'.tr,
        description: 'Account created successfully'.tr,
      );

      // Navigate to dashboard
      Get.offAllNamed(AppRoutes.DashboardScreen);
    } catch (e) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error'.tr,
        description: 'Apple sign in failed. Please try again.'.tr,
      );
    } finally {
      isLoadingAppleSignIn.value = false;
    }
  }
}
