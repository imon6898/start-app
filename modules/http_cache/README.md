# http_cache

A Dio interceptor that caches HTTP responses **the way HTTP says to**, rather than inventing a TTL of its own: `ETag` / `If-None-Match` and `Last-Modified` / `If-Modified-Since` revalidation, `Cache-Control` freshness, `Vary`-aware cache keys, stale-while-revalidate, and a sqflite store with a byte cap and LRU eviction. A `304 Not Modified` is turned back into a `200` carrying the stored body — **no caller ever sees a 304 as an error**.

**Read this first: `Vary` is the reason this module exists.** A cache that keys only on the URL will hand a response generated for `Accept-Language: fr` to a request that asked for `en`, and — far worse — hand the response generated for one user's `Authorization` header to the next account signed in on that device. That is not a performance bug, it is a data-leak bug, and it is the default behaviour of almost every hand-rolled "just cache the JSON for 5 minutes" helper. This module:

1. Files every entry under a **primary key** of `method + canonical url + auth identity`.
2. Stores the response's `Vary` header names and the **selecting request header values**, then only reuses an entry whose selectors match the new request.
3. Refuses to store a `Vary: *` response at all.

Everything else — freshness, revalidation, SWR, eviction — is ordinary cache plumbing. The keying is the part that is dangerous to get wrong.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/domain/http_cache_policy.dart` | `HttpCachePolicy` (pure decisions: key building, identity fingerprint, `Vary` selection, header reads, HTTP-date parsing), `CacheControl` (the directive parser) and `HttpCacheConfig` (the tunables). No I/O. |
| `lib/app/services/domain/http_cache_store.dart` | `CacheEntry` (one stored response + its freshness maths), the `HttpCacheStore` contract, `MemoryHttpCacheStore`, `HttpCacheMetrics` (process counters), `HttpCacheStats` (what a settings screen shows) and `HttpCache` (the static store holder: `use`, `clear`, `stats`, `reset`). |
| `lib/app/services/domain/sqflite_http_cache_store.dart` | `SqfliteHttpCacheStore` — one sqflite table, byte cap, LRU eviction, disposable schema. |
| `lib/app/services/domain/http_cache_interceptor.dart` | `HttpCacheInterceptor` — the Dio `Interceptor` that ties it together. |
| `lib/app/services/http_cache_service.dart` | `HttpCacheService` — optional `GetxService` with `Rx<HttpCacheStats>`, `clear()` and `invalidate(urlPart)` for the `settings_ui` module. |
| `test/unit/http_cache_test.dart` | 60 tests: directive parsing, key building, `Vary` selection, freshness maths, LRU eviction, and the interceptor against a fake adapter. No plugin, no network. |

## Install

```bash
dart run tool/add_module.dart http_cache
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
cp modules/http_cache/lib/app/services/domain/http_cache_policy.dart       lib/app/services/domain/
cp modules/http_cache/lib/app/services/domain/http_cache_store.dart        lib/app/services/domain/
cp modules/http_cache/lib/app/services/domain/sqflite_http_cache_store.dart lib/app/services/domain/
cp modules/http_cache/lib/app/services/domain/http_cache_interceptor.dart  lib/app/services/domain/
cp modules/http_cache/lib/app/services/http_cache_service.dart             lib/app/services/
cp modules/http_cache/test/unit/http_cache_test.dart                       test/unit/
```

### pubspec.yaml

```yaml
dependencies:
  # http_cache module
  sqflite: ^2.4.2
```

Optional, only if you want to choose the database directory yourself (see [Where the database lives](#where-the-database-lives)):

```yaml
  path_provider: ^2.1.5
```

`dio` and `get` are already in the template core.

### Platform config

**None.** `sqflite` bundles its own Android (`sqflite_android`) and iOS/macOS (`sqflite_darwin`) implementations — no manifest entry, no plist key, no permission, no Gradle change. The database file lives in the app's own sandbox.

Web is not supported by `sqflite`. On web, skip wiring step 2 and the default `MemoryHttpCacheStore` is used instead.

## Wiring

Two core files change: `lib/app/services/domain/api_service.dart` and `lib/bootstrap.dart`.

### 1. The interceptor — `lib/app/services/domain/api_service.dart`

Add the import next to the other relative imports at the top:

```dart
import 'http_cache_interceptor.dart';
```

Then add the interceptor inside the `ApiService` constructor, immediately after the closing `);` of the existing token-refresh `_dio.interceptors.add(InterceptorsWrapper(...))` block:

```dart
    // Protocol cache: ETag/Last-Modified, Cache-Control, Vary, SWR.
    _dio.interceptors.add(HttpCacheInterceptor(_dio));
```

**Order matters, three ways** — see [Interceptor order](#interceptor-order) for the reasoning.

To tune it, pass a config:

```dart
    _dio.interceptors.add(
      HttpCacheInterceptor(
        _dio,
        config: const HttpCacheConfig(
          cacheableMethods: {'GET'},                        // GET only; see caveats
          cacheableStatusCodes: {200},                      // add 203/301/404 only if you mean it
          staleWhileRevalidate: Duration(seconds: 60),      // client window when the server sends none
          staleIfError: Duration.zero,                      // off; the server can still opt in
          defaultMaxAge: null,                              // no invented TTL
          maxStale: Duration(days: 7),                      // past this, delete instead of revalidate
        ),
      ),
    );
```

### 2. The persistent store — `lib/bootstrap.dart`

Add the imports:

```dart
import 'app/services/domain/http_cache_store.dart';
import 'app/services/domain/sqflite_http_cache_store.dart';
```

Then, right after `await CacheManager.init();`:

```dart
    // HTTP response cache: persistent, 8 MB, LRU. Falls back to memory.
    try {
      HttpCache.use(
        await SqfliteHttpCacheStore.open(maxBytes: 8 * 1024 * 1024),
      );
    } catch (e) {
      devPrint('HttpCache: sqflite open failed, using memory: $e');
    }
```

Skipping this step is safe. `HttpCache.store` lazily defaults to `MemoryHttpCacheStore`, so the interceptor works before — and without — bootstrap ever running; you just lose persistence across launches. That default is also what keeps `test/widget/app_boot_test.dart` from touching a `MethodChannel`.

### 3. Stable cache identity (optional, recommended)

By default the auth identity is a fingerprint of the `Authorization` header. When the token-refresh interceptor swaps in a new bearer token, the fingerprint changes and **every entry cached under the old token becomes unreachable** — not wrong, just orphaned until LRU reclaims it. To keep one user's namespace stable, set an explicit identity. In the token-refresh interceptor's `onRequest`, right after the `Authorization` line:

```dart
          // Keeps the cache namespace stable across token refreshes.
          options.extra[HttpCachePolicy.identityExtra] ??=
              CacheManager.getLoginEmail ?? '';
```

with

```dart
import 'http_cache_policy.dart';
```

Use whatever stable per-user id your backend returns — a user id is better than an email. An empty string falls back to the token fingerprint, so guests are fine. **Never use a value that is the same for two accounts**, which is the one way to reintroduce the bug this module exists to prevent.

### 4. The Rx service (optional)

For a settings screen that shows the size and hit rate. In `lib/bootstrap.dart` before `runApp`:

```dart
Get.put(HttpCacheService(), permanent: true);
```

Nothing goes in `ViewModelBinding`: `HttpCacheService` is a `GetxService`, not a screen controller, so `test/guardrails/bindings_test.dart` does not ask for it.

### 5. Offline reads (optional)

`ApiService.get()` starts with `if (!await checkInternet()) { … return null; }`, so **while offline the request never reaches Dio and the cache is never consulted**. To let a cached copy answer instead of a snackbar, replace that early return in `get()` with:

```dart
    //check internet connection
    if (!await checkInternet()) {
      // Offline: a cached copy beats a snackbar. 504 = nothing stored.
      try {
        return await _dio.get(
          endpoint,
          queryParameters: params,
          data: data,
          options: Options(headers: {'cache-control': 'only-if-cached'}),
        );
      } catch (_) {
        showCustomSnackBar(
          context: Get.context!,
          type: SnackBarType.Warning,
          title: 'No internet connection'.tr,
          description: 'Please check your internet connection'.tr,
        );
        return null;
      }
    }
```

`only-if-cached` serves a stored entry however stale it is and never opens a socket; with nothing stored it fails with a synthetic `504`, which the `catch` turns back into the original snackbar. Pairs well with the **connectivity_banner** module so the user can see the data is offline data.

## Usage

Nothing changes at the call site. `ApiService().get(...)` now revalidates and serves from cache on its own, and repos keep receiving the same `Response`.

### Telling a cache hit from a network response

```dart
final response = await ApiService().get(ApiConstant.ordersUri);   // your endpoint
if (response?.extra[HttpCachePolicy.fromCacheExtra] == true) {
  final seconds = response.extra[HttpCachePolicy.cacheAgeExtra] as int;
  devPrint('served from cache, ${seconds}s old');
}
```

| `response.extra` key | Constant | Means |
| --- | --- | --- |
| `fromCache` | `HttpCachePolicy.fromCacheExtra` | The body came from the store. |
| `servedStale` | `HttpCachePolicy.staleExtra` | Past its freshness lifetime. |
| `revalidated` | `HttpCachePolicy.revalidatedExtra` | The server answered `304`; this is fresh. |
| `staleOnError` | `HttpCachePolicy.staleOnErrorExtra` | The network failed and `stale-if-error` covered it. |
| `cacheAge` | `HttpCachePolicy.cacheAgeExtra` | Age in seconds (`int`). |

A cached response also carries `x-cache: HIT` and `statusMessage: 'OK (cached)'`.

### Showing "updating…" during a stale-while-revalidate hit

```dart
Obx(() => controller.isStale.value
    ? Text('Showing saved data, updating…'.tr, style: CustomTextStyles.medium12)
    : const SizedBox.shrink());
```

```dart
// In the controller, after the repo call:
isStale.value = response?.extra[HttpCachePolicy.staleExtra] == true;
```

### Opting a single request out

```dart
// Never read, never write — for a poll or a one-shot you always want live.
_dio.get(url, options: Options(extra: {HttpCachePolicy.noCacheExtra: true}));
```

### Forcing revalidation without losing the entry

Standard HTTP, no module API needed:

```dart
Options(headers: {'cache-control': 'no-cache'})     // revalidate, then reuse if 304
Options(headers: {'cache-control': 'only-if-cached'}) // never touch the network
```

### Invalidating after a write

The server usually cannot tell you that a `POST /orders` just invalidated `GET /orders`. Do it yourself:

```dart
await ApiService().post(ApiConstant.createOrderUri, params);  // your endpoint
await Get.find<HttpCacheService>().invalidate('/orders');     // drops matching entries
```

(`ordersUri` / `createOrderUri` are placeholders — the template ships no order endpoints.)

Without the service registered:

```dart
await HttpCache.store.invalidatePrefix('/orders');
```

### A settings screen

With the **settings_ui** module, point its hook at the cache — one line, in `ViewModelBinding` or the settings binding:

```dart
Get.find<SettingsController>().onClearCache = HttpCache.reset;
```

Or build your own row:

```dart
final cache = Get.find<HttpCacheService>();

Obx(() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${cache.stats.value.formattedSize} / ${cache.stats.value.formattedMaxSize}',
          style: CustomTextStyles.medium14,
        ),
        SizedBox(height: R.h(4)),
        Text(
          '${cache.stats.value.entryCount} ${'responses'.tr} · '
          '${cache.stats.value.formattedHitRate} ${'hit rate'.tr}',
          style: CustomTextStyles.regular12,
        ),
        SizedBox(height: R.h(12)),
        CustomButton(
          text: 'Clear cache'.tr,
          onPressed: cache.isBusy.value ? null : cache.clear,
        ),
      ],
    ));
```

`HttpCacheStats` exposes `entryCount`, `totalBytes`, `maxBytes`, `hits`, `misses`, `revalidations`, `staleServed`, `evictions`, `oldestStoredAt`, plus `hitRate` / `formattedHitRate` / `formattedSize` / `formattedMaxSize`.

### On sign-out

```dart
await HttpCache.reset();   // drops every stored response and the counters
```

The identity namespace already keeps accounts apart, so this is belt-and-braces — but a shared device is exactly where you want both.

## Interceptor order

Dio builds one FIFO chain and walks it in **registration order for `onRequest`, `onResponse` *and* `onError`** (`dio_mixin.dart`, `_dispatchRequest`). So the position of this interceptor is behaviour, not taste.

```dart
_dio.interceptors.add(InterceptorsWrapper(...));      // 1. token refresh (already in core)
_dio.interceptors.add(HttpCacheInterceptor(_dio));    // 2. this module
_dio.interceptors.add(ApiResilienceInterceptor(_dio)); // 3. api_resilience, if installed
if (kDebugMode) _dio.interceptors.add(PrettyDioLogger(...)); // 4. already in core
```

**After the token-refresh wrapper.** That wrapper's `onRequest` is what writes the current `Authorization` header. The cache reads that header to build the identity namespace, so running before it would key a signed-in request as `anon`.

**Before `ApiResilienceInterceptor`.** Three separate reasons:

- **A `304` is an error until this interceptor says otherwise.** Dio's default `validateStatus` rejects `304`, so it arrives in `onError`. If resilience ran first it would classify `304` as non-retryable, `_release` its in-flight dedup slot **with an error**, and every coalesced follower would get a `DioException` instead of the revalidated body. With the cache first, the `304` is resolved into a `200` and resilience never sees it.
- **A cache hit should cost nothing.** `RequestInterceptorHandler.resolve()` defaults to `callFollowingResponseInterceptor: false`, so a hit resolved inside `onRequest` skips every later interceptor entirely: no dedup slot claimed, no circuit-breaker attempt recorded, no socket.
- **Retries replay the whole chain.** `ApiResilienceInterceptor` retries via `_dio.fetch(options)`, which re-enters `HttpCacheInterceptor.onRequest`. Because the cache sits earlier, a retry can be answered from the store if the entry became usable in the meantime.

**Before the debug logger** is cosmetic: a cache hit resolves in `onRequest` and is never logged either way, so hits are silent in `PrettyDioLogger` regardless. The `devPrint` lines in the interceptor are how you see them.

One deliberate trade-off in that order: on a network failure, the cache's `onError` runs **before** resilience gets to retry, so if `stale-if-error` covers the entry the stale body is served immediately instead of after three backoff attempts. With the shipped default (`staleIfError: Duration.zero`) that only happens when the server explicitly sent `stale-if-error`, which is the server asking for exactly this. If you would rather exhaust retries first, register the two the other way round and accept the `304` caveat above — or keep `staleIfError` at zero and don't send the directive.

## Behaviour, exactly

**The cache key.** `METHOD canonical-url @identity`, then a `Vary` suffix. The canonical URL sorts query parameters by name, so `?a=1&b=2` and `?b=2&a=1` are one entry. The identity is `id:<value>` from `extra['cacheIdentity']`, else `tok:<16 hex>` — a two-pass FNV-1a fingerprint of the `Authorization`, `Cookie` or `X-Api-Key` header — else `anon`. The raw credential is never written to disk or into a key.

**`Vary`.** Header names are lowercased, sorted, de-duplicated, and hop-by-hop names are dropped. The *selecting values* are read from the request (case-insensitively) and stored with the entry, so several variants coexist under one primary key and the interceptor picks the one whose selectors match. A missing selecting header is recorded as empty, not skipped — `Accept-Language: en` and no `Accept-Language` at all are different entries. `Vary: *` is never stored.

**Freshness.** `max-age` wins; otherwise `Expires - Date`. Age follows RFC 9111: the larger of the `Age` header and the `Date`-to-arrival gap, plus residence time. Neither `max-age` nor `Expires` means "unknown", **not** "forever" — such a response is only stored if it has a validator, and it is always revalidated.

**`Cache-Control`, request and response.** `no-store` skips read *and* write on either side. `no-cache` stores but always revalidates first. `must-revalidate` additionally forbids ever serving stale, including SWR and `stale-if-error`. `max-age=0` stores and revalidates. Negative values clamp to `0`. `private` is noted and otherwise ignored — an app *is* a private cache. `s-maxage` is ignored for the same reason. `immutable` is parsed but not yet acted on. Unknown directives are ignored, never fatal. Multiple `Cache-Control` header lines behave as one comma-joined header, and quoted values (`max-age="42"`) parse.

**Revalidation.** A stale entry with an `ETag` sends `If-None-Match`; with a `Last-Modified` it sends `If-Modified-Since` (both, if both exist). A `304` bumps `HttpCacheMetrics.revalidations`, merges the re-sent headers into the stored ones (`Content-Length` excluded), refreshes the freshness clock, and resolves as a `200` with `extra['revalidated'] == true`. A `200` replaces the entry.

**Stale-while-revalidate.** Past freshness but inside the SWR window, the stored body is returned **immediately** and a silent copy of the request goes out behind it (`extra['_httpCacheBackground']`, so it does not read the cache it is refreshing). The refresh is keyed, so a burst of screens sharing one stale entry triggers exactly one. The window is the server's `stale-while-revalidate` when present, otherwise `HttpCacheConfig.staleWhileRevalidate` (60s default) — the server always wins, and `must-revalidate` / `no-cache` disable it outright.

**Stale-if-error.** On `connectionError`, any timeout, or `500/502/503/504`, an entry inside the `stale-if-error` window is served with `extra['staleOnError'] == true`. The client-side default window is `Duration.zero` — off — so this only fires when the server asked for it. Without a covering window the error propagates unchanged.

**`only-if-cached`.** Serves whatever is stored however stale, and never opens a socket. Nothing stored → a `DioException` carrying a synthetic `504`.

**What gets stored.** `GET` (by default), status `200` (by default), not a stream response, not `no-store` on either side, not `Vary: *`, has either freshness info or a validator, and fits under the store cap. Bodies are stored as JSON, text or raw bytes and rebuilt as a **new object on every read**, so a caller mutating the decoded map cannot corrupt the cache.

**Eviction.** `put` writes, then deletes least-recently-used rows until total `size` is under `maxBytes` (8 MB default), returning the count into `HttpCacheMetrics.evictions`. `size` is body bytes plus stored header bytes. A single entry larger than the whole cap is not stored at all. Serving from cache updates `last_used_at` and `hits`, so LRU reflects reads, not just writes.

**Death.** Past `freshness + maxStale` (7 days default) an entry is deleted on sight instead of revalidated — it stops sending pointless conditional requests for data nobody wants.

**Failures are never fatal.** Every store read, write, touch and delete is wrapped: a database error is `devPrint`ed and the request goes to the network. A broken cache degrades to no cache.

### Where the database lives

`SqfliteHttpCacheStore.open()` defaults to `getDatabasesPath()` — on Android the app's `databases/` folder, on iOS the `Documents` directory. **On iOS that means the cache is included in iCloud/iTunes backups**, which is wasteful for disposable data. To put it somewhere the OS may reclaim, add `path_provider` and pass a directory:

```dart
final dir = await getApplicationCacheDirectory();   // Library/Caches on iOS
HttpCache.use(
  await SqfliteHttpCacheStore.open(directory: dir.path),
);
```

Be aware of the other side of that trade: iOS may delete `Library/Caches` under storage pressure while the app is not running, and `sqflite` will simply create a fresh database next launch.

## What this does NOT do

- **It is not an offline mode.** It replays responses the server said were reusable. It has no local writes, no outbox, no conflict resolution, and no way to answer a request that was never made before. That is the **offline_first** module's job; the two do not share storage.
- **It does not cache POST/PUT/PATCH/DELETE**, and you should think hard before adding them to `cacheableMethods`. Replaying a write response is how an app shows a stale total after a successful update.
- **It does not know that a write invalidated a read.** HTTP has no reliable client-side signal for that. Call `HttpCacheService.invalidate(...)` after mutations, or have the server send short `max-age` values on the lists that change.
- **`invalidatePrefix` is a substring match, not a prefix match.** `MemoryHttpCacheStore` uses `contains`; `SqfliteHttpCacheStore` uses `LIKE '%…%'`, which also means `%` and `_` in your argument are SQL wildcards. Pass a plain path fragment like `/orders`. The name is historical — treat it as "invalidate anything whose key mentions this".
- **The stored body is not encrypted.** It is a SQLite file in the app sandbox, readable on a rooted or jailbroken device and by anything with a backup of it. Do not cache responses you would not put in `SharedPreferences`; the honest answer for those is `Cache-Control: no-store` **on the server**, which this module obeys. `secure_storage` protects tokens, not response bodies.
- **The identity fingerprint is not a security boundary.** It is a 64-bit non-cryptographic hash used to *namespace* entries. Collisions are astronomically unlikely but not impossible, and nothing stops a caller from passing the same `cacheIdentity` for two accounts. It prevents accidents; it does not resist an attacker who already controls the process.
- **It cannot rescue a server that sends no cache headers.** With neither freshness nor a validator, nothing is stored and every request goes to the network. `HttpCacheConfig.defaultMaxAge` lets you invent a TTL anyway — that is a guess about your API's semantics, which is why it is `null` by default.
- **Counters are per process.** `HttpCacheMetrics` resets on app restart, so a hit rate shown in settings describes this session, not all time. The entry count and byte size come from the store and do persist.
- **It does not compress.** Bodies are stored as received (after Dio's transformer), so a 1 MB JSON list costs about 1 MB of the cap.
- **`extra['cacheIdentity']` is trusted as given.** If you wire it to something that is not per-user, you have rebuilt the leak described at the top of this README.

## Notes and gotchas

- **`ApiService.get()`'s internet check runs before Dio.** Until you apply [wiring step 5](#5-offline-reads-optional), a cached response is unreachable while offline — the core returns `null` with a snackbar before the interceptor chain is ever entered. This surprises people; it is the single most common "the cache doesn't work" report.
- **A token refresh orphans the old namespace** unless you set an explicit `cacheIdentity` ([wiring step 3](#3-stable-cache-identity-optional-recommended)). Nothing incorrect is served; the cache just goes cold.
- **`HttpCache.store` and `HttpCacheMetrics` are static**, because this template constructs a new `ApiService()` — and a new `Dio` — per call. Per-instance state would hold nothing. `HttpCache.reset()` clears both; `HttpCacheInterceptor.resetShared()` clears the in-flight background-refresh set (useful between tests).
- **Tests pass a store explicitly**: `HttpCacheInterceptor(dio, store: MemoryHttpCacheStore())` bypasses the static holder entirely, so unit tests never share state.
- **`SqfliteHttpCacheStore` is not covered by the shipped tests.** It needs the native plugin, so it only runs on a device or simulator; the 60 tests exercise `MemoryHttpCacheStore` and a fake `HttpClientAdapter`. Adding `sqflite_common_ffi` as a dev dependency would let you run the same suite against the SQL store — that package is **not** in this project's lockfile, so treat the SQL path as verified by compilation and by hand, not by CI.
- **The schema is disposable.** A version bump `DROP`s the table and recreates it rather than migrating. It is a cache; there is nothing worth migrating.
- **`maxBytes` caps the accounted entry size, not the file.** SQLite pages, indexes and free lists live outside the count, so the `.db` file will be somewhat larger than the cap. Leave headroom if you are tight on storage.
- **`HttpDate` parsing.** `Date`, `Expires` and friends go through `dart:io`'s `HttpDate`, falling back to `DateTime.tryParse`. An unparseable value is treated as absent rather than as an error.
- **`If-Modified-Since` is echoed back verbatim** from the stored `Last-Modified` string, which is what RFC 9110 asks for — no reformatting, no clock arithmetic.
- **A 304 handled in `onResponse`** (only reachable if you widen `validateStatus` to accept 304) is handled too, and continues down the chain as a `200`.
- Run the tests with `flutter test test/unit/http_cache_test.dart` — 60 tests, no network, no plugin, no sleeping beyond ~30 ms for the background-refresh assertion.
- This module adds **no user-facing strings**, so it needs no `lib/app/localization/locales/` entries. The snippets in this README do; add those to `en_US` if you paste them.

## Why it is not in core

Caching changes *what data the app shows*, which is a much bigger promise than the rest of the template makes. A core `ApiService` that silently returns a 40-second-old list is a debugging trap for anyone who did not know the cache was there — and the behaviour is only correct if the backend actually sends honest `Cache-Control`, `ETag` and `Vary` headers. Many don't.

It is also the module where a mistake is a security incident rather than a slow screen: get the key wrong and you hand one user another user's data. That is worth an explicit, informed opt-in — a decision made per project, after reading the caveats above — not a default the template turns on for you. The core `ApiService` stays a plain, predictable Dio wrapper that always talks to the server.
