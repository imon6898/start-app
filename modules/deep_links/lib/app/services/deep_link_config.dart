// The only file a project edits: which links this app answers to, where each
// one lands, and which routes need a session. The service stays generic.

import 'package:flutter_starter/app/routes/app_routes.dart';

/// Decides whether a matched link may open now. false bounces it through sign-in.
typedef DeepLinkGuard = bool Function(DeepLinkMatch match);

class DeepLinkConfig {
  /// Custom schemes this app owns: flutterstarter://product/42
  static const Set<String> schemes = {'flutterstarter'};

  /// Hosts accepted on http/https links. Empty set = accept any host.
  static const Set<String> hosts = {'example.com', 'www.example.com'};

  /// Link pattern -> AppRoutes entry. ':name' captures one segment; a trailing
  /// '*' captures everything left as 'rest'.
  static const Map<String, String> routes = {
    '/': AppRoutes.DashboardScreen,
    '/signin': AppRoutes.SigninScreen,
    '/terms': AppRoutes.TermsOfServiceScreen,
    '/privacy': AppRoutes.PrivacyPolicyScreen,
    '/verify/:email': AppRoutes.VerifyOtpScreen,
    '/reset-password/:token': AppRoutes.RetypePassScreen,
    // Point this at AppRoutes.ProductScreen once that page exists.
    '/product/:id': AppRoutes.DashboardScreen,
  };

  /// Routes that need a signed-in user; the default guard parks these.
  static const Set<String> authOnly = {AppRoutes.DashboardScreen};

  /// Where a parked link sends the user first.
  static const String signInRoute = AppRoutes.SigninScreen;
}

/// One resolved link: the route to open plus the arguments to hand it.
class DeepLinkMatch {
  final Uri uri;
  final String pattern;
  final String route;
  final Map<String, String> pathParams;

  const DeepLinkMatch({
    required this.uri,
    required this.pattern,
    required this.route,
    required this.pathParams,
  });

  Map<String, String> get queryParams => uri.queryParameters;

  /// Handed over as Get.arguments; a path param wins over a query param of the
  /// same name, and the raw link is always available under 'deepLinkUri'.
  Map<String, dynamic> get arguments => {
    ...uri.queryParameters,
    ...pathParams,
    'deepLinkUri': uri.toString(),
  };

  @override
  String toString() => 'DeepLinkMatch($pattern -> $route, $pathParams)';
}
