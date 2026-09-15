# offline_first

An offline-first data layer. Every write lands in a local sqlite store **first** and is appended to a durable **outbox**; the outbox is replayed to the server whenever the device is online. The UI reads local rows only, so it never waits on the network and never shows a spinner for a write.

**Read this first.** The hard part of offline-first is not caching — it is replaying writes safely. A mutation can be sent, committed by the server, and have its response lost on the way back. The client cannot tell that apart from a request that never arrived. So every queued op carries a **client-generated UUID as its idempotency key**, generated once and reused on every replay for the life of that op. The server must de-duplicate on it. Without that, one dropped response becomes two orders, two charges, two accounts.

This module also **requires real server support** — `updated_at`, idempotent writes keyed on `op_id`, and tombstones for deletes. See [What the backend must provide](#what-the-backend-must-provide). Bolt it onto a backend that has none of those and it will lose and duplicate data.

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/services/sync/sync_service.dart` | `SyncService` — the engine. A `GetxService`: optimistic `save`/`delete`, outbox drain, pull, conflict dispatch, triggers, Rx state. |
| `lib/app/services/sync/sync_store.dart` | `SyncStore` — the persistence contract. The engine never touches SQL. |
| `lib/app/services/sync/drift/sync_database.dart` | Three drift tables: `sync_records`, `outbox_ops`, `sync_metas`. Needs codegen. |
| `lib/app/services/sync/drift/drift_sync_store.dart` | `DriftSyncStore` — the sqlite implementation. The only file that knows SQL. |
| `lib/app/services/sync/memory_sync_store.dart` | `MemorySyncStore` — in-memory store for tests and UI spikes. |
| `lib/app/services/sync/outbox_op.dart` | `OutboxOp` + `OutboxKind` — one pending mutation, `opId` is the idempotency key. |
| `lib/app/services/sync/sync_record.dart` | `SyncRecord` — an entity as the engine sees it: opaque JSON + `updatedAt` / `deleted` / `dirty`. |
| `lib/app/services/sync/sync_transport.dart` | `SyncTransport` + the sealed `SyncPushOutcome` (accepted / conflict / rejected / retry) and `SyncPullPage`. |
| `lib/app/services/sync/sync_conflict_resolver.dart` | `SyncConflictResolver` and four implementations: `LastWriteWinsResolver` (default), `PreferLocalResolver`, `FieldMergeResolver`, `ManualConflictResolver`. |
| `lib/app/services/sync/sync_backoff.dart` | `SyncBackoff` — full-jitter exponential backoff with a dead-letter threshold. |
| `lib/app/services/sync/sync_config.dart` | `SyncConfig` — the tunables. |
| `lib/app/services/sync/sync_status.dart` | `SyncStatus` — `idle` / `syncing` / `offline` / `error`. |
| `lib/app/widgets/feedback/sync_status_banner.dart` | `SyncStatusBanner` — ready-made strip bound to the Rx state, with a Retry action. |
| `lib/app/feature/notes/**` | The worked example entity: model, Style-A trio, `NotesSyncTransport`, controller, screen. Copy it per entity. |
| `test/unit/offline_first_test.dart` | 28 tests: backoff bounds, optimistic write, idempotency-key reuse across a replay, rollback, every resolver, dead-lettering, per-entity ordering, the offline gate, pull, tombstone retention. No drift, no sqlite, no network. |

## Install

```bash
dart run tool/add_module.dart offline_first
flutter pub get
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/services/sync/drift lib/app/feature/notes/{notes_models,notes_logic,notes_controllers,notes_presentation}
cp -R modules/offline_first/lib/app/services/sync/.      lib/app/services/sync/
cp -R modules/offline_first/lib/app/feature/notes/.      lib/app/feature/notes/
cp modules/offline_first/lib/app/widgets/feedback/sync_status_banner.dart lib/app/widgets/feedback/
cp modules/offline_first/test/unit/offline_first_test.dart                test/unit/
```

### pubspec.yaml

```yaml
dependencies:
  drift: ^2.20.0                 # resolves to 2.35.x today; pinned loose on purpose
  sqlite3_flutter_libs: ^0.5.24  # bundles the sqlite3 native library
  path_provider: ^2.1.5          # locates the database file
  uuid: ^4.5.1                   # the idempotency keys

dev_dependencies:
  drift_dev: ^2.20.0             # REQUIRED - the installer does not add these
  build_runner: ^2.4.13          # REQUIRED
```

The installer only writes the top-level `dependencies:` block, so **add the two dev dependencies by hand.** They are not optional: without them drift generates nothing and the project will not build.

### Codegen — do this before anything else

```bash
flutter pub get
dart run build_runner build
```

That writes `lib/app/services/sync/drift/sync_database.g.dart`. **Until it exists, `flutter analyze` reports errors** in `sync_database.dart` and `drift_sync_store.dart` — expected, not a broken module. Re-run `build_runner` after any edit to the table definitions. Commit the `.g.dart` or generate it in CI; either is fine, just pick one.

(Newer `build_runner` versions removed `--delete-conflicting-outputs` and ignore it with a warning. Plain `build` is correct.)

### Platform config

| Platform | What is needed |
| --- | --- |
| Android | `minSdk 21` or higher — `sqlite3_flutter_libs` requires it. No manifest change, no permission: the native library is bundled. |
| iOS | Nothing. sqlite3 is linked statically. |
| Android ≤ 6.0.1 | Loading `libsqlite3.so` can fail. Call `await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();` (from `package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart`) in `bootstrap()` before the first query. |

No `.env` keys. Hosts still come from `ApiConstant.activeBaseUrl`; the sync paths live in the module's own `NotesApiConst`.

## Wiring

Four core files change. All four snippets below were applied verbatim to a clean copy of this template: `flutter analyze` → 0 issues, `flutter test` → all guardrails pass.

### 1. `lib/bootstrap.dart` — register the service

Add the imports:

```dart
import 'package:get/get.dart';
import 'app/feature/notes/notes_logic/notes_sync_transport.dart';
import 'app/services/domain/api_service.dart';
import 'app/services/sync/drift/drift_sync_store.dart';
import 'app/services/sync/sync_service.dart';
```

Then inside `bootstrap()`, after `await CacheManager.init();` and **before** `ViewModelBinding().dependencies();`:

```dart
    // Offline-first: one store, one service, one transport per collection.
    final sync = Get.put(
      SyncService(store: DriftSyncStore(), isOnline: checkInternet),
      permanent: true,
    );
    sync.register(NotesSyncTransport.collection, NotesSyncTransport());
```

`checkInternet` is the top-level helper already in `api_service.dart` — reusing it means the engine never calls a transport while the radio is down, which is also what keeps `ApiService`'s offline snackbar (`Get.context!`) out of a background sync.

Create the `SyncDatabase` **exactly once**. `DriftSyncStore()` builds one for you; a second instance on the same file races and drift prints a warning about it.

To tune the engine:

```dart
    SyncService(
      store: DriftSyncStore(),
      isOnline: checkInternet,
      config: const SyncConfig(
        backoff: SyncBackoff(
          base: Duration(seconds: 2),        // first backoff ceiling
          max: Duration(minutes: 5),         // backoff cap
          maxAttempts: 8,                    // then the op is dead-lettered
        ),
        pushBatchSize: 50,                   // ops replayed per run
        pullPageSize: 200,
        maxPullPages: 20,                    // guard against an endless cursor
        tombstoneRetention: Duration(days: 30),
        coalescePendingUpdates: true,        // merge un-sent updates
        syncOnResume: true,
        syncOnReconnect: true,
      ),
    );
```

### 2. `lib/app/bindings/view_model_binding.dart` — REQUIRED

`test/guardrails/bindings_test.dart` fails on any unregistered controller under `lib/app/feature`, so this is not optional while the notes example is present.

```dart
import '../feature/notes/notes_controllers/notes_controller.dart';
```

```dart
    // Notes (offline_first example)
    _lazy<NotesController>(() => NotesController());
```

`SyncService` is **not** registered here — it is a `GetxService`, not a screen controller, so the guardrail does not ask for it.

### 3. Routes — optional, demo screen only

`lib/app/routes/app_routes.dart`:

```dart
  /// Offline-first worked example.
  static const String NotesScreen = '/notesScreen';
```

`lib/app/routes/app_pages.dart` — import and one entry:

```dart
import '../feature/notes/notes_presentation/notes_screen.dart';
```

```dart
    _page(AppRoutes.NotesScreen, () => const NotesScreen()),
```

Both or neither: `routes_test.dart` fails on a constant with no `GetPage`.

### 4. Translations — REQUIRED

`localization_test.dart` fails on a `.tr` literal with no `en_US` entry **and** on any locale whose key set differs. Paste this block at the end of the map in `lib/app/localization/locales/en_us.dart` (values mirror the keys):

```dart
  // Offline sync (offline_first)
  'Notes': 'Notes',
  'Note title': 'Note title',
  'Save': 'Save',
  'No notes yet': 'No notes yet',
  'Add one — it will sync when you are back online':
      'Add one — it will sync when you are back online',
  'Synced': 'Synced',
  'Syncing': 'Syncing',
  'Offline — saved on this device': 'Offline — saved on this device',
  'Sync failed': 'Sync failed',
  '@n pending': '@n pending',
  'Retry': 'Retry',
```

And the same keys in `lib/app/localization/locales/bn_bd.dart`:

```dart
  // Offline sync (offline_first)
  'Notes': 'নোট',
  'Note title': 'নোটের শিরোনাম',
  'Save': 'সংরক্ষণ',
  'No notes yet': 'এখনও কোনো নোট নেই',
  'Add one — it will sync when you are back online':
      'একটি যোগ করুন — অনলাইনে ফিরলে এটি সিঙ্ক হবে',
  'Synced': 'সিঙ্ক হয়েছে',
  'Syncing': 'সিঙ্ক হচ্ছে',
  'Offline — saved on this device': 'অফলাইন — এই ডিভাইসে সংরক্ষিত',
  'Sync failed': 'সিঙ্ক ব্যর্থ হয়েছে',
  '@n pending': '@n টি অপেক্ষমাণ',
  'Retry': 'আবার চেষ্টা করুন',
```

Deleting `lib/app/feature/notes/` and `sync_status_banner.dart` instead is also fine — then no translation keys are needed and the engine still stands alone.

### 5. Optional — sync the moment the radio returns

With the **connectivity_banner** module installed:

```dart
sync.attachConnectivity(ConnectivityService.to.isOnline.stream);
```

Without it the engine still syncs on app resume, on manual refresh, and on its retry timer — just not instantly on reconnect.

### 6. Optional — wipe on sign-out

The outbox holds one account's unsent writes. Never carry it across a session:

```dart
await Get.find<SyncService>().wipe();
```

### 7. Optional — send the idempotency key as a header

By default the key travels in the request **body** as `op_id`, because the template's `ApiService` exposes no per-request headers. If your server insists on `Idempotency-Key`, add a nullable `headers` parameter to `ApiService.post`:

```dart
  Future<dynamic> post(String endpoint, [dynamic params, Map<String, String>? headers]) async {
    ...
    response = await _dio.post(endpoint, data: params, options: Options(headers: headers));
```

then pass it from `NotesImpl.postOp`:

```dart
    final dynamic response = await ApiService().post(url, params, {
      'Idempotency-Key': params['op_id'] as String,
    });
```

## Usage

### Writing

```dart
final sync = Get.find<SyncService>();

// Create. The id is generated on the device, so the row is usable immediately.
final id = sync.newId();
await sync.save('notes', id: id, data: {'id': id, 'title': 'Buy milk'});

// Update.
await sync.save('notes', id: id, data: {'id': id, 'title': 'Buy oat milk'});

// Delete — writes a tombstone locally, queues the op.
await sync.delete('notes', id);
```

All three return as soon as the **local** write is committed. Nothing blocks on the network.

### Reading

```dart
final rows = await sync.read('notes');                 // one-shot
sync.watch('notes').listen(...);                       // live, emits on every change
final one = await sync.findOne('notes', id);
```

In a controller (this is what `NotesController` does):

```dart
_sub = sync.watch('notes').listen((rows) => notes.assignAll(rows.map(NoteModel.fromRecord)));
```

`NoteModel.pending` mirrors the row's `dirty` flag, so the list can mark unsent rows:

```dart
if (note.pending) Icon(LucideIcons.clock, size: R.sp(14), color: CustomColors.warning()),
```

### Syncing

```dart
await sync.syncNow();                // push then pull; concurrent calls share one run
await sync.syncNow(pull: false);      // drain the outbox only
await sync.retryFailed();             // revive dead letters, then sync
```

Pull-to-refresh is just `syncNow`:

```dart
RefreshIndicator(onRefresh: controller.refreshNotes, child: ...)
```

### The Rx state

```dart
Obx(() => Text(switch (sync.status.value) {
      SyncStatus.idle => 'Synced'.tr,
      SyncStatus.syncing => 'Syncing'.tr,
      SyncStatus.offline => 'Offline — saved on this device'.tr,
      SyncStatus.error => 'Sync failed'.tr,
    }));

sync.pendingCount.value    // live outbox depth (dead letters excluded)
sync.deadLetterCount.value // ops that gave up, or conflicts awaiting a human
sync.lastSyncedAt.value    // DateTime? — null until the first successful run
sync.lastError.value       // '' when healthy
sync.pendingConflicts      // RxList<SyncConflict>, only with ManualConflictResolver
```

Or drop the ready-made strip at the top of a screen body:

```dart
const SyncStatusBanner(),                      // hidden when idle and empty
const SyncStatusBanner(showWhenIdle: true),    // always visible
```

### Adding a second synced entity

1. Copy `notes_logic/notes_api_const.dart` and change the two paths.
2. Copy `notes_logic/notes_api_service.dart` — the Style-A trio, unchanged in shape.
3. Copy `notes_logic/notes_sync_transport.dart`, change `collection` and the Repo type.
4. Register it in `bootstrap.dart`:

```dart
sync.register(OrdersSyncTransport.collection, OrdersSyncTransport());
```

No migration and no codegen re-run: every entity shares the one `sync_records` table as opaque JSON.

### Choosing a conflict policy

```dart
sync.register('notes', NotesSyncTransport());                                  // LWW (default)
sync.register('notes', NotesSyncTransport(), resolver: const PreferLocalResolver());
sync.register('notes', NotesSyncTransport(), resolver: const ManualConflictResolver());

// Field-level merge — only safe when fields are genuinely independent.
sync.register('notes', NotesSyncTransport(), resolver: FieldMergeResolver(
  (key, local, remote) => key == 'title' ? local : remote,
));
```

With `ManualConflictResolver`, conflicts land in `pendingConflicts` and the local row stays dirty. Present both sides and apply the user's choice:

```dart
Obx(() => Column(children: sync.pendingConflicts.map((c) => Row(children: [
      Text(c.local.data['title'].toString()),
      Text(c.remote.data['title'].toString()),
      CustomButton(text: 'Keep mine'.tr,
          onPressed: () => sync.resolveConflict(c, const KeepLocal())),
      CustomButton(text: 'Keep theirs'.tr,
          onPressed: () => sync.resolveConflict(c, const KeepRemote())),
    ])).toList()));
```

## The outbox contract, exactly

**Writes go local first.** `save` computes the row, writes it with `dirty: true` and `updatedAt = now`, and appends an `OutboxOp`. The UI sees the change on the next stream tick. Nothing is awaited on the network.

**Each op carries one immutable idempotency key.** `opId` is a UUID v4 generated when the op is created, stored with it in sqlite, and sent as `op_id` in the request body. It is **never regenerated** — a replay after a timeout, a retry after a 500, a retry after the app was killed and restarted all send the same key. That is the whole safety property: the server can recognise the second arrival and return the first result instead of applying the write again. A test asserts it (`a replay after a timeout reuses the SAME op id`).

**Ordering is per entity.** Ops are drained oldest-first. If one op fails transiently, that entity is blocked for the rest of the run — replaying a later edit before an earlier one would reorder writes on the server. Other entities keep going, so one stuck row does not freeze the queue.

**Un-sent updates are coalesced.** A second `save` to the same row, while a never-transmitted update op is still queued, replaces that op's payload and keeps its id. A slider drag becomes one request, not two hundred. Only ops with `attempts == 0` that are not in flight qualify — an op that may already have reached the server is never rewritten, because reusing its key with a different body would be a lie.

**Transient failures back off with full jitter.** `delay = random(0, min(base * 2^attempt, max))`. Fixed backoff makes every client in an outage retry in lockstep and flatten the recovering server; the random spread is the point. After `maxAttempts` (8) an op is **dead-lettered**: kept, flagged, excluded from the drain so it cannot block anything, and counted in `deadLetterCount`. `retryFailed()` clears the flags.

**Permanent rejections roll back.** A `SyncPushRejected` (validation, 403, 404, 422) undoes the optimistic write from the op's `rollback` snapshot — or purges the row entirely if it never existed on the server. Rollback is skipped when newer ops for the same entity are still queued, because reverting would silently throw away an edit the user made after the failing one; the newer op wins and `lastError` carries the reason.

**Conflicts are resolved, then re-queued.** A `409` must carry the server's current row. The resolver's answer is applied as: `KeepRemote` → local row replaced, ops dropped; `KeepLocal` / merged → a **new** op is queued whose `base_updated_at` is the server's `updated_at`, so the next push is an intentional overwrite rather than another 409; `ManualResolution` → conflict parked, op dead-lettered, local edit untouched.

**Pull is cursor-based.** `pull(collection, since: lastPulledAt, cursor:)` asks for rows with `updated_at > since`, tombstones included. The next `since` is the **server's** `server_time`, not the device clock — a phone whose clock is five minutes fast would otherwise skip five minutes of changes. A remote row is written straight through when the local copy is clean; when the local copy is dirty or has queued ops, the resolver decides. A remote row older than a dirty local row is ignored — the pending push carries it.

**Tombstones are kept.** A delete writes `deleted: true` locally rather than removing the row, so the next pull cannot resurrect it. Tombstones older than `tombstoneRetention` (30 days) are purged after each pull.

**Triggers.** On reconnect (via `attachConnectivity`), on `AppLifecycleState.resumed`, on manual `syncNow`, and on a retry timer scheduled after any failed or incomplete run. All of them funnel into one run: concurrent `syncNow` calls share the same `Future`.

## What the backend must provide

Without these, this module cannot work correctly. This is not a nice-to-have list.

**1. A server-set `updated_at` on every row.** Monotonic, from the server clock, on every collection. Conflict detection and the pull cursor are both built on it. Client timestamps are unusable: phone clocks drift, and users change them.

**2. Idempotent writes keyed on `op_id`.** Store the key with its result for at least as long as a client might retry (days, not minutes — a phone can be offline for a week). On a repeat, return the original response and do not apply anything.

```
POST /sync/notes/push
{ "op_id": "b2c1...-4f9a-...", "kind": "update", "id": "9f2e...",
  "base_updated_at": "2026-09-14T10:00:00Z", "title": "Buy oat milk" }

200 { "record": { "id": "9f2e...", "title": "Buy oat milk",
                  "updated_at": "2026-09-15T09:12:03Z" } }
```

`kind` is `create` / `update` / `delete`. Returning the stored row in `record` is strongly recommended — it stamps the authoritative `updated_at` locally in the same round trip. `data`-wrapped envelopes (`{"data": {...}}`) are also accepted.

**3. `409` with the current row.** If `base_updated_at` does not match, reject with `409` and include the server's version:

```
409 { "record": { "id": "9f2e...", "title": "Server wins", "updated_at": "..." } }
```

A `409` without a record is treated as a transient failure and retried — there is nothing to resolve. If you do not implement optimistic concurrency at all, omit the check: the write then silently overwrites, which is last-write-wins on the server side.

**4. Tombstones.** A delete must remain readable as `deleted: true` (or `deleted_at`) with its own `updated_at`, for at least as long as a client may be offline. Hard-delete the row and every client that was offline at the time re-creates it on its next pull.

**5. A pull endpoint filtered by `updated_at > since`.**

```
GET /sync/notes/pull?since=2026-09-14T10:00:00Z&limit=200&cursor=...

200 { "changes": [ { "id": "...", "title": "...", "updated_at": "...", "deleted": false } ],
      "next_cursor": null,
      "server_time": "2026-09-15T09:12:03Z" }
```

`changes` / `records` / `items` are all accepted, as is a bare array. `server_time` is what makes the cursor skew-proof — omit it and the device clock is used instead. `next_cursor` is `null` on the last page.

**Status codes the transport acts on:** `200/201/204` accepted · `409` conflict · `408/425/429/5xx` retry (honouring `Retry-After` in seconds) · any other `4xx` permanent rejection.

## Limitations and caveats

- **Last-write-wins silently loses data.** The default resolver compares `updated_at` and keeps the newer **whole row**. Two devices editing *different* fields of the same row means the older edit vanishes — not merged, not flagged, no error, no log the user will ever see. This is the correct default for rows one user edits from one device at a time, and the wrong default for anything collaborative. Use `FieldMergeResolver` where fields are independent, or `ManualConflictResolver` where losing an edit is unacceptable. There is no policy that makes this problem disappear; a real merge needs CRDTs or operational transforms, which is a different and much larger module.
- **A tie goes to the server**, and a remote tombstone beats a newer local edit. Both are deliberate: re-creating a row someone deleted is worse than losing an edit.
- **Idempotency is the server's job.** `op_id` is a promise the client keeps. If the server does not de-duplicate on it, a retry after a lost response *will* double-apply, and nothing on the device can detect that.
- **The sqlite file is not encrypted.** It is plaintext on disk under Application Support. Encrypt sensitive fields before writing them, or keep them out of the offline store. A rooted or jailbroken device reads the file directly. `secure_storage` protects tokens, not this database.
- **The database is included in device backups.** On iOS, Application Support goes to iCloud/iTunes; unsynced rows therefore leave the device. Exclude the file or move it to a cache directory if that matters.
- **The outbox is per account.** Call `wipe()` on sign-out. Skip it and the next user replays the previous user's unsent writes under their own token.
- **`dirty` is row-level, not field-level.** The engine does not know *which* field changed, so a push sends the whole payload. That is what makes LWW the natural default, and what makes a true field merge require the resolver to reconstruct intent from values.
- **Tombstone retention must be shorter than the server's.** Purge a tombstone locally while the server still serves it and a full re-pull resurrects the row. 30 days is a guess, not a guarantee — match it to your server.
- **The retry timer is coarse.** After a failed run it schedules `max(minRetryDelay, backoff(consecutiveFailures))`. It does not read the earliest `nextAttemptAt` out of the queue, so a run may wake early and find nothing ready. Harmless, just not optimal.
- **Pull is not incremental inside a page.** A page's rows are applied one at a time, not in one transaction, so a crash mid-page leaves some rows applied. The cursor only advances after the whole collection is pulled, so the next run re-applies them — idempotently, because a pull is a write-through of server state.
- **No background sync.** Everything happens while the app is running. Syncing from a terminated app needs WorkManager / BGTaskScheduler, which is native work this module does not do.
- **`maxPullPages` (20) caps one run.** A first sync of a very large collection needs several runs. Raise it, or seed the store from a bulk endpoint.
- **The drift store is not multi-isolate.** `NativeDatabase.createInBackground` runs sqlite off the UI isolate, but one `SyncDatabase` instance is assumed. Two instances on the same file race; drift warns about it at construction.
- **This is not a conflict-free replicated data type.** It is an outbox plus a resolver. It makes offline writes *safe* and *ordered*; it does not make concurrent edits *correct*.

## Notes and gotchas

- **Codegen is a hard prerequisite.** A fresh install fails `flutter analyze` until `dart run build_runner build` has produced `sync_database.g.dart`. Everything else in the module is hand-written and compiles on its own — the engine has no drift import at all, which is why the 28 tests run without sqlite.
- **Pushes are always `POST`**, even for updates and deletes. `ApiService.post` is the only verb in the template that returns the error response; `get` / `patch` / `put` / `delete` swallow the `DioException` and return `null`, which would make a `409` indistinguishable from a timeout — and a conflict retried as a timeout loops until it dead-letters.
- **`ApiService.get/post` show an offline snackbar through `Get.context!`.** Wiring `isOnline: checkInternet` means the engine does not call a transport while offline, so that path is not hit during a background sync. If you drop the `isOnline` gate, the null-check throws inside `push`, the engine catches it and calls it a transient failure — correct, but noisy.
- **Widget tests.** `DriftSyncStore()` opens a real file through `path_provider`, which has no platform implementation under `flutter test`. `SyncService._boot()` catches that and sets `status = error` instead of letting it escape into `runZonedGuarded`, so `app_boot_test.dart` still passes. In your own tests inject `MemorySyncStore()` or `DriftSyncStore(SyncDatabase.memory())`.
- **Timestamps are stored as epoch millis**, not drift `dateTime()` columns. Drift's datetime storage mode is a project-wide build option, and this module must not depend on which one you chose. `SyncRecord.parseTimestamp` accepts ISO-8601, epoch seconds and epoch millis on the way in, because servers disagree.
- **One table for every entity.** Rows are opaque JSON in `sync_records`, keyed `(collection, id)`. Adding a synced entity needs no migration. The cost is no per-entity indexes and no SQL queries on entity fields — filter and sort in Dart, or add a typed drift table alongside for anything you need to query.
- **`SyncStatus.offline` is not an error.** It is the resting state of an offline-first app and the banner colours it as a warning, not a failure.
- **`register()` must run before the first `syncNow()`.** An op whose collection has no transport is skipped with a `devPrint`, not dropped.
- Run the tests with `flutter test test/unit/offline_first_test.dart`. They use `MemorySyncStore` and a scripted fake transport: no network, no sqlite, no sleeping beyond a few milliseconds. The same suite was also run unchanged against `DriftSyncStore(SyncDatabase.memory())` and passes, which is how the sqlite implementation is verified.

## Why it is not in core

Offline-first is a product decision, not a default. It changes what a write *means*: a save no longer succeeds or fails, it becomes eventually-consistent, and the UI has to show that. It adds a sqlite file, a codegen step, four packages, and — unavoidably — a class of bug where data quietly disagrees between devices. Most apps starting from this template talk to one backend over a decent connection and are better served by the plain `ApiService` call that either works or shows an error.

And it is the one module that **cannot be made to work from the client alone**. `updated_at`, idempotent writes and tombstones are server contracts. Shipping this in core would imply the template can make an app offline-capable, which it cannot; the backend has to be built for it first. So it stays an explicit, informed opt-in — with the worked `notes` entity as the pattern to copy and the caveats above as the price of admission.
