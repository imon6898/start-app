import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/models/country.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/signup_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/platform_utils.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_phone_text_field.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SignupController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(title: 'Create new account'),
          body: _body(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, SignupController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.w(16)),
      child: Obx(
        () => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: R.h(16)),
              buildInputField(context, controller),
              SizedBox(height: R.h(10)),
              buildCheckAgreement(context, controller),
              SizedBox(height: R.h(24)),
              buildSignupButton(context, controller),
              SizedBox(height: R.h(10)),
              buildOrDivider(),
              SizedBox(height: R.h(10)),
              buildGoogleSigninButton(context, controller),

              SizedBox(height: R.h(10)),

              if (PlatformUtils.isIOS)
                buildAppleSigninButton(context, controller),
              SizedBox(height: R.h(30)),
              buildHaveAccount(context, controller),
              SizedBox(height: R.h(30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInputField(BuildContext context, SignupController controller) {
    return Form(
      key: controller.createNewAccountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: R.h(4),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 5,
                child: CustomTextField(
                  controller: controller.firstNameCtr,
                  textHeading: 'First name',
                  hintText: 'Enter first name',
                  required: true,
                  inputType: TextInputType.name,
                  validator: Validators.nameValidator.call,
                ),
              ),
              SizedBox(width: R.w(8)),
              Flexible(
                flex: 5,
                child: CustomTextField(
                  controller: controller.lastNameCtr,
                  textHeading: 'Last name',
                  hintText: 'Enter last name',
                  required: true,
                  inputType: TextInputType.name,
                  validator: Validators.nameValidator.call,
                ),
              ),
            ],
          ),
          CustomTextField(
            controller: controller.emailRegCtr,
            textHeading: 'Email',
            hintText: 'Enter email',
            required: true,
            inputType: TextInputType.emailAddress,
            validator: Validators.emailValidator.call,
          ),
          CustomPhoneTextField(
            controller: controller.mobileNumberCtr,
            textHeading: 'Phone',
            hintText: 'Enter phone number',
            required: true,
            validator: Validators.phoneValidatorFor(
              countryCode: controller.selectedCountry?.code,
            ),
            onCountryChanged: (Country country) {
              controller.updateSelectedCountry(country);
            },
            initialCountry:
                controller.selectedCountry ??
                CountryData.fromDeviceLocale() ??
                CountryData.fromIpCached() ??
                CountryData.getDefaultCountry(),
          ),

          SizedBox(height: R.h(4)),

          CustomTextField(
            controller: controller.passwordRegCtr,
            textHeading: 'Password',
            hintText: 'Enter password',
            isPassword: true,
            required: true,
            inputType: TextInputType.visiblePassword,
            validator: Validators.registerPasswordValidator.call,
          ),
          CustomTextField(
            controller: controller.confirmPasswordRegCtr,
            textHeading: 'Confirm password',
            hintText: 'Enter confirm password',
            isPassword: true,
            required: true,
            inputType: TextInputType.visiblePassword,
            validator: Validators.confirmPasswordValidator(
              () => controller.passwordRegCtr.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCheckAgreement(
    BuildContext context,
    SignupController controller,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: controller.toggleAcceptTerms,
          child: Container(
            padding: EdgeInsets.only(top: R.h(2), right: R.w(8)),
            child: Icon(
              controller.isAccept.value
                  ? LucideIcons.squareCheck
                  : LucideIcons.square,
              color: controller.isAccept.value
                  ? CustomColors.primary()
                  : CustomColors.whiteStroke(),
              size: R.sp(25),
            ),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to terms screen
                      controller.toggleAcceptTerms();
                    },
                    child: Text(
                      'I agree to the'.tr,
                      style: CustomTextStyles.medium14.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: ' ',
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.paragraph(),
                  ),
                ),

                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to terms screen
                      //Get.toNamed(AppRoutes.TermsOfServiceScreen);
                    },
                    child: Text(
                      'Terms'.tr,
                      style: CustomTextStyles.medium14.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: ' & ',
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.paragraph(),
                  ),
                ),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to privacy policy screen
                      //Get.toNamed(AppRoutes.PrivacyPolicyScreen);
                    },
                    child: Text(
                      'Privacy Policy'.tr,
                      style: CustomTextStyles.medium14.copyWith(
                        color: CustomColors.paragraph(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSignupButton(BuildContext context, SignupController controller) {
    return SizedBox(
      width: double.infinity,
      height: R.h(44),
      child: CustomButton(
        text: 'Create Account'.tr,
        backgroundColor: controller.isAccept.value
            ? CustomColors.primary()
            : CustomColors.textGray(),
        loading: controller.isLoadingCreateNewAccount.value,
        textStyle: CustomTextStyles.medium16.copyWith(
          color: CustomColors.white(),
        ),
        onPressed: () {
          FocusScope.of(context).unfocus();
          if (controller.createNewAccountFormKey.currentState!.validate()) {
            if (!controller.isAccept.value) {
              showCustomSnackBar(
                context: context,
                title: 'Accept terms'.tr,
                description: 'Please accept terms'.tr,
                type: SnackBarType.Warning,
              );
              return;
            }
            FocusScope.of(context).unfocus();
            // Form is already validated, proceed with registration
            controller.createNewAccount(fromPage: 'fromCreateAccount');
          }
        },
      ),
    );
  }

  Widget buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: CustomColors.whiteStroke(), thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: R.w(10)),
          child: Text(
            'or'.tr,
            style: CustomTextStyles.regular14.copyWith(
              color: CustomColors.paragraph(),
            ),
          ),
        ),
        Expanded(
          child: Divider(color: CustomColors.whiteStroke(), thickness: 1),
        ),
      ],
    );
  }

  Widget buildGoogleSigninButton(
    BuildContext context,
    SignupController controller,
  ) {
    return Obx(() {
      final isDisabled = controller.isLoadingSignIn.value;
      return SizedBox(
        //padding: R.pad(horizontal: 16),
        width: double.infinity,
        height: R.h(44),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: CustomOutlinedButton(
            text: 'Login with Google'.tr,
            textStyle: CustomTextStyles.medium12,
            loading: controller.isLoadingGoogleSignIn.value,
            onPressed: isDisabled
                ? () {}
                : () {
                    FocusScope.of(context).unfocus();
                    controller.signInWithGoogle();
                  },
            // Placeholder glyph — drop in the official brand asset here.
            icon: Icon(
              LucideIcons.globe,
              size: R.h(20),
              color: CustomColors.black(),
            ),
          ),
        ),
      );
    });
  }

  Widget buildAppleSigninButton(
    BuildContext context,
    SignupController controller,
  ) {
    return Obx(() {
      final isDisabled = controller.isLoadingSignIn.value;
      return SizedBox(
        //padding: R.pad(horizontal: 16),
        width: double.infinity,
        height: R.h(44),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: CustomOutlinedButton(
            text: 'Login With Apple'.tr,
            textStyle: CustomTextStyles.medium12,
            loading: controller.isLoadingAppleSignIn.value,
            onPressed: isDisabled
                ? () {}
                : () {
                    FocusScope.of(context).unfocus();
                    controller.signInWithApple();
                  },
            // Placeholder glyph — drop in the official brand asset here.
            icon: Icon(
              LucideIcons.apple,
              size: R.w(20),
              color: CustomColors.black(),
            ),
          ),
        ),
      );
    });
  }

  Widget buildHaveAccount(BuildContext context, SignupController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: CustomTextStyles.medium14.copyWith(
            color: CustomColors.textGray(),
          ),
        ),
        SizedBox(width: R.w(5)),
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            Get.back();
          },
          child: Text(
            'Log in',
            style: CustomTextStyles.bold14.copyWith(
              color: CustomColors.primary(),
            ),
          ),
        ),
      ],
    );
  }
}
