import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logistics/app/core/enums/enums.dart';
import 'package:logistics/app/feature/auth/auth_controllers/signin_controller.dart';
import 'package:logistics/app/routes/app_routes.dart';
import 'package:logistics/app/utils/constants/app_assets.dart';
import 'package:logistics/app/utils/constants/app_colors.dart';
import 'package:logistics/app/utils/constants/app_fonts.dart';
import 'package:logistics/app/utils/platform_utils.dart';
import 'package:logistics/app/utils/responsive_utils.dart';
import 'package:logistics/app/utils/validator.dart';
import 'package:logistics/app/widgets/appbar_widget.dart';
import 'package:logistics/app/widgets/custom_image.dart';
import 'package:logistics/app/widgets/custom_primary_button.dart';
import 'package:logistics/app/widgets/custom_text_field.dart';

class SigninScreen extends StatelessWidget {
  const SigninScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SigninController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.artboardColor(),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight + R.h(10)),
            child: AppBarWidget(
              title: "Login".tr,
              backgroundColor: CustomColors.transparent(),
              elevation: 0,
              // toolbarActions: [
              //   CustomOutlinedButton(
              //     onPressed: () {
              //       FocusScope.of(context).unfocus();
              //       c.skipSignIn();
              //     },
              //     text: "Skip".tr,
              //     borderRadius: R.r(30),
              //     height: R.h(28),
              //     padding: R.pad(horizontal: 16, vertical: 0),
              //     backgroundColor: CustomColors.gray(),
              //     borderColor: CustomColors.whiteStroke(),
              //     textStyle: CustomTextStyles.regular14.copyWith(
              //       color: CustomColors.black(),
              //     ),
              //   ),
              // ],
            ),
          ),
          body: _body(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, SigninController controller) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: R.h(20)),
            Text(
              "Welcome to Logistics Rider".tr,
              style: CustomTextStyles.semiBold20.copyWith(
                color: CustomColors.primary(),
              ),
            ),
            SizedBox(height: R.h(5)),
            Text(
              "Please enter your registration email & password".tr,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.paragraph(),
              ),
            ),
            SizedBox(height: R.h(40)),

            buildInputField(context, controller),
            SizedBox(height: R.h(10)),
            buildForgotPassword(context, controller),

            SizedBox(height: R.h(20)),
            buildSigninButton(context, controller),

            // Padding(
            //   padding: EdgeInsets.symmetric(
            //     horizontal: R.w(20),
            //     vertical: R.h(10),
            //   ),
            //   child: Row(
            //     children: [
            //       Expanded(
            //         child: Divider(
            //           color: CustomColors.whiteStroke(),
            //           thickness: 1,
            //         ),
            //       ),
            //       SizedBox(width: R.w(10)),
            //       Text(
            //         "or".tr,
            //         style: CustomTextStyles.regular14.copyWith(
            //           color: CustomColors.paragraph(),
            //         ),
            //       ),
            //       SizedBox(width: R.w(10)),
            //       Expanded(
            //         child: Divider(
            //           color: CustomColors.whiteStroke(),
            //           thickness: 1,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            //
            // buildGoogleSigninButton(context, controller),
            //
            // SizedBox(height: R.h(10)),
            //
            // if (PlatformUtils.isIOS)
            // buildAppleSigninButton(context, controller),

            SizedBox(height: R.h(40)),
            buildDontHaveAccount(context, controller),
            SizedBox(height: R.h(20)),
          ],
        ),
      ),
    );
  }

  Widget buildInputField(BuildContext context, SigninController controller) {
    return Form(
      key: controller.signInFormKey,
      // Required for autofill. The hints on the fields are only acted on when
      // the fields sit in an AutofillGroup — that is what tells the OS these
      // two belong to one login form, so a saved credential can fill both.
      // Without it each field attaches to the platform alone and no suggestion
      // is ever offered.
      child: AutofillGroup(
        child: Container(
          padding: R.pad(horizontal: R.w(16)),
          child: Column(
            children: [
              CustomTextField(
                controller: controller.emailController,
                textHeading: "Email Address".tr,
                hintText: "Enter email address".tr,
                inputType: TextInputType.emailAddress,
                validator: Validators.emailValidator.call,
              ),
              SizedBox(height: R.h(10)),
              CustomTextField(
                controller: controller.passwordController,
                textHeading: "Password".tr,
                hintText: "Enter password".tr,
                isPassword: true,
                inputType: TextInputType.visiblePassword,
                inputAction: TextInputAction.done,
                validator: Validators.requiredValidator.call,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildForgotPassword(
    BuildContext context,
    SigninController controller,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          Get.toNamed(
            AppRoutes.SentOtpScreen,
            arguments: {"fromPage": "fromForgot"},
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: R.w(16)),
          child: Text(
            "Forget Password?".tr,
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.primary(),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }

  Widget buildSigninButton(BuildContext context, SigninController controller) {
    return Obx(() {
      final isDisabled = controller.isLoadingGoogleSignIn.value;
      return Container(
        padding: R.pad(horizontal: R.w(16)),
        width: double.infinity,
        height: R.h(44),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: CustomButton(
            loading: controller.isLoadingSignIn.value,
            text: "Login".tr,
            textStyle: CustomTextStyles.medium16.copyWith(
              color: CustomColors.white(),
            ),
            onPressed:
                isDisabled
                    ? () {}
                    : () {
                      FocusScope.of(context).unfocus();
                      //Get.offAllNamed(AppRoutes.DashboardScreen);
                      if (controller.signInFormKey.currentState!.validate()) {
                        controller.signIn();
                      }
                    },
          ),
        ),
      );
    });
  }

  Widget buildGoogleSigninButton(
    BuildContext context,
    SigninController controller,
  ) {
    return Obx(() {
      final isDisabled = controller.isLoadingSignIn.value;
      return Container(
        padding: R.pad(horizontal: R.w(16)),
        width: double.infinity,
        height: R.h(44),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: CustomOutlinedButton(
            text: "Login with Google".tr,
            textStyle: CustomTextStyles.medium12,
            loading: controller.isLoadingGoogleSignIn.value,
            onPressed:
                isDisabled
                    ? () {}
                    : () {
                      FocusScope.of(context).unfocus();
                      controller.signInWithGoogle();
                    },
            icon: CustomImage(
              image: ImageUtils.GoogleIcon,
              width: R.h(20),
              height: R.h(20),
              imageType: ImageType.asset,
              isSvg: true,
            ),
          ),
        ),
      );
    });
  }

  Widget buildAppleSigninButton(
    BuildContext context,
    SigninController controller,
  ) {
    return Obx(() {
      final isDisabled = controller.isLoadingSignIn.value;
      return Container(
        padding: R.pad(horizontal: R.w(16)),
        width: double.infinity,
        height: R.h(44),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: CustomOutlinedButton(
            text: "Login With Apple".tr,
            textStyle: CustomTextStyles.medium12,
            loading: controller.isLoadingAppleSignIn.value,
            onPressed:
                isDisabled
                    ? () {}
                    : () {
                      FocusScope.of(context).unfocus();
                      controller.signInWithApple();
                    },
            icon: CustomImage(
              image: ImageUtils.AppleIcon,
              width: R.w(20),
              height: R.w(20),
              imageType: ImageType.asset,
              isSvg: true,
            ),
          ),
        ),
      );
    });
  }

  Widget buildDontHaveAccount(
    BuildContext context,
    SigninController controller,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.w(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don’t have an account?".tr,
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.textGray(),
            ),
          ),
          SizedBox(width: R.w(5)),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              Get.toNamed(AppRoutes.CreateAccountScreen);
            },
            child: Text(
              "Create New Account".tr,
              style: CustomTextStyles.bold14.copyWith(
                color: CustomColors.primary(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
