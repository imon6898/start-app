# api_resilience

A Dio interceptor that makes the app behave correctly when the server pushes back: duplicate GETs are coalesced, `429` is handled by honouring `Retry-After` (both header forms), transient failures are retried with full-jitter backoff **on idempotent requests only**, and a dead host is short-circuited instead of hammered.

**Read this first.** Rate limiting and abuse prevention are *server* responsibilities. A mobile client cannot enforce them — an attacker edits the app, or skips it and calls the API directly. This module does exactly two honest things:

1. **Be a well-behaved client**, so normal use never trips a limit (dedup, backoff, no retry storms).
2. **Degrade gracefully when the server does limit you** — a clear message and a live countdown instead of a spinner that never ends.

It protects **your server** and **your UX**. It does not protect the client. See [What this does NOT protect against](#what-this-does-not-protect-against).

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/domain/api_resilience_interceptor.dart` | `ApiResilienceInterceptor` — the Dio `Interceptor`: dedup, 429, retries, circuit breaker. |
| `lib/app/services/domain/retry_policy.dart` | `RetryPolicy` (pure decision helpers: `Retry-After` parsing, full-jitter backoff, idempotency, retryable statuses) and `ResilienceConfig` (the tunables). |
| `lib/app/services/domain/circuit_breaker.dart` | `CircuitBreaker` — per-host consecutive-failure counter with open / half-open / closed states, plus `CircuitOpenException`. |
| `lib/app/services/api_resilience_service.dart` | `ApiResilienceService` — optional `GetxService` mirroring the state into `Rx` so a screen can show a countdown. |
| `lib/app/widgets/feedback/api_resilience_banner.dart` | `ApiResilienceBanner` — ready-made banner bound to that service. |
| `test/unit/api_resilience_test.dart` | 32 tests: both `Retry-After` forms, jitter bounds, idempotency rules, breaker lifecycle, and the interceptor itself against a fake adapter. |

## Install

```bash
dart run tool/add_module.dart api_resilience
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/api_resilience/lib/app/services/domain/retry_policy.dart               lib/app/services/domain/
cp modules/api_resilience/lib/app/services/domain/circuit_breaker.dart            lib/app/services/domain/
cp modules/api_resilience/lib/app/services/domain/api_resilience_interceptor.dart lib/app/services/domain/
cp modules/api_resilience/lib/app/services/api_resilience_service.dart            lib/app/services/
cp modules/api_resilience/lib/app/widgets/feedback/api_resilience_banner.dart     lib/app/widgets/feedback/
cp modules/api_resilience/test/unit/api_resilience_test.dart                      test/unit/
```

### pubspec.yaml

Nothing to add:

```yaml
# dio, get and lucide_icons_flutter are already in the template core.
```

### Platform config

None. No native code, no permissions, no `.env` keys.

## Wiring

One core file changes: `lib/app/services/domain/api_service.dart`.

**1. Add the import** next to the other relative imports at the top:

```dart
import 'api_resilience_interceptor.dart';
```

**2. Add the interceptor** inside the `ApiService` constructor — immediately after the closing `);` of the existing token-refresh `_dio.interceptors.add(InterceptorsWrapper(...))` block, and before the `if (kDebugMode) {` logger block:

```dart
    // Dedup, Retry-After, jittered retries, circuit breaker.
    _dio.interceptors.add(ApiResilienceInterceptor(_dio));
```

Order matters. The refresh interceptor is registered first so it still sees `401` first; this interceptor never retries a `401`, so the two do not fight. It also skips dedup for any request carrying `extra['isRetry'] == true`, which is the flag the refresh retry already sets.

To tune it, pass a config:

```dart
    _dio.interceptors.add(
      ApiResilienceInterceptor(
        _dio,
        config: const ResilienceConfig(
          maxAttempts: 3,                                  // total tries, first one included
          baseDelay: Duration(milliseconds: 500),          // first backoff ceiling
          maxDelay: Duration(seconds: 8),                  // backoff cap
          maxRetryAfterWait: Duration(seconds: 60),        // longer 429 waits go to the UI
          failureThreshold: 5,                             // consecutive host failures -> open
          openDuration: Duration(seconds: 30),             // cooldown before the probe
        ),
      ),
    );
```

**3. Optional — the Rx state**, if you want a countdown in the UI. In `lib/bootstrap.dart` before `runApp`, or in `ViewModelBinding.dependencies()`:

```dart
Get.put(ApiResilienceService(), permanent: true);
```

Every reporter (`ApiResilienceService.reportRateLimit`, `.reportCircuit`) no-ops when the service is not registered, so skipping this step costs you only the UI state — the interceptor keeps working, and tests that skip `bootstrap()` keep passing.

Nothing goes in `ViewModelBinding` as a `lazyPut`: `ApiResilienceService` is a `GetxService`, not a screen controller, so `test/guardrails/bindings_test.dart` does not ask for it.

**4. Optional — the widget barrel.** `ApiResilienceBanner` can be imported directly. To reach it through `package:flutter_starter/app/widgets/widgets.dart`, add one line to `lib/app/widgets/feedback/feedback.dart`:

```dart
export 'api_resilience_banner.dart';
```

## Usage

Normal calls need no changes — `ApiService().get(...)` now dedups, retries and backs off on its own.

### Opting a POST into retries

Only do this when the endpoint is genuinely idempotent (the server dedups on an idempotency key, or the write is a no-op the second time):

```dart
await ApiService().post(ApiConstant.syncUri, params);         // never retried
_dio.post(url, data: params, options: Options(extra: {'idempotent': true})); // retried
```

### Opting out of dedup

Two identical GETs in flight at once normally share one network call. For a poll where you really want every request to hit the wire:

```dart
Options(extra: {'noDedup': true})
```

### Showing the countdown

```dart
// In the screen body, above the content:
const ApiResilienceBanner(),
```

Or read the state yourself:

```dart
final resilience = Get.find<ApiResilienceService>();

Obx(() {
  if (!resilience.isRateLimited.value) return const SizedBox.shrink();
  return Text(
    resilience.isWaitUnknown
        ? 'Please slow down and try again shortly'.tr
        : '${'Try again in'.tr} ${resilience.formattedTime}',   // 00:42
    style: CustomTextStyles.medium14,
  );
});
```

`countdownTime` / `formattedTime` are the same idiom as the 60-second OTP resend cooldown in `verify_otp_controller.dart`, generalised: a `Timer.periodic` ticking an `RxInt` down to zero. The difference is that the number comes from the server's `Retry-After`, not from a constant.

### Disabling a screen's action while limited

```dart
Obx(() => CustomButton(
      text: 'Refresh'.tr,
      onPressed: resilience.isRateLimited.value ? null : controller.refreshOrders,
    ));
```

### Reacting to an open circuit

```dart
if (error is DioException && error.error is CircuitOpenException) {
  final open = error.error as CircuitOpenException;
  showCustomSnackBar(
    context: Get.context!,
    type: SnackBarType.Failure,
    title: 'Server unreachable'.tr,
    description: '${'Retrying in'.tr} ${open.retryAfter.inSeconds}s',
  );
}
```

## Behaviour, exactly

**429 — the server sets the pace.** `Retry-After` is parsed in both legal forms: delay-seconds (`120`) and HTTP-date (`Wed, 21 Oct 2015 07:28:00 GMT`). The header value is respected as-is; no backoff of our own is layered on top. If the wait is `<= maxRetryAfterWait` (60s) and the request is idempotent, the interceptor waits and retries once more. Otherwise the error is surfaced immediately and the wait goes to the UI as "try again in 09:45" — the app never silently hangs for ten minutes. A `429` never counts as a circuit-breaker failure: the server is up, it is just saying no.

**Transient failures — full jitter.** `408/500/502/503/504` plus `connectionTimeout`, `sendTimeout`, `receiveTimeout` and `connectionError` are retried up to `maxAttempts` (3) with `delay = random(0, min(baseDelay * 2^attempt, maxDelay))`. Full jitter, not fixed backoff: if every client retried at exactly 1s, 2s, 4s, they would all hit the recovering server at the same instant — that is the thundering herd. The random spread is the whole point.

**Only idempotent requests are retried.** `GET`, `HEAD`, `OPTIONS`, or a request that explicitly opted in with `Options(extra: {'idempotent': true})`. **A blind POST retry can charge a card twice or create two accounts.** The response may have been lost on the way back after the server already committed the write; the client cannot tell that apart from a request that never arrived. So the default is: do not retry it.

**Dedup / in-flight coalescing.** An identical `GET` (method + full url + query) that arrives while another is on the wire does not fire a second request — it waits on the first and receives the same payload (its `response.extra['coalesced']` is `true`). This kills the double-tap and the rebuild-storm. Retries reuse the leader's slot rather than claiming a new one. The in-flight map and the default breaker are `static`, because this template constructs a new `ApiService()` — and a new `Dio` — per call; per-instance state would never coalesce anything. `ApiResilienceInterceptor.resetShared()` clears both.

**Circuit breaker.** After `failureThreshold` (5) consecutive transient failures to a host, the circuit opens and requests to that host fail fast with a `DioException` whose `error` is a `CircuitOpenException` — no socket is opened at all. After `openDuration` (30s) the circuit goes half-open and lets exactly one probe through: success closes it, failure reopens it for another full cooldown. State is per host, so a dead third-party API does not block your own.

**Non-retryable by design.** Every other `4xx` — `400`, `401`, `403`, `404`, `409`, `422` — fails on the first try. Retrying them cannot succeed, and a client that hammers `401` looks exactly like a credential-stuffing script to anything watching your logs.

## What this does NOT protect against

- **It is not a client-side rate limiter.** Nothing here stops a determined attacker from making as many requests as they want. They patch the app, use a rooted device, or drop the client entirely and `curl` your API. Enforce limits at the edge — gateway, WAF, or middleware — keyed by IP, user and endpoint.
- **It does not prevent abuse, scraping, credential stuffing or spam.** Those are server problems. This module only makes the *honest* client quieter.
- **It does not make your API idempotent.** The `idempotent: true` opt-in is a promise *you* make about an endpoint. If the server does not dedup on an idempotency key, retrying is still unsafe no matter what the flag says.
- **The dedup map and the default circuit breaker are per process and reset on app restart.** They have to be static: this template builds a fresh `ApiService()` (and therefore a fresh `Dio`) per call, so per-instance state would never see two duplicates or a failure streak. Call `ApiResilienceInterceptor.resetShared()` on sign-out if you want a clean slate. It is a politeness mechanism, not a quota.
- **Coalescing keys on method + url + query only.** Two concurrent identical GETs sent with different auth tokens would share one response. With one signed-in user that cannot happen; if your app multiplexes accounts over one process, pass `Options(extra: {'noDedup': true})`.
- **It cannot tell a real user from a script.** Nothing in a request proves the app is genuine. That is what attestation (Play Integrity / App Attest) is for — a separate concern, and also verified server-side.
- **`Retry-After` is trusted as given.** A hostile or misconfigured server can send a huge value; the `maxRetryAfterWait` cap is what keeps that from freezing the UI, but the request still fails.

## Notes and gotchas

- `Retry-After` parsing uses `dart:io`'s `HttpDate`, which covers IMF-fixdate, RFC 850 and asctime. RFC 850's two-digit year parses as year `0094`, which would look like "retry immediately", so any parsed date before the year 2000 is rejected as unparseable instead. RFC 7231 requires senders to use IMF-fixdate anyway.
- `retryAfterOf` reads the header off `DioException.response`; when it is absent the module does **not** invent a delay — the error is surfaced and `isWaitUnknown` is `true` so the UI can say "slow down" without a fake number.
- The interceptor calls `_dio.fetch(options)` to replay a request, which re-runs the whole interceptor chain, exactly like the existing token-refresh retry. Retried requests carry `extra['resilienceAttempt']`, which is also what stops a retry from deduping against itself.
- A cancelled request (`CancelToken`) is never retried.
- `DioExceptionType.unknown` is deliberately *not* treated as transient. Dio maps real socket failures to `connectionError`; `unknown` usually means a bug in a transformer or interceptor, and retrying that just repeats it.
- The module changes error *timing*, not error *shape*: `ApiService.get/post/...` still return what they always returned, so existing repos need no changes.
- Run the tests with `flutter test test/unit/api_resilience_test.dart` — they use a fake `HttpClientAdapter`, so there is no network and no sleeping beyond a couple of milliseconds.

## Why it is not in core

Most projects starting from this template talk to one friendly backend and never see a `429`. The interceptor adds real behaviour that must be understood before it is trusted — silent retries, a breaker that can refuse requests, and a dedup map that changes when a second identical call actually hits the network. That is a deliberate opt-in, not a default. The core `ApiService` stays a plain, predictable Dio wrapper.
