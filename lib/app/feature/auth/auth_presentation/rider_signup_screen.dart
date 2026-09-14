import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/rider_signup_controller.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_starter/app/widgets/appbar_widgets/appbar_widget.dart';
import 'package:flutter_starter/app/widgets/custom_dropdown_button.dart';
import 'package:flutter_starter/app/widgets/custom_phone_text_field.dart';
import 'package:flutter_starter/app/widgets/custom_primary_button.dart';
import 'package:flutter_starter/app/widgets/custom_text_field.dart';
import 'package:flutter_starter/app/widgets/file_upload_widget.dart';

class RiderSignupScreen extends StatelessWidget {
  const RiderSignupScreen({super.key});

  static const _vehicleIcons = {
    'BIKE': 'assets/svg/registration/vehicle_bike.svg',
    'SCOOTER': 'assets/svg/registration/vehicle_scooter.svg',
    'CAR': 'assets/svg/registration/vehicle_car.svg',
    'VAN': 'assets/svg/registration/vehicle_van.svg',
    'TRUCK': 'assets/svg/registration/vehicle_truck.svg',
    'MINI TRUCK': 'assets/svg/registration/vehicle_mini_truck.svg',
    'BICYCLE': 'assets/svg/registration/vehicle_bicycle.svg',
  };

  static const _vehicleLabels = {
    'BIKE': 'Bike',
    'SCOOTER': 'Scooter',
    'CAR': 'Car',
    'VAN': 'Van',
    'TRUCK': 'Truck',
    'MINI TRUCK': 'Mini Truck',
    'BICYCLE': 'Bicycle',
  };

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RiderSignupController>(
      builder: (c) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(
            title: 'Rider Registration'.tr,
            leadingWidget: IconButton(
              onPressed: () {
                if (c.currentStep.value > 0) {
                  c.previousStep();
                } else {
                  Get.back();
                }
              },
              icon: Icon(
                Icons.arrow_back_ios,
                size: R.sp(18),
                color: CustomColors.black(),
              ),
            ),
          ),
          body: Column(
            children: [
              _buildStepIndicator(c),
              Expanded(
                child: PageView(
                  controller: c.pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (index) {
                    c.currentStep.value = index;
                  },
                  children: [
                    _buildPersonalInfoStep(context, c),
                    _buildDocumentsStep(context, c),
                    _buildVehicleStep(context, c),
                    _buildBankStep(context, c),
                    _buildSecurityStep(context, c),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, c),
        ),
        );
      },
    );
  }

  // --- Step Indicator (Figma style) ---
  Widget _buildStepIndicator(RiderSignupController c) {
    return Obx(() {
      final step = c.currentStep.value;
      final percent = ((step + 1) / c.totalSteps * 100).round();
      return Container(
        color: CustomColors.white(),
        padding: EdgeInsets.symmetric(horizontal: R.w(14), vertical: R.h(12)),
        child: Column(
          children: [
            // Progress bar segments
            Row(
              children: List.generate(c.totalSteps, (i) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < c.totalSteps - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i <= step
                          ? CustomColors.primary()
                          : CustomColors.whiteStroke(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: R.h(14)),
            // Step info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${step + 1} of ${c.totalSteps}',
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.textGrayDark(),
                  ),
                ),
                Text(
                  '$percent% complete',
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.textGrayDark(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ===================== STEP 1: Personal Info =====================
  Widget _buildPersonalInfoStep(BuildContext context, RiderSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.personalFormKey,
        child: Column(
          children: [
            // Personal Information
            _section(
              title: 'Personal Information',
              child: Column(
                children: [
                  // Profile photo
                  Center(child: _buildProfilePhoto(context, c)),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.firstNameCtr,
                    textHeading: 'First Name',
                    hintText: 'Enter first name',
                    required: true,
                    inputType: TextInputType.name,
                    validator: Validators.nameValidator.call,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomTextField(
                    controller: c.lastNameCtr,
                    textHeading: 'Last Name',
                    hintText: 'Enter last name',
                    required: true,
                    inputType: TextInputType.name,
                    validator: Validators.nameValidator.call,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomTextField(
                    controller: c.emailCtr,
                    textHeading: 'Email',
                    hintText: 'Enter email address',
                    required: true,
                    inputType: TextInputType.emailAddress,
                    validator: Validators.emailValidator.call,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomPhoneTextField(
                    controller: c.phoneCtr,
                    textHeading: 'Phone Number',
                    hintText: 'Enter phone number',
                    required: true,
                    validator: Validators.phoneValidatorFor(
                      countryCode: c.phoneCountry?.code,
                    ),
                    onCountryChanged: (Country country) => c.updatePhoneCountry(country),
                    initialCountry: c.phoneCountry ?? CountryData.fromDeviceLocale() ?? CountryData.fromIpCached() ?? CountryData.getDefaultCountry(),
                  ),
                  SizedBox(height: R.h(16)),
                  CustomPhoneTextField(
                    controller: c.altPhoneCtr,
                    textHeading: 'Alternate Phone',
                    hintText: 'Enter alternate phone',
                    onCountryChanged: (Country country) => c.updateAltPhoneCountry(country),
                    initialCountry: c.altPhoneCountry ?? CountryData.fromDeviceLocale() ?? CountryData.fromIpCached() ?? CountryData.getDefaultCountry(),
                    validator: Validators.optionalPhoneValidatorFor(
                      countryCode: c.altPhoneCountry?.code,
                    ),
                  ),
                  SizedBox(height: R.h(16)),
                  // Date of Birth
                  _buildDateField(
                    context: context,
                    label: 'Date of Birth',
                    value: c.dobDate.value,
                    onPicked: (d) {
                      c.dobDate.value = d;
                      c.update();
                    },
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
                  ),
                  SizedBox(height: R.h(16)),
                  Obx(() => CustomDropdownButton(
                    labelText: 'Gender',
                    isRequired: true,
                    valueText: c.selectedGender.value ?? '',
                    itemList: c.genders,
                    onChange: (val) {
                      c.selectedGender.value = val;
                      c.update();
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select gender' : null,
                  )),
                ],
              ),
            ),
            SizedBox(height: R.h(14)),

            // Address Information
            _section(
              title: 'Address Information',
              child: Obx(() => Column(
                children: [
                  CustomTextField(
                    controller: c.currentAddressCtr,
                    textHeading: 'Current Address',
                    hintText: 'Enter current address',
                    inputType: TextInputType.streetAddress,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomDropdownButton(
                    labelText: 'Parish',
                    isRequired: true,
                    valueText: c.selectedParish.value?['name'] ?? '',
                    itemList: c.parishes.map((p) => p['name'] as String).toList(),
                    isEmptyText: c.isLoadingParishes.value ? 'Loading...' : null,
                    onChange: (val) {
                      final parish = c.parishes.firstWhereOrNull((p) => p['name'] == val);
                      c.onParishSelected(parish);
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select a parish' : null,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomDropdownButton(
                    labelText: 'City',
                    isRequired: true,
                    valueText: c.selectedCity.value?['name'] ?? '',
                    itemList: c.cities.map((ct) => ct['name'] as String).toList(),
                    isEmptyText: c.isLoadingCities.value ? 'Loading...' : null,
                    onChange: (val) {
                      final city = c.cities.firstWhereOrNull((ct) => ct['name'] == val);
                      c.onCitySelected(city);
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select a city' : null,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomDropdownButton(
                    labelText: 'Zone',
                    isRequired: true,
                    valueText: c.selectedZone.value?['name'] ?? '',
                    itemList: c.zones.map((z) => z['name'] as String).toList(),
                    isEmptyText: c.isLoadingZones.value ? 'Loading...' : null,
                    onChange: (val) {
                      final zone = c.zones.firstWhereOrNull((z) => z['name'] == val);
                      c.onZoneSelected(zone);
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select a zone' : null,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomTextField(
                    controller: c.postalCodeCtr,
                    textHeading: 'Postal Code',
                    hintText: 'Enter postal code',
                    inputType: TextInputType.text,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomTextField(
                    controller: c.landmarkCtr,
                    textHeading: 'Landmark',
                    hintText: 'Enter nearby landmark',
                    inputType: TextInputType.text,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomTextField(
                    controller: c.permanentAddressCtr,
                    textHeading: 'Permanent Address (if different)',
                    hintText: 'Enter permanent address',
                    inputType: TextInputType.streetAddress,
                    maxLines: 2,
                    miniLine: 1,
                  ),
                ],
              )),
            ),
            SizedBox(height: R.h(14)),

            // Emergency Contact
            _section(
              title: 'Emergency Contact',
              child: Column(
                children: [
                  CustomTextField(
                    controller: c.emergencyNameCtr,
                    textHeading: 'Contact Name',
                    hintText: 'Enter contact name',
                    required: true,
                    inputType: TextInputType.name,
                    validator: Validators.nameValidator.call,
                  ),
                  SizedBox(height: R.h(16)),
                  CustomPhoneTextField(
                    controller: c.emergencyPhoneCtr,
                    textHeading: 'Contact Phone',
                    hintText: 'Enter contact phone',
                    required: true,
                    validator: Validators.phoneValidatorFor(
                      countryCode: c.emergencyPhoneCountry?.code,
                    ),
                    onCountryChanged: (Country country) => c.updateEmergencyPhoneCountry(country),
                    initialCountry: c.emergencyPhoneCountry ?? CountryData.fromDeviceLocale() ?? CountryData.fromIpCached() ?? CountryData.getDefaultCountry(),
                  ),
                  SizedBox(height: R.h(16)),
                  CustomTextField(
                    controller: c.emergencyRelationCtr,
                    textHeading: 'Relationship',
                    hintText: 'e.g. Spouse, Parent, Sibling',
                    required: true,
                    inputType: TextInputType.text,
                    validator: Validators.requiredValidator.call,
                  ),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),
          ],
        ),
      ),
    );
  }

  // ===================== STEP 2: Documents =====================
  Widget _buildDocumentsStep(BuildContext context, RiderSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.documentsFormKey,
        child: Obx(() => Column(
          children: [
            // Document Numbers
            _section(
              title: 'Document Numbers',
              child: Column(
                children: [
                  CustomTextField(
                    controller: c.trnNumberCtr,
                    textHeading: 'TRN Number',
                    hintText: 'Enter 9-digit TRN number',
                    required: true,
                    inputType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    validator: Validators.trnValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.nisNumberCtr,
                    textHeading: 'NIS Number',
                    hintText: 'Enter 9-digit NIS number',
                    required: true,
                    inputType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    validator: Validators.nisValidator.call,
                  ),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),
            // Upload Documents
            _section(
              title: 'Upload Documents',
              child: Column(
                children: [
                  FileUploadWidget(
                    title: 'TRN Card',
                    hint: 'Upload your PDF, JPG, PNG. Max 1 file. here to continue with the next step',
                    selectedFile: c.trnCardFile.value,
                    onFilePicked: (f) => c.trnCardFile.value = f,
                    required: true,
                  ),
                  SizedBox(height: R.h(20)),
                  FileUploadWidget(
                    title: 'NIS Card',
                    hint: 'Upload your PDF, JPG, PNG. Max 1 file. here to continue with the next step',
                    selectedFile: c.nisCardFile.value,
                    onFilePicked: (f) => c.nisCardFile.value = f,
                    required: true,
                  ),
                  SizedBox(height: R.h(20)),
                  FileUploadWidget(
                    title: 'Proof of Address',
                    hint: 'Upload your PDF, JPG, PNG. Max 1 file. here to continue with the next step',
                    selectedFile: c.proofOfAddressFile.value,
                    onFilePicked: (f) => c.proofOfAddressFile.value = f,
                    required: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),
          ],
        )),
      ),
    );
  }

  // ===================== STEP 3: Vehicle =====================
  Widget _buildVehicleStep(BuildContext context, RiderSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.vehicleFormKey,
        child: Obx(() => Column(
          children: [
            // Vehicle Type - horizontal scrollable chips
            _section(
              title: 'Vehicle Type',
              showTitleInCard: false,
              child: const SizedBox.shrink(),
            ),
            SizedBox(height: R.h(14)),
            _buildVehicleTypeChips(c),
            SizedBox(height: R.h(20)),

            // Vehicle Details
            _section(
              title: 'Vehicle Details',
              child: Column(
                children: [
                  CustomTextField(
                    controller: c.vehicleNumberCtr,
                    textHeading: 'Plate Number',
                    hintText: 'Enter vehicle plate number',
                    required: !c.isBicycle,
                    validator: c.isBicycle ? null : Validators.requiredValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.vehicleModelCtr,
                    textHeading: 'Vehicle Model',
                    hintText: 'Enter vehicle model',
                    required: true,
                    validator: Validators.requiredValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.vehicleCapacityCtr,
                    textHeading: 'Capacity (kg)',
                    hintText: 'Enter vehicle capacity in kg',
                    required: true,
                    inputType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: Validators.requiredValidator.call,
                  ),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),

            // Driver's License (optional for Bicycle)
            _section(
              title: c.isBicycle ? "Driver's License (Optional)" : "Driver's License",
              child: Column(
                children: [
                  CustomTextField(
                    controller: c.licenseNumberCtr,
                    textHeading: 'License Number',
                    hintText: 'Enter vehicle license number',
                    required: !c.isBicycle,
                    validator: c.isBicycle ? null : Validators.requiredValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  _buildDateField(
                    context: context,
                    label: 'Expiry Date',
                    required: !c.isBicycle,
                    value: c.licenseExpiryDate.value,
                    onPicked: (d) {
                      c.licenseExpiryDate.value = d;
                      c.update();
                    },
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2050),
                  ),
                  SizedBox(height: R.h(20)),
                  FileUploadWidget(
                    title: 'License Front Image',
                    hint: 'Upload your PDF, JPG, PNG. Max 1 file. here to continue with the next step',
                    selectedFile: c.licenseFrontFile.value,
                    onFilePicked: (f) => c.licenseFrontFile.value = f,
                    required: !c.isBicycle,
                  ),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),
          ],
        )),
      ),
    );
  }

  // --- Vehicle Type Horizontal Chips ---
  Widget _buildVehicleTypeChips(RiderSignupController c) {
    return SizedBox(
      height: R.h(46),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: R.w(14)),
        itemCount: c.vehicleTypes.length,
        separatorBuilder: (_, _) => SizedBox(width: R.w(14)),
        itemBuilder: (context, index) {
          final type = c.vehicleTypes[index];
          final isSelected = c.selectedVehicleType.value == type;
          final label = _vehicleLabels[type] ?? type;
          final svgPath = _vehicleIcons[type];

          return GestureDetector(
            onTap: () {
              c.selectedVehicleType.value = type;
              c.update();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: R.w(16),
                vertical: R.h(10),
              ),
              decoration: BoxDecoration(
                color: CustomColors.gray(),
                borderRadius: BorderRadius.circular(R.r(8)),
                border: isSelected
                    ? Border.all(color: CustomColors.primary(), width: 2)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (svgPath != null) ...[
                    SvgPicture.asset(
                      svgPath,
                      width: R.w(24),
                      height: R.w(24),
                    ),
                    SizedBox(width: R.w(8)),
                  ],
                  Text(
                    label,
                    style: (isSelected
                            ? CustomTextStyles.semiBold14
                            : CustomTextStyles.medium14)
                        .copyWith(
                      color: isSelected
                          ? CustomColors.primary()
                          : CustomColors.black(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== STEP 4: Bank & Preferences =====================
  Widget _buildBankStep(BuildContext context, RiderSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.bankFormKey,
        child: Obx(() => Column(
          children: [
            _section(
              title: 'Bank Account Details',
              child: Column(
                children: [
                  CustomTextField(
                    controller: c.accountHolderCtr,
                    textHeading: 'Account Holder Name',
                    hintText: 'Enter account holder name',
                    required: true,
                    inputType: TextInputType.name,
                    validator: Validators.nameValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomDropdownButton(
                    labelText: 'Bank Name',
                    isRequired: true,
                    valueText: c.selectedBank.value ?? '',
                    itemList: c.banks,
                    onChange: (val) {
                      c.selectedBank.value = val;
                      c.update();
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select a bank' : null,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.accountNumberCtr,
                    textHeading: 'Account Number',
                    hintText: 'Enter bank account number',
                    required: true,
                    inputType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: Validators.accountNumberValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.branchCodeCtr,
                    textHeading: 'Branch Code',
                    hintText: 'Enter bank branch code',
                    inputType: TextInputType.text,
                  ),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),
          ],
        )),
      ),
    );
  }

  // ===================== Bottom Bar =====================
  // ===================== STEP 5: Account Security =====================
  Widget _buildSecurityStep(BuildContext context, RiderSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.securityFormKey,
        child: Column(
          children: [
            _section(
              title: 'Account Security',
              child: Column(
                children: [
                  CustomTextField(
                    controller: c.passwordCtr,
                    textHeading: 'Password',
                    hintText: 'Enter password',
                    isPassword: true,
                    required: true,
                    inputType: TextInputType.visiblePassword,
                    validator: Validators.registerPasswordValidator.call,
                  ),
                  SizedBox(height: R.h(20)),
                  CustomTextField(
                    controller: c.confirmPasswordCtr,
                    textHeading: 'Confirm Password',
                    hintText: 'Enter confirm password',
                    isPassword: true,
                    required: true,
                    inputType: TextInputType.visiblePassword,
                    validator: Validators.confirmPasswordValidator(
                      () => c.passwordCtr.text,
                    ),
                  ),
                  SizedBox(height: R.h(8)),
                  Text(
                    'Password must be at least 8 characters and include: uppercase letter, lowercase letter, number, and special character',
                    style: CustomTextStyles.regular14.copyWith(
                      fontSize: R.sp(13),
                      color: CustomColors.error(),
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: R.h(24)),
                  // Terms agreement
                  Obx(() {
                    return GestureDetector(
                      onTap: c.toggleAcceptTerms,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            c.isAcceptTerms.value
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: c.isAcceptTerms.value
                                ? CustomColors.primary()
                                : CustomColors.whiteStroke(),
                            size: R.sp(24),
                          ),
                          SizedBox(width: R.w(8)),
                          Expanded(
                            child: Text(
                              'By registering, you agree to our Terms of Service and Privacy Policy. Your account will be reviewed and you will receive an email upon approval.',
                              style: CustomTextStyles.regular14.copyWith(
                                color: CustomColors.paragraph(),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: R.h(20)),
          ],
        ),
      ),
    );
  }

  // ===================== Bottom Bar =====================
  Widget _buildBottomBar(BuildContext context, RiderSignupController c) {
    return Obx(() {
      final isLastStep = c.currentStep.value == c.totalSteps - 1;
      return Container(
        decoration: BoxDecoration(
          color: CustomColors.white(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 3,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          R.w(16), R.h(16), R.w(16),
          R.h(16) + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          height: R.h(48),
          child: CustomButton(
            text: isLastStep ? 'Submit'.tr : 'Continue'.tr,
            borderRadius: 8,
            loading: c.isSubmitting.value,
            backgroundColor: CustomColors.primary(),
            textStyle: CustomTextStyles.semiBold16.copyWith(
              color: CustomColors.white(),
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              c.nextStep();
            },
          ),
        ),
      );
    });
  }

  // ===================== Shared Widgets =====================
  Widget _section({
    required String title,
    required Widget child,
    bool showTitleInCard = true,
  }) {
    if (!showTitleInCard) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: R.w(14)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.black(),
            ),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.w(14)),
      decoration: BoxDecoration(
        color: CustomColors.white(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CustomTextStyles.medium14.copyWith(
              color: CustomColors.black(),
            ),
          ),
          SizedBox(height: R.h(14)),
          child,
        ],
      ),
    );
  }

  Widget _buildProfilePhoto(BuildContext context, RiderSignupController c) {
    return Obx(() {
      return GestureDetector(
        onTap: () => _showPhotoPickerSheet(context, c),
        child: Stack(
          children: [
            Container(
              width: R.w(90),
              height: R.w(90),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: CustomColors.whiteStroke(), width: 1.2),
              ),
              child: ClipOval(
                child: c.profilePhoto.value != null
                    ? Image.file(c.profilePhoto.value!, fit: BoxFit.cover, width: R.w(90), height: R.w(90))
                    : Container(
                        color: CustomColors.gray(),
                        child: Icon(LucideIcons.user, size: R.sp(40), color: CustomColors.textGray()),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(R.w(6)),
                decoration: BoxDecoration(
                  color: CustomColors.primary(),
                  shape: BoxShape.circle,
                  border: Border.all(color: CustomColors.white(), width: 2),
                ),
                child: Icon(LucideIcons.camera, size: R.sp(14), color: CustomColors.white()),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
    required DateTime firstDate,
    required DateTime lastDate,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(text: label, style: CustomTextStyles.medium14.copyWith(color: CustomColors.black())),
            if (required) TextSpan(text: ' *', style: CustomTextStyles.medium14.copyWith(color: CustomColors.error())),
          ]),
        ),
        SizedBox(height: R.h(10)),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? (lastDate.isBefore(DateTime.now()) ? lastDate : DateTime.now()),
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (date != null) onPicked(date);
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: R.w(20), vertical: R.h(12)),
            decoration: BoxDecoration(
              color: CustomColors.white(),
              borderRadius: BorderRadius.circular(R.r(8)),
              border: Border.all(color: CustomColors.whiteStroke()),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? DateFormat('dd/MM/yyyy').format(value) : 'Select date',
                    style: CustomTextStyles.regular16.copyWith(
                      color: value != null ? CustomColors.black() : CustomColors.gray2(),
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: R.sp(18), color: CustomColors.textGray()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Photo picker with permission ---
  void _showPhotoPickerSheet(BuildContext context, RiderSignupController c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CustomColors.white(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.r(16))),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(R.w(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose Photo', style: CustomTextStyles.semiBold16.copyWith(color: CustomColors.black())),
                SizedBox(height: R.h(16)),
                ListTile(
                  leading: Icon(LucideIcons.camera, color: CustomColors.primary()),
                  title: Text('Camera', style: CustomTextStyles.medium14),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _pickImage(ImageSource.camera, c);
                  },
                ),
                ListTile(
                  leading: Icon(LucideIcons.image, color: CustomColors.primary()),
                  title: Text('Gallery', style: CustomTextStyles.medium14),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _pickImage(ImageSource.gallery, c);
                  },
                ),
                if (c.profilePhoto.value != null)
                  ListTile(
                    leading: Icon(LucideIcons.trash2, color: CustomColors.error()),
                    title: Text('Remove Photo', style: CustomTextStyles.medium14.copyWith(color: CustomColors.error())),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      c.profilePhoto.value = null;
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, RiderSignupController c) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (status.isDenied) status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        Get.dialog(AlertDialog(
          title: Text('Camera Permission Required', style: CustomTextStyles.semiBold16),
          content: Text('Please allow Camera access in settings.', style: CustomTextStyles.regular14),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('Cancel', style: CustomTextStyles.medium14)),
            TextButton(onPressed: () { Get.back(); openAppSettings(); }, child: Text('Open Settings', style: CustomTextStyles.medium14.copyWith(color: CustomColors.primary()))),
          ],
        ));
        return;
      }
      if (!status.isGranted && !status.isLimited) return;
    }
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (picked != null) c.profilePhoto.value = File(picked.path);
    } catch (e) {
      Get.dialog(AlertDialog(
        title: Text('Permission Required', style: CustomTextStyles.semiBold16),
        content: Text('Please allow access in settings to use this feature.', style: CustomTextStyles.regular14),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel', style: CustomTextStyles.medium14)),
          TextButton(onPressed: () { Get.back(); openAppSettings(); }, child: Text('Open Settings', style: CustomTextStyles.medium14.copyWith(color: CustomColors.primary()))),
        ],
      ));
    }
  }
}
