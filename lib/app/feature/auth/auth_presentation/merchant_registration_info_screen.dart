import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/custom_primary_button.dart';

class MerchantRegistrationInfoScreen extends StatelessWidget {
  const MerchantRegistrationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.BGColor(),
      appBar: AppBarWidget(title: 'Merchant Registration'.tr),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: R.h(16)),
            // Top green card
            _buildTopCard(),
            SizedBox(height: R.h(20)),
            // What you'll complete
            _buildSectionTitle('What you\'ll complete'),
            SizedBox(height: R.h(14)),
            _buildStepCard(
              svgIcon: 'assets/svg/ic_step_user_m.svg',
              title: 'Your Details',
              subtitle: 'Personal info and secure account credentials.',
              requiredFields: [
                'First & last name',
                'Email address',
                'Password',
                'Phone number',
              ],
              optionalFields: ['Profile photo'],
            ),
            SizedBox(height: R.h(6)),
            _buildStepCard(
              svgIcon: 'assets/svg/ic_step_business.svg',
              title: 'Business Info',
              subtitle:
                  'Your trading name, type, and a short description.',
              requiredFields: ['Business name'],
              optionalFields: ['Merchant type', 'Business description'],
            ),
            SizedBox(height: R.h(6)),
            _buildStepCard(
              svgIcon: 'assets/svg/ic_step_location.svg',
              title: 'Your Location',
              subtitle:
                  'Business address and exact pickup pin on the map.',
              requiredFields: ['Map pin (exact location)'],
              optionalFields: ['Parish / City / Zone', 'Street address'],
            ),
            SizedBox(height: R.h(6)),
            _buildStepCard(
              svgIcon: 'assets/svg/ic_step_shield.svg',
              title: 'Verification Docs',
              subtitle:
                  'Supporting documents for identity and compliance.',
              requiredFields: [],
              optionalFields: [
                'Business registration',
                'TRN certificate',
                'Gov. ID (front + back)',
                'Proof of address',
                'Bank statement',
              ],
            ),
            SizedBox(height: R.h(20)),
            // Documents to have ready
            _buildSectionTitle('Documents to have ready'),
            SizedBox(height: R.h(14)),
            _buildDocCard(
              title: 'Business Registration',
              description:
                  'Certificate of incorporation or sole trader registration',
              isRequired: true,
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'TRN Certificate',
              description:
                  'Taxpayer Registration Number issued by Tax Administration Jamaica',
              isRequired: true,
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'Government-issued ID',
              description:
                  'Passport, driver\'s licence, or national ID — front and back scans',
              isRequired: true,
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'Proof of Address',
              description:
                  'Utility bill or bank letter dated within the last 3 months',
              isRequired: false,
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'Bank Statement',
              description:
                  'Most recent 3-month statement for the business account',
              isRequired: false,
            ),
            SizedBox(height: R.h(20)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildTopCard() {
    return Padding(
      padding: R.pad(horizontal: R.w(14)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(R.w(12)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.15, -1.0),
            end: Alignment(0.15, 1.0),
            colors: [Color(0xFFF0FCED), Color(0xFFE4F8DF)],
          ),
          borderRadius: BorderRadius.circular(R.r(12)),
          border: Border.all(color: const Color(0xFFC8EABF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/svg/ic_check_badge.svg',
              width: R.w(32),
              height: R.w(32),
            ),
            SizedBox(width: R.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4-step registration',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: R.sp(14),
                      height: 1.43,
                      color: const Color(0xFF2D6622),
                    ),
                  ),
                  SizedBox(height: R.h(6)),
                  Text(
                    'The form is split into 4 short steps. You can go back and edit any step before submitting. Documents are optional now — you can upload them any time after registering.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: R.sp(12),
                      height: 1.625,
                      color: const Color(0xFF4E8C3D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: R.pad(horizontal: R.w(16)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: R.sp(14),
            height: 1.0,
            color: const Color(0xFF030303),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String svgIcon,
    required String title,
    required String subtitle,
    required List<String> requiredFields,
    required List<String> optionalFields,
  }) {
    return Container(
      width: double.infinity,
      padding: R.pad(
        horizontal: R.w(16),
        vertical: R.h(16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.r(0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon + title
          Row(
            children: [
              SvgPicture.asset(svgIcon, width: R.w(24), height: R.w(24)),
              SizedBox(width: R.w(8)),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: R.sp(14),
                  height: 1.0,
                  color: const Color(0xFF1E2939),
                ),
              ),
            ],
          ),
          SizedBox(height: R.h(12)),
          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: R.sp(12),
              height: 1.625,
              color: const Color(0xFF6A7282),
            ),
          ),
          SizedBox(height: R.h(16)),
          // Required
          if (requiredFields.isNotEmpty) ...[
            Text(
              'REQUIRED',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: R.sp(10),
                height: 1.57,
                letterSpacing: R.sp(10) * 0.05,
                color: const Color(0xFF3A7A2C),
              ),
            ),
            SizedBox(height: R.h(10)),
            ...requiredFields.map((f) => _buildCheckItem(f, true)),
          ],
          // Optional
          if (optionalFields.isNotEmpty) ...[
            if (requiredFields.isNotEmpty) SizedBox(height: R.h(12)),
            Text(
              'OPTIONAL',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: R.sp(10),
                height: 1.57,
                letterSpacing: R.sp(10) * 0.05,
                color: const Color(0xFF99A1AF),
              ),
            ),
            SizedBox(height: R.h(10)),
            ...optionalFields.map((f) => _buildCheckItem(f, false)),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isRequired) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.h(4)),
      child: SizedBox(
        height: R.h(20),
        child: Row(
          children: [
            SvgPicture.asset(
              isRequired
                  ? 'assets/svg/ic_check_green.svg'
                  : 'assets/svg/ic_check_gray.svg',
              width: R.w(10),
              height: R.w(10),
            ),
            SizedBox(width: R.w(6)),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: R.sp(12),
                height: 1.33,
                color: isRequired
                    ? const Color(0xFF364153)
                    : const Color(0xFF6A7282),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard({
    required String title,
    required String description,
    required bool isRequired,
  }) {
    return Container(
      width: double.infinity,
      padding: R.pad(all: R.w(16)),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: R.h(4)),
            child: SvgPicture.asset(
              isRequired
                  ? 'assets/svg/ic_check_green.svg'
                  : 'assets/svg/ic_check_gray.svg',
              width: R.w(10),
              height: R.w(10),
            ),
          ),
          SizedBox(width: R.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: R.sp(14),
                    height: 1.43,
                    color: const Color(0xFF364153),
                  ),
                ),
                SizedBox(height: R.h(2)),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: R.sp(12),
                    height: 1.33,
                    color: const Color(0xFF99A1AF),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: R.w(8)),
          _buildRequiredBadge(isRequired),
        ],
      ),
    );
  }

  Widget _buildRequiredBadge(bool isRequired) {
    final fg = isRequired
        ? const Color(0xFF3A7A2C)
        : const Color(0xFF6A7282);
    final bg = isRequired
        ? const Color(0xFFE8F5E1)
        : const Color(0xFFF1F2F4);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: R.w(8),
        vertical: R.h(3),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(R.r(10)),
      ),
      child: Text(
        isRequired ? 'Required' : 'Optional',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: R.sp(10),
          height: 1.4,
          letterSpacing: R.sp(10) * 0.04,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
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
        MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: R.h(48),
        child: CustomButton(
          text: 'Start Registration'.tr,
          borderRadius: 8,
          backgroundColor: CustomColors.primary(),
          textStyle: CustomTextStyles.semiBold16.copyWith(
            color: Colors.white,
          ),
          onPressed: () => Get.toNamed(AppRoutes.MerchantSignupScreen),
        ),
      ),
    );
  }
}
