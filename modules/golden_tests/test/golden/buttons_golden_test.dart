import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';

import 'golden_harness.dart';

void main() {
  goldenMatrixTest(
    'custom_button_default',
    () => SizedBox(
      width: R.w(240),
      child: CustomButton(text: 'Sign In'.tr, onPressed: () {}),
    ),
  );

  goldenMatrixTest(
    'custom_button_disabled',
    () => SizedBox(
      width: R.w(240),
      child: CustomButton(text: 'Sign In'.tr, onPressed: null),
    ),
    matrix: kPhoneOnlyMatrix,
  );

  // A CircularProgressIndicator never settles, so pump a fixed slice instead.
  goldenMatrixTest(
    'custom_button_loading',
    () => SizedBox(
      width: R.w(240),
      child: CustomButton(text: 'Sign In'.tr, loading: true, onPressed: () {}),
    ),
    matrix: kPhoneOnlyMatrix,
    settle: false,
  );

  goldenMatrixTest(
    'custom_button_secondary',
    () => SizedBox(
      width: R.w(240),
      child: CustomButton(
        text: 'Continue'.tr,
        backgroundColor: CustomColors.secondary(),
        onPressed: () {},
      ),
    ),
    matrix: kPhoneOnlyMatrix,
  );
}
