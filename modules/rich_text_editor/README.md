# rich_text_editor

A themed rich-text (WYSIWYG) form field built on `flutter_quill` — heading label, configurable toolbar, bordered editor box.

## Install

```bash
dart run tool/add_module.dart rich_text_editor
```

Manual steps (equivalent):

1. Copy `modules/rich_text_editor/lib/custom_quil_text_field.dart` → `lib/app/widgets/custom_quil_text_field.dart`
2. Add the dependency below to `pubspec.yaml`
3. `flutter pub get`

### pubspec.yaml

```yaml
dependencies:
  flutter_quill: ^11.5.1
```

### Platform config

None. `flutter_quill` needs no permissions, API keys or native setup for the plain editor + toolbar used here.

Optional: if you enable `showLink: true` and want the link dialog to be localized, add `FlutterQuillLocalizations.delegate` to your `MaterialApp.localizationsDelegates`.

## Usage

```dart
// In your controller
final quillController = QuillController.basic();

// In your view
CustomQuilTextField(
  controller: controller.quillController,
  textHeading: 'Question Details',
  required: true,
  placeholder: 'Click here to add details...',
  height: R.h(150),
)

// Read the content back
final delta = controller.quillController.document.toDelta().toJson();
final plainText = controller.quillController.document.toPlainText();
```

Every toolbar button is a flag (`showBoldButton`, `showListBullets`, `showColorButton`, …). Defaults enable bold/italic/underline, bullet + numbered lists, header style and clear-format; everything else is off. Set `showToolbar: false` for a bare editor, `isEnabled: false` for read-only.

## Core dependencies

Uses `CustomColors`, `CustomTextStyles` and `R` from the template core — no extra files to copy.

## Notes

The original file also contained two stub classes, `CustomHtmlTextField` and `CustomHtmlTextFieldSimple`, whose `build()` returned `const SizedBox.shrink()`. **They were deleted, not reimplemented** — they had no callers anywhere in the repo and `CustomQuilTextField` already covers the rich-text-input case. For plain HTML *rendering* use the `html_view` module.

## Why it is not in core

`flutter_quill` is a large dependency most apps never need; only pull it in when a screen actually requires formatted text input.
