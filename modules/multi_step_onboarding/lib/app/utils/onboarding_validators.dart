import 'package:get/get.dart';

/// Jamaica-specific validators used by the rider flow. Replace for your country.
class OnboardingValidators {
  /// Jamaican TRN: exactly 9 digits.
  static String? Function(String?) get trnValidator => (String? value) {
    final digits = _toDigits(value);
    if (digits.isEmpty) return 'TRN is required.'.tr;
    if (digits.length != 9) return 'TRN must be 9 digits.'.tr;
    return null;
  };

  /// Jamaican NIS: exactly 9 digits.
  static String? Function(String?) get nisValidator => (String? value) {
    final digits = _toDigits(value);
    if (digits.isEmpty) return 'NIS number is required.'.tr;
    if (digits.length != 9) return 'NIS number must be 9 digits.'.tr;
    return null;
  };

  static String _toDigits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');
}
