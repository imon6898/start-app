import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/signup_controller.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/custom_phone_text_field.dart';
import 'package:flutter_starter/app/widgets/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/custom_text_field.dart';

class UserRegistrationInfoScreen extends StatefulWidget {
  const UserRegistrationInfoScreen({super.key});

  @override
  State<UserRegistrationInfoScreen> createState() =>
      _UserRegistrationInfoScreenState();
}

class _UserRegistrationInfoScreenState
    extends State<UserRegistrationInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SignupController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(title: 'Create Account'.tr),
          body: _body(context, c),
          bottomNavigationBar: _bottomBar(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, SignupController c) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: R.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: R.h(16)),
          _buildSubtitle(),
          SizedBox(height: R.h(20)),
          _buildForm(c),
          SizedBox(height: R.h(16)),
          _buildTerms(c),
          SizedBox(height: R.h(24)),
          _buildAlreadyHaveAccount(context),
          SizedBox(height: R.h(30)),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Tell us a bit about yourself to finish setting up your account.'.tr,
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        fontSize: R.sp(14),
        height: 1.5,
        color: const Color(0xFF6A7282),
      ),
    );
  }

  Widget _buildForm(SignupController c) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: CustomTextField(
                  controller: c.firstNameCtr,
                  textHeading: 'First Name'.tr,
                  hintText: 'Enter your first name'.tr,
                  required: true,
                  inputType: TextInputType.name,
                  validator: Validators.nameValidator.call,
                ),
              ),
              SizedBox(width: R.w(8)),
              Flexible(
                child: CustomTextField(
                  controller: c.lastNameCtr,
                  textHeading: 'Last Name'.tr,
                  hintText: 'Enter your last name'.tr,
                  required: true,
                  inputType: TextInputType.name,
                  validator: Validators.nameValidator.call,
                ),
              ),
            ],
          ),
          SizedBox(height: R.h(4)),

          CustomTextField(
                  controller: c.emailRegCtr,
                  textHeading: 'Email Address'.tr,
                  hintText: 'Enter your email'.tr,
                  required: true,
                  inputType: TextInputType.emailAddress,
                  validator: Validators.emailValidator.call,
                ),

          SizedBox(height: R.h(4)),
          CustomPhoneTextField(
                  controller: c.mobileNumberCtr,
                  textHeading: 'Phone Number'.tr,
                  hintText: 'Enter phone number'.tr,
                  required: true,
                  initialCountry: c.selectedCountry ??
                      CountryData.fromDeviceLocale() ??
                      CountryData.fromIpCached() ??
                      CountryData.getDefaultCountry(),
                  onCountryChanged: (Country country) =>
                      c.updateSelectedCountry(country),
                  validator: Validators.phoneValidatorFor(
                    countryCode: c.selectedCountry?.code,
                  ),
                  ),

          SizedBox(height: R.h(4)),
          CustomTextField(
            controller: c.addressRegCtr,
            textHeading: 'Address'.tr,
            hintText: 'Enter your address'.tr,
            required: true,
            inputType: TextInputType.streetAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required'.tr;
              }
              return null;
            },
          ),
          SizedBox(height: R.h(4)),
          CustomTextField(
            controller: c.passwordRegCtr,
            textHeading: 'Password'.tr,
            hintText: 'Enter password'.tr,
            isPassword: true,
            required: true,
            inputType: TextInputType.visiblePassword,
            validator: Validators.registerPasswordValidator.call,
          ),
          SizedBox(height: R.h(4)),
          CustomTextField(
            controller: c.confirmPasswordRegCtr,
            textHeading: 'Confirm Password'.tr,
            hintText: 'Enter confirm password'.tr,
            isPassword: true,
            required: true,
            inputType: TextInputType.visiblePassword,
            validator: Validators.confirmPasswordValidator(
              () => c.passwordRegCtr.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerms(SignupController c) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  c.toggleAcceptTerms();
                  if (c.isAccept.value) c.showTermsError.value = false;
                },
                child: Padding(
                  padding: EdgeInsets.only(right: R.w(8)),
                  child: Icon(
                    c.isAccept.value
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: c.isAccept.value
                        ? CustomColors.primary()
                        : CustomColors.whiteStroke(),
                    size: R.sp(22),
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'I agree to the '.tr,
                        style: CustomTextStyles.regular14.copyWith(
                          color: CustomColors.paragraph(),
                        ),
                      ),
                      TextSpan(
                        text: 'Terms'.tr,
                        style: CustomTextStyles.medium14.copyWith(
                          color: CustomColors.primary(),
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Get.toNamed(AppRoutes.TermsOfServiceScreen),
                      ),
                      TextSpan(
                        text: ' & ',
                        style: CustomTextStyles.regular14.copyWith(
                          color: CustomColors.paragraph(),
                        ),
                      ),
                      TextSpan(
                        text: 'Privacy Policy'.tr,
                        style: CustomTextStyles.medium14.copyWith(
                          color: CustomColors.primary(),
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Get.toNamed(AppRoutes.PrivacyPolicyScreen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (c.showTermsError.value)
            Padding(
              padding: EdgeInsets.only(top: R.h(4), left: R.w(30)),
              child: Text(
                'You must agree to the terms'.tr,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: R.sp(12),
                  color: CustomColors.error(),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildAlreadyHaveAccount(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Already have an account? '.tr,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.textGray(),
              ),
            ),
            TextSpan(
              text: 'Login'.tr,
              style: CustomTextStyles.semiBold14.copyWith(
                color: CustomColors.primary(),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  FocusScope.of(context).unfocus();
                  Get.back();
                  Get.back();
                },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, SignupController c) {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 3,
              offset: const Offset(0, -1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          R.w(16),
          R.h(16),
          R.w(16),
          R.h(16) + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          height: R.h(48),
          child: CustomButton(
            text: 'Create Account'.tr,
            borderRadius: 8,
            loading: c.isLoadingCreateNewAccount.value,
            backgroundColor: CustomColors.primary(),
            textStyle: CustomTextStyles.semiBold16.copyWith(
              color: Colors.white,
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (_formKey.currentState!.validate()) {
                if (!c.isAccept.value) {
                  c.showTermsError.value = true;
                  return;
                }
                c.showTermsError.value = false;
                c.createNewAccount(fromPage: 'fromCreateAccount');
              }
            },
          ),
        ),
      );
    });
  }
}
