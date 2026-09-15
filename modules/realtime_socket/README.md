# realtime_socket

Socket.IO realtime client as a `GetxService`: auth-aware connect/disconnect, manager-driven reconnects with exponential backoff, a reactive `SocketStatus`, and a typed `on<T>()` / `emit()` registry whose handlers survive reconnects and are removed on dispose.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/socket_service.dart` | `SocketService` — the whole client: connect/disconnect, token lifecycle, subscription registry, `emit` / `emitWithAck`. |
| `lib/app/core/enums/socket_status.dart` | `SocketStatus` + `SocketStatusX` — `idle / connecting / connected / reconnecting / disconnected / error`, with `label`, `isConnected`, `isConnecting`, `isOffline`. A separate file, so core `enums.dart` is never overwritten. |
| `lib/app/feature/realtime/realtime_controllers/realtime_demo_controller.dart` | `RealtimeDemoController` — the pattern: subscribe in `onInit`, cancel in `onClose`, emit with and without an ack. |
| `lib/app/feature/realtime/realtime_presentation/realtime_demo_screen.dart` | `RealtimeDemoScreen` — live status badge, event feed, composer. Delete both demo files once you have copied the pattern. |

## Install

```bash
dart run tool/add_module.dart realtime_socket
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/realtime_socket/lib/app/core/enums/socket_status.dart  lib/app/core/enums/
cp modules/realtime_socket/lib/app/services/socket_service.dart   lib/app/services/
mkdir -p lib/app/feature/realtime/realtime_controllers lib/app/feature/realtime/realtime_presentation
cp modules/realtime_socket/lib/app/feature/realtime/realtime_controllers/realtime_demo_controller.dart \
   lib/app/feature/realtime/realtime_controllers/
cp modules/realtime_socket/lib/app/feature/realtime/realtime_presentation/realtime_demo_screen.dart \
   lib/app/feature/realtime/realtime_presentation/
```

### 1. pubspec.yaml

```yaml
dependencies:
  socket_io_client: ^3.1.6
```

`get`, `flutter_dotenv`, `intl`, `shared_preferences` and `lucide_icons_flutter` are already in the template core. `socket_io_client` is pure Dart (it pulls `socket_io_common`, `web_socket`, `logging`) — no native plugin, no `pod install`, no Gradle change.

### 2. .env

Both keys already ship in the template's `.env`:

```env
SOCKET_URL="https://chat.adventcircle.com"
SOCKET_URL_DEV="https://chat-dev.adventcircle.com"
```

`Env.socketUrl` / `Env.socketUrlDev` already exist in `lib/app/core/config/env.dart`, and `ApiConstant.activeSocketUrl` already picks the right one per flavor. **No core edit is needed for the host.** The service reads `ApiConstant.activeSocketUrl` unless you set `SocketService.to.baseUrl` yourself.

### 3. Platform

- **Android** — `INTERNET` is already declared in `android/app/src/main/AndroidManifest.xml`. Nothing else. A plain `ws://` / `http://` host would additionally need cleartext traffic enabled; both `.env` hosts are `https`, so it does not apply.
- **iOS** — nothing for a `wss://` host. A plain `ws://` host needs an `NSAppTransportSecurity` exception in `ios/Runner/Info.plist`.

## Wiring

Paste these exactly. Only the bootstrap entry is mandatory for the service; the binding entry is mandatory as long as the demo controller is on disk.

### `lib/bootstrap.dart` — register the service

Add the import next to the other package imports:

```dart
import 'package:get/get.dart';
```

and with the other app imports:

```dart
import 'app/services/socket_service.dart';
```

Then, right after `await CacheManager.init();` and before `ViewModelBinding().dependencies();`:

```dart
    // Realtime transport; connect() is called from the auth flow, not here.
    Get.put(SocketService(), permanent: true);
```

Registering is not connecting. Opening a socket during startup would hold the first frame behind a network handshake and would connect signed-out users.

### `lib/app/bindings/view_model_binding.dart` — required while the demo exists

`test/guardrails/bindings_test.dart` fails on any controller under `lib/app/feature` that is not registered, so this is not optional:

```dart
import '../feature/realtime/realtime_controllers/realtime_demo_controller.dart';
```

and inside `dependencies()`:

```dart
    // Realtime
    _lazy<RealtimeDemoController>(() => RealtimeDemoController());
```

(Deleting the two demo files instead is also fine — `SocketService` and `SocketStatus` stand alone.)

### `lib/app/routes/app_routes.dart` — demo screen only

```dart
  /// Realtime
  static const String RealtimeDemoScreen = '/realtimeDemoScreen';
```

### `lib/app/routes/app_pages.dart` — demo screen only

```dart
import '../feature/realtime/realtime_presentation/realtime_demo_screen.dart';
```

and inside `pages`:

```dart
    // Realtime
    _page(AppRoutes.RealtimeDemoScreen, () => const RealtimeDemoScreen()),
```

`test/guardrails/routes_test.dart` requires every `AppRoutes` constant to have a `GetPage`, so add both lines or neither.

### Auth lifecycle — where to call what

| Moment | Call |
| --- | --- |
| Login succeeded, token cached | `SocketService.to.onLogin(token);` |
| Warm start with a cached token (e.g. splash, after `CacheManager.token` check) | `SocketService.to.connect();` |
| Logout | `SocketService.to.onLogout();` |
| Screen wants a manual retry | `SocketService.to.disconnect(); SocketService.to.connect();` |

`onLogin` tears the socket down and rebuilds it, because the `Authorization` handshake header is fixed for the life of a socket. `onLogout` closes it **and** drops every registered handler.

## Usage

```dart
final socket = SocketService.to;

// Optional config — set before the first connect().
socket.namespace = '/chat';
socket.maxReconnectAttempts = 20;                       // null = forever
socket.authPayloadBuilder = (t) => {'Authorization': 'Bearer $t'};

socket.connect();                                       // token from CacheManager
socket.connect(token: freshToken, query: {'room': '42'});
```

Subscribe and emit from a controller:

```dart
class ChatController extends GetxController {
  SocketService get socket => SocketService.to;
  final List<SocketSubscription> _subs = <SocketSubscription>[];
  final RxList<String> messages = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _subs.add(
      socket.on<Map<String, dynamic>>('message', (data) {
        messages.insert(0, '${data['text']}');
      }),
    );
    socket.connect();
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }

  void send(String text) => socket.emit('message', {'text': text});

  Future<void> ping() async {
    final ack = await socket.emitWithAck('ping', {'at': DateTime.now().toIso8601String()});
    devPrint('$ack');
  }
}
```

Bind the status in a screen:

```dart
Obx(() => Text(controller.socket.status.value.label.tr))
Obx(() => Icon(controller.socket.status.value.isConnected ? LucideIcons.wifi : LucideIcons.wifiOff))
```

### API

| Member | Notes |
| --- | --- |
| `status` | `Rx<SocketStatus>` — the only thing the UI should bind to. |
| `lastError`, `reconnectAttempts` | `RxString` / `RxInt`, reset on a successful connect. |
| `isConnected`, `socketId`, `resolvedUrl` | Plain getters, safe before the first connect. |
| `connect({token, query})` | Idempotent: a live socket on the same host **and** token is kept. |
| `disconnect()` | Closes the socket, keeps handlers; `connect()` resumes them. |
| `onLogin(token)` / `onLogout()` | Rebuild with a new token / close and forget everything. |
| `awaitConnected({timeout})` | `Future<bool>`; false on timeout. |
| `on<T>(event, handler, {decode})` | Returns a `SocketSubscription`; call `cancel()`. |
| `once<T>(...)` | Same, self-cancelling after the first payload. |
| `off(event)` / `clearSubscriptions()` | Bulk removal. |
| `emit(event, [data])` | socket.io buffers while offline and flushes on connect. |
| `emitWithAck(event, data, {timeout})` | `Future<dynamic>`; times out instead of hanging. |

Tunables (set before the first `connect()`): `baseUrl`, `namespace`, `transports`, `reconnectDelay`, `reconnectDelayMax`, `connectTimeout`, `maxReconnectAttempts`, `extraHeaders`, `authPayloadBuilder`, `debugLogging`.

## Notes and gotchas

- **Reconnect backoff is the socket.io manager's own**, not hand-rolled: `reconnectDelay` doubles on each attempt up to `reconnectDelayMax`, with a `0.5` randomization factor. Defaults are 1 s → 30 s, unlimited attempts. After `reconnect_failed` (only reachable with `maxReconnectAttempts` set) the status goes to `error` and you must call `connect()` again.
- **The token goes out twice**, because server contracts differ: as `Authorization: Bearer <token>` in `extraHeaders`, and as the CONNECT auth payload `{'token': ...}`. The auth payload comes from a callback that socket.io runs on *every* handshake, so reconnects always carry the current token. Headers are baked in when the socket is built — that is why `onLogin()` rebuilds rather than reconnects. Override `authPayloadBuilder` if your server expects a different shape.
- **Handlers outlive the socket.** `on<T>()` stores the wrapped handler in a registry, re-attaches it whenever the socket is rebuilt, and detaches it on `cancel()`. Registering before `connect()` is fine and is the recommended order.
- **`on<T>` is a cast, not a parser.** Payloads that are already `T` pass through; a `Map` coerces to `Map<String, dynamic>`; a single-element `List` is unwrapped. Anything else throws a `FormatException` that is caught and logged rather than crashing the socket. Pass `decode:` for real deserialisation: `socket.on<ChatMessage>('message', handler, decode: (raw) => ChatMessage.fromJson(raw))`.
- **Transports default to `['websocket']`** — no HTTP long-polling handshake. If your server requires the polling upgrade path, set `SocketService.to.transports = ['polling', 'websocket'];`. Note that on Flutter Web the browser ignores `extraHeaders` on a WebSocket, so web builds must rely on the auth payload or a query parameter.
- **Logging** goes through `devPrint(tag: 'Socket')` and is gated by `debugLogging`, which defaults to `kDebugMode`. With it on, every inbound event name is logged via `onAny` — payloads are not, so tokens in messages are not printed.
- `emit()` before `connect()` is dropped with a log line (there is no socket to buffer into). `emit()` *after* `connect()` but while offline is buffered by socket.io and flushed on the next connect.
- Reserved event names (`connect`, `connect_error`, `disconnect`, `disconnecting`, `newListener`, `removeListener`) cannot be emitted — socket.io throws. Subscribe to connection state through `status` instead.
- Verified against `socket_io_client 3.1.6` in the local pub cache (`io()`, `OptionBuilder`, `setAuthFn`, `setExtraHeaders`, `Socket.on/off/emit/emitWithAckAsync/dispose`, and the `onConnect` / `onReconnectAttempt` / `onReconnectFailed` extension helpers).

## Why it is not in core

Most apps built from this template never open a socket, and the template should not carry a transport — plus its reconnect and auth policy — that only chat- and presence-style products use.
