import 'package:logistics/app/core/enums/enums.dart';
import 'package:logistics/app/utils/responsive_utils.dart';
import 'package:logistics/app/widgets/custom_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/constants/app_assets.dart';
import '../../utils/constants/app_colors.dart';
import 'controllers/splash_controller.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashScreenController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: CustomColors.BGColor(),
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color:
                      CustomColors.white(), // Adding 60% opacity to the blue overlay
                ),
              ),

              // Animated Icon in the Center
              Center(
                child: ScaleTransition(
                  scale: controller.scaleAnimation,
                  child: Container(
                    padding: R.pad(horizontal: R.w(48)),

                    alignment: Alignment.center,
                    child: CustomImage(
                      image: ImageUtils.yaadLogoHori,
                      imageType: ImageType.asset,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
