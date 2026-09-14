import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../utils/responsive_utils.dart';

class CustomTextField extends StatefulWidget {
  final String? hintText;
  final String? textHeading;
  final String? labelText;
  final String? prefixImage;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final TextInputType inputType;
  final TextInputAction inputAction;
  final bool isPassword;
  final bool prefixIconVisible;
  final bool isAmount;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String text)? onChanged;
  final bool isEnabled;
  final int? maxLines;
  final int? miniLine;
  final TextCapitalization capitalization;
  final double? borderRadius;
  final String? prefixIcon;
  final String? suffixIcon;
  final Color? suffixIconColor;
  final bool showBorder;
  final bool isPriceFiled;
  final String? countryDialCode;
  final double prefixHeight;
  final double? verticalPadding;
  final double regularBorderSize;
  final Color? fillColor;
  final bool filled;
  final Color? focusBorderColor;
  final Color? disableBorderColor;
  final Color? enabledBorderColor;
  final bool showCodePicker;
  final bool suffix;
  final TextStyle? hintStyle;
  final Function()? onPressedSuffix;
  final bool required;

  final Function()? onTap;
  final Function(String text)? onSubmit;
  final FormFieldValidator<String>? validator;

  const CustomTextField({
    super.key,
    this.hintText = 'Write something...',
    this.controller,
    this.focusNode,
    this.prefixImage,
    this.nextFocus,
    this.verticalPadding,
    this.validator,
    this.isEnabled = true,
    this.isPriceFiled = false,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.next,
    this.maxLines,
    this.miniLine,
    this.onChanged,
    this.hintStyle,
    this.prefixIcon,
    this.capitalization = TextCapitalization.none,
    this.isPassword = false,
    this.prefixIconVisible = false,
    this.isAmount = false,
    this.inputFormatters,
    this.borderRadius,
    this.showBorder = true,
    this.prefixHeight = 44,
    this.countryDialCode,
    this.fillColor,
    this.filled = false,
    this.focusBorderColor,
    this.suffix = true,
    this.suffixIcon,
    this.suffixIconColor,
    this.onPressedSuffix,
    this.required = false,
    this.textHeading,
    this.labelText,
    this.showCodePicker = false,

    this.onTap,
    this.regularBorderSize = 1.0,
    this.disableBorderColor,
    this.enabledBorderColor,
    this.onSubmit,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFormFiledState();
}

/// Maximum allowed length for email input fields across the app.
/// Enforced via [LengthLimitingTextInputFormatter] in [CustomTextField] and
/// double-checked in `Validators.emailValidator`.
const int _kEmailMaxLength = 60;

/// Maximum allowed length for name input fields (first name, last name,
/// full name, contact name, etc.) across the app. Enforced via
/// [LengthLimitingTextInputFormatter] in [CustomTextField] and
/// double-checked in `Validators.nameValidator` / `fullNameValidator`.
const int _kNameMaxLength = 60;

class _CustomTextFormFiledState extends State<CustomTextField> {
  bool _obscureText = true;

  /// Hints handed to the platform autofill service, derived from [inputType]
  /// (plus [isPassword], which is set more consistently than the keyboard type
  /// on password fields).
  ///
  /// These hints only produce a suggestion when the fields are wrapped in an
  /// [AutofillGroup] — that is what tells the OS the fields belong to one form.
  /// See `signin_screen.dart` for the reference setup.
  List<String>? get _autofillHints {
    final type = widget.inputType;

    if (widget.isPassword || type == TextInputType.visiblePassword) {
      return const [AutofillHints.password];
    }
    // `username` is the hint password managers pair with `password`; `email`
    // on its own is read as a contact field and never matches a credential.
    if (type == TextInputType.emailAddress) {
      return const [AutofillHints.username, AutofillHints.email];
    }
    if (type == TextInputType.name) return const [AutofillHints.name];
    if (type == TextInputType.phone) {
      return const [AutofillHints.telephoneNumber];
    }
    if (type == TextInputType.streetAddress) {
      return const [AutofillHints.fullStreetAddress];
    }
    if (type == TextInputType.url) return const [AutofillHints.url];
    return null;
  }

  @override
  Widget build(BuildContext context) {

    /*      final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final focusColor = isDark ? AppColors.yellow : AppColors.black;*/

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.textHeading != null) ...[
          Row(
              children: [
                Text(
                  widget.textHeading!,
                  style: CustomTextStyles.medium14.copyWith(color: CustomColors.black()),
                ),
                if (widget.required && widget.textHeading != null)
                  Text(
                    ' *',
                    style: CustomTextStyles.medium14.copyWith(color: CustomColors.error()),
                  ),
              ]),

          SizedBox(height: R.h(5)),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (widget.maxLines ?? 1) > 1 ? 0 : R.h(42), // Match CustomDropdownButton height for single line
          ),
          child: TextFormField(
          textAlignVertical: TextAlignVertical.center,
          textAlign: TextAlign.start,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: widget.validator,

          maxLines: widget.maxLines ?? 1,
          minLines: widget.miniLine ?? 1,
          controller: widget.controller,
          focusNode: widget.focusNode,

          style: CustomTextStyles.regular14,
          textInputAction:  (widget.maxLines != null && widget.maxLines! > 1)
              ? TextInputAction.newline
              : widget.inputAction,
          keyboardType:
          (widget.maxLines != null && widget.maxLines! > 1)
              ? TextInputType.multiline
              : (widget.isAmount || widget.inputType == TextInputType.phone)
              ? const TextInputType.numberWithOptions(
            signed: false,
            decimal: true,
          )
              : widget.inputType,
          textCapitalization: widget.capitalization,
          enabled: widget.isEnabled,
          autofocus: false,
          autofillHints: _autofillHints,
          obscureText: widget.isPassword ? _obscureText : false,
          inputFormatters: widget.inputType == TextInputType.phone
              ? <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
          ]
              : widget.isAmount
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : widget.inputType == TextInputType.emailAddress
              ? <TextInputFormatter>[
                  // Hard 60-char cap on every email field in the app. Paste
                  // operations are also clipped. Validator double-checks.
                  LengthLimitingTextInputFormatter(_kEmailMaxLength),
                  ...?widget.inputFormatters,
                ]
              : widget.inputType == TextInputType.name
              ? <TextInputFormatter>[
                  // Hard 60-char cap on every name field (first / last /
                  // full / contact name). Validator double-checks.
                  LengthLimitingTextInputFormatter(_kNameMaxLength),
                  ...?widget.inputFormatters,
                ]
              : widget.inputFormatters,
          decoration: InputDecoration(
            errorMaxLines: 2,
            isDense: false,
            enabledBorder: widget.showBorder ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? R.r(8),
              ),
              borderSide: BorderSide(
                width: 1,
                color: widget.enabledBorderColor ?? CustomColors.whiteStroke(),
              ),
            ) : InputBorder.none,
            prefixIconConstraints: BoxConstraints(
              minWidth: 0,
              minHeight: 0,
              maxWidth: R.w(42),
              maxHeight: R.h(42),
            ),

            focusedBorder: widget.showBorder ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? R.r(8),
              ),
              borderSide: BorderSide(
                width: 1,
                color: widget.focusBorderColor ?? CustomColors.whiteStroke(),
              ),
            ) : InputBorder.none,
            focusedErrorBorder: widget.showBorder ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? R.r(8),
              ),
              borderSide: BorderSide(width: 1.5, color: Colors.red),
            ) : InputBorder.none,
            disabledBorder: widget.showBorder ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? R.r(8),
              ),
              borderSide: BorderSide(
                width: 1,
                color: widget.disableBorderColor ?? CustomColors.gray(),
              ),
            ) : InputBorder.none,
            errorBorder: widget.showBorder ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? R.r(8),
              ),
              borderSide: BorderSide(width: 1.5, color: Colors.red),
            ) : InputBorder.none,
            errorStyle: TextStyle(color: CustomColors.error()),
            hintText: widget.hintText,
            fillColor: widget.fillColor,
            hintMaxLines: widget.miniLine,
            hintStyle:
            widget.hintStyle ??  CustomTextStyles.regular14.copyWith(color: CustomColors.gray2()),

            filled: widget.filled,
            contentPadding: EdgeInsets.symmetric(
              horizontal: R.w(14),
              vertical: widget.verticalPadding ?? R.h(8),
            ),
            labelStyle: widget.labelText != null
                ? TextTheme.of(
              context,
            ).bodyMedium?.copyWith(color: CustomColors.gray())
                : null,
            helperMaxLines: 1,
            alignLabelWithHint: true,

            prefixIcon: widget.isPriceFiled
                ? Container(
              margin: EdgeInsets.only(left: R.w(0)),
              width: R.w(40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(widget.borderRadius ?? R.r(8)),
                ),
                color: CustomColors.gray(),
              ),
              child: Center(
                child: Text(
                  "J\$ ",
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            )
                : widget.prefixIconVisible
                ? (widget.maxLines ?? 1) > 1
                ? null
                : Padding(
              padding: EdgeInsets.symmetric(horizontal: R.w(10)),
              child: SizedBox(
                child: SvgPicture.asset(
                  '${widget.prefixIcon}',
                  height: R.h(widget.prefixHeight),
                  color: CustomColors.gray(),
                ),
              ),
            )
                : null,

            label: widget.labelText != null
                ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.labelText ?? '',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(
                      fontSize: 14,
                      color: CustomColors.gray(),
                    ),
                  ),

                  if (widget.required || widget.labelText != null)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            )
                : null,
            suffixIcon: widget.suffixIcon != null
                ? GestureDetector(
              onTap: widget.onPressedSuffix,
              child: Container(
                width: R.w(40),
                padding: const EdgeInsets.all(1),
                /*decoration: BoxDecoration(
                      color: widget.fillColor != null
                          ? Colors.transparent
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.only(
                          topRight:
                          Radius.circular(widget.borderRadius ?? 10),
                          bottomRight:
                          Radius.circular(widget.borderRadius ?? 10)))*/
                child: Center(
                  child: SvgPicture.asset(
                    '${widget.suffixIcon}',
                    colorFilter: ColorFilter.mode(
                      widget.suffixIconColor ??
                          CustomColors.gray(),
                      BlendMode.srcIn,
                    ),
                    height: R.h(widget.prefixHeight),
                  ),
                ),
              ),
            )
                : widget.isPassword
                ? IconButton(
              icon: Icon(
                _obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                 size: R.h(18),
                color: CustomColors.textGray(),
              ),
              onPressed: _toggle,
            )
                : null,
          ),

          onFieldSubmitted: (text) => widget.onSubmit == null
              ? widget.nextFocus != null
              ? FocusScope.of(context).requestFocus(widget.nextFocus)
              : null
              : widget.onSubmit!(text),
          onChanged: widget.onChanged,
          onTap: widget.onTap,
        ),
        ),
      ],
    );
  }

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
}
