// Every flag the app knows about. Declare it here and it is typed at the call
// site and listed in the debug screen — nothing else registers it.

enum FlagType { boolean, integer, string, json }

/// A flag name plus the value compiled into the binary.
///
/// [fallback] is the last resort: used only when there is no local override and
/// no cached document. It is the value a first launch with no network sees.
class FlagKey<T> {
  final String name;
  final T fallback;
  final FlagType type;
  final String description;

  const FlagKey(this.name, this.fallback, this.type, {this.description = ''});
}

class BoolFlag extends FlagKey<bool> {
  const BoolFlag(String name, {bool fallback = false, String description = ''})
    : super(name, fallback, FlagType.boolean, description: description);
}

/// A remote off switch for something that already shipped.
///
/// [fallback] is what a device with no cached document sees. Leave it true for a
/// feature users already rely on; set it false for anything you must be able to
/// keep off on a device that has never reached the backend.
class KillSwitch extends BoolFlag {
  const KillSwitch(super.name, {super.fallback = true, super.description});
}

class IntFlag extends FlagKey<int> {
  const IntFlag(String name, {int fallback = 0, String description = ''})
    : super(name, fallback, FlagType.integer, description: description);
}

class StringFlag extends FlagKey<String> {
  const StringFlag(String name, {String fallback = '', String description = ''})
    : super(name, fallback, FlagType.string, description: description);
}

class JsonFlag extends FlagKey<Map<String, dynamic>> {
  const JsonFlag(
    String name, {
    Map<String, dynamic> fallback = const {},
    String description = '',
  }) : super(name, fallback, FlagType.json, description: description);
}

/// An A/B experiment. [variants] first entry is the control.
///
/// [exposure] is the percentage of users enrolled at all; the rest get null
/// from `variantOf` so they can be excluded from the analysis.
class Experiment {
  final String key;
  final List<String> variants;
  final int exposure;
  final String description;

  const Experiment(
    this.key, {
    required this.variants,
    this.exposure = 100,
    this.description = '',
  });

  String get control => variants.isEmpty ? '' : variants.first;
}

/// Replace these with your own. Keep [all] and [experiments] in sync — the
/// debug screen and QA see exactly what is listed here.
class FeatureFlags {
  FeatureFlags._();

  // Kill switches — flip the backend value to false to disable without a release.
  static const KillSwitch checkout = KillSwitch(
    'checkout_enabled',
    description: 'Whole checkout flow. Off means show the maintenance notice.',
  );
  static const KillSwitch socialLogin = KillSwitch(
    'social_login_enabled',
    description: 'Google / Apple buttons on the sign-in screen.',
  );

  // Feature gates — off until the backend turns them on.
  static const BoolFlag newDashboard = BoolFlag(
    'new_dashboard',
    description: 'Ships dark, enabled by rollout percentage.',
  );

  // Tunables.
  static const IntFlag maxUploadMb = IntFlag(
    'max_upload_mb',
    fallback: 10,
    description: 'Client-side upload size ceiling.',
  );
  static const StringFlag supportEmail = StringFlag(
    'support_email',
    fallback: 'support@example.com',
    description: 'Shown on the error screens.',
  );
  static const JsonFlag promoBanner = JsonFlag(
    'promo_banner',
    description: 'Home banner payload: {title, body, deeplink}.',
  );

  /// Debug-screen order.
  static const List<FlagKey<Object>> all = [
    checkout,
    socialLogin,
    newDashboard,
    maxUploadMb,
    supportEmail,
    promoBanner,
  ];

  static const Experiment onboardingCopy = Experiment(
    'onboarding_copy',
    variants: ['control', 'short', 'video'],
    exposure: 50,
    description: 'Onboarding first-screen wording.',
  );

  static const List<Experiment> experiments = [onboardingCopy];
}
