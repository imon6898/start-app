import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:calldone/app/core/enums/enums.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calldone/app/utils/constants/app_colors.dart';
import 'package:calldone/app/utils/constants/app_fonts.dart';
import 'package:calldone/app/utils/responsive_utils.dart';
import 'package:calldone/app/widgets/custom_image.dart';

class FileUploadWidget extends StatelessWidget {
  final String? title;
  final String hint;
  final String allowedExtensions;
  final File? selectedFile;
  final String? existingUrl;
  final ValueChanged<File?> onFilePicked;
  final bool required;

  const FileUploadWidget({
    super.key,
    this.title,
    this.hint = 'PDF, JPG, PNG. Max 1 file.',
    this.allowedExtensions = 'pdf,jpg,jpeg,png',
    this.selectedFile,
    this.existingUrl,
    required this.onFilePicked,
    this.required = false,
  });

  Future<void> _pickFile() async {
    final extensions = allowedExtensions.split(',').map((e) => e.trim()).toList();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result != null && result.files.single.path != null) {
      onFilePicked(File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: CustomTextStyles.medium14.copyWith(
                    color: CustomColors.black(),
                  ),
                ),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: CustomTextStyles.medium14.copyWith(
                      color: CustomColors.error(),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: R.h(10)),
        ],
        GestureDetector(
          onTap: _pickFile,
          child: selectedFile != null
              ? _buildFilePreview()
              : (existingUrl != null && existingUrl!.isNotEmpty)
                  ? _buildExistingUrlPreview()
                  : _buildUploadArea(),
        ),
      ],
    );
  }

  Widget _buildUploadArea() {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: Radius.circular(R.r(8)),
      color: CustomColors.whiteStroke(),
      strokeWidth: 1.5,
      dashPattern: const [6, 4],
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: R.h(20)),
        decoration: BoxDecoration(
          color: CustomColors.white(),
          borderRadius: BorderRadius.circular(R.r(8)),
        ),
        child: Column(
          children: [
            Icon(
              LucideIcons.cloudUpload,
              size: R.sp(28),
              color: CustomColors.textGray(),
            ),
            SizedBox(height: R.h(8)),
            Text(
              'Click or drag file to upload',
              style: CustomTextStyles.medium14.copyWith(
                color: CustomColors.textGray(),
              ),
            ),
            SizedBox(height: R.h(4)),
            Padding(
              padding: R.pad(horizontal: 8),
              child: Center(
                child: Text(
                  hint,
                  style: CustomTextStyles.regular12.copyWith(
                    color: CustomColors.gray2(),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingUrlPreview() {
    final url = existingUrl!;
    final fileName = url.split('/').last;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.w(12)),
      decoration: BoxDecoration(
        color: CustomColors.white(),
        borderRadius: BorderRadius.circular(R.r(8)),
        border: Border.all(color: CustomColors.successGreen(), width: 1),
      ),
      child: Row(
        children: [
          CustomImage(
            image: url,
            isEndUrl: true,
            imageType: ImageType.network,
            width: R.w(40),
            height: R.w(40),
            fit: BoxFit.cover,
            borderRadius: R.r(6),
          ),
          SizedBox(width: R.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: CustomTextStyles.medium14.copyWith(color: CustomColors.black()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: R.h(2)),
                Text(
                  'Uploaded • Tap to replace',
                  style: CustomTextStyles.regular10.copyWith(color: CustomColors.successGreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    final fileName = selectedFile!.path.split('/').last;
    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.w(12)),
      decoration: BoxDecoration(
        color: CustomColors.white(),
        borderRadius: BorderRadius.circular(R.r(8)),
        border: Border.all(color: CustomColors.primary(), width: 1),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(R.r(6)),
              child: Image.file(
                selectedFile!,
                width: R.w(40),
                height: R.w(40),
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: R.w(40),
              height: R.w(40),
              decoration: BoxDecoration(
                color: CustomColors.gray(),
                borderRadius: BorderRadius.circular(R.r(6)),
              ),
              child: Icon(
                LucideIcons.fileText,
                size: R.sp(20),
                color: CustomColors.primary(),
              ),
            ),
          SizedBox(width: R.w(12)),
          Expanded(
            child: Text(
              fileName,
              style: CustomTextStyles.medium14.copyWith(
                color: CustomColors.black(),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => onFilePicked(null),
            child: Icon(
              LucideIcons.x,
              size: R.sp(20),
              color: CustomColors.error(),
            ),
          ),
        ],
      ),
    );
  }
}
