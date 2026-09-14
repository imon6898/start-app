import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// House pattern for a unit test: call the helper directly, no widgets, no Get.
void main() {
  group('emailValidator', () {
    final validate = Validators.emailValidator;

    test('accepts a normal address', () {
      expect(validate('user@example.com'), isNull);
    });

    test('rejects empty', () {
      expect(validate(''), isNotNull);
      expect(validate(null), isNotNull);
    });

    test('rejects a missing dotted domain', () {
      expect(validate('user@example'), isNotNull);
    });

    test('rejects an address over 60 characters', () {
      expect(validate('${'a' * 60}@example.com'), isNotNull);
    });
  });

  group('registerPasswordValidator', () {
    final validate = Validators.registerPasswordValidator;

    test('accepts 8+ chars with a letter and a digit', () {
      expect(validate('passw0rd'), isNull);
    });

    test('rejects under 8 characters', () {
      expect(validate('pass1'), isNotNull);
    });

    test('rejects letters only', () {
      expect(validate('password'), isNotNull);
    });

    test('rejects digits only', () {
      expect(validate('12345678'), isNotNull);
    });
  });

  group('confirmPasswordValidator', () {
    test('accepts a match', () {
      final validate = Validators.confirmPasswordValidator(() => 'passw0rd');
      expect(validate('passw0rd'), isNull);
    });

    test('rejects a mismatch', () {
      final validate = Validators.confirmPasswordValidator(() => 'passw0rd');
      expect(validate('passw0rD'), isNotNull);
    });
  });

  group('otpValidator', () {
    final validate = Validators.otpValidator;

    test('accepts exactly 6 digits', () {
      expect(validate('123456'), isNull);
    });

    test('rejects the wrong length', () {
      expect(validate('12345'), isNotNull);
    });

    test('rejects non-digits', () {
      expect(validate('12345a'), isNotNull);
    });
  });

  group('phoneValidatorFor', () {
    test('NANP countries require exactly 10 digits', () {
      final validate = Validators.phoneValidatorFor(countryCode: 'US');
      expect(validate('(555) 010-1234'), isNull);
      expect(validate('5550101'), isNotNull);
    });

    test('other countries allow 7-15 digits', () {
      final validate = Validators.phoneValidatorFor(countryCode: 'BD');
      expect(validate('01712345678'), isNull);
      expect(validate('123456'), isNotNull);
    });

    test('optional variant accepts empty', () {
      final validate = Validators.optionalPhoneValidatorFor(countryCode: 'US');
      expect(validate(''), isNull);
      expect(validate('555010'), isNotNull);
    });
  });
}
