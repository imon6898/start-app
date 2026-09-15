# observability

Three things the template's `devPrint` cannot do: **levels and fields** you can query, a **trace id**
that ties a client call to the server spans it caused, and **real frame timings** so "the app feels
slow" becomes a number. Counters are mirrored into `Rx` so a debug overlay can render them.

**Read this first.** This module produces *signals*. It ships no backend, no dashboard and no
uploader — the default sink writes to the console. Everything here is only as useful as the place you
send it (a log collector, an OpenTelemetry-aware API gateway, your APM). Two honest consequences:

1. **`traceparent` is inert unless your backend propagates it.** The client is the root of the trace.
   If the server drops the header, you have a random hex string and nothing to join it to.
2. **Debug-build numbers are fiction.** Frame timings in a debug build are 2–10× slower than release.
   Measure in `--profile`.

It pairs with **crash_analytics** and does not overlap it: that module owns error *reporting*
(Sentry, `FlutterError`/`runZonedGuarded` hooks, its own scrubber); this one owns logging, tracing and
frame timing. Neither installs the other's hooks.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/observability/app_logger.dart` | `AppLogger` — `trace/debug/info/warn/error`, structured fields, redaction, sink fan-out. Plus `LogSink`, `ConsoleLogSink`, `MemoryLogSink`. |
| `lib/app/services/observability/log_record.dart` | `LogLevel`, `LogRecord` — one immutable, already-redacted record with `toJson()` / `toJsonLine()` / `toLine()`. |
| `lib/app/services/observability/log_redactor.dart` | `LogRedactor` — the PII/secret rules. Everything a record carries passes through it before any sink sees it. |
| `lib/app/services/observability/trace_interceptor.dart` | `TraceContext` (W3C `traceparent` build/parse) and `TraceInterceptor` (Dio interceptor: header per request, one structured line per call). |
| `lib/app/services/observability/perf_monitor.dart` | `PerfMonitor` — jank from `SchedulerBinding.addTimingsCallback`, first-frame and time-to-interactive, named spans. |
| `lib/app/services/observability_service.dart` | `ObservabilityService` — optional `GetxService` holding every counter as `Rx`, published on a throttle. |
| `lib/app/widgets/feedback/observability_overlay.dart` | `ObservabilityOverlay` — developer HUD: a pill that expands into the full counter panel. Debug/profile only. |
| `test/unit/observability_test.dart` | 43 tests: redaction rules, level filtering, the `traceparent` shape and parser, replay/span behaviour against a fake Dio adapter, jank classification with synthetic `FrameTiming`s, spans, TTI, service counters. No network. |

## Install

```bash
dart run tool/add_module.dart observability
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the
project:

```bash
mkdir -p lib/app/services/observability
cp modules/observability/lib/app/services/observability/log_record.dart        lib/app/services/observability/
cp modules/observability/lib/app/services/observability/log_redactor.dart      lib/app/services/observability/
cp modules/observability/lib/app/services/observability/app_logger.dart        lib/app/services/observability/
cp modules/observability/lib/app/services/observability/trace_interceptor.dart lib/app/services/observability/
cp modules/observability/lib/app/services/observability/perf_monitor.dart      lib/app/services/observability/
cp modules/observability/lib/app/services/observability_service.dart           lib/app/services/
cp modules/observability/lib/app/widgets/feedback/observability_overlay.dart   lib/app/widgets/feedback/
cp modules/observability/test/unit/observability_test.dart                     test/unit/
```

### pubspec.yaml

Nothing to add:

```yaml
# dio, get and lucide_icons_flutter are already in the template core.
```

### Platform config

None. No native code, no permissions, no `.env` keys. The one exception: if you point a sink at an
HTTP collector, Android release builds need `INTERNET` (the template manifest declares no
permissions):

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Wiring

Every piece is independent and degrades to a no-op, so install the parts you want. The blocks below
were applied verbatim to a clean checkout: `flutter analyze` → **No issues found**, `flutter test` →
**88 passed**.

### 1. `lib/bootstrap.dart` — the logger, the counters, the frame monitor

Add the imports (`get` is **not** imported by `bootstrap.dart` today, so it has to go in):

```dart
import 'package:get/get.dart';

import 'app/core/config/app_flavor.dart';
import 'app/services/observability/app_logger.dart';
import 'app/services/observability/perf_monitor.dart';
import 'app/services/observability_service.dart';
```

Then, inside `runZonedGuarded`, immediately after `await CacheManager.init();`:

```dart
    Get.put(ObservabilityService(), permanent: true);
    AppLogger.context['flavor'] = AppFlavor.name;
    PerfMonitor.start();
```

`AppLogger.context` is merged into every record — that is the place for the build number, the flavor
and (after sign-in) the opaque user id. Never put an email or a phone number there; it would be
redacted anyway.

### 2. `lib/bootstrap.dart` — route the error handlers into the logger

Optional, and mutually exclusive with keeping `devPrint` there. Replace the `FlutterError.onError`
body:

```dart
    FlutterError.onError = (details) {
      AppLogger.error(
        details.exceptionAsString(),
        logger: 'flutter',
        error: details.exception,
        stack: details.stack,
      );
    };
```

and the `runZonedGuarded` handler on the last line of `bootstrap()`:

```dart
  }, (error, stack) => AppLogger.error('uncaught', error: error, stack: stack));
```

**Then delete the now-unused `import 'app/services/domain/dev_tools.dart';`** — `unused_import` is an
error in this repo's lint set, so leaving it breaks the build.

If **crash_analytics** is installed, leave its `CrashService` lines in these handlers alone. Two
reporters in one handler is fine; two *console* writers for the same line is just noise.

### 3. `lib/app/services/domain/api_service.dart` — tracing

Add the import next to the other relative ones:

```dart
import '../observability/trace_interceptor.dart';
```

Then in the `ApiService` constructor, after the closing `);` of the token-refresh
`_dio.interceptors.add(InterceptorsWrapper(...))` block and before the `if (kDebugMode) {` logger
block:

```dart
    // traceparent per request + one structured line per call.
    _dio.interceptors.add(TraceInterceptor());
```

To tune it:

```dart
    _dio.interceptors.add(
      TraceInterceptor(
        sampleRate: 0.2,                                   // flags byte: 20% marked sampled
        slowRequestThreshold: const Duration(seconds: 1),  // slower -> warn + slow counter
        logger: 'http',                                    // the `logger` field on each record
      ),
    );
```

Order with the other interceptors does not matter for correctness — it only changes whether the
`traceparent` is stamped before or after another interceptor rewrites the request. Register it after
the refresh wrapper and it will tag the refresh retry too.

### 4. `lib/app/app.dart` — the debug overlay

```dart
        builder: ObservabilityOverlay.builder(),
```

with

```dart
import 'widgets/feedback/observability_overlay.dart';
```

`GetMaterialApp` has **one** `builder` slot. If `connectivity_banner` or `biometric_lock` already
claimed it, compose instead of replacing:

```dart
builder: (context, child) =>
    ObservabilityOverlay(child: OfflineBanner.builder()(context, child)),
```

### 5. Optional — make time-to-interactive mean something

`PerfMonitor` reports the first *frame* by itself. "Interactive" is a product decision, so you mark
it: call this once, from the first screen that has finished loading the content the user came for.

```dart
// In the controller, after the first real data has landed:
PerfMonitor.markInteractive(route: AppRoutes.HomeScreen);
```

Only the first call counts; later calls are ignored.

### Bindings and routes

Nothing goes in `ViewModelBinding` — `ObservabilityService` is a `GetxService`, not a screen
controller, so `test/guardrails/bindings_test.dart` does not ask for it. No routes are added. Every
static reporter no-ops while the service is unregistered, so tests that skip `bootstrap()` keep
passing.

## Usage

### Logging

```dart
AppLogger.info('order placed', logger: 'orders', fields: {'order_id': 4821, 'items': 3});
AppLogger.warn('cache miss', logger: 'orders', fields: {'key': 'orders:page:1'});

try {
  await repo.fetchOrders();
} catch (e, s) {
  AppLogger.error('fetch orders failed', logger: 'orders', error: e, stack: s);
}
```

Output from the default sink (one line, newlines added here for readability):

```json
{"ts":"2026-09-15T09:21:04.412Z","level":"info","logger":"orders","msg":"order placed",
 "flavor":"dev","order_id":4821,"items":3}
```

Level threshold:

```dart
AppLogger.minLevel = LogLevel.warn;   // default: info in release, debug otherwise
```

Dropped records are counted (`droppedLogCount`) and never formatted, so a `trace` call in a hot loop
costs a comparison, not a `jsonEncode`.

### Sending logs somewhere real

`ConsoleLogSink` is the default and prints nothing useful in a release build beyond logcat/oslog.
Implement a sink for anything else:

```dart
class HttpLogSink implements LogSink {
  final List<LogRecord> _buffer = [];

  @override
  void write(LogRecord record) {
    _buffer.add(record);
    if (_buffer.length >= 50) unawaited(flush());
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = _buffer.map((r) => r.toJson()).toList();
    _buffer.clear();
    // A plain Dio, NOT ApiService: TraceInterceptor would log the log upload.
    await Dio().post('https://logs.example.com/ingest', data: {'records': batch});
  }
}

// bootstrap.dart
AppLogger.sinks = [const ConsoleLogSink(), HttpLogSink()];
```

`MemoryLogSink` keeps the last N records in RAM for a "send diagnostics" button:

```dart
final diagnostics = MemoryLogSink(capacity: 300);
AppLogger.sinks = [const ConsoleLogSink(), diagnostics];
// later
final text = diagnostics.records.map((r) => r.toJsonLine()).join('\n');
```

Call `await AppLogger.flush()` before a deliberate exit or on logout.

### Forwarding warnings to crash_analytics

If **crash_analytics** is installed, this gives every crash an HTTP + log trail. Records are already
redacted, so Sentry's own scrubber sees clean input:

```dart
class CrashBreadcrumbSink implements LogSink {
  @override
  void write(LogRecord record) {
    if (record.level.index < LogLevel.warn.index) return;
    CrashService.to.addBreadcrumb(
      record.message,
      category: record.logger,
      data: record.fields,
    );
  }

  @override
  Future<void> flush() async {}
}
```

### Tracing

Nothing to call — every `ApiService` request carries the header once the interceptor is installed:

```http
GET /api/v1/orders HTTP/1.1
traceparent: 00-4b7f0b6c7d0a4e1b9c3d8e2f1a5b6c7d-9f8e7d6c5b4a3210-01
```

Join several calls into one trace (a checkout flow, a screen's parallel fetches):

```dart
final traceId = TraceContext.generate().traceId;
final options = Options(extra: {TraceInterceptor.extraTraceId: traceId});
await Future.wait([
  dio.get('/cart', options: options),
  dio.get('/shipping', options: options),
]);
```

Show the id in an error so support can search for it:

```dart
if (error is DioException) {
  final traceId = TraceInterceptor.traceIdOf(error);
  showCustomSnackBar(
    context: Get.context!,
    type: SnackBarType.Failure,
    title: 'Something went wrong'.tr,
    description: traceId == null ? '' : 'Ref ${traceId.substring(0, 8)}',
  );
}
```

### Performance

```dart
// Time an async unit of work; the span closes even if it throws.
final orders = await PerfMonitor.span('load-orders', () => repo.fetchOrders());

// Or open and close by hand (e.g. across a navigation).
PerfMonitor.startSpan('checkout');
...
PerfMonitor.endSpan('checkout', fields: {'items': 3});

// Tighter budget on a 120Hz target.
PerfMonitor.frameBudget = const Duration(milliseconds: 8);
```

Every closed span logs `{"msg":"span","name":"load-orders","ms":214}` and lands in
`ObservabilityService.spanMs`.

### Reading the counters yourself

```dart
final observability = Get.find<ObservabilityService>();

Obx(() => Text(
      '${observability.jankPercent.toStringAsFixed(1)}% jank · '
      'p95 ${observability.p95FrameMs.value}ms · '
      '${observability.failedRequestCount.value} failed calls',
      style: CustomTextStyles.regular12,
    ));
```

| Rx field | Meaning |
| --- | --- |
| `framesObserved`, `jankFrames`, `jankPercent` | frames seen and how many missed `frameBudget` |
| `lastFrameMs`, `worstFrameMs`, `p50FrameMs`, `p95FrameMs` | frame cost now, worst ever, percentiles over the last 120 frames |
| `firstFrameMs`, `timeToInteractiveMs` | since `PerfMonitor.start()` |
| `requestCount`, `failedRequestCount`, `slowRequestCount`, `lastRequestMs`, `lastTraceId` | HTTP, fed by `TraceInterceptor` |
| `logCount`, `warnCount`, `errorCount`, `droppedLogCount`, `recentLogs` | logging; `recentLogs` keeps the last 50 records |
| `spanMs`, `openSpanCount` | last duration per named span |

## What the redaction strips, exactly

Nothing reaches a sink un-redacted. `AppLogger` scrubs the message, the stringified error and every
field **before** it builds the `LogRecord`.

**Field names** are matched two ways. A *token* match (the name is lowercased and split on `_`, `-`,
`.` and camelCase boundaries, then each token compared for equality):

```
auth  jwt  pwd  pin  otp  ssn  cvv  cvc  iban  card  mail  session
signature  address  lat  lng  latitude  longitude
```

and a *substring* match anywhere in the name:

```
token  authorization  authorisation  password  passwd  secret  credential
bearer  apikey  api_key  cookie  email  phone  mobile  msisdn
```

A match replaces the whole value with `[redacted]`. Token matching is why `user_pin` is redacted and
`spinner` is not — plain `contains` would have hit both.

**Values** that survive the key check are rewritten by regex:

| Pattern | Example | Becomes |
| --- | --- | --- |
| `Bearer <anything>` | `Bearer eyJhb...` | `Bearer [redacted]` |
| JWT (`eyJ…`.`…`.`…`) | `eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig` | `[redacted]` |
| email address | `a.user+tag@example.co.uk` | `[redacted]` |
| international phone | `+44 20 7946 0958` | `[redacted]` |
| nine or more consecutive digits | `0123456789` | `[redacted]` |

Nested maps and lists inside `fields` are walked to a depth of 4; deeper non-primitive values are
replaced wholesale rather than recursed into, which is also what stops a cyclic structure.

**What is *not* scrubbed:**

- **Stack traces.** Frames carry file paths and symbols, and rewriting them would break symbolication.
  Do not interpolate user data into an exception you rethrow.
- **The digit rule over-redacts.** Epoch-millis timestamps, long numeric ids and order numbers with
  nine or more digits become `[redacted]`. That is the price of catching an unformatted phone or card
  number. Tune `LogRedactor` if it hurts; the regexes are `static final` and in one file.
- **A local phone number without a `+` and with fewer than nine digits** (`020 7946 0958` has ten, so
  it is caught; `555-1234` is not). No regex catches every national format.
- **Free-form text you log yourself.** `AppLogger.info(userTypedMessage)` gets the regexes and nothing
  else. Log ids, not content.

## The `traceparent` header, exactly

```
00-4b7f0b6c7d0a4e1b9c3d8e2f1a5b6c7d-9f8e7d6c5b4a3210-01
│  │                                │                │
│  │                                │                └─ trace-flags: 01 sampled, 00 not
│  │                                └─ span-id: 8 random bytes, this one hop
│  └─ trace-id: 16 random bytes, the whole request tree
└─ version: always 00
```

- **Your backend has to continue the trace.** OpenTelemetry, Datadog, Sentry, Elastic APM and most API
  gateways parse `traceparent` natively; a hand-rolled server does not. Until the server reads the
  header and emits its own spans as children, the id correlates with nothing but your own log lines.
- **The client is always the root.** Each request starts a new trace unless you pass
  `extra: {TraceInterceptor.extraTraceId: ...}`. There is no incoming parent on a mobile app.
- **A replay gets a new span, same trace.** The token-refresh retry in `api_service.dart` and
  `api_resilience`'s backoff both call `_dio.fetch(options)` with the *same* `RequestOptions`. The
  interceptor detects the already-tagged request and mints a fresh span id under the original trace
  id, so a retry storm reads as one trace with N spans.
- **Sampling is advisory.** `sampleRate` only sets the flags byte; the request is still sent and still
  logged locally. Whether a backend honours `00` is the backend's business.
- **`parse()` is strict**: exactly `00`–`ff` hex fields of the right length, version `ff` rejected,
  all-zero trace or span id rejected, uppercase rejected (the spec mandates lowercase). Anything else
  returns `null` and the interceptor mints a fresh context instead of trusting it.
- Ids come from `Random()`, not `Random.secure()` — they are correlation handles, not secrets. They
  are still visible to every proxy, so never derive them from user data.

## How jank is measured

`SchedulerBinding.instance.addTimingsCallback` hands back a `FrameTiming` per frame, *after* the frame
is on screen. Cost is `buildDuration + rasterDuration` — the UI thread plus the raster thread — and a
frame over `frameBudget` (default 16ms, i.e. 60Hz) counts as jank.

- `vsyncOverhead` is logged but deliberately **not** counted: it is time the engine waited, not time
  your code spent.
- A frame over `freezeBudget` (700ms) is logged at `warn` every single time as `frame freeze`.
- Ordinary jank is **rate limited to one log line per `jankLogInterval`** (2s). A janky scroll produces
  hundreds of bad frames; logging each one would be its own performance problem. The *counters* still
  see every frame — only the log lines are throttled.
- `ObservabilityService` publishes frame counters into `Rx` at most every 500ms
  (`publishInterval`), because an overlay that rebuilt on every frame would be the jank it reports.
  `publishNow()` forces a publish; the overlay calls it on tap.
- Percentiles are nearest-rank over the last 120 frames (`windowSize`) — a couple of seconds of
  scrolling, not a session average.

## What this does NOT do

- **No backend, no dashboard, no uploader.** The default sink is the console. Without a collector this
  module is a nicer `print`.
- **Time-to-interactive excludes native startup.** The clock starts at `PerfMonitor.start()` inside
  `bootstrap()`, so process fork, Dart VM boot and engine init are already over. The number is good for
  *comparing builds of your Dart code*; it is not the number a store listing or a field measurement
  reports. For that, measure on the platform side (Android `reportFullyDrawn`, iOS launch metrics).
- **Debug numbers are not real numbers.** Assertions, unoptimised code and the debug raster path make
  frame timings 2–10× worse. Run `flutter run --profile` before believing anything.
- **Not a profiler.** There is no CPU sampling, no memory tracking, no shader-warmup analysis, no
  widget-rebuild attribution. When the overlay says "p95 34ms", DevTools' Performance view is the next
  step, not this module.
- **No Zone-based trace propagation.** `AppLogger.traceIdProvider` is a hook you fill in; a log line
  written inside a request does not automatically inherit that request's trace id. Pass `traceId:`
  explicitly when it matters.
- **Counters are per process.** Everything resets on restart; nothing is persisted. `recentLogs` holds
  50 records in memory and is never written to disk (a persisted log file is a data-retention decision,
  not a default).
- **Logging is not free.** Each emitted record does a handful of regex passes and, for the console
  sink, a `jsonEncode`. Do not log inside `build()` or a per-frame callback; raise `minLevel` in release
  if a hot path needs it.
- **It is not privacy compliance.** The redactor removes the obvious shapes. Whether shipping the
  remaining fields off-device is lawful, and to which processor, is a decision the code cannot make for
  you.

## Notes and gotchas

- `ConsoleLogSink` uses `devPrint` (dart:developer) in debug and `debugPrint` otherwise, because
  `devPrint` compiles out of release builds — the template's own helper is debug-only by design.
- `LogRecord.toJsonLine()` encodes non-encodable field values with `toString()` instead of throwing, so
  a stray `Duration` or `DateTime` in `fields` can never break a log call.
- A throwing sink is caught per record: the failure is reported through `devPrint` and the other sinks
  still get the line.
- `TraceInterceptor` logs **method, host, path, status and duration only** — never the query string,
  never a request or response body. Query strings routinely carry tokens and ids.
- Do not send your log batches through `ApiService`: `TraceInterceptor` would log the upload, which
  produces more logs. Use a bare `Dio` in the sink.
- `PerfMonitor` is static because the engine's timings callback list is process-wide. `PerfMonitor.stop()`
  removes the callback; `reset()` clears open spans and the one-shot first-frame / interactive flags.
- `PerfMonitor.start()` must run after `WidgetsFlutterBinding.ensureInitialized()` — `bootstrap()`
  already does that on its first line.
- The overlay's strings are intentionally **not** `.tr`. It is a developer tool, and adding keys for it
  would force an entry in every locale file (which `test/guardrails/localization_test.dart` enforces)
  for text no user ever sees.
- The overlay renders nothing when `ObservabilityService` is not registered, so it is safe to leave
  wired in a test run.
- Run the tests with `flutter test test/unit/observability_test.dart` — 43 tests, a fake
  `HttpClientAdapter`, synthetic `FrameTiming`s, no network and no sleeping.

## Why it is not in core

The template's `devPrint` is the right default: one line, no config, compiled out of release. This
module replaces it with a system that has opinions — a level threshold, a redaction list that will
sometimes redact too much, a header on every outbound request, and a frame callback that runs for the
life of the process. All three only pay off once there is somewhere to send the data, which is a
project decision and usually a paid one.

It also has to be *read* before it is trusted: a log pipeline that quietly ships a token, or a trace id
derived from user data, is worse than no observability at all. That is a deliberate opt-in, not a
default.
