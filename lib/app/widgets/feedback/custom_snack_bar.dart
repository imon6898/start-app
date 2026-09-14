// ignore_for_file: constant_identifier_names
// SnackBarType values are pinned — opt-in modules call SnackBarType.Failure.

import 'package:flutter/material.dart';

import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CustomSnackBar extends StatelessWidget {
  final String title;
  final String description;
  final SnackBarType type;

  const CustomSnackBar({
    super.key,
    required this.title,
    required this.description,
    required this.type,
  });

  Color _getBackgroundColor() {
    switch (type) {
      case SnackBarType.Success:
        return CustomColors.successSnackBar();
      case SnackBarType.Warning:
        return CustomColors.warningSnackBar();
      case SnackBarType.Failure:
        return CustomColors.failureSnackBar();
      case SnackBarType.Light:
        return CustomColors.lightSnackBar();
    }
  }

  Icon _getIcon() {
    switch (type) {
      case SnackBarType.Success:
        return Icon(LucideIcons.circleCheck, color: Colors.green);
      case SnackBarType.Warning:
        return Icon(LucideIcons.triangleAlert, color: Colors.orange);
      case SnackBarType.Failure:
        return Icon(LucideIcons.x, color: Colors.red);
      case SnackBarType.Light:
        return Icon(LucideIcons.building2, color: CustomColors.black());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CustomColors.whiteStroke(),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CustomColors.white(),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: _getIcon(),
              ),
              const SizedBox(width: 12),
              // Title and Description with Scrollable Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CustomColors.black(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: 100, // Set max height for scrolling
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: CustomColors.black(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Close Button
        Positioned(
          top: 10,
          right: 12,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: CustomColors.black(), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Icon(
                  LucideIcons.x,
                  color: CustomColors.black(),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum SnackBarType { Success, Warning, Failure, Light }

void showCustomSnackBar({
  required BuildContext context,
  required SnackBarType type,
  required String title,
  required String description,
}) {
  // Check if the context is still valid before showing snackbar
  if (!context.mounted) {
    debugPrint('⚠️ SnackBar skipped: context is no longer mounted');
    return;
  }

  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: MediaQuery.of(context).size.width,
        behavior: SnackBarBehavior.floating,
        content: CustomSnackBar(
          title: title,
          description: description,
          type: type,
        ),
      ),
    );
  } catch (e) {
    debugPrint('⚠️ SnackBar error: $e');
  }
}
