import 'package:flutter_starter/app/core/config/env.dart';

/// Module-owned endpoint, so installing this needs no edit to ApiConstant.
class FeatureFlagsApiConst {
  FeatureFlagsApiConst._();

  /// Path on `ApiConstant.activeBaseUrl`. Override with FEATURE_FLAGS_PATH.
  static String get flagsUri =>
      Env.optional('FEATURE_FLAGS_PATH', fallback: '/config/flags');
}
