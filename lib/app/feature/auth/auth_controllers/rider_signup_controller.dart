import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logistics/app/feature/auth/auth_logic/location_api_service.dart';
import 'package:logistics/app/feature/auth/auth_logic/rider_api_service.dart';
import 'package:logistics/app/routes/app_routes.dart';
import 'package:logistics/app/services/data/cache_manager.dart';
import 'package:logistics/app/widgets/custom_phone_text_field.dart';
import 'package:logistics/app/widgets/custom_snack_bar.dart';

class RiderSignupController extends GetxController {
  final LocationRepo _locationRepo = LocationRepo();
  final RiderRegistrationRepo _riderRepo = RiderRegistrationRepo();
  // Step management
  final currentStep = 0.obs;
  final totalSteps = 5;
  final pageController = PageController();
  final stepLabels = ['Personal Info', 'Documents', 'Vehicle', 'Bank & Preferences', 'Security'];

  // Form keys
  final personalFormKey = GlobalKey<FormState>();
  final documentsFormKey = GlobalKey<FormState>();
  final vehicleFormKey = GlobalKey<FormState>();
  final bankFormKey = GlobalKey<FormState>();
  final securityFormKey = GlobalKey<FormState>();

  // --- Step 1: Personal Information ---
  final Rxn<File> profilePhoto = Rxn<File>();
  final firstNameCtr = TextEditingController();
  final lastNameCtr = TextEditingController();
  final emailCtr = TextEditingController();
  final phoneCtr = TextEditingController();
  final altPhoneCtr = TextEditingController();
  Country? phoneCountry;
  Country? altPhoneCountry;
  final dobDate = Rxn<DateTime>();
  final selectedGender = Rxn<String>();
  final genders = ['Male', 'Female', 'Other'];

  // Address
  final currentAddressCtr = TextEditingController();
  final selectedParish = Rxn<Map<String, dynamic>>();
  final selectedCity = Rxn<Map<String, dynamic>>();
  final selectedZone = Rxn<Map<String, dynamic>>();
  final postalCodeCtr = TextEditingController();
  final landmarkCtr = TextEditingController();
  final permanentAddressCtr = TextEditingController();

  // Emergency Contact
  final emergencyNameCtr = TextEditingController();
  final emergencyPhoneCtr = TextEditingController();
  Country? emergencyPhoneCountry;
  final emergencyRelationCtr = TextEditingController();

  // Location data
  final parishes = <Map<String, dynamic>>[].obs;
  final cities = <Map<String, dynamic>>[].obs;
  final zones = <Map<String, dynamic>>[].obs;
  final isLoadingParishes = false.obs;
  final isLoadingCities = false.obs;
  final isLoadingZones = false.obs;

  // --- Step 2: Documents ---
  final trnNumberCtr = TextEditingController();
  final nisNumberCtr = TextEditingController();
  final Rxn<File> trnCardFile = Rxn<File>();
  final Rxn<File> nisCardFile = Rxn<File>();
  final Rxn<File> proofOfAddressFile = Rxn<File>();

  // --- Step 3: Vehicle ---
  final selectedVehicleType = Rxn<String>();
  final vehicleTypes = ['BIKE', 'SCOOTER', 'CAR', 'VAN', 'TRUCK', 'MINI TRUCK', 'BICYCLE'];
  bool get isBicycle => selectedVehicleType.value == 'BICYCLE';
  final vehicleNumberCtr = TextEditingController();
  final vehicleModelCtr = TextEditingController();
  final vehicleCapacityCtr = TextEditingController();
  final licenseNumberCtr = TextEditingController();
  final licenseExpiryDate = Rxn<DateTime>();
  final Rxn<File> licenseFrontFile = Rxn<File>();

  // --- Step 4: Bank & Preferences ---
  final accountHolderCtr = TextEditingController();
  final selectedBank = Rxn<String>();
  final banks = [
    'National Commercial Bank (NCB)',
    'Scotiabank Jamaica',
    'CIBC FirstCaribbean',
    'Sagicor Bank',
    'JMMB Bank',
    'JN Bank',
    'Victoria Mutual',
    'Other',
  ];
  final accountNumberCtr = TextEditingController();
  final branchCodeCtr = TextEditingController();


  // --- Step 5: Account Security ---
  final passwordCtr = TextEditingController();
  final confirmPasswordCtr = TextEditingController();
  final isAcceptTerms = false.obs;

  void toggleAcceptTerms() {
    isAcceptTerms.value = !isAcceptTerms.value;
  }

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
    emailCtr.dispose();
    phoneCtr.dispose();
    altPhoneCtr.dispose();
    currentAddressCtr.dispose();
    postalCodeCtr.dispose();
    landmarkCtr.dispose();
    permanentAddressCtr.dispose();
    emergencyNameCtr.dispose();
    emergencyPhoneCtr.dispose();
    emergencyRelationCtr.dispose();
    trnNumberCtr.dispose();
    nisNumberCtr.dispose();
    vehicleNumberCtr.dispose();
    vehicleModelCtr.dispose();
    vehicleCapacityCtr.dispose();
    licenseNumberCtr.dispose();
    accountHolderCtr.dispose();
    accountNumberCtr.dispose();
    branchCodeCtr.dispose();
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
    log('Validating step ${currentStep.value}');
    bool result;
    bool specificMessageShown = false;

    switch (currentStep.value) {
      case 0:
        result = personalFormKey.currentState?.validate() ?? true;
        break;
      case 1:
        result = _validateDocuments();
        specificMessageShown = !result;
        break;
      case 2:
        result = vehicleFormKey.currentState?.validate() ?? true;
        if (result && selectedVehicleType.value == null) {
          showCustomSnackBar(
            context: Get.context!,
            type: SnackBarType.Warning,
            title: 'Required',
            description: 'Please select a vehicle type.',
          );
          result = false;
          specificMessageShown = true;
        }
        break;
      case 3:
        result = bankFormKey.currentState?.validate() ?? true;
        break;
      case 4:
        result = securityFormKey.currentState?.validate() ?? true;
        if (result && !isAcceptTerms.value) {
          showCustomSnackBar(
            context: Get.context!,
            type: SnackBarType.Warning,
            title: 'Terms Required',
            description: 'Please accept the Terms of Service to continue.',
          );
          result = false;
          specificMessageShown = true;
        }
        break;
      default:
        result = true;
    }

    if (!result) {
      log('Validation failed on step ${currentStep.value}');
      if (!specificMessageShown) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Warning,
          title: 'Validation',
          description: 'Please fill all required fields correctly.',
        );
      }
    }
    return result;
  }

  bool _validateDocuments() {
    if (!(documentsFormKey.currentState?.validate() ?? true)) return false;
    if (trnCardFile.value == null) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please upload TRN Card',
      );
      return false;
    }
    if (nisCardFile.value == null) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please upload NIS Card',
      );
      return false;
    }
    if (proofOfAddressFile.value == null) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'Required',
        description: 'Please upload Proof of Address',
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
    if (parish != null) fetchCitiesByParish(parish['id']);
    update();
  }

  void onCitySelected(Map<String, dynamic>? city) {
    selectedCity.value = city;
    if (city != null) fetchZonesByCity(city['id']);
    update();
  }

  void onZoneSelected(Map<String, dynamic>? zone) {
    selectedZone.value = zone;
    update();
  }

  void updatePhoneCountry(Country country) { phoneCountry = country; update(); }
  void updateAltPhoneCountry(Country country) { altPhoneCountry = country; update(); }
  void updateEmergencyPhoneCountry(Country country) { emergencyPhoneCountry = country; update(); }

  /// Format phone with country dial code: +8801322600847
  String formatPhone(TextEditingController ctr, Country? country) {
    final phone = ctr.text.trim();
    if (phone.isEmpty) return '';
    final dialCode = country?.dialCode ?? '+1';
    return '$dialCode$phone';
  }

  String get stepTitle => stepLabels[currentStep.value];

  Future<void> submitRegistration() async {
    isSubmitting.value = true;
    try {
      // === STEP 1: Personal Info ===
      final step1Fields = <String, dynamic>{
        'firstName': firstNameCtr.text.trim(),
        'lastName': lastNameCtr.text.trim(),
        'email': emailCtr.text.trim(),
        'phone': formatPhone(phoneCtr, phoneCountry),
        'password': passwordCtr.text,
        if (altPhoneCtr.text.isNotEmpty) 'alternatePhone': formatPhone(altPhoneCtr, altPhoneCountry),
        if (dobDate.value != null) 'dob': '${dobDate.value!.year}-${dobDate.value!.month.toString().padLeft(2, '0')}-${dobDate.value!.day.toString().padLeft(2, '0')}',
        if (selectedGender.value != null) 'gender': selectedGender.value!.toUpperCase(),
        if (currentAddressCtr.text.isNotEmpty) 'currentAddress': currentAddressCtr.text.trim(),
        if (selectedParish.value != null) 'parish': selectedParish.value!['id'],
        if (selectedCity.value != null) 'city': selectedCity.value!['id'],
        if (selectedZone.value != null) 'zone': selectedZone.value!['id'],
        if (postalCodeCtr.text.isNotEmpty) 'postalCode': postalCodeCtr.text.trim(),
        if (landmarkCtr.text.isNotEmpty) 'landMark': landmarkCtr.text.trim(),
        if (permanentAddressCtr.text.isNotEmpty) 'permanentAddress': permanentAddressCtr.text.trim(),
        if (emergencyNameCtr.text.isNotEmpty) 'emergencyContactName': emergencyNameCtr.text.trim(),
        if (emergencyPhoneCtr.text.isNotEmpty) 'emergencyContactPhone': formatPhone(emergencyPhoneCtr, emergencyPhoneCountry),
        if (emergencyRelationCtr.text.isNotEmpty) 'emergencyContactRelationship': emergencyRelationCtr.text.trim(),
      };

      final step1Result = await _riderRepo.submitStep1(step1Fields, profilePhoto: profilePhoto.value);
      if (step1Result == null) {
        _showError('Failed to create rider account. Please try again.');
        return;
      }

      final riderId = step1Result['id']?.toString() ?? '';
      if (riderId.isEmpty) {
        _showError(step1Result['message']?.toString() ?? 'Registration failed');
        return;
      }
      log('Rider created: $riderId');

      // Save email/password for auto-login after OTP
      final savedEmail = emailCtr.text;
      final savedPassword = passwordCtr.text;
      await CacheManager.setLoginEmail(savedEmail);
      await CacheManager.setLoginPassword(savedPassword);

      // === STEP 2: Documents ===
      final step2Fields = <String, dynamic>{
        if (trnNumberCtr.text.isNotEmpty) 'trnNumber': trnNumberCtr.text.trim(),
        if (nisNumberCtr.text.isNotEmpty) 'nisNumber': nisNumberCtr.text.trim(),
      };
      await _riderRepo.submitStep2(
        riderId, step2Fields,
        trnCard: trnCardFile.value,
        nisCard: nisCardFile.value,
        proofOfAddress: proofOfAddressFile.value,
      );
      log('Step 2 completed');

      // === STEP 3: Vehicle & License ===
      final step3Fields = <String, dynamic>{
        if (selectedVehicleType.value != null) 'vehicleType': selectedVehicleType.value,
        if (vehicleNumberCtr.text.isNotEmpty) 'vehicleNumber': vehicleNumberCtr.text.trim(),
        if (vehicleModelCtr.text.isNotEmpty) 'vehicleModel': vehicleModelCtr.text.trim(),
        if (vehicleCapacityCtr.text.isNotEmpty) 'capacity': int.tryParse(vehicleCapacityCtr.text.trim()) ?? 0,
        if (licenseNumberCtr.text.isNotEmpty) 'dlNumber': licenseNumberCtr.text.trim(),
        if (licenseExpiryDate.value != null) 'dlExpiryDate': '${licenseExpiryDate.value!.year}-${licenseExpiryDate.value!.month.toString().padLeft(2, '0')}-${licenseExpiryDate.value!.day.toString().padLeft(2, '0')}',
      };
      await _riderRepo.submitStep3(
        riderId, step3Fields,
        dlFront: licenseFrontFile.value,
      );
      log('Step 3 completed');

      // === STEP 4: Bank & Preferences ===
      final step4Body = <String, dynamic>{
        if (accountHolderCtr.text.isNotEmpty) 'bankAccountHolderName': accountHolderCtr.text.trim(),
        if (accountNumberCtr.text.isNotEmpty) 'bankAccountNumber': accountNumberCtr.text.trim(),
        if (branchCodeCtr.text.isNotEmpty) 'bankBranchCode': branchCodeCtr.text.trim(),
        if (selectedBank.value != null) 'bankName': selectedBank.value,
        if (selectedZone.value != null) 'preferredZoneId': selectedZone.value!['id'],
        'isFinalSubmission': true,
      };
      await _riderRepo.submitStep4(riderId, step4Body);
      log('Step 4 completed — registration finalized');

      // Success
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Success,
        title: 'Success',
        description: 'Registration submitted! Please verify your email.',
      );

      // Navigate to OTP verification
      Get.toNamed(
        AppRoutes.VerifyOtpScreen,
        arguments: [
          "fromCreateAccount",
          savedEmail,
          "",
          null,
          savedPassword,
        ],
      );
    } catch (e) {
      log('Error submitting registration: $e');
      _showError('Failed to submit registration. Please try again.');
    } finally {
      isSubmitting.value = false;
    }
  }

  void _showError(String message) {
    showCustomSnackBar(
      context: Get.context!,
      type: SnackBarType.Failure,
      title: 'Error',
      description: message,
    );
  }
}
