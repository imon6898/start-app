import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/enums/enums.dart';
import '../services/domain/api_const.dart';
import '../utils/constants/app_colors.dart';

class CustomImage extends StatelessWidget {
  final String image;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final String? placeholder;
  final bool isSvgPlaceholder;
  final bool circular;
  final bool showBorder;
  final double? borderWidth;
  final Color? borderColor;
  final ImageType imageType;
  final bool fullView;
  final Color? color;
  final Color? bgColor;
  final double? borderRadius;
  final BorderRadius? customBorderRadius;
  final GestureTapCallback? onTap;
  final bool isSvg;
  final VoidCallback? onRemove;
  final bool isRemoveable;
  final bool isEndUrl;
  final IconData? placeholderIcon;
  final double? placeholderIconSize;
  final Color? placeholderIconColor;

  const CustomImage({
    super.key,
    required this.image,
    this.height,
    this.width,
    this.onTap,
    this.borderWidth,
    this.borderColor,
    this.borderRadius,
    this.customBorderRadius,
    this.fit = BoxFit.fill,
    this.placeholder,
    this.isSvgPlaceholder = false,
    this.imageType = ImageType.network,
    this.circular = false,
    this.showBorder = false,
    this.fullView = false,
    this.color,
    this.bgColor,
    this.isSvg = false,
    this.onRemove,
    this.isRemoveable = false,
    this.isEndUrl = false,
    this.placeholderIcon,
    this.placeholderIconSize,
    this.placeholderIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: bgColor ?? Colors.transparent,
              borderRadius:
                  customBorderRadius ??
                  BorderRadius.circular(
                    circular ? screenWidth(context) / 2 : borderRadius ?? 0,
                  ),
              border: showBorder
                  ? Border.all(
                      color: borderColor ?? CustomColors.black(),
                      width: borderWidth ?? 1,
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.all(showBorder ? (borderWidth ?? 0) : 0),
              child: ClipRRect(
                borderRadius:
                    customBorderRadius ??
                    BorderRadius.circular(
                      circular ? screenWidth(context) / 2 : borderRadius ?? 0,
                    ),
                child: isSvg ? _buildSvgWidget() : _buildImageWidget(),
              ),
            ),
          ),
          if (isRemoveable && onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: CustomColors.white(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Document/non-image extensions that should not be loaded as images
  static const _nonImageExtensions = {
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.txt', '.csv', '.mp3', '.wav', '.aac', '.m4a', '.ogg',
    '.wma', '.flac', '.amr', '.opus', '.3gp'
  };

  bool _isNonImageFile(String path) {
    final lower = path.toLowerCase();
    for (final ext in _nonImageExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  Widget _buildImageWidget() {
    if (image.isEmpty) return _buildPlaceholder();

    // Skip non-image files (documents, audio, etc.)
    if (_isNonImageFile(image)) {
      return _buildPlaceholder();
    }

    // 🔹 NEW LOGIC: If local file path exists, load from file automatically
    if (File(image).existsSync()) {
      return Image.file(
        File(image),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    switch (imageType) {
      case ImageType.network:
        String imageUrl = image;

        // handle relative or absolute URLs
        if (isEndUrl) {
          if (!(image.startsWith('http') || image.startsWith('https'))) {
            imageUrl = '${ApiConstant.imageUrl}/$image';
          }
        }

        return CachedNetworkImage(
          imageUrl: imageUrl,
          height: height,
          width: width,
          fit: fit,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
          httpHeaders: const {
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          },
        );

      case ImageType.asset:
        return Image.asset(
          image,
          height: height,
          width: width,
          fit: fit,
          color: color,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );

      case ImageType.file:
        return Image.file(
          File(image),
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );

      default:
        return _buildPlaceholder();
    }
  }

  Widget _buildSvgWidget() {
    if (File(image).existsSync()) {
      return SvgPicture.file(
        File(image),
        height: height,
        width: width,
        fit: fit ?? BoxFit.contain,
        colorFilter: color != null
            ? ColorFilter.mode(color!, BlendMode.srcIn)
            : null,
      );
    }

    switch (imageType) {
      case ImageType.network:
        return SvgPicture.network(
          image,
          height: height,
          width: width,
          fit: fit ?? BoxFit.contain,
          placeholderBuilder: (_) => _buildPlaceholder(),
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
        );
      case ImageType.asset:
        return SvgPicture.asset(
          image,
          height: height,
          width: width,
          fit: fit ?? BoxFit.contain,
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
        );
      case ImageType.file:
        return SvgPicture.file(
          File(image),
          height: height,
          width: width,
          fit: fit ?? BoxFit.contain,
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
        );
      default:
        return _buildPlaceholder();
    }
  }

  /// Falls back to [placeholder] if an asset was supplied, otherwise draws an
  /// icon — so the template ships without a bundled placeholder image.
  Widget _buildPlaceholder() {
    if (placeholder != null && placeholder!.isNotEmpty) {
      return isSvgPlaceholder
          ? SvgPicture.asset(
              placeholder!,
              height: height,
              width: width,
              fit: BoxFit.cover,
            )
          : Image.asset(
              placeholder!,
              height: height,
              width: width,
              fit: BoxFit.cover,
            );
    }
    return Container(
      height: height,
      width: width,
      color: bgColor ?? CustomColors.gray(),
      child: Center(
        child: Icon(
          placeholderIcon ?? LucideIcons.imageOff,
          size: placeholderIconSize ?? (height != null ? height! * 0.5 : 40),
          color: placeholderIconColor ?? CustomColors.textGrayDark(),
        ),
      ),
    );
  }

  double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
}
