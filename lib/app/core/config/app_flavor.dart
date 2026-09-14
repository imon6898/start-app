import 'package:flutter/foundation.dart';

enum Flavor { dev, staging, prod }

/// Build flavor, set with `--dart-define=FLAVOR=staging`.
class AppFlavor {
  static const String _define = String.fromEnvironment('FLAVOR');

  static final Flavor current = _resolve();

  static Flavor _resolve() {
    switch (_define.toLowerCase()) {
      case 'prod':
      case 'production':
        return Flavor.prod;
      case 'staging':
        return Flavor.staging;
      case 'dev':
      case 'development':
        return Flavor.dev;
      default:
        // No flag given: release builds are prod, everything else dev.
        return kReleaseMode ? Flavor.prod : Flavor.dev;
    }
  }

  static bool get isDev => current == Flavor.dev;
  static bool get isStaging => current == Flavor.staging;
  static bool get isProd => current == Flavor.prod;

  static String get name => current.name;
}
