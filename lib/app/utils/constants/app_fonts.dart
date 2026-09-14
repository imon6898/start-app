///How to use
library;

/*
Text(
  'Hello World',
  style: CustomTextStyles.regular14,
  CustomTextStyles.medium18.copyWith(color: CustomColors.black),
);

*/

import "package:flutter/material.dart";

import "../responsive_utils.dart";
import "app_colors.dart";

// Extension for Custom Colors
/// Colour shorthands. Unlike the merchant app's copy these resolve through
/// [CustomColors], so they stay correct in dark mode AND follow the store's
/// brand accent instead of freezing a hex.
extension CustomTextStyleExtensions on TextStyle {
  TextStyle get white => copyWith(color: CustomColors.white());
  TextStyle get gray => copyWith(color: CustomColors.textGray());
  TextStyle get muted => copyWith(color: CustomColors.paragraph());
  TextStyle get primary => copyWith(color: CustomColors.primary());
  TextStyle get onAccent => copyWith(color: CustomColors.onAccent());
  TextStyle get error => copyWith(color: CustomColors.error());
  TextStyle get success => copyWith(color: CustomColors.success());
  TextStyle get warning => copyWith(color: CustomColors.warning());
  TextStyle get light => copyWith(color: CustomColors.textInverse());
  TextStyle get dark => copyWith(color: CustomColors.textPrimary());
}

class CustomTextStyles {
  static const String _fontFamily = 'Inter';

  // 10 px
  static TextStyle get regular10 => TextStyle(
        fontSize: R.sp(10),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium10 => TextStyle(
        fontSize: R.sp(10),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold10 => TextStyle(
        fontSize: R.sp(10),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold10 => TextStyle(
        fontSize: R.sp(10),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

  // 12 px
  static TextStyle get regular12 => TextStyle(
        fontSize: R.sp(12),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium12 => TextStyle(
        fontSize: R.sp(12),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold12 => TextStyle(
        fontSize: R.sp(12),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold12 => TextStyle(
        fontSize: R.sp(12),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

  // 14 px
  static TextStyle get regular14 => TextStyle(
        fontSize: R.sp(14),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium14 => TextStyle(
        fontSize: R.sp(14),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold14 => TextStyle(
        fontSize: R.sp(14),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold14 => TextStyle(
        fontSize: R.sp(14),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

  // 16 px
  static TextStyle get regular16 => TextStyle(
        fontSize: R.sp(16),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium16 => TextStyle(
        fontSize: R.sp(16),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold16 => TextStyle(
        fontSize: R.sp(16),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold16 => TextStyle(
        fontSize: R.sp(16),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

  // 18 px
  static TextStyle get regular18 => TextStyle(
        fontSize: R.sp(18),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium18 => TextStyle(
        fontSize: R.sp(18),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold18 => TextStyle(
        fontSize: R.sp(18),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold18 => TextStyle(
        fontSize: R.sp(18),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

  // 20 px
  static TextStyle get regular20 => TextStyle(
        fontSize: R.sp(20),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium20 => TextStyle(
        fontSize: R.sp(20),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold20 => TextStyle(
        fontSize: R.sp(20),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold20 => TextStyle(
        fontSize: R.sp(20),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

// 22 px
  static TextStyle get regular22 => TextStyle(
        fontSize: R.sp(22),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium22 => TextStyle(
        fontSize: R.sp(22),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold22 => TextStyle(
        fontSize: R.sp(22),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold22 => TextStyle(
        fontSize: R.sp(22),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

// 24 px
  static TextStyle get regular24 => TextStyle(
        fontSize: R.sp(24),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium24 => TextStyle(
        fontSize: R.sp(24),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold24 => TextStyle(
        fontSize: R.sp(24),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold24 => TextStyle(
        fontSize: R.sp(24),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

// 28 px
  static TextStyle get regular28 => TextStyle(
        fontSize: R.sp(28),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium28 => TextStyle(
        fontSize: R.sp(28),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold28 => TextStyle(
        fontSize: R.sp(28),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold28 => TextStyle(
        fontSize: R.sp(28),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

// 30 px
  static TextStyle get regular30 => TextStyle(
        fontSize: R.sp(30),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium30 => TextStyle(
        fontSize: R.sp(30),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold30 => TextStyle(
        fontSize: R.sp(30),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold30 => TextStyle(
        fontSize: R.sp(30),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );

// 36 px
  static TextStyle get regular36 => TextStyle(
        fontSize: R.sp(36),
        fontWeight: FontWeight.w400,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get medium36 => TextStyle(
        fontSize: R.sp(36),
        fontWeight: FontWeight.w500,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get semiBold36 => TextStyle(
        fontSize: R.sp(36),
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
  static TextStyle get bold36 => TextStyle(
        fontSize: R.sp(36),
        fontWeight: FontWeight.w700,
        fontFamily: _fontFamily,
        color: CustomColors.black(),
      );
}
