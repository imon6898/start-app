import 'package:get/get.dart';

/// Form-field validators shared across the app.
class Validators {
  Validators._();

  static const int _emailMaxLength = 60;
  static const int _nameMaxLength = 60;
  static const int _otpLength = 6;

  // Pragmatic email shape: no spaces, single @, dotted domain.
  static final RegExp _emailRegex = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
  );

  // Letters, spaces, apostrophes, hyphens and dots only.
  static final RegExp _nameRegex = RegExp(r"^[A-Za-z][A-Za-z\s.'-]*$");

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  static String? Function(String?) get requiredValidator => (String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.'.tr;
    }
    return null;
  };

  static String? Function(String?) get nameValidator => (String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.'.tr;
    if (text.length < 2) return 'Must be at least 2 characters.'.tr;
    if (text.length > _nameMaxLength) {
      return 'Must be @n characters or less.'.trParams({
        'n': '$_nameMaxLength',
      });
    }
    if (!_nameRegex.hasMatch(text)) return 'Please enter a valid name.'.tr;
    return null;
  };

  static String? Function(String?) get emailValidator => (String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.'.tr;
    if (text.length > _emailMaxLength) {
      return 'Email must be @n characters or less.'.trParams({
        'n': '$_emailMaxLength',
      });
    }
    if (!_emailRegex.hasMatch(text)) {
      return 'Please enter a valid email address.'.tr;
    }
    return null;
  };

  static String? Function(String?) get registerPasswordValidator =>
      (String? value) {
        final text = value ?? '';
        if (text.isEmpty) return 'Password is required.'.tr;
        if (text.length < 8) {
          return 'Password must be at least 8 characters.'.tr;
        }
        if (!text.contains(RegExp(r'[A-Za-z]'))) {
          return 'Password must contain at least one letter.'.tr;
        }
        if (!text.contains(RegExp(r'\d'))) {
          return 'Password must contain at least one number.'.tr;
        }
        return null;
      };

  /// [original] reads the password field this one must match.
  static String? Function(String?) confirmPasswordValidator(
    String Function() original,
  ) {
    return (String? value) {
      final text = value ?? '';
      if (text.isEmpty) return 'Please confirm your password.'.tr;
      if (text != original()) return 'Passwords do not match.'.tr;
      return null;
    };
  }

  static String? Function(String?) get otpValidator => (String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the verification code.'.tr;
    if (text.length != _otpLength || !_digitsOnly.hasMatch(text)) {
      return 'Enter the @n-digit code.'.trParams({'n': '$_otpLength'});
    }
    return null;
  };

  /// Required phone field, length checked against the selected ISO country.
  static String? Function(String?) phoneValidatorFor({String? countryCode}) {
    return (String? value) {
      final digits = _toDigits(value);
      if (digits.isEmpty) return 'Phone number is required.'.tr;
      return _phoneLengthError(digits, countryCode);
    };
  }

  /// Same as [phoneValidatorFor] but allows an empty value.
  static String? Function(String?) optionalPhoneValidatorFor({
    String? countryCode,
  }) {
    return (String? value) {
      final digits = _toDigits(value);
      if (digits.isEmpty) return null;
      return _phoneLengthError(digits, countryCode);
    };
  }

  static String? Function(String?) get accountNumberValidator =>
      (String? value) {
        final digits = _toDigits(value);
        if (digits.isEmpty) return 'Account number is required.'.tr;
        if (digits.length < 6 || digits.length > 20) {
          return 'Enter a valid account number.'.tr;
        }
        return null;
      };

  static String _toDigits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  // NANP countries use a fixed 10-digit number; others fall back to 7-15.
  static const Set<String> _nanpCountries = {
    'US',
    'CA',
    'JM',
    'BS',
    'BB',
    'TT',
    'DO',
    'PR',
  };

  static String? _phoneLengthError(String digits, String? countryCode) {
    final nanp = countryCode != null && _nanpCountries.contains(countryCode);
    final min = nanp ? 10 : 7;
    final max = nanp ? 10 : 15;
    if (digits.length < min || digits.length > max) {
      return 'Please enter a valid phone number.'.tr;
    }
    return null;
  }
}
