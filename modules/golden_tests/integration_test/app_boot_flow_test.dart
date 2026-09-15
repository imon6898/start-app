// End-to-end on a real device/emulator: app boot -> splash -> sign-in.
// Run with:  flutter test integration_test/app_boot_flow_test.dart -d <device>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_starter/app/app.dart';
import 'package:flutter_starter/app/feature/auth/auth_presentation/signin_screen.dart';
import 'package:flutter_starter/app/feature/placeholder/placeholder_screen.dart';
import 'package:flutter_starter/app/feature/splash/splash_presentation/splash_screen.dart';
import 'package:flutter_starter/app/routes/app_routes.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';

import '../test/helpers/test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // bootstrap() calls runApp itself, which the tester cannot drive — so this
  // repeats its steps in the same order and pumps App directly.
  testWidgets('splash routes a returning visitor to sign-in', (tester) async {
    await initTestApp(prefs: const {'hasSeenOnboarding': true});

    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);

    // Splash holds for 2s. On the live binding this is real elapsed time.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SigninScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.SigninScreen);
  });

  testWidgets('a fresh install lands on onboarding instead', (tester) async {
    await initTestApp();

    await tester.pumpWidget(const App());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.OnboardingScreen);
  });

  testWidgets('the sign-in form rejects a bad email', (tester) async {
    await initTestApp(prefs: const {'hasSeenOnboarding': true});

    await tester.pumpWidget(const App());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsWidgets);

    await tester.enterText(fields.first, 'not-an-email');
    await tester.pumpAndSettle();

    // "Login" is also the screen title, so target the button itself.
    // The screen validates before calling signIn(), so no request is made and
    // we must still be on sign-in afterwards.
    await tester.tap(find.widgetWithText(CustomButton, 'Login'.tr));
    await tester.pumpAndSettle();

    expect(find.byType(SigninScreen), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.SigninScreen);
  });
}
