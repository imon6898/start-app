// Link targets for the legal rows. Read through Env.optional so the module adds
// no getter to the core env.dart and boots fine with the keys absent.

import 'package:flutter_starter/app/core/config/env.dart';

class SettingsLinks {
  SettingsLinks._();

  /// Empty means "no URL configured" — the screen opens the in-app route instead.
  static String get privacyPolicy => Env.optional('PRIVACY_POLICY_URL');

  static String get termsOfService => Env.optional('TERMS_OF_SERVICE_URL');

  static String get support => Env.optional('SUPPORT_URL');
}
