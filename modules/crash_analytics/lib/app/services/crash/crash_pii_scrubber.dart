// beforeSend / beforeBreadcrumb filters. Nothing leaves the device without
// passing through here, so keep the rules conservative and additive.

import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Strips credentials and contact details out of events and breadcrumbs.
class CrashPiiScrubber {
  CrashPiiScrubber._();

  /// Replacement value; visible in Sentry so you know a field was dropped.
  static const String redacted = '[redacted]';

  /// A map key containing any of these (case-insensitive) loses its value.
  static const List<String> sensitiveKeys = [
    'auth',
    'token',
    'jwt',
    'bearer',
    'credential',
    'password',
    'passwd',
    'pwd',
    'secret',
    'apikey',
    'api_key',
    'signature',
    'cookie',
    'session',
    'email',
    'mail',
    'phone',
    'mobile',
    'msisdn',
    'otp',
    'pin',
    'ssn',
    'address',
    'card',
    'cvv',
    'cvc',
    'iban',
  ];

  /// Request headers dropped outright, whatever their value looks like.
  static const List<String> blockedHeaders = [
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-refresh-token',
  ];

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final RegExp _bearer = RegExp(
    r'bearer\s+[\w\-._~+/=]+',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+');
  // Nine or more consecutive digits: phone numbers, not dates or HTTP codes.
  static final RegExp _longNumber = RegExp(r'\+?\d{9,}');
  // International form with separators; the leading + keeps dates out.
  static final RegExp _intlPhone = RegExp(r'\+\d[\d\s().-]{6,}\d');

  /// Wire to `options.beforeSend`.
  static FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) {
    event.user = _scrubUser(event.user);
    event.request = _scrubRequest(event.request);
    event.tags = _scrubTags(event.tags);
    // ignore: deprecated_member_use
    event.extra = _scrubData(event.extra);
    event.message = _scrubMessage(event.message);

    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final exception in exceptions) {
        exception.value = scrubText(exception.value);
      }
    }

    final crumbs = event.breadcrumbs;
    if (crumbs != null) {
      event.breadcrumbs = crumbs.map(_scrubBreadcrumb).toList();
    }
    return event;
  }

  /// Wire to `options.beforeBreadcrumb`.
  static Breadcrumb? beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) =>
      breadcrumb == null ? null : _scrubBreadcrumb(breadcrumb);

  /// Redacts emails, bearer tokens, JWTs and phone-shaped digit runs.
  static String? scrubText(String? text) {
    if (text == null || text.isEmpty) return text;
    return text
        .replaceAll(_bearer, 'Bearer $redacted')
        .replaceAll(_jwt, redacted)
        .replaceAll(_email, redacted)
        .replaceAll(_intlPhone, redacted)
        .replaceAll(_longNumber, redacted);
  }

  /// True when a map key names something that must never be transmitted.
  static bool isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return sensitiveKeys.any((needle) => lower.contains(needle));
  }

  /// Keeps the opaque user id; drops every other identifying field.
  static SentryUser? _scrubUser(SentryUser? user) {
    if (user == null) return null;
    user.email = null;
    user.username = null;
    user.name = null;
    user.ipAddress = null;
    user.geo = null;
    user.data = _scrubData(user.data);
    return user;
  }

  /// Keeps the endpoint and verb; drops bodies, cookies and auth headers.
  static SentryRequest? _scrubRequest(SentryRequest? request) {
    if (request == null) return null;
    final headers = <String, String>{};
    request.headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (blockedHeaders.contains(lower)) return;
      headers[key] = isSensitiveKey(key) ? redacted : scrubText(value) ?? value;
    });
    return SentryRequest(
      url: _scrubUrl(request.url),
      method: request.method,
      // Query strings carry ids and tokens; the path is enough to group by.
      queryString: null,
      cookies: null,
      fragment: request.fragment,
      // Request and response bodies are dropped wholesale.
      data: null,
      headers: headers,
      env: request.env,
    );
  }

  /// Keeps scheme/host/path only; userinfo, query and fragment are dropped.
  static String? _scrubUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return scrubText(url);
    final stripped = Uri(
      scheme: uri.scheme.isEmpty ? null : uri.scheme,
      host: uri.host.isEmpty ? null : uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
    return scrubText(stripped.toString());
  }

  static Map<String, String>? _scrubTags(Map<String, String>? tags) {
    if (tags == null) return null;
    return tags.map(
      (key, value) => MapEntry(
        key,
        isSensitiveKey(key) ? redacted : scrubText(value) ?? value,
      ),
    );
  }

  static Map<String, dynamic>? _scrubData(Map<String, dynamic>? data) {
    if (data == null) return null;
    return data.map((key, value) {
      if (isSensitiveKey(key)) return MapEntry(key, redacted);
      if (value is String) return MapEntry(key, scrubText(value));
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _scrubData(value));
      }
      return MapEntry(key, value);
    });
  }

  static SentryMessage? _scrubMessage(SentryMessage? message) {
    if (message == null) return null;
    message.formatted = scrubText(message.formatted) ?? message.formatted;
    message.template = scrubText(message.template);
    message.params = message.params
        ?.map((p) => p is String ? scrubText(p) : p)
        .toList();
    return message;
  }

  static Breadcrumb _scrubBreadcrumb(Breadcrumb crumb) {
    crumb.message = scrubText(crumb.message);
    crumb.data = _scrubData(crumb.data);
    return crumb;
  }
}
