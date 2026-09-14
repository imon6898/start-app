import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/location_api_service.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/feature/auth/auth_logic/merchant_api_service.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/widgets/custom_phone_text_field.dart';
import 'package:flutter_starter/app/widgets/custom_snack_bar.dart';

class MerchantSignupController extends GetxController {
  final LocationRepo _locationRepo = LocationRepo();
  final MerchantRepo _merchantRepo = MerchantRepo();

  // Step management
  final currentStep = 0.obs;
  final totalSteps = 5;
  final pageController = PageController();

  // Form keys per step
  final contactFormKey = GlobalKey<FormState>();
  final businessFormKey = GlobalKey<FormState>();
  final locationFormKey = GlobalKey<FormState>();
  final documentsFormKey = GlobalKey<FormState>();
  final securityFormKey = GlobalKey<FormState>();

  // Step 1: Contact Information
  final Rxn<File> profilePhoto = Rxn<File>();
  final firstNameCtr = TextEditingController();
  final lastNameCtr = TextEditingController();
  final contactPersonCtr = TextEditingController();
  final emailCtr = TextEditingController();
  final phoneCtr = TextEditingController();
  final altPhoneCtr = TextEditingController();
  Country? phoneCountry;
  Country? altPhoneCountry;

  void updatePhoneCountry(Country country) {
    phoneCountry = country;
    update();
  }

  void updateAltPhoneCountry(Country country) {
    altPhoneCountry = country;
    update();
  }

  /// Format phone with country dial code: +8801322600847
  String _formatPhone(TextEditingController ctr, Country? country) {
    final phone = ctr.text.trim();
    if (phone.isEmpty) return '';
    final dialCode = country?.dialCode ?? '+1';
    return '$dialCode$phone';
  }

  // Step 2: Business Details
  final businessNameCtr = TextEditingController();
  final businessDescriptionCtr = TextEditingController();
  final selectedBusinessType = Rxn<String>();
  final selectedBusinessCategory = Rxn<String>();
  final businessTypes = {
    'INDIVIDUAL': 'Individual',
    'ECOMMERCE': 'E-Commerce',
    'CORPORATE': 'Corporate',
  };
  final businessCategories = {
    'RETAIL': 'Retail',
    'FOOD_BEVERAGE': 'Food & Beverage',
    'ELECTRONICS': 'Electronics',
    'FASHION': 'Fashion',
    'HEALTH_BEAUTY': 'Health & Beauty',
    'HOME_GARDEN': 'Home & Garden',
    'AUTOMOTIVE': 'Automotive',
    'SERVICES': 'Services',
    'OTHER': 'Other',
  };

  // Step 3: Location
  final selectedParish = Rxn<Map<String, dynamic>>();
  final selectedCity = Rxn<Map<String, dynamic>>();
  final selectedZone = Rxn<Map<String, dynamic>>();
  final streetAddressCtr = TextEditingController();
  final postalCodeCtr = TextEditingController();
  final parishes = <Map<String, dynamic>>[].obs;
  final cities = <Map<String, dynamic>>[].obs;
  final zones = <Map<String, dynamic>>[].obs;
  final isLoadingParishes = false.obs;
  final isLoadingCities = false.obs;
  final isLoadingZones = false.obs;

  // Map location
  final addressCtr = TextEditingController();
  final selectedLocation = LatLng(18.1096, -77.2975).obs; // Jamaica center
  final isMapInteracting = false.obs;
  final currentAddress = ''.obs;

  // Step 4: Documents
  final additionalNotesCtr = TextEditingController();
  final businessRegNumber = TextEditingController();
  final trnNumber = TextEditingController();
  final idNumber = TextEditingController();
  final idExpiryDate = Rxn<DateTime>();
  final selectedIdType = Rxn<String>();
  final idTypes = ["Driver's License", 'National ID', 'Passport'];

  final Rxn<File> businessRegFile = Rxn<File>();
  final Rxn<File> trnFile = Rxn<File>();
  final Rxn<File> idFrontFile = Rxn<File>();
  final Rxn<File> idBackFile = Rxn<File>();
  final Rxn<File> addressProofFile = Rxn<File>();
  final Rxn<File> bankStatementFile = Rxn<File>();

  // Step 6: Account Security
  final passwordCtr = TextEditingController();
  final confirmPasswordCtr = TextEditingController();
  final isAcceptTerms = false.obs;

  // Loading
  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchParishes();
  }

  @override
  void onClose() {
    pageController.dispose();
    firstNameCtr.dispose();
    lastNameCtr.dispose();
    contactPersonCtr.dispose();
    emailCtr.dispose();
    phoneCtr.dispose();
    altPhoneCtr.dispose();
    businessNameCtr.dispose();
    businessDescriptionCtr.dispose();
    streetAddressCtr.dispose();
    postalCodeCtr.dispose();
    addressCtr.dispose();
    additionalNotesCtr.dispose();
    businessRegNumber.dispose();
    trnNumber.dispose();
    idNumber.dispose();
    passwordCtr.dispose();
    confirmPasswordCtr.dispose();
    super.onClose();
  }

  // --- Navigation ---
  void nextStep() {
    if (!_validateCurrentStep()) return;
    if (currentStep.value < totalSteps - 1) {
      currentStep.value++;
      pageController.animateToPage(
        currentStep.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      submitRegistration();
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      pageController.animateToPage(
        currentStep.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (currentStep.value) {
      case 0:
        return contactFormKey.currentState?.validate() ?? true;
      case 1:
        return businessFormKey.currentState?.validate() ?? true;
      case 2:
        return locationFormKey.currentState?.validate() ?? true;
      case 3:
        return _validateDocuments();
      case 4:
        return securityFormKey.currentState?.validate() ?? true;
      default:
        return true;
    }
  }

  bool _validateDocuments() {
    if (businessRegFile.value == null) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please upload Business Registration document',
      );
      return false;
    }
    if (businessRegNumber.text.isEmpty) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please enter Registration Number',
      );
      return false;
    }
    if (idFrontFile.value == null) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please upload ID Front document',
      );
      return false;
    }
    if (idNumber.text.isEmpty) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please enter ID Number',
      );
      return false;
    }
    return true;
  }

  // --- API Calls ---
  Future<void> fetchParishes() async {
    isLoadingParishes.value = true;
    try {
      parishes.value = await _locationRepo.fetchParishes();
    } catch (e) {
      log('Error fetching parishes: $e');
    } finally {
      isLoadingParishes.value = false;
    }
  }

  Future<void> fetchCitiesByParish(String parishId) async {
    isLoadingCities.value = true;
    selectedCity.value = null;
    selectedZone.value = null;
    cities.clear();
    zones.clear();
    try {
      cities.value = await _locationRepo.fetchCitiesByParish(parishId);
    } catch (e) {
      log('Error fetching cities: $e');
    } finally {
      isLoadingCities.value = false;
    }
  }

  Future<void> fetchZonesByCity(String cityId) async {
    isLoadingZones.value = true;
    selectedZone.value = null;
    zones.clear();
    try {
      zones.value = await _locationRepo.fetchZonesByCity(cityId);
    } catch (e) {
      log('Error fetching zones: $e');
    } finally {
      isLoadingZones.value = false;
    }
  }


  void onParishSelected(Map<String, dynamic>? parish) {
    selectedParish.value = parish;
    if (parish != null) {
      fetchCitiesByParish(parish['id']);
    }
    update();
  }

  void onCitySelected(Map<String, dynamic>? city) {
    selectedCity.value = city;
    if (city != null) {
      fetchZonesByCity(city['id']);
    }
    update();
  }

  void onZoneSelected(Map<String, dynamic>? zone) {
    selectedZone.value = zone;
    update();
  }

  void toggleAcceptTerms() {
    isAcceptTerms.value = !isAcceptTerms.value;
    update();
  }

  void updateLocationDisplay(LatLng latLng) {
    selectedLocation.value = latLng;
  }

  String get stepTitle {
    switch (currentStep.value) {
      case 0:
        return 'Contact Information';
      case 1:
        return 'Business Details';
      case 2:
        return 'Location';
      case 3:
        return 'Additional Notes';
      case 4:
        return 'Merchant Documents';
      case 5:
        return 'Account Security';
      default:
        return '';
    }
  }

  Future<void> submitRegistration() async {
    if (!isAcceptTerms.value) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please accept Terms of Service and Privacy Policy',
      );
      return;
    }
    isSubmitting.value = true;
    try {
      // Step 1: Register merchant
      final regBody = {
        'firstName': firstNameCtr.text.trim(),
        'lastName': lastNameCtr.text.trim(),
        'businessName': businessNameCtr.text.trim(),
        'merchantType': selectedBusinessType.value ?? 'INDIVIDUAL',
        if (selectedBusinessCategory.value != null && selectedBusinessCategory.value!.isNotEmpty)
          'businessCategory': selectedBusinessCategory.value,
        if (businessDescriptionCtr.text.isNotEmpty)
          'businessDescription': businessDescriptionCtr.text.trim(),
        'contactPerson': contactPersonCtr.text.trim(),
        'email': emailCtr.text.trim(),
        'phone': _formatPhone(phoneCtr, phoneCountry),
        if (altPhoneCtr.text.isNotEmpty) 'alternativePhone': _formatPhone(altPhoneCtr, altPhoneCountry),
        if (businessRegNumber.text.isNotEmpty)
          'businessRegistrationNumber': businessRegNumber.text.trim(),
        if (trnNumber.text.isNotEmpty)
          'taxIdentificationNumber': trnNumber.text.trim(),
        if (streetAddressCtr.text.isNotEmpty) 'streetAddress': streetAddressCtr.text.trim(),
        if (selectedParish.value != null) 'parishId': selectedParish.value!['id'],
        if (selectedCity.value != null) 'cityId': selectedCity.value!['id'],
        if (selectedZone.value != null) 'zoneId': selectedZone.value!['id'],
        if (postalCodeCtr.text.isNotEmpty) 'postalCode': postalCodeCtr.text.trim(),
        'latitude': selectedLocation.value.latitude,
        'longitude': selectedLocation.value.longitude,
        if (additionalNotesCtr.text.isNotEmpty) 'notes': additionalNotesCtr.text.trim(),
        'password': passwordCtr.text,
      };

      final regData = await _merchantRepo.register(regBody);

      if (regData == null) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Error',
          description: 'Registration failed. Please try again.',
        );
        return;
      }

      // Check response status
      final isSuccess = regData['status'] == true;
      final data = regData['data'];
      final merchantId = data?['id']?.toString() ?? '';

      if (!isSuccess || merchantId.isEmpty) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Failure,
          title: 'Error',
          description: regData['message']?.toString() ?? 'Registration failed',
        );
        return;
      }

      log('Merchant registered: $merchantId');

      // Step 2: Upload documents (batch)
      await _uploadDocuments(merchantId);

      // Save email & password to local storage (for token refresh) and before clearing
      final savedEmail = emailCtr.text;
      final savedPassword = passwordCtr.text;
      await CacheManager.setLoginEmail(savedEmail);
      await CacheManager.setLoginPassword(savedPassword);

      // Show success snackbar
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Success,
        title: 'Success',
        description: 'Account created successfully. Please verify your email.',
      );

      // Clear all fields
      _clearAllFields();

      // Navigate to OTP verification
      // Arguments: [fromPage, email, phone, countryCode, password]
      // Registration API already sends OTP — no need to call resend-otp
      Get.toNamed(
        AppRoutes.VerifyOtpScreen,
        arguments: [
          "fromCreateAccount",
          savedEmail,
          "",           // phone (not used for merchant)
          null,         // countryCode
          savedPassword, // password at index 4 for auto-login
        ],
      );
    } catch (e) {
      log('Error submitting registration: $e');
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Failure,
        title: 'Error',
        description: 'Failed to submit registration. Please try again.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _uploadDocuments(String merchantId) async {
    final Map<String, File> files = {};
    final Map<String, dynamic> fields = {};

    if (profilePhoto.value != null) files['logo'] = profilePhoto.value!;
    if (businessRegFile.value != null) files['businessReg'] = businessRegFile.value!;
    if (businessRegNumber.text.isNotEmpty) fields['registrationNumber'] = businessRegNumber.text.trim();
    if (trnFile.value != null) files['trn'] = trnFile.value!;
    if (trnNumber.text.isNotEmpty) fields['trnNumber'] = trnNumber.text.trim();
    if (idFrontFile.value != null) files['idFront'] = idFrontFile.value!;
    if (idBackFile.value != null) files['idBack'] = idBackFile.value!;
    if (selectedIdType.value != null) {
      final idTypeMap = {
        "Driver's License": 'DRIVERS_LICENSE',
        'National ID': 'NATIONAL_ID',
        'Passport': 'PASSPORT',
      };
      fields['idType'] = idTypeMap[selectedIdType.value] ?? 'DRIVERS_LICENSE';
    }
    if (idNumber.text.isNotEmpty) fields['idNumber'] = idNumber.text.trim();
    if (idExpiryDate.value != null) {
      fields['idExpiryDate'] =
          '${idExpiryDate.value!.year}-${idExpiryDate.value!.month.toString().padLeft(2, '0')}-${idExpiryDate.value!.day.toString().padLeft(2, '0')}';
    }
    if (addressProofFile.value != null) files['addressProof'] = addressProofFile.value!;
    if (bankStatementFile.value != null) files['bankStatement'] = bankStatementFile.value!;

    if (files.isNotEmpty || fields.isNotEmpty) {
      try {
        await _merchantRepo.uploadAllDocuments(merchantId, fields, files);
        log('Documents uploaded successfully');
      } catch (e) {
        log('Error uploading documents: $e');
      }
    }
  }

  void _clearAllFields() {
    // Step 1
    profilePhoto.value = null;
    firstNameCtr.clear();
    lastNameCtr.clear();
    contactPersonCtr.clear();
    emailCtr.clear();
    phoneCtr.clear();
    altPhoneCtr.clear();

    // Step 2
    businessNameCtr.clear();
    businessDescriptionCtr.clear();
    selectedBusinessType.value = null;
    selectedBusinessCategory.value = null;

    // Step 3
    selectedParish.value = null;
    selectedCity.value = null;
    selectedZone.value = null;
    streetAddressCtr.clear();
    postalCodeCtr.clear();
    cities.clear();
    zones.clear();
    addressCtr.clear();
    currentAddress.value = '';

    // Step 4
    additionalNotesCtr.clear();
    businessRegNumber.clear();
    trnNumber.clear();
    idNumber.clear();
    idExpiryDate.value = null;
    selectedIdType.value = null;
    businessRegFile.value = null;
    trnFile.value = null;
    idFrontFile.value = null;
    idBackFile.value = null;
    addressProofFile.value = null;
    bankStatementFile.value = null;

    // Step 6
    passwordCtr.clear();
    confirmPasswordCtr.clear();
    isAcceptTerms.value = false;

    // Reset step
    currentStep.value = 0;
    pageController.jumpToPage(0);
  }
}
