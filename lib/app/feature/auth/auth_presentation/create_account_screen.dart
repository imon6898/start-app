import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/create_account_controller.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CreateAccountController>(
      builder: (c) {
        return Scaffold(
          backgroundColor: CustomColors.white(),
          appBar: AppBarWidget(title: 'Create New Account'.tr),
          body: _body(context, c),
          bottomNavigationBar: _bottomBar(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, CreateAccountController controller) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: R.w(14)),
      child: Column(
        children: [
          SizedBox(height: R.h(20)),
          _buildRoleCards(controller),
          SizedBox(height: R.h(24)),
          _buildAlreadyHaveAccount(context),
          SizedBox(height: R.h(20)),
        ],
      ),
    );
  }

  Widget _buildRoleCards(CreateAccountController controller) {
    return Obx(() {
      final selected = controller.selectedRole.value;
      return Column(
        children: [
          _buildRoleCard(
            controller: controller,
            role: AccountRole.personal,
            icon: LucideIcons.user,
            title: 'Personal account'.tr,
            subtitle: 'For individuals using the app on their own.'.tr,
            isSelected: selected == AccountRole.personal,
          ),
          SizedBox(height: R.h(12)),
          _buildRoleCard(
            controller: controller,
            role: AccountRole.business,
            icon: LucideIcons.store,
            title: 'Business account'.tr,
            subtitle: 'For teams and organizations.'.tr,
            isSelected: selected == AccountRole.business,
          ),
        ],
      );
    });
  }

  Widget _buildRoleCard({
    required CreateAccountController controller,
    required AccountRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => controller.selectRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.all(R.w(16)),
        decoration: BoxDecoration(
          color: CustomColors.white(),
          borderRadius: BorderRadius.circular(R.r(16)),
          border: Border.all(
            color: isSelected
                ? CustomColors.black()
                : CustomColors.whiteStroke(),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, size: R.sp(40), color: CustomColors.primary()),
            SizedBox(height: R.h(14)),
            Text(
              title,
              style: CustomTextStyles.medium16.copyWith(
                color: CustomColors.black(),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: R.h(6)),
            Text(
              subtitle,
              style: CustomTextStyles.regular14.copyWith(
                color: CustomColors.textGray(),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyHaveAccount(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${'Already have an account?'.tr} ',
            style: CustomTextStyles.semiBold14.copyWith(
              color: CustomColors.primary(),
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
              },
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, CreateAccountController controller) {
    return Obx(() {
      final isEnabled = controller.isRoleSelected;
      return Container(
        decoration: BoxDecoration(
          color: CustomColors.white(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 3,
              offset: const Offset(0, -1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, -1),
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
            text: 'Get Started'.tr,
            borderRadius: 8,
            backgroundColor: isEnabled
                ? CustomColors.primary()
                : CustomColors.primary().withValues(alpha: 0.5),
            textStyle: CustomTextStyles.semiBold16.copyWith(
              color: CustomColors.white(),
            ),
            onPressed: isEnabled
                ? () => Get.toNamed(AppRoutes.UserRegistrationInfoScreen)
                : null,
          ),
        ),
      );
    });
  }
}
