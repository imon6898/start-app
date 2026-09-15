import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/utils/validator.dart';
import 'package:flutter_starter/app/widgets/inputs/custom_text_field.dart';

import 'golden_harness.dart';

void main() {
  goldenMatrixTest(
    'custom_text_field_empty',
    () => SizedBox(
      width: R.w(300),
      child: CustomTextField(
        textHeading: 'Email'.tr,
        hintText: 'you@example.com',
        required: true,
      ),
    ),
  );

  goldenMatrixTest(
    'custom_text_field_filled',
    () => SizedBox(
      width: R.w(300),
      child: CustomTextField(
        textHeading: 'Email'.tr,
        controller: TextEditingController(text: 'imam@example.com'),
      ),
    ),
    matrix: kPhoneOnlyMatrix,
  );

  goldenMatrixTest(
    'custom_text_field_password',
    () => SizedBox(
      width: R.w(300),
      child: CustomTextField(
        textHeading: 'Password'.tr,
        controller: TextEditingController(text: 'hunter2hunter2'),
        isPassword: true,
      ),
    ),
    matrix: kPhoneOnlyMatrix,
  );

  goldenMatrixTest(
    'custom_text_field_disabled',
    () => SizedBox(
      width: R.w(300),
      child: CustomTextField(
        textHeading: 'Email'.tr,
        hintText: 'you@example.com',
        isEnabled: false,
      ),
    ),
    matrix: kPhoneOnlyMatrix,
  );

  // The error state needs a Form that has been validated once.
  testWidgets('custom_text_field_error — phone_light', (tester) async {
    final formKey = GlobalKey<FormState>();

    await pumpGolden(
      tester,
      () => SizedBox(
        width: R.w(300),
        child: Form(
          key: formKey,
          child: CustomTextField(
            textHeading: 'Email'.tr,
            controller: TextEditingController(text: 'not-an-email'),
            validator: Validators.emailValidator.call,
          ),
        ),
      ),
      scenario: const GoldenScenario(name: 'phone_light'),
    );

    formKey.currentState!.validate();
    await tester.pumpAndSettle();

    await expectGolden('custom_text_field_error_phone_light');
  });
}
