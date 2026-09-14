import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'bindings/view_model_binding.dart';
import 'localization/app_translations.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'themes/app_theme.dart';
import 'themes/theme_controller.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    // Obx so a themeMode change rebuilds GetMaterialApp itself.
    return Obx(
      () => GetMaterialApp(
        title: 'Flutter Starter',
        debugShowCheckedModeBanner: false,
        initialBinding: ViewModelBinding(),
        initialRoute: AppRoutes.SplashScreen,
        getPages: AppPages.pages,
        unknownRoute: AppPages.unknownRoute,
        translations: AppTranslations(),
        locale: AppTranslations.initialLocale,
        fallbackLocale: AppTranslations.fallbackLocale,
        // GetX handles `.tr`; these localise Material's own widgets
        // (date picker, text-selection menu) for non-English locales.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppTranslations.supported,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeModeRx.value,
      ),
    );
  }
}
