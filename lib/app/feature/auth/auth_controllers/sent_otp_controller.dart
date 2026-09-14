import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/widgets/custom_phone_text_field.dart';
import 'package:flutter_starter/app/widgets/custom_snack_bar.dart';

class SentOtpController extends GetxController {
  final GlobalKey<FormState> sentOtpFormKey = GlobalKey<FormState>();

  final TextEditingController sentOtpController = TextEditingController();
  final TextEditingController mobileNumberCtr = TextEditingController();

  final RxBool isLoadingSentOtp = false.obs;

  String sentOtpType = "email"; // "email" or "phone"
  Country? selectedCountry;
  String fromPage = ""; // Track the source page

  @override
  void onInit() {
    super.onInit();
    selectedCountry = CountryData.getDefaultCountry();
    _getArguments();
  }

  final _authRepo = AuthRepo();

  @override
  void onClose() {
    sentOtpController.dispose();
    mobileNumberCtr.dispose();
    super.onClose();
  }

  void _getArguments() {
    final arguments = Get.arguments;
    if (arguments is Map<String, dynamic>) {
      fromPage = arguments['fromPage'] ?? "";
    }
  }

  void updateSelectedCountry(Country country) {
    selectedCountry = country;
    update();
  }

  Future<void> sentOtp() async {
    if (!sentOtpFormKey.currentState!.validate()) {
      return;
    }

    isLoadingSentOtp.value = true;

    try {
      Map<String, dynamic> params;

      if (sentOtpType == "email") {
        params = {'email': sentOtpController.text, 'type': 'email'};
      } else {
        params = {
          'phone': mobileNumberCtr.text,
          'country_code': selectedCountry?.code,
          'type': 'phone',
        };
      }

      final response = await _authRepo.postSentOtpRepo(params);

      if (response != null && response['status'] == true) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Success,
          title: 'Success',
          description: response['data']?['message'] ?? response['message'] ?? 'OTP sent successfully',
        );

        Get.toNamed(
          AppRoutes.VerifyOtpScreen,
          arguments: [
            "fromForgot",
            sentOtpType == "email" ? sentOtpController.text : null,
            sentOtpType == "phone" ? mobileNumberCtr.text : null,
            selectedCountry?.code,
          ],
        );
      } else {
        final errorMessage = response?['message'] ?? 'Failed to send OTP. Please try again.';
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
      isLoadingSentOtp.value = false;
    }
  }
}
