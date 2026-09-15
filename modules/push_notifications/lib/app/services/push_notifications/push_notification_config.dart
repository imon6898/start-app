import 'package:flutter_starter/app/routes/app_routes.dart';

/// The one Android channel this module creates and posts every push to.
class PushChannel {
  /// Must match `android.notification.channel_id` in the FCM payload.
  static const String id = 'high_importance_channel';
  static const String name = 'General notifications';
  static const String description =
      'Order updates, messages and announcements.';

  /// Small icon resource. Swap for '@drawable/ic_notification' once you add one.
  static const String androidIcon = '@mipmap/ic_launcher';
}

/// Keys the backend must put in the FCM `data` map.
class PushPayloadKeys {
  static const String route = 'route';
  static const String id = 'id';
}

/// Turns a payload `route` value into a route registered in [AppRoutes].
class PushRoutes {
  /// Slugs the backend may send instead of a raw path. Add your screens here.
  static final Map<String, String> bySlug = <String, String>{
    'dashboard': AppRoutes.DashboardScreen,
    'signin': AppRoutes.SigninScreen,
    'onboarding': AppRoutes.OnboardingScreen,
    'terms': AppRoutes.TermsOfServiceScreen,
    'privacy': AppRoutes.PrivacyPolicyScreen,
  };

  /// Raw paths a payload is allowed to target. Anything else is ignored.
  static final Set<String> allowed = bySlug.values.toSet();

  /// Returns a known route for [value], or null when it is unroutable.
  static String? resolve(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (allowed.contains(raw)) return raw;
    return bySlug[raw.toLowerCase()];
  }
}
