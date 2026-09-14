import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/custom_primary_button.dart';

class RiderRegistrationInfoScreen extends StatelessWidget {
  const RiderRegistrationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.BGColor(),
      appBar: AppBarWidget(title: 'Rider Registration'.tr),
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
              svgIcon: 'assets/svg/ic_step_user.svg',
              title: 'Your Details',
              subtitle:
                  'Personal and contact information, address, and\nemergency contact.',
              requiredFields: [
                'Full name',
                'Email & password',
                'Phone number',
                'Date of birth',
                'Current address',
              ],
              optionalFields: [
                'Profile photo',
                'Alternate phone',
                'Permanent address',
              ],
            ),
            SizedBox(height: R.h(6)),
            _buildStepCard(
              svgIcon: 'assets/svg/ic_step_document.svg',
              title: 'Upload Documents',
              subtitle:
                  'Identity and compliance documents required for\nverification.',
              requiredFields: ['TRN card', 'NIS card', 'Proof of address'],
              optionalFields: [],
            ),
            SizedBox(height: R.h(6)),
            _buildStepCard(
              svgIcon: 'assets/svg/ic_step_bank.svg',
              title: 'Bank & Schedule',
              subtitle:
                  'Bank account for payouts and your preferred work\nschedule.',
              requiredFields: [
                'Bank name',
                'Account number',
                'Account holder name',
              ],
              optionalFields: [
                'Zone preference',
                'Shift preference',
                'Available days',
              ],
            ),
            SizedBox(height: R.h(20)),
            // Documents to have ready
            _buildSectionTitle('Documents to have ready'),
            SizedBox(height: R.h(14)),
            _buildDocCard(
              title: 'TRN Card',
              description:
                  'Taxpayer Registration Number card issued by Tax Administration Jamaica',
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'NIS Card',
              description:
                  'National Insurance Scheme card issued by the Ministry of Labour',
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'Proof of Address',
              description:
                  'Utility bill or bank letter dated within the last 3 months',
            ),
            SizedBox(height: R.h(6)),
            _buildDocCard(
              title: 'Driver\'s Licence',
              description:
                  'Valid Jamaican driver\'s licence — front scan required (not needed for bicycle riders)',
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
        padding: R.pad(all: R.w(12)),
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
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: R.sp(12),
                        height: 1.625,
                        color: const Color(0xFF4E8C3D),
                      ),
                      children: [
                        const TextSpan(text: 'The form is split into '),
                        TextSpan(
                          text: '4 short steps.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: R.sp(12),
                            height: 1.625,
                            color: const Color(0xFF4E8C3D),
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' You can go back and edit any step before submitting. Start delivering within ',
                        ),
                        TextSpan(
                          text: '48 hours',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: R.sp(12),
                            height: 1.625,
                            color: const Color(0xFF4E8C3D),
                          ),
                        ),
                        const TextSpan(text: ' of approval.'),
                      ],
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
            color: const Color(0xFF222222),
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
            SizedBox(height: R.h(12)),
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
            SizedBox(width: R.w(12)),
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
              'assets/svg/ic_check_green.svg',
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
        ],
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
          onPressed: () => Get.toNamed(AppRoutes.RiderSignupScreen),
        ),
      ),
    );
  }
}
