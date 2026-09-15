// The startup sequence a test needs before pumping App or a real screen: the
// same order as bootstrap(), minus the orientation lock and the IP preload.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/app/bindings/view_model_binding.dart';
import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';

/// [prefs] seeds SharedPreferences — pass `{'hasSeenOnboarding': true}` to make
/// splash route to sign-in instead of onboarding.
Future<void> initTestApp({Map<String, Object> prefs = const {}}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(prefs);

  await Env.load();
  await CacheManager.init();
  ViewModelBinding().dependencies();
}
