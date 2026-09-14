import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/verify_otp_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/custom_snack_bar.dart';
import 'package:pinput/pinput.dart';

class VerifyOtpScreen extends StatelessWidget {
  const VerifyOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VerifyOtpController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(title: "Verification".tr),
          body: _body(context, c),
          bottomSheet: Padding(
            padding: EdgeInsets.only(
              left: R.w(16),
              right: R.w(16),
              bottom: R.h(10),
            ),
            child: SizedBox(
              width: double.infinity,
              height: R.h(44),
              child: CustomButton(
                text: "Continue".tr,
                loading: c.isLoadingVerifyOtp.value,
                onPressed: () {
                  if (c.verifyOtpFormKey.currentState?.validate() == true) {
                    final arguments = Get.arguments;
                    String fromPage = "";

                    if (arguments is Map<String, dynamic>) {
                      fromPage = arguments['fromPage'] ?? "";
                    } else if (arguments is List && arguments.isNotEmpty) {
                      fromPage = arguments[0]?.toString() ?? "";
                    }

                    print("fromPage in VerifyOtpScreen: $fromPage");

                    c.verifyOtp(fromPage: fromPage);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, VerifyOtpController controller) {
    // Get email from arguments - handle both List and Map types
    final arguments = Get.arguments;
    String email = "";

    if (arguments is List<String> && arguments.length > 1) {
      email = arguments[1];
    } else if (arguments is Map<String, dynamic> &&
        arguments.containsKey('email')) {
      email = arguments['email'] ?? "";
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: R.w(16)),
      child: Column(
        children: [
          SizedBox(height: R.h(44)),
          Text(
            "We’ve the code send to your email".tr,
            style: CustomTextStyles.medium16.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
          SizedBox(height: R.h(4)),
          Text(
            email,
            style: CustomTextStyles.medium16.copyWith(
              color: CustomColors.black(),
            ),
          ),

          SizedBox(height: R.h(20)),

          buildOtpInput(context, controller),

          buildResendoption(context, controller, email),

          SizedBox(height: R.h(24)),
        ],
      ),
    );
  }

  Widget buildOtpInput(BuildContext context, VerifyOtpController controller) {
    return Form(
      key: controller.verifyOtpFormKey,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: R.h(50), // Minimum height
          maxHeight: R.h(80), // Maximum height to accommodate error
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(R.r(10)),
        ),
        child: Pinput(
          controller: controller.verificationCodeCtr,
          length: 6,
          onCompleted: (data) {
            if (controller.verifyOtpFormKey.currentState?.validate() == true) {
              final arguments = Get.arguments;
              String fromPage = "";

              if (arguments is Map<String, dynamic>) {
                fromPage = arguments['fromPage'] ?? "";
              } else if (arguments is List && arguments.isNotEmpty) {
                fromPage = arguments[0]?.toString() ?? "";
              }

              print("fromPage in VerifyOtpScreen: $fromPage");

              controller.verifyOtp(fromPage: fromPage);
            }
          },
          mainAxisAlignment: MainAxisAlignment.start,
          validator: Validators.otpValidator.call,
          pinputAutovalidateMode: PinputAutovalidateMode.values.first,
          errorTextStyle: TextStyle(color: CustomColors.error()),

          showCursor: true,
          defaultPinTheme: PinTheme(
            width: R.w(48),
            height: R.h(50),
            textStyle: TextStyle(
              fontSize: 20.sp,
              color: CustomColors.black(),
              fontWeight: FontWeight.w400,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.transparent,
              border: Border.all(color: CustomColors.stroke()),
              borderRadius: BorderRadius.circular(R.r(8)),
            ),
          ),
          focusedPinTheme: PinTheme(
            width: R.w(48),
            height: R.h(50),
            textStyle: TextStyle(
              fontSize: 20.sp,
              color: CustomColors.primary(),
              fontWeight: FontWeight.w400,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.transparent,
              border: Border.all(color: CustomColors.primary()),
              borderRadius: BorderRadius.circular(R.r(8)),
            ),
          ),
          submittedPinTheme: PinTheme(
            width: R.w(48),
            height: R.h(50),
            textStyle: TextStyle(
              fontSize: 20.sp,
              color: CustomColors.black(),
              fontWeight: FontWeight.w500,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.transparent,
              border: Border.all(color: CustomColors.primary()),
              borderRadius: BorderRadius.circular(R.r(8)),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildResendoption(
    BuildContext context,
    VerifyOtpController controller,
    String email,
  ) {
    return Obx(
      () => Container(
        //: EdgeInsets.only(top: 10.h),
        child: Column(
          children: [
            SizedBox(height: R.h(20)),
            // Timer display
            Text(
              controller.formattedTime,
              style: CustomTextStyles.semiBold16.copyWith(
                color:
                    controller.countdownTime.value > 0
                        ? CustomColors.primary()
                        : CustomColors.textGray(),
              ),
            ),
            SizedBox(height: R.h(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn’t receive code? ".tr,
                  style: CustomTextStyles.medium16.copyWith(
                    color: CustomColors.textGray(),
                  ),
                ),
                SizedBox(width: R.w(4)),
                GestureDetector(
                  onTap: () {
                    controller.verifyOtpFormKey.currentState?.validate();
                    if (controller.canResend.value) {
                      log("Resend Code");
                      FocusScope.of(context).unfocus();
                      showCustomSnackBar(
                        context: context,
                        type: SnackBarType.Success,
                        title: "Resend Code".tr,
                        description: "Resend code success".tr,
                      );
                      controller.resendOtp(context, email);
                    } else {
                      // Show warning if timer is still running

                      showCustomSnackBar(
                        context: context,
                        type: SnackBarType.Warning,
                        title: "Please wait".tr,
                        description: "Wait for timer complete".tr,
                      );
                    }
                  },
                  child: Text(
                    "Resend Code".tr,
                    style: CustomTextStyles.medium16.copyWith(
                      color:
                          controller.canResend.value
                              ? CustomColors.primary()
                              : CustomColors.textGray().withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
