import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/utils/constants/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/responsive_utils.dart';

class CustomQuilTextField extends StatelessWidget {
  final QuillController controller;
  final String? textHeading;
  final String? placeholder;
  final bool required;
  final double? height;
  final double? borderRadius;
  final bool showToolbar;
  final bool isEnabled;
  final Color? borderColor;
  final Color? focusBorderColor;
  final Color? fillColor;
  final EdgeInsetsGeometry? editorPadding;

  // Toolbar options
  final bool showBoldButton;
  final bool showItalicButton;
  final bool showUnderLineButton;
  final bool showListBullets;
  final bool showListNumbers;
  final bool showHeaderStyle;
  final bool showLink;
  final bool showCodeBlock;
  final bool showInlineCode;
  final bool showQuote;
  final bool showIndent;
  final bool showClearFormat;
  final bool showAlignmentButtons;
  final bool showSearchButton;
  final bool showSubscript;
  final bool showSuperscript;
  final bool showStrikeThrough;
  final bool showColorButton;
  final bool showBackgroundColorButton;
  final bool showFontFamily;
  final bool showFontSize;
  final bool multiRowsDisplay;

  const CustomQuilTextField({
    super.key,
    required this.controller,
    this.textHeading,
    this.placeholder = 'Click here to add details...',
    this.required = false,
    this.height,
    this.borderRadius,
    this.showToolbar = true,
    this.isEnabled = true,
    this.borderColor,
    this.focusBorderColor,
    this.fillColor,
    this.editorPadding,
    // Toolbar options with sensible defaults
    this.showBoldButton = true,
    this.showItalicButton = true,
    this.showUnderLineButton = true,
    this.showListBullets = true,
    this.showListNumbers = true,
    this.showHeaderStyle = true,
    this.showLink = false,
    this.showCodeBlock = false,
    this.showInlineCode = false,
    this.showQuote = false,
    this.showIndent = false,
    this.showClearFormat = true,
    this.showAlignmentButtons = false,
    this.showSearchButton = false,
    this.showSubscript = false,
    this.showSuperscript = false,
    this.showStrikeThrough = false,
    this.showColorButton = false,
    this.showBackgroundColorButton = false,
    this.showFontFamily = false,
    this.showFontSize = false,
    this.multiRowsDisplay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textHeading != null) ...[
          Row(
            children: [
              Text(
                textHeading!,
                style: CustomTextStyles.medium14.copyWith(
                  color: CustomColors.black(),
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.error(),
                  ),
                ),
            ],
          ),
          SizedBox(height: R.h(8)),
        ],
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(
              color: borderColor ?? CustomColors.whiteStroke(),
            ),
            borderRadius: BorderRadius.circular(
              borderRadius ?? R.r(8),
            ),
          ),
          child: Column(
            children: [
              if (showToolbar) ...[
                AbsorbPointer(
                  absorbing: !isEnabled,
                  child: Opacity(
                    opacity: isEnabled ? 1.0 : 0.5,
                    child: QuillSimpleToolbar(
                      controller: controller,
                      config: QuillSimpleToolbarConfig(
                        showBoldButton: showBoldButton,
                        showItalicButton: showItalicButton,
                        showUnderLineButton: showUnderLineButton,
                        showListBullets: showListBullets,
                        showListNumbers: showListNumbers,
                        showListCheck: false,
                        showHeaderStyle: showHeaderStyle,
                        showLink: showLink,
                        showCodeBlock: showCodeBlock,
                        showInlineCode: showInlineCode,
                        showQuote: showQuote,
                        showIndent: showIndent,
                        showClearFormat: showClearFormat,
                        showAlignmentButtons: showAlignmentButtons,
                        showSearchButton: showSearchButton,
                        showSubscript: showSubscript,
                        showSuperscript: showSuperscript,
                        showStrikeThrough: showStrikeThrough,
                        showColorButton: showColorButton,
                        showBackgroundColorButton: showBackgroundColorButton,
                        showFontFamily: showFontFamily,
                        showFontSize: showFontSize,
                        multiRowsDisplay: multiRowsDisplay,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: CustomColors.whiteStroke()),
              ],
              Container(
                height: height ?? R.h(150),
                padding: editorPadding ?? EdgeInsets.all(R.w(12)),
                child: AbsorbPointer(
                  absorbing: !isEnabled,
                  child: Opacity(
                    opacity: isEnabled ? 1.0 : 0.7,
                    child: QuillEditor.basic(
                      controller: controller,
                      config: QuillEditorConfig(
                        placeholder: placeholder,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How use Quil
/*
CustomQuilTextField(
            controller: controller.quillController,
            textHeading: 'Question Details',
            required: true,
            placeholder: 'Click here to add details...',
            height: R.h(150),
          ),
*/

class CustomHtmlTextField extends StatelessWidget {
  final dynamic controller;
  const CustomHtmlTextField({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class CustomHtmlTextFieldSimple extends StatelessWidget {
  final dynamic controller;
  const CustomHtmlTextFieldSimple({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}