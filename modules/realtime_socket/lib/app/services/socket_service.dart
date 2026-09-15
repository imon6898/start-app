// Socket.IO client as a GetxService. Register once in bootstrap:
//   Get.put(SocketService(), permanent: true);
// Then connect/subscribe/emit from any controller through SocketService.to.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'package:flutter_starter/app/core/enums/socket_status.dart';
import 'package:flutter_starter/app/services/domain/api_const.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';

/// Handle returned by [SocketService.on]; cancel it to unsubscribe.
class SocketSubscription {
  final String event;
  final void Function() _remove;
  bool _cancelled = false;

  SocketSubscription._(this.event, this._remove);

  bool get isCancelled => _cancelled;

  /// Removes the handler from the socket and from the service registry.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _remove();
  }
}

/// One registered handler, kept so it can be re-attached after a rebuild.
class _Registration {
  final String event;
  final void Function(dynamic data) raw;

  const _Registration(this.event, this.raw);
}

/// Realtime Socket.IO connection, reconnects and typed event subscriptions.
class SocketService extends GetxService {
  static SocketService get to => Get.find<SocketService>();

  // ── Reactive state ──
  final Rx<SocketStatus> status = SocketStatus.idle.obs;
  final RxString lastError = ''.obs;
  final RxInt reconnectAttempts = 0.obs;

  // ── Config — set these before the first connect() ──
  /// Host override; empty falls back to `ApiConstant.activeSocketUrl`.
  String baseUrl = '';

  /// Namespace appended to the host, e.g. `/chat`.
  String namespace = '';

  /// Transports offered to the server, in order.
  List<String> transports = const ['websocket'];

  /// First retry delay; the manager doubles it up to [reconnectDelayMax].
  Duration reconnectDelay = const Duration(seconds: 1);
  Duration reconnectDelayMax = const Duration(seconds: 30);
  Duration connectTimeout = const Duration(seconds: 20);

  /// Retry cap; null retries forever.
  int? maxReconnectAttempts;

  /// Extra handshake headers merged with the bearer token.
  Map<String, String> extraHeaders = const {};

  /// Auth payload sent on every handshake; override for a non-standard server.
  Map<String, dynamic> Function(String token)? authPayloadBuilder;

  /// Verbose event logging through devPrint.
  bool debugLogging = kDebugMode;

  socket_io.Socket? _socket;
  String _url = '';
  String _token = '';
  final Map<String, List<_Registration>> _registry = {};

  /// Socket id assigned by the server; null while offline.
  String? get socketId => _socket?.id;

  bool get isConnected => _socket?.connected ?? false;

  /// Host this service is pointed at, resolved from config and .env.
  String get resolvedUrl => _resolveUrl();

  // ── Lifecycle ──

  /// Opens the connection. Safe to call repeatedly — a live identical socket
  /// is kept, a different host or token rebuilds it.
  void connect({String? token, Map<String, dynamic>? query}) {
    final String target = _resolveUrl();
    if (target.isEmpty) {
      lastError.value = 'SOCKET_URL is not set in .env';
      status.value = SocketStatus.error;
      _log('no socket url configured — connect skipped');
      return;
    }

    final String authToken = (token ?? CacheManager.token ?? '').trim();
    final bool sameEndpoint =
        _socket != null && _url == target && _token == authToken;
    if (sameEndpoint && (isConnected || status.value.isConnecting)) {
      _log('already ${status.value.name} on $target');
      return;
    }

    if (_socket != null) _teardownSocket();

    _url = target;
    _token = authToken;
    lastError.value = '';
    status.value = SocketStatus.connecting;

    // Handlers are bound before connect() so the first 'connect' is not missed.
    final socket_io.Socket socket = socket_io.io(target, _options(query));
    _socket = socket;
    _bindLifecycle(socket);
    _attachRegistry(socket);
    socket.connect();
    _log('connecting to $target');
  }

  /// Closes the connection but keeps handlers, so [connect] resumes them.
  void disconnect() {
    _socket?.disconnect();
    status.value = SocketStatus.disconnected;
    _log('disconnect requested');
  }

  /// Call after login: rebuilds the connection so the new token is used.
  void onLogin(String token) {
    _log('token changed — reconnecting');
    _teardownSocket();
    connect(token: token);
  }

  /// Call on logout: closes the socket and forgets every handler.
  void onLogout() {
    _teardownSocket();
    clearSubscriptions();
    _token = '';
    status.value = SocketStatus.idle;
    _log('logged out — socket closed');
  }

  /// Resolves once the socket is connected, or false on timeout.
  Future<bool> awaitConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (isConnected) return true;
    final Completer<bool> completer = Completer<bool>();
    final StreamSubscription<SocketStatus> sub = status.listen((value) {
      if (value.isConnected && !completer.isCompleted) completer.complete(true);
    });
    try {
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } finally {
      await sub.cancel();
    }
  }

  // ── Subscribe / emit ──

  /// Subscribes to [event]. Handlers survive reconnects and socket rebuilds.
  /// Pass [decode] when the payload is not already a [T].
  SocketSubscription on<T>(
    String event,
    void Function(T data) handler, {
    T Function(dynamic raw)? decode,
  }) {
    void wrapped(dynamic raw) {
      try {
        handler(decode != null ? decode(raw) : _coerce<T>(raw, event));
      } catch (e) {
        _log('handler for "$event" failed: $e');
      }
    }

    final _Registration registration = _Registration(event, wrapped);
    _registry.putIfAbsent(event, () => <_Registration>[]).add(registration);
    _socket?.on(event, wrapped);
    return SocketSubscription._(event, () => _remove(registration));
  }

  /// Like [on], but unsubscribes after the first payload.
  SocketSubscription once<T>(
    String event,
    void Function(T data) handler, {
    T Function(dynamic raw)? decode,
  }) {
    late final SocketSubscription subscription;
    subscription = on<T>(event, (T data) {
      subscription.cancel();
      handler(data);
    }, decode: decode);
    return subscription;
  }

  /// Removes every handler registered for [event].
  void off(String event) {
    final List<_Registration>? list = _registry.remove(event);
    if (list == null) return;
    for (final _Registration registration in list) {
      _socket?.off(event, registration.raw);
    }
  }

  /// Removes every handler this service registered.
  void clearSubscriptions() {
    for (final MapEntry<String, List<_Registration>> entry
        in _registry.entries) {
      for (final _Registration registration in entry.value) {
        _socket?.off(entry.key, registration.raw);
      }
    }
    _registry.clear();
  }

  /// Sends [data] on [event]. socket.io buffers it while offline.
  void emit(String event, [dynamic data]) {
    final socket_io.Socket? socket = _socket;
    if (socket == null) {
      _log('emit "$event" dropped — connect() was never called');
      return;
    }
    socket.emit(event, data);
    _log('-> $event');
  }

  /// Emits and waits for the server acknowledgement.
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final socket_io.Socket? socket = _socket;
    if (socket == null) {
      return Future<dynamic>.error(
        StateError('SocketService.connect() was never called'),
      );
    }
    _log('-> $event (ack)');
    return socket.emitWithAckAsync(event, data).timeout(timeout);
  }

  @override
  void onClose() {
    _teardownSocket();
    _registry.clear();
    super.onClose();
  }

  // ── Internals ──

  Map<String, dynamic> _options(Map<String, dynamic>? query) {
    final socket_io.OptionBuilder builder = socket_io.OptionBuilder()
        .setTransports(transports)
        .disableAutoConnect()
        .enableForceNew()
        .setTimeout(connectTimeout.inMilliseconds)
        .setReconnectionDelay(reconnectDelay.inMilliseconds)
        .setReconnectionDelayMax(reconnectDelayMax.inMilliseconds)
        .setRandomizationFactor(0.5)
        // Runs on every handshake, so a reconnect always carries a fresh token.
        .setAuthFn((callback) => callback(_authPayload()));

    if (maxReconnectAttempts != null) {
      builder.setReconnectionAttempts(maxReconnectAttempts!);
    }
    if (query != null && query.isNotEmpty) builder.setQuery(query);

    final Map<String, String> headers = _headers();
    if (headers.isNotEmpty) builder.setExtraHeaders(headers);

    return builder.build();
  }

  Map<String, String> _headers() => <String, String>{
    ...extraHeaders,
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  /// Read live so a token refreshed mid-session reaches the next handshake.
  Map<String, dynamic> _authPayload() {
    final String token = _token.isNotEmpty
        ? _token
        : (CacheManager.token ?? '');
    if (token.isEmpty) return <String, dynamic>{};
    return authPayloadBuilder?.call(token) ?? <String, dynamic>{'token': token};
  }

  String _resolveUrl() {
    final String host =
        (baseUrl.isNotEmpty ? baseUrl : ApiConstant.activeSocketUrl).trim();
    if (host.isEmpty) return '';
    final String cleanHost = host.endsWith('/')
        ? host.substring(0, host.length - 1)
        : host;
    if (namespace.isEmpty) return cleanHost;
    return namespace.startsWith('/')
        ? '$cleanHost$namespace'
        : '$cleanHost/$namespace';
  }

  void _bindLifecycle(socket_io.Socket socket) {
    socket.onConnect((_) {
      reconnectAttempts.value = 0;
      lastError.value = '';
      status.value = SocketStatus.connected;
      _log('connected as ${socket.id}');
    });
    socket.onDisconnect((reason) {
      status.value = SocketStatus.disconnected;
      _log('disconnected ($reason)');
    });
    socket.onConnectError((error) {
      lastError.value = '$error';
      status.value = SocketStatus.error;
      _log('connect error: $error');
    });
    socket.onError((error) {
      lastError.value = '$error';
      _log('error: $error');
    });
    // Backoff is the manager's: reconnectDelay doubled up to reconnectDelayMax.
    socket.onReconnectAttempt((attempt) {
      reconnectAttempts.value = attempt is int
          ? attempt
          : reconnectAttempts.value + 1;
      status.value = SocketStatus.reconnecting;
      _log('reconnect attempt ${reconnectAttempts.value}');
    });
    socket.onReconnect((_) => _log('reconnected'));
    socket.onReconnectFailed((_) {
      lastError.value = 'Reconnection failed';
      status.value = SocketStatus.error;
      _log('reconnect failed — call connect() to retry');
    });
    if (debugLogging) {
      socket.onAny((event, data) => _log('<- $event'));
    }
  }

  void _attachRegistry(socket_io.Socket socket) {
    for (final MapEntry<String, List<_Registration>> entry
        in _registry.entries) {
      for (final _Registration registration in entry.value) {
        socket.on(entry.key, registration.raw);
      }
    }
  }

  void _remove(_Registration registration) {
    final List<_Registration>? list = _registry[registration.event];
    if (list == null) return;
    list.remove(registration);
    if (list.isEmpty) _registry.remove(registration.event);
    _socket?.off(registration.event, registration.raw);
  }

  void _teardownSocket() {
    final socket_io.Socket? socket = _socket;
    if (socket == null) return;
    for (final MapEntry<String, List<_Registration>> entry
        in _registry.entries) {
      for (final _Registration registration in entry.value) {
        socket.off(entry.key, registration.raw);
      }
    }
    socket.dispose();
    _socket = null;
    status.value = SocketStatus.disconnected;
  }

  T _coerce<T>(dynamic raw, String event) {
    if (raw is T) return raw;
    // Some servers deliver JSON objects as Map<dynamic, dynamic>.
    if (raw is Map && <Map<String, dynamic>>[] is List<T>) {
      return Map<String, dynamic>.from(raw) as T;
    }
    // Multi-argument events arrive as a List; unwrap a lone payload.
    if (raw is List && raw.length == 1 && raw.first is T) return raw.first as T;
    throw FormatException(
      'Event "$event" payload is ${raw.runtimeType}, expected $T',
    );
  }

  void _log(String message) {
    if (debugLogging) devPrint(message, tag: 'Socket');
  }
}
