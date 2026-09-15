import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';
import 'package:flutter_starter/app/services/push_notifications/push_notification_api_service.dart';
import 'package:flutter_starter/app/services/push_notifications/push_notification_config.dart';
import 'package:flutter_starter/app/services/push_notifications/push_payload.dart';
import 'package:get/get.dart';

const String _tag = 'Push';

/// Handles messages while the app is backgrounded or terminated.
///
/// MUST stay a top-level (or static) function with this annotation — Firebase
/// spawns a fresh isolate for it and the compiler strips unannotated entries.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  // The isolate has no Firebase app of its own.
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  devPrint(
    'background message ${message.messageId}: ${message.data}',
    tag: _tag,
  );
}

/// Fires when a notification action is tapped with the app killed.
///
/// Runs in a background isolate: no GetX, no navigation. The tap is replayed
/// through `getInitialMessage()` on the next launch.
@pragma('vm:entry-point')
void pushBackgroundTapHandler(NotificationResponse response) {
  devPrint('background tap: ${response.payload}', tag: _tag);
}

/// FCM + local notifications: permission, token sync, foreground rendering and
/// tap-to-route for cold and warm starts.
class PushNotificationService extends GetxService {
  static PushNotificationService get to => Get.find();

  PushNotificationService({
    this.autoHandleInitialMessage = true,
    this.initialMessageDelay = const Duration(milliseconds: 1500),
    this.syncTokenOnStart = true,
  });

  /// Open the cold-start notification's route automatically after the first frame.
  final bool autoHandleInitialMessage;

  /// Grace period so splash/auth settle before the deep link fires.
  final Duration initialMessageDelay;

  /// POST the token to the backend as soon as it is known.
  final bool syncTokenOnStart;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final PushRepo _repo = PushRepo();

  /// Current FCM registration token, null until the first fetch succeeds.
  final RxnString token = RxnString();

  /// Last known OS permission state.
  final Rx<AuthorizationStatus> permission =
      AuthorizationStatus.notDetermined.obs;

  final RxBool isSyncingToken = false.obs;

  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];
  PushPayload? _pending;
  int _localId = 0;

  /// Call once from bootstrap, after `Firebase.initializeApp()`.
  Future<PushNotificationService> init() async {
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    await _initLocalNotifications();
    await _createAndroidChannel();
    await requestPermission();
    await _bindToken();
    _bindMessageStreams();
    await _bindInitialMessage();
    return this;
  }

  // ── setup ──

  Future<void> _initLocalNotifications() async {
    // iOS prompts are owned by FCM's requestPermission, so ask for none here.
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings(PushChannel.androidIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalTap,
      onDidReceiveBackgroundNotificationResponse: pushBackgroundTapHandler,
    );
  }

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      PushChannel.id,
      PushChannel.name,
      description: PushChannel.description,
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Asks for notification permission. Covers iOS and Android 13+
  /// POST_NOTIFICATIONS; a no-op once the user has answered the OS prompt.
  Future<AuthorizationStatus> requestPermission() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      permission.value = settings.authorizationStatus;

      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }

      // iOS would draw its own foreground banner; we render it ourselves.
      if (Platform.isIOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: true,
              sound: false,
            );
      }
    } catch (e) {
      devPrint('permission request failed: $e', tag: _tag);
    }
    devPrint('permission: ${permission.value}', tag: _tag);
    return permission.value;
  }

  // ── token ──

  Future<void> _bindToken() async {
    try {
      token.value = await FirebaseMessaging.instance.getToken();
      devPrint('token: ${token.value}', tag: _tag);
    } catch (e) {
      devPrint('getToken failed: $e', tag: _tag);
    }
    if (syncTokenOnStart) await syncToken();

    _subs.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((String value) {
        token.value = value;
        syncToken();
      }),
    );
  }

  /// POSTs the current token to the backend. Call again after sign-in, when a
  /// session token finally exists.
  Future<bool> syncToken() async {
    final String? value = token.value;
    if (value == null || value.isEmpty) return false;
    if ((CacheManager.token ?? '').isEmpty) {
      devPrint('no session yet — token sync deferred', tag: _tag);
      return false;
    }
    if (isSyncingToken.value) return false;

    isSyncingToken.value = true;
    try {
      final dynamic response = await _repo.registerDevice(<String, dynamic>{
        'token': value,
        'platform': Platform.operatingSystem,
      });
      devPrint('token synced: ${response != null}', tag: _tag);
      return response != null;
    } catch (e) {
      devPrint('token sync failed: $e', tag: _tag);
      return false;
    } finally {
      isSyncingToken.value = false;
    }
  }

  /// Detaches this device on logout, then drops the local token.
  Future<void> unregisterToken({bool deleteLocal = true}) async {
    final String? value = token.value;
    try {
      if (value != null && value.isNotEmpty) {
        await _repo.unregisterDevice(<String, dynamic>{
          'token': value,
          'platform': Platform.operatingSystem,
        });
      }
      if (deleteLocal) await FirebaseMessaging.instance.deleteToken();
      token.value = null;
    } catch (e) {
      devPrint('unregister failed: $e', tag: _tag);
    }
  }

  // ── messages ──

  void _bindMessageStreams() {
    _subs.add(FirebaseMessaging.onMessage.listen(showForeground));
    _subs.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) => _open(PushPayload.fromData(message.data)),
      ),
    );
  }

  /// Renders a foreground message through the local-notification channel.
  Future<void> showForeground(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    // Data-only messages have nothing to draw.
    if (notification == null) return;

    _localId = (_localId + 1) % 100000;
    await _local.show(
      id: _localId,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          PushChannel.id,
          PushChannel.name,
          channelDescription: PushChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: notification.android?.smallIcon ?? PushChannel.androidIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: PushPayload.fromData(message.data).toJsonString(),
    );
  }

  void _onLocalTap(NotificationResponse response) =>
      _open(PushPayload.fromJsonString(response.payload));

  // ── routing ──

  Future<void> _bindInitialMessage() async {
    final RemoteMessage? message = await FirebaseMessaging.instance
        .getInitialMessage();
    if (message != null) _pending = PushPayload.fromData(message.data);

    // A local notification can cold-start the app too.
    if (_pending == null) {
      final NotificationAppLaunchDetails? details = await _local
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        _pending = PushPayload.fromJsonString(
          details?.notificationResponse?.payload,
        );
      }
    }

    if (_pending == null || !autoHandleInitialMessage) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(initialMessageDelay, flushPendingRoute);
    });
  }

  /// Opens the route a cold-start notification asked for, once. Call it from
  /// the splash controller when you want to control the timing yourself.
  void flushPendingRoute() {
    final PushPayload? payload = _pending;
    _pending = null;
    if (payload != null) _open(payload);
  }

  void _open(PushPayload payload) {
    final String? route = payload.targetRoute;
    if (route == null) {
      devPrint('unroutable payload: ${payload.data}', tag: _tag);
      return;
    }
    // Navigator not mounted yet — replay after the first frame.
    if (Get.key.currentState == null) {
      _pending = payload;
      WidgetsBinding.instance.addPostFrameCallback((_) => flushPendingRoute());
      return;
    }
    devPrint('opening $route', tag: _tag);
    Get.toNamed(route, arguments: payload.data);
  }

  @override
  void onClose() {
    for (final StreamSubscription<dynamic> sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.onClose();
  }
}
