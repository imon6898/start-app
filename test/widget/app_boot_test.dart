import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/app.dart';
import 'package:flutter_starter/app/bindings/view_model_binding.dart';
import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/feature/placeholder/placeholder_screen.dart';
import 'package:flutter_starter/app/feature/splash/splash_presentation/splash_screen.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';

void main() {
  testWidgets('boots to splash then lands on the first real route', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Env.load();
    await CacheManager.init();
    ViewModelBinding().dependencies();

    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Splash holds for 2s before redirecting.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Fresh install: no token and onboarding unseen.
    expect(find.byType(PlaceholderScreen), findsOneWidget);
  });
}
