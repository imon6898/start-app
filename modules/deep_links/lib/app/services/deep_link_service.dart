// Routes OS deep links / universal links onto AppRoutes. The link table lives
// in deep_link_config.dart; nothing here is app-specific.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_starter/app/core/di/user_di.dart';
import 'package:flutter_starter/app/routes/app_pages.dart';
import 'package:flutter_starter/app/services/deep_link_config.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:get/get.dart';

class DeepLinkService extends GetxService {
  static DeepLinkService get to => Get.find();

  static bool get isReady => Get.isRegistered<DeepLinkService>();

  /// Splash/sign-in call these: they no-op when the service was never
  /// registered, so widget tests that skip bootstrap do not blow up.
  static bool dispatchInitial() => isReady ? to.dispatchInitialLink() : false;

  static bool resume() => isReady ? to.resumePending() : false;

  /// Every table is injectable so tests can build a service without touching
  /// DeepLinkConfig.
  DeepLinkService({
    Map<String, String>? routes,
    Set<String>? schemes,
    Set<String>? hosts,
    Set<String>? authOnly,
    String? signInRoute,
    this.guard,
  }) : routes = routes ?? DeepLinkConfig.routes,
       schemes = schemes ?? DeepLinkConfig.schemes,
       hosts = hosts ?? DeepLinkConfig.hosts,
       authOnly = authOnly ?? DeepLinkConfig.authOnly,
       signInRoute = signInRoute ?? DeepLinkConfig.signInRoute;

  static const String _tag = 'DeepLink';

  final Map<String, String> routes;
  final Set<String> schemes;
  final Set<String> hosts;
  final Set<String> authOnly;
  final String signInRoute;

  /// Your own rule; null falls back to the [authOnly] check.
  DeepLinkGuard? guard;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Uri? _initialUri;
  bool _expectReplay = false;

  /// Link parked by the guard, replayed by [resumePending] after sign-in.
  Uri? pendingLink;

  bool get hasPendingLink => pendingLink != null;

  /// Cold-start link, still undispatched. Null once it has been consumed.
  Uri? get initialLink => _initialUri;

  /// Call from bootstrap before runApp so the cold-start link is not missed.
  Future<DeepLinkService> init() async {
    try {
      _initialUri = await _appLinks.getInitialLink();
    } catch (e) {
      devPrint('initial link failed: $e', tag: _tag);
    }
    // The platform stream replays that same link on the first listen.
    _expectReplay = _initialUri != null;
    _sub = _appLinks.uriLinkStream.listen(
      _onStreamLink,
      onError: (Object e) => devPrint('stream error: $e', tag: _tag),
    );
    devPrint('ready, initial link: ${_initialUri ?? 'none'}', tag: _tag);
    return this;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// Opens the cold-start link. Call it once the first real screen is on the
  /// stack — before that any navigation is wiped by the splash redirect.
  bool dispatchInitialLink() {
    final uri = _initialUri;
    _initialUri = null;
    _expectReplay = false;
    if (uri == null) return false;
    return handle(uri);
  }

  /// Entry point for links the OS did not deliver: push payloads, QR codes.
  bool open(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return false;
    return handle(uri);
  }

  /// Replays the parked link. Call after a successful sign-in.
  bool resumePending() {
    final uri = pendingLink;
    pendingLink = null;
    if (uri == null) return false;
    return handle(uri);
  }

  void clearPending() => pendingLink = null;

  /// Resolves [uri] and navigates. false = parked, unknown or foreign link.
  bool handle(Uri uri, {bool replace = false}) {
    devPrint('handling $uri', tag: _tag);
    if (!accepts(uri)) return _openUnknown(uri);

    final match = matchUri(uri);
    if (match == null) return _openUnknown(uri);

    if (!allows(match)) {
      pendingLink = uri;
      devPrint('parked ${match.route} until sign-in', tag: _tag);
      Get.toNamed(signInRoute);
      return false;
    }

    if (replace) {
      Get.offNamed(match.route, arguments: match.arguments);
    } else {
      Get.toNamed(match.route, arguments: match.arguments);
    }
    return true;
  }

  /// True when the link belongs to this app: a known scheme, or a known host
  /// on http/https. An empty table means "accept anything".
  bool accepts(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return true;
    if (scheme == 'http' || scheme == 'https') {
      return hosts.isEmpty || hosts.contains(uri.host.toLowerCase());
    }
    return schemes.isEmpty || schemes.contains(scheme);
  }

  /// Best pattern wins: literal segments beat ':param', which beats '*'.
  DeepLinkMatch? matchUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final direct = _best(uri, segments);
    if (direct != null) return direct;
    // myapp://product/42 parses 'product' as the host, not as a path segment.
    final scheme = uri.scheme.toLowerCase();
    if (uri.host.isEmpty || scheme == 'http' || scheme == 'https') return null;
    return _best(uri, [uri.host, ...segments]);
  }

  DeepLinkMatch? _best(Uri uri, List<String> segments) {
    DeepLinkMatch? best;
    var bestScore = -1;
    routes.forEach((pattern, route) {
      final parts = pattern.split('/').where((s) => s.isNotEmpty).toList();
      final params = _capture(parts, segments);
      if (params == null) return;
      final score = _score(parts);
      if (score <= bestScore) return;
      bestScore = score;
      best = DeepLinkMatch(
        uri: uri,
        pattern: pattern,
        route: route,
        pathParams: params,
      );
    });
    return best;
  }

  /// The guard hook. Override [guard] to add roles, entitlements, paywalls.
  bool allows(DeepLinkMatch match) {
    final check = guard;
    if (check != null) return check(match);
    return !authOnly.contains(match.route) || isSignedIn;
  }

  /// Session check the default guard uses.
  bool get isSignedIn {
    if (Get.isRegistered<UserDi>()) return Get.find<UserDi>().isLoggedIn;
    return CacheManager.token?.isNotEmpty ?? false;
  }

  // Captured path params, or null when the pattern does not match.
  Map<String, String>? _capture(List<String> pattern, List<String> segments) {
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      final part = pattern[i];
      if (part == '*') {
        params['rest'] = segments.skip(i).join('/');
        return params;
      }
      if (i >= segments.length) return null;
      if (part.startsWith(':')) {
        params[part.substring(1)] = segments[i];
        continue;
      }
      if (part.toLowerCase() != segments[i].toLowerCase()) return null;
    }
    return pattern.length == segments.length ? params : null;
  }

  // Literal 4, ':param' 2, '*' 1 — longer and more literal scores higher.
  int _score(List<String> pattern) {
    var score = 0;
    for (final part in pattern) {
      score += part == '*' ? 1 : (part.startsWith(':') ? 2 : 4);
    }
    return score;
  }

  // dispatchInitialLink owns the cold-start link, so drop the stream's replay.
  void _onStreamLink(Uri uri) {
    if (_expectReplay) {
      _expectReplay = false;
      if (uri == _initialUri) return;
    }
    handle(uri);
  }

  // Unmatched links land on AppPages.unknownRoute instead of doing nothing.
  bool _openUnknown(Uri uri) {
    devPrint('no route for $uri', tag: _tag);
    Get.toNamed(
      AppPages.unknownRoute.name,
      arguments: {'deepLinkUri': uri.toString()},
    );
    return false;
  }
}
