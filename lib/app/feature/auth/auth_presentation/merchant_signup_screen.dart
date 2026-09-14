import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_starter/app/feature/auth/auth_controllers/merchant_signup_controller.dart';
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
import 'package:flutter_starter/app/widgets/profile_location_picker.dart';

class MerchantSignupScreen extends StatelessWidget {
  const MerchantSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MerchantSignupController>(
      builder: (c) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
          backgroundColor: CustomColors.BGColor(),
          appBar: AppBarWidget(
            title: 'Merchant Registration'.tr,
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
                    _buildContactInfoStep(context, c),
                    _buildBusinessDetailsStep(context, c),
                    _buildLocationStep(context, c),
                    _buildDocumentsStep(context, c),
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
  Widget _buildStepIndicator(MerchantSignupController c) {
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
              children: List.generate(c.totalSteps, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index < c.totalSteps - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: index <= step
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

  // --- Step 1: Contact Information ---
  Widget _buildContactInfoStep(BuildContext context, MerchantSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.contactFormKey,
        child: Container(
          padding: EdgeInsets.all(R.w(14)),
          decoration: _sectionDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Picker
              Center(
                child: Obx(() {
                  return GestureDetector(
                    onTap: () => _showPhotoPickerSheet(context, c),
                    child: Stack(
                      children: [
                        Container(
                          width: R.w(90),
                          height: R.w(90),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CustomColors.whiteStroke(),
                              width: 1.2,
                            ),
                          ),
                          child: ClipOval(
                            child: c.profilePhoto.value != null
                                ? Image.file(
                                    c.profilePhoto.value!,
                                    fit: BoxFit.cover,
                                    width: R.w(90),
                                    height: R.w(90),
                                  )
                                : Container(
                                    color: CustomColors.gray(),
                                    child: Icon(
                                      LucideIcons.user,
                                      size: R.sp(40),
                                      color: CustomColors.textGray(),
                                    ),
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
                              border: Border.all(
                                color: CustomColors.white(),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.camera,
                              size: R.sp(14),
                              color: CustomColors.white(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              SizedBox(height: R.h(20)),
              CustomTextField(
                controller: c.firstNameCtr,
                textHeading: 'First Name',
                hintText: 'Enter your first name',
                required: true,
                inputType: TextInputType.name,
                validator: Validators.nameValidator.call,
              ),
              SizedBox(height: R.h(20)),
              CustomTextField(
                controller: c.lastNameCtr,
                textHeading: 'Last Name',
                hintText: 'Enter your last name',
                required: true,
                inputType: TextInputType.name,
                validator: Validators.nameValidator.call,
              ),
              SizedBox(height: R.h(20)),
              CustomTextField(
                controller: c.contactPersonCtr,
                textHeading: 'Contact Person',
                hintText: 'Enter your contact person',
                required: true,
                inputType: TextInputType.name,
                validator: Validators.nameValidator.call,
              ),
              SizedBox(height: R.h(20)),
              CustomTextField(
                controller: c.emailCtr,
                textHeading: 'Email',
                hintText: 'Enter your email address',
                required: true,
                inputType: TextInputType.emailAddress,
                validator: Validators.emailValidator.call,
              ),
              SizedBox(height: R.h(20)),
              CustomPhoneTextField(
                controller: c.phoneCtr,
                textHeading: 'Phone',
                hintText: 'Enter your phone number',
                required: true,
                validator: Validators.phoneValidatorFor(
                  countryCode: c.phoneCountry?.code,
                ),
                onCountryChanged: (Country country) => c.updatePhoneCountry(country),
                initialCountry: c.phoneCountry ?? CountryData.fromDeviceLocale() ?? CountryData.fromIpCached() ?? CountryData.getDefaultCountry(),
              ),
              SizedBox(height: R.h(20)),
              CustomPhoneTextField(
                controller: c.altPhoneCtr,
                textHeading: 'Alternative Phone',
                hintText: 'Enter alternative phone number',
                onCountryChanged: (Country country) => c.updateAltPhoneCountry(country),
                initialCountry: c.altPhoneCountry ?? CountryData.fromDeviceLocale() ?? CountryData.fromIpCached() ?? CountryData.getDefaultCountry(),
                validator: Validators.phoneValidatorFor(
                  countryCode: c.altPhoneCountry?.code,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 2: Business Details ---
  Widget _buildBusinessDetailsStep(BuildContext context, MerchantSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.businessFormKey,
        child: Container(
          padding: EdgeInsets.all(R.w(14)),
          decoration: _sectionDecoration(),
          child: Obx(() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  controller: c.businessNameCtr,
                  textHeading: 'Business Name',
                  hintText: 'Enter your business name',
                  required: true,
                  inputType: TextInputType.text,
                  validator: Validators.requiredValidator.call,
                ),
                SizedBox(height: R.h(20)),
                CustomDropdownButton(
                  labelText: 'Business Type',
                  isRequired: true,
                  valueText: c.businessTypes[c.selectedBusinessType.value] ?? '',
                  itemList: c.businessTypes.values.toList(),
                  onChange: (val) {
                    String key = '';
                    for (final e in c.businessTypes.entries) {
                      if (e.value == val) { key = e.key; break; }
                    }
                    c.selectedBusinessType.value = key;
                    c.update();
                  },
                  validator: (val) => val == null || val.isEmpty ? 'Please select a business type' : null,
                ),
                SizedBox(height: R.h(20)),
                CustomDropdownButton(
                  labelText: 'Business Category',
                  isRequired: true,
                  valueText: c.businessCategories[c.selectedBusinessCategory.value] ?? '',
                  itemList: c.businessCategories.values.toList(),
                  onChange: (val) {
                    String key = '';
                    for (final e in c.businessCategories.entries) {
                      if (e.value == val) { key = e.key; break; }
                    }
                    c.selectedBusinessCategory.value = key;
                    c.update();
                  },
                  validator: (val) => val == null || val.isEmpty ? 'Please select a category' : null,
                ),
                SizedBox(height: R.h(20)),
                CustomTextField(
                  controller: c.businessDescriptionCtr,
                  textHeading: 'Business Description',
                  hintText: 'Describe your business',
                  required: true,
                  inputType: TextInputType.multiline,
                  maxLines: 5,
                  miniLine: 3,
                  validator: Validators.requiredValidator.call,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // --- Step 3: Location ---
  Widget _buildLocationStep(BuildContext context, MerchantSignupController c) {
    return Obx(() {
      return SingleChildScrollView(
        physics: c.isMapInteracting.value
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: R.pad(vertical: R.w(14)),
        child: Form(
          key: c.locationFormKey,
          child: Column(
            children: [
              // Location dropdowns
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomDropdownButton(
                      labelText: 'Parish',
                      isRequired: true,
                      showSearch: true,
                      valueText: c.selectedParish.value?['name'] ?? '',
                      itemList: c.parishes.map((p) => p['name'] as String).toList(),
                      isEmptyText: c.isLoadingParishes.value ? 'Loading...' : null,
                      onChange: (val) {
                        final parish = c.parishes.firstWhereOrNull((p) => p['name'] == val);
                        c.onParishSelected(parish);
                      },
                      validator: (val) => val == null || val.isEmpty ? 'Please select a parish' : null,
                    ),
                    SizedBox(height: R.h(20)),
                    CustomDropdownButton(
                      labelText: 'City',
                      isRequired: true,
                      valueText: c.selectedCity.value?['name'] ?? '',
                      itemList: c.cities.map((city) => city['name'] as String).toList(),
                      isEmptyText: c.isLoadingCities.value ? 'Loading...' : null,
                      onChange: (val) {
                        final city = c.cities.firstWhereOrNull((ct) => ct['name'] == val);
                        c.onCitySelected(city);
                      },
                      validator: (val) => val == null || val.isEmpty ? 'Please select a city' : null,
                    ),
                    SizedBox(height: R.h(20)),
                    CustomDropdownButton(
                      labelText: 'Zone',
                      isRequired: true,
                      valueText: c.selectedZone.value?['name'] ?? '',
                      itemList: c.zones.map((zone) => zone['name'] as String).toList(),
                      isEmptyText: c.isLoadingZones.value ? 'Loading...' : null,
                      onChange: (val) {
                        final zone = c.zones.firstWhereOrNull((z) => z['name'] == val);
                        c.onZoneSelected(zone);
                      },
                      validator: (val) => val == null || val.isEmpty ? 'Please select a zone' : null,
                    ),
                    SizedBox(height: R.h(20)),
                    CustomTextField(
                      controller: c.streetAddressCtr,
                      textHeading: 'Street Address',
                      hintText: '123 main street, Kingston',
                      required: true,
                      inputType: TextInputType.streetAddress,
                      maxLines: 3,
                      miniLine: 2,
                      validator: Validators.requiredValidator.call,
                    ),
                    SizedBox(height: R.h(20)),
                    CustomTextField(
                      controller: c.postalCodeCtr,
                      textHeading: 'Postal Code',
                      hintText: 'Enter postal code',
                      inputType: TextInputType.text,
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.h(14)),
              // Map section
              FocusScope(
                node: FocusScopeNode(),
                child: Container(
                  padding: EdgeInsets.all(R.w(14)),
                  decoration: _sectionDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Location on Map',
                        style: CustomTextStyles.semiBold16.copyWith(
                          color: CustomColors.black(),
                        ),
                      ),
                      SizedBox(height: R.h(12)),
                      SizedBox(
                        height: R.h(260),
                        child: ProfileLocationPicker(
                        addressController: c.addressCtr,
                        selectedLocation: c.selectedLocation,
                        isMapInteracting: c.isMapInteracting,
                        subTitle: 'Please select a location',
                        title: 'Address',
                        mapHeight: R.h(140),
                        hintText: 'Search for a location',
                        onAddressChanged: (address) {
                          c.addressCtr.text = address;
                          c.currentAddress.value = address;
                        },
                        onLocationChanged: (latLng) {
                          c.selectedLocation.value = latLng;
                          c.updateLocationDisplay(latLng);
                        },
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }


  // --- Step 4: Merchant Documents ---
  Widget _buildDocumentsStep(BuildContext context, MerchantSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.documentsFormKey,
        child: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Text(
                  'Upload your documents for verification. Business Registration and ID Proof are required for account approval.',
                  style: CustomTextStyles.regular14.copyWith(
                    color: CustomColors.textGray(),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: R.h(14)),

              // Business Registration
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Business Registration (Required)'),
                    SizedBox(height: R.h(12)),
                    CustomTextField(
                      controller: c.businessRegNumber,
                      textHeading: 'Registration Number',
                      hintText: 'Enter registration number',
                      required: true,
                      validator: Validators.requiredValidator.call,
                    ),
                    SizedBox(height: R.h(14)),
                    FileUploadWidget(
                      selectedFile: c.businessRegFile.value,
                      onFilePicked: (file) => c.businessRegFile.value = file,
                      required: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.h(14)),

              // TRN Document
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('TRN Document'),
                    SizedBox(height: R.h(12)),
                    CustomTextField(
                      controller: c.trnNumber,
                      textHeading: 'TRN Number',
                      hintText: 'Enter TRN number',
                      required: true,
                      validator: Validators.requiredValidator.call,
                    ),
                    SizedBox(height: R.h(14)),
                    FileUploadWidget(
                      selectedFile: c.trnFile.value,
                      onFilePicked: (file) => c.trnFile.value = file,
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.h(14)),

              // ID Proof
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('ID Proof (Required)'),
                    SizedBox(height: R.h(12)),
                    CustomDropdownButton(
                      labelText: 'ID Type',
                      isRequired: true,
                      valueText: c.selectedIdType.value ?? '',
                      itemList: c.idTypes,
                      onChange: (val) {
                        c.selectedIdType.value = val;
                        c.update();
                      },
                    ),
                    SizedBox(height: R.h(14)),
                    CustomTextField(
                      controller: c.idNumber,
                      textHeading: 'ID Number',
                      hintText: 'Enter ID number',
                      required: true,
                      validator: Validators.requiredValidator.call,
                    ),
                    SizedBox(height: R.h(14)),
                    // ID Expiry Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'ID Expiry Date',
                                style: CustomTextStyles.medium14.copyWith(
                                  color: CustomColors.black(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: R.h(10)),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: c.idExpiryDate.value ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2050),
                            );
                            if (date != null) {
                              c.idExpiryDate.value = date;
                              c.update();
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: R.w(20),
                              vertical: R.h(12),
                            ),
                            decoration: BoxDecoration(
                              color: CustomColors.white(),
                              borderRadius: BorderRadius.circular(R.r(8)),
                              border: Border.all(color: CustomColors.whiteStroke()),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.idExpiryDate.value != null
                                        ? DateFormat('dd/MM/yyyy').format(c.idExpiryDate.value!)
                                        : 'Select date',
                                    style: CustomTextStyles.regular16.copyWith(
                                      color: c.idExpiryDate.value != null
                                          ? CustomColors.black()
                                          : CustomColors.gray2(),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: R.sp(18),
                                  color: CustomColors.textGray(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: R.h(14)),
                    FileUploadWidget(
                      title: 'ID Front',
                      selectedFile: c.idFrontFile.value,
                      onFilePicked: (file) => c.idFrontFile.value = file,
                      required: true,
                    ),
                    SizedBox(height: R.h(14)),
                    FileUploadWidget(
                      title: 'ID Back',
                      selectedFile: c.idBackFile.value,
                      onFilePicked: (file) => c.idBackFile.value = file,
                      required: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.h(14)),

              // Address Proof
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Address Proof Document (Optional)'),
                    SizedBox(height: R.h(12)),
                    FileUploadWidget(
                      selectedFile: c.addressProofFile.value,
                      onFilePicked: (file) => c.addressProofFile.value = file,
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.h(14)),

              // Bank Statement
              Container(
                padding: EdgeInsets.all(R.w(14)),
                decoration: _sectionDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Bank Statement Document (Optional)'),
                    SizedBox(height: R.h(12)),
                    FileUploadWidget(
                      selectedFile: c.bankStatementFile.value,
                      onFilePicked: (file) => c.bankStatementFile.value = file,
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.h(14)),

              // Additional Note
              Container(
                padding: EdgeInsets.symmetric(horizontal: R.w(14), vertical: R.h(16)),
                decoration: _sectionDecoration(),
                child: CustomTextField(
                  controller: c.additionalNotesCtr,
                  textHeading: 'Additional Note',
                  hintText: 'Any additional information about your business.',
                  inputType: TextInputType.multiline,
                  maxLines: 4,
                  miniLine: 4,
                ),
              ),
              SizedBox(height: R.h(20)),
            ],
          );
        }),
      ),
    );
  }

  // --- Step 5: Account Security ---
  Widget _buildSecurityStep(BuildContext context, MerchantSignupController c) {
    return SingleChildScrollView(
      padding: R.pad(vertical: R.w(14)),
      child: Form(
        key: c.securityFormKey,
        child: Container(
          padding: EdgeInsets.all(R.w(14)),
          decoration: _sectionDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
  }

  // --- Bottom Bar ---
  Widget _buildBottomBar(BuildContext context, MerchantSignupController c) {
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
          R.w(16),
          R.h(16),
          R.w(16),
          R.h(16) + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          height: R.h(48),
          child: CustomButton(
            text: isLastStep ? 'Continue'.tr : 'Continue'.tr,
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

  // --- Helpers ---
  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
      color: CustomColors.white(),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: CustomTextStyles.semiBold14.copyWith(
        color: CustomColors.black(),
      ),
    );
  }

  void _showPhotoPickerSheet(BuildContext context, MerchantSignupController c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CustomColors.white(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.r(16))),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(R.w(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Photo',
                  style: CustomTextStyles.semiBold16.copyWith(
                    color: CustomColors.black(),
                  ),
                ),
                SizedBox(height: R.h(16)),
                ListTile(
                  leading: Icon(LucideIcons.camera, color: CustomColors.primary()),
                  title: Text('Camera', style: CustomTextStyles.medium14),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImageWithPermission(ImageSource.camera, c);
                  },
                ),
                ListTile(
                  leading: Icon(LucideIcons.image, color: CustomColors.primary()),
                  title: Text('Gallery', style: CustomTextStyles.medium14),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImageWithPermission(ImageSource.gallery, c);
                  },
                ),
                if (c.profilePhoto.value != null)
                  ListTile(
                    leading: Icon(LucideIcons.trash2, color: CustomColors.error()),
                    title: Text('Remove Photo', style: CustomTextStyles.medium14.copyWith(color: CustomColors.error())),
                    onTap: () {
                      Navigator.pop(sheetContext);
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

  Future<void> _pickImageWithPermission(
    ImageSource source,
    MerchantSignupController c,
  ) async {
    // Only camera needs explicit permission; gallery is handled by image_picker internally
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        status = await Permission.camera.request();
      }
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog('Camera');
        return;
      }
      if (!status.isGranted && !status.isLimited) return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null) {
        c.profilePhoto.value = File(picked.path);
      }
    } catch (e) {
      _showPermissionDeniedDialog(
        source == ImageSource.camera ? 'Camera' : 'Photo Library',
      );
    }
  }

  void _showPermissionDeniedDialog(String permName) {
    Get.dialog(
      AlertDialog(
        title: Text(
          '$permName Permission Required',
          style: CustomTextStyles.semiBold16,
        ),
        content: Text(
          'Please allow $permName access in your device settings to use this feature.',
          style: CustomTextStyles.regular14.copyWith(
            color: CustomColors.paragraph(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: CustomTextStyles.medium14.copyWith(
                color: CustomColors.textGray(),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: CustomTextStyles.medium14.copyWith(
                color: CustomColors.primary(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
