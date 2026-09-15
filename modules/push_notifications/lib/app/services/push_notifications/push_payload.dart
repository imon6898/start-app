import 'dart:convert';

import 'package:flutter_starter/app/services/push_notifications/push_notification_config.dart';

/// The `data` half of an FCM message, typed.
class PushPayload {
  final String? route;
  final String? id;
  final Map<String, dynamic> data;

  const PushPayload({
    this.route,
    this.id,
    this.data = const <String, dynamic>{},
  });

  /// Straight from `RemoteMessage.data`.
  factory PushPayload.fromData(Map<String, dynamic> data) => PushPayload(
    route: data[PushPayloadKeys.route]?.toString(),
    id: data[PushPayloadKeys.id]?.toString(),
    data: data,
  );

  /// Decodes the JSON string carried by a local-notification tap.
  factory PushPayload.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const PushPayload();
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return PushPayload.fromData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Malformed payload — treat it as a plain tap.
    }
    return const PushPayload();
  }

  /// What the local notification carries so a tap can be routed later.
  String toJsonString() => jsonEncode(data);

  /// Route this payload opens, or null when it targets nothing known.
  String? get targetRoute => PushRoutes.resolve(route);

  bool get hasTarget => targetRoute != null;

  @override
  String toString() => 'PushPayload(route: $route, id: $id)';
}
