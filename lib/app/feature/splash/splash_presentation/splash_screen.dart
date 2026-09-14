import 'package:flutter_starter/app/core/enums/enums.dart';
import 'package:flutter_starter/app/utils/responsive_utils.dart';
import 'package:flutter_starter/app/widgets/media/custom_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/utils/constants/app_assets.dart';
import 'package:flutter_starter/app/utils/constants/app_colors.dart';
import 'package:flutter_starter/app/feature/splash/splash_controllers/splash_controller.dart';

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
                    padding: R.pad(horizontal: 48),

                    alignment: Alignment.center,
                    child: CustomImage(
                      image: ImageUtils.appLogo,
                      imageType: ImageType.asset,
                      isSvg: true,
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
