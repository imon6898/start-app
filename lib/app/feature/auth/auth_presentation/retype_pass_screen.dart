import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logistics/app/feature/auth/auth_controllers/retype_pass_controller.dart';
import 'package:logistics/app/utils/constants/app_colors.dart';
import 'package:logistics/app/utils/constants/app_fonts.dart';
import 'package:logistics/app/utils/responsive_utils.dart';
import 'package:logistics/app/utils/validator.dart';
import 'package:logistics/app/widgets/appbar_widget.dart';
import 'package:logistics/app/widgets/custom_primary_button.dart';
import 'package:logistics/app/widgets/custom_text_field.dart';

class RetypePassScreen extends StatelessWidget {
  const RetypePassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RetypePassController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(title: "Set-up new password".tr),
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
                loading: c.isLoadingResetPass.value,
                text: "Change Password".tr,
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  if (c.resetPassFormKey.currentState!.validate()) {
                    c.resetPassword();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, RetypePassController controller) {
    return Form(
      key: controller.resetPassFormKey,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: R.w(16)),
        width: double.infinity,
        child: Column(
          children: [
            SizedBox(height: R.h(44)),
            Text(
              "Create a new password to secure your account and continue using Yaad"
                  .tr,
              style: CustomTextStyles.regular16.copyWith(
                color: CustomColors.paragraph(),
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: R.h(20)),
            CustomTextField(
              controller: controller.newPasswordController,
              textHeading: "New Password".tr,
              hintText: "Enter new password".tr,
              isPassword: true,
              inputType: TextInputType.visiblePassword,
              validator: Validators.registerPasswordValidator.call,
            ),
            SizedBox(height: R.h(10)),
            CustomTextField(
              controller: controller.confirmPasswordController,
              textHeading: "Confirm New Password".tr,
              hintText: "Enter confirm new password".tr,
              isPassword: true,
              inputType: TextInputType.visiblePassword,
              validator: Validators.confirmPasswordValidator(
                () => controller.newPasswordController.text,
              ),
            ),

            SizedBox(height: R.h(20)),
          ],
        ),
      ),
    );
  }
}
