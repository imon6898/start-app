import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/models/country.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/sent_otp_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_phone_text_field.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SentOtpScreen extends StatelessWidget {
  const SentOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SentOtpController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(title: 'Forgot Password'.tr),
          body: _body(context, c),
          bottomSheet: Padding(
            padding: EdgeInsets.only(
              left: R.w(16),
              right: R.w(16),
              bottom: R.h(10),
            ),
            child: buildSentOtpButton(context, c),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, SentOtpController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: R.w(16)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: R.h(44)),

            Text(
              'Enter the email address or phone number associated with your account.'
                  .tr,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.paragraph(),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: R.h(20)),

            buildInputField(context, controller),

            SizedBox(height: R.h(20)),
          ],
        ),
      ),
    );
  }

  /// Radio-style option that switches the form between email and phone entry.
  Widget buildTypeOption(
    SentOtpController controller,
    String type,
    String label,
  ) {
    final selected = controller.sentOtpType == type;
    return GestureDetector(
      onTap: () {
        controller.sentOtpType = type;
        controller.update();
      },
      child: Row(
        children: [
          Icon(
            selected ? LucideIcons.circleDot : LucideIcons.circle,
            color: selected ? CustomColors.primary() : CustomColors.lightGrey(),
          ),
          SizedBox(width: R.w(8)),
          Text(
            label,
            style: CustomTextStyles.regular14.copyWith(
              color: CustomColors.black(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputField(BuildContext context, SentOtpController controller) {
    return Form(
      key: controller.sentOtpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              buildTypeOption(controller, 'email', 'Email'.tr),
              SizedBox(width: R.w(20)),
              buildTypeOption(controller, 'phone', 'Phone'.tr),
            ],
          ),

          SizedBox(height: R.h(16)),

          if (controller.sentOtpType == 'email') ...[
            CustomTextField(
              controller: controller.sentOtpController,
              hintText: 'Enter email address'.tr,
              inputType: TextInputType.emailAddress,
              validator: Validators.emailValidator.call,
            ),
          ] else ...[
            CustomPhoneTextField(
              controller: controller.mobileNumberCtr,
              hintText: 'Enter phone number'.tr,
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
          ],
        ],
      ),
    );
  }

  Widget buildSentOtpButton(
    BuildContext context,
    SentOtpController controller,
  ) {
    return SizedBox(
      width: double.infinity,
      height: R.h(44),
      child: CustomButton(
        loading: controller.isLoadingSentOtp.value,
        text: 'Continue'.tr,
        textStyle: CustomTextStyles.medium16.copyWith(
          color: CustomColors.white(),
        ),
        onPressed: () {
          FocusScope.of(context).unfocus();
          if (controller.sentOtpFormKey.currentState!.validate()) {
            controller.sentOtp();
          }
        },
      ),
    );
  }
}
