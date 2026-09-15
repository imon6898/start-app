# ai_assistant

A Claude API client for Flutter: streaming chat, a capped tool-use loop, and a ready-made chat screen. Built entirely on the template's existing `dio` — **it adds no packages at all**.

**Read this first.** There is no official Anthropic Dart or Flutter SDK — Dart is an unsupported-SDK language, so this module speaks raw HTTP to `POST /v1/messages`. More importantly: **an Anthropic API key inside an app binary is extractable.** Anyone who pulls your APK or IPA can spend your Anthropic budget without limit, and you find out on the invoice. So the module's default and documented path is:

```
Flutter app  ──▶  YOUR backend  ──▶  api.anthropic.com
                  · holds the API key
                  · authenticates YOUR user
                  · enforces per-user quota
                  · pipes the SSE stream straight through
```

`ClaudeProxyClient` (the default) implements that. `ClaudeDirectClient` exists for local debugging only and **refuses to construct in a release build**. See [Security](#security-the-part-you-cannot-skip).

## What you get

| File (installed path) | What it is |
| --- | --- |
| `lib/app/feature/ai_assistant/ai_assistant_models/claude_message.dart` | `ClaudeMessage` + the `ClaudeBlock` family (`text`, `thinking`, `tool_use`, `tool_result`, and `ClaudeUnknownBlock` for forward compatibility). |
| `…/ai_assistant_models/claude_response.dart` | `ClaudeResponse` (`stopReason`, `content`, `usage`, refusal category), `ClaudeUsage` (4 token counters), `ClaudeApiException`. |
| `…/ai_assistant_models/claude_tool.dart` | `ClaudeTool` definition + `ClaudeToolHandler` typedef. |
| `…/ai_assistant_logic/claude_api_const.dart` | `ClaudeApiConstant` (hosts, paths, model, `max_tokens` defaults) + `ClaudeEffort` / `ClaudeThinkingDisplay`. Module-local, so no core `api_const.dart` edit. |
| `…/ai_assistant_logic/claude_api_service.dart` | The trio: abstract `ClaudeApiService`, `ClaudeProxyClient` (default), `ClaudeDirectClient` (debug only), `ClaudeRepo` (owns the endpoint + request body). |
| `…/ai_assistant_logic/claude_sse_parser.dart` | `ClaudeSseParser` — byte-oriented SSE line parser → typed events — and `ClaudeStreamAccumulator`, which rebuilds a complete `ClaudeResponse` from a stream. |
| `…/ai_assistant_logic/claude_tool_runner.dart` | `ClaudeToolRunner` — the ask → execute → send-results loop with an iteration cap. |
| `…/ai_assistant_controllers/chat_controller.dart` | `ChatController` — `RxList<ClaudeMessage>`, token-by-token append, cancel via Dio `CancelToken`, `RxBool isStreaming`, everything disposed in `onClose()`. |
| `…/ai_assistant_presentation/chat_screen.dart` | `ChatScreen` — bubbles, streaming cursor, thinking-summary disclosure, copy, retry-on-error, stop button. |
| `test/unit/claude_sse_parser_test.dart` | 19 tests: chunk-split and multi-byte-split SSE frames, the accumulator, partial tool-input JSON, refusal handling, and every request-body rule. No network. |

## Install

```bash
dart run tool/add_module.dart ai_assistant
```

Manual equivalent — copy each path in `module.yaml > files` from this module to the same path in the project:

```bash
mkdir -p lib/app/feature/ai_assistant
cp -R modules/ai_assistant/lib/app/feature/ai_assistant/ lib/app/feature/ai_assistant/
cp modules/ai_assistant/test/unit/claude_sse_parser_test.dart test/unit/
```

### pubspec.yaml

Nothing to add:

```yaml
# dio, get, flutter_dotenv and lucide_icons_flutter are already in the template core.
```

That is deliberate, and it is the main reason this module is small: no generated code, no `build_runner`, no `http` package alongside `dio`, no SDK to keep in sync with an API that moves every few months.

### Platform config

None beyond `INTERNET`, which the template already declares. No native code, no plist keys, no console setup. The platform work is on your **backend** — see [Backend contract](#backend-contract).

### Environment (`.env`)

All optional. With zero `.env` changes the module posts to `ApiConstant.activeBaseUrl` + `/ai/claude/messages`. Add placeholders to `.env.example` for whichever you use:

```dotenv
CLAUDE_PROXY_URL=                       # your AI host, if it isn't the main BASE_URL
CLAUDE_PROXY_PATH=/ai/claude/messages
CLAUDE_MODEL=claude-opus-5              # never append a date suffix to a model id
ANTHROPIC_API_KEY=                      # DEBUG ONLY — ClaudeDirectClient. Do not ship.
```

Every key is read through `ClaudeApiConstant` using `Env.optional(...)`, so **no `Env` getter needs adding** and `Env.requiredKeys` is untouched.

## Wiring

Four core files change. Nothing needs a bootstrap step, a `Get.put`, or a `GetMaterialApp.builder` slot.

**1. `lib/app/routes/app_routes.dart`** — add the constant:

```dart
  /// AI assistant
  static const String ChatScreen = '/chatScreen';
```

**2. `lib/app/routes/app_pages.dart`** — add the import next to the others, and the page inside `AppPages.pages`:

```dart
import '../feature/ai_assistant/ai_assistant_presentation/chat_screen.dart';
```

```dart
    // AI assistant
    _page(AppRoutes.ChatScreen, () => const ChatScreen()),
```

**3. `lib/app/bindings/view_model_binding.dart`** — add the import, then register the controller inside `dependencies()`:

```dart
import '../feature/ai_assistant/ai_assistant_controllers/chat_controller.dart';
```

```dart
    // AI assistant
    _lazy<ChatController>(() => ChatController());
```

`_lazy` already passes `fenix: true`.

**4. `lib/app/localization/locales/en_us.dart` and `bn_bd.dart`** — append this block to **both** files, just before the closing `};`. The localization guardrail requires every `.tr` string to have an `en_US` entry *and* every locale to carry exactly the same keys, so pasting it in only one file fails `flutter test`. Translate the `bn_bd` values later; English placeholders pass:

```dart
  // AI assistant
  'AI Assistant': 'AI Assistant',
  'Clear chat': 'Clear chat',
  'Ask anything': 'Ask anything',
  'Replies stream in token by token.': 'Replies stream in token by token.',
  'Reasoning summary': 'Reasoning summary',
  'Used tool': 'Used tool',
  'Tool results': 'Tool results',
  'Copy': 'Copy',
  'Copied': 'Copied',
  'The reply is on your clipboard': 'The reply is on your clipboard',
  'Retry': 'Retry',
  'Message Claude…': 'Message Claude…',
  'Claude declined this request': 'Claude declined this request',
  'Reply was cut off by the token limit': 'Reply was cut off by the token limit',
```

`Thinking` and `Something went wrong. Please try again.` are already in the template's locales and are reused as-is — don't paste them again, a duplicate key in a `const` map is a Dart compile error.

Then open the screen:

```dart
Get.toNamed(AppRoutes.ChatScreen);
```

Verified end to end: with these four steps applied, `flutter analyze` reports 0 issues and `flutter test` is 64 passing (45 template + 19 from this module).

## Backend contract

Your endpoint (`CLAUDE_PROXY_PATH`, default `POST /ai/claude/messages`) does four things:

1. **Authenticate the caller.** The module sends `Authorization: Bearer <CacheManager.token>` — the same session token the rest of the app uses. Reject anything else.
2. **Enforce a per-user quota** before forwarding. This is the only place it can be enforced; see [Security](#security-the-part-you-cannot-skip).
3. **Forward the JSON body verbatim** to `https://api.anthropic.com/v1/messages`, adding `x-api-key`, `anthropic-version: 2023-06-01` and `content-type: application/json`. Don't rewrite the body — the client already emits a valid one, and rewriting it is how `budget_tokens` or a `temperature` sneaks back in and earns a 400.
4. **Pipe the response straight through.** For `"stream": true` (the module sends `Accept: text/event-stream`), stream the SSE bytes unbuffered and without re-framing. A proxy that buffers the whole response turns a streaming chat into a 40-second blank screen.

Node/Express sketch:

```js
app.post('/ai/claude/messages', requireUser, enforceQuota, async (req, res) => {
  const upstream = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify(req.body),          // forward as-is
  });
  res.status(upstream.status);
  res.setHeader('content-type', upstream.headers.get('content-type') ?? 'application/json');
  await upstream.body.pipeTo(/* your writable */);   // no buffering
});
```

Non-2xx responses pass through unchanged: the module reads the `{"error": {"type", "message"}}` envelope — even on a streaming request, where it drains the error body rather than reporting a useless "stream failed".

## Usage

### Streaming chat (what `ChatScreen` does)

```dart
final repo = ClaudeRepo();                       // ClaudeProxyClient by default
final cancelToken = CancelToken();
final accumulator = ClaudeStreamAccumulator();

repo
    .stream(
      messages: [ClaudeMessage.user('Explain optimistic locking in one paragraph.')],
      system: 'You are a concise engineering assistant.',
      thinkingDisplay: ClaudeThinkingDisplay.summarized,
      effort: ClaudeEffort.high,
      cancelToken: cancelToken,
    )
    .listen((event) {
      accumulator.add(event);
      if (event is ClaudeTextDeltaEvent) render(accumulator.text);
    }, onDone: () {
      final response = accumulator.build();
      if (response.isRefusal) return showRefusal();   // check BEFORE reading content
      history.add(response.asMessage);                // full blocks, ready to resend
    });

// Stop mid-reply — the partial turn is kept.
cancelToken.cancel('user tapped stop');
```

### A single non-streaming call

```dart
final response = await ClaudeRepo().send(
  messages: [ClaudeMessage.user('Classify this ticket: "app crashes on login"')],
  system: 'Reply with exactly one of: bug, question, billing.',
  effort: ClaudeEffort.low,
);

if (response.isRefusal) { /* content may be empty — do not index it */ }
print(response.text);
print('${response.usage.totalInputTokens} in / ${response.usage.outputTokens} out');
```

### Tool use

```dart
final orders = ClaudeTool.object(
  name: 'get_order_status',
  // Be prescriptive about WHEN to call it, not just what it does.
  description: 'Call this when the user asks where an order is or when it will arrive.',
  properties: {
    'order_id': {'type': 'string', 'description': 'The order id, e.g. ORD-4192'},
  },
  required: ['order_id'],
);

final runner = ClaudeToolRunner(
  tools: [orders],
  handlers: {
    'get_order_status': (input) async {
      final order = await OrdersRepo().fetch(input['order_id'] as String);
      return {'status': order.status, 'eta': order.eta};   // Map is JSON-encoded
    },
  },
  system: 'You are a support agent. Use tools before answering about an order.',
  maxIterations: 10,
);

final result = await runner.run([ClaudeMessage.user('Where is ORD-4192?')]);

switch (result.outcome) {
  case ClaudeRunOutcome.completed:
    print(result.text);
  case ClaudeRunOutcome.refused:
    print('Declined: ${result.response?.refusalCategory}');
  case ClaudeRunOutcome.iterationCapReached:
    print('Gave up after ${result.iterations} turns — fix the tools or the prompt');
}

// result.messages is the full history — feed it straight back in for turn two.
```

`result.usage` sums every turn in the loop, which is what you meter against a quota.

### Switching to the debug-only direct client

```dart
// Local spike, no backend yet. Requires ANTHROPIC_API_KEY in .env.
// Throws a StateError in any non-debug build.
final repo = ClaudeRepo(client: ClaudeDirectClient());
```

### Changing the model or the endpoint

```dart
await ClaudeRepo().send(messages: history, model: 'claude-haiku-4-5');
```

```dotenv
CLAUDE_MODEL=claude-sonnet-5
CLAUDE_PROXY_PATH=/v2/assistant/messages
```

## Security — the part you cannot skip

- **Shipping `ClaudeDirectClient` is a financial-loss bug, not a style preference.** An API key in an app binary is extractable with `unzip` and `strings` — obfuscation, splitting it across constants, and fetching it at runtime all fail, because the running app must eventually hold the plaintext key. With no spend cap on the key, a single leaked build is an open tab on your Anthropic account. That is why the constructor `assert`s `kDebugMode`, throws a `StateError` in release, and logs a warning in debug.
- **Per-user rate limiting belongs on your backend. The client cannot enforce it.** A patched APK, a rooted device, or plain `curl` against your endpoint skips every client-side counter. Meter on the server, keyed by your authenticated user, and reject before forwarding. Anything the app does — a cooldown, a disabled send button — is politeness, not enforcement.
- **Prompt injection is real once tools enter the loop.** Text you feed the model (a fetched web page, a user-supplied document, another user's message) can contain instructions. If a tool handler can spend money, send a message, or delete a row, gate it behind an explicit user confirmation instead of executing whatever the model asks for. Read-only tools are the safe default.
- **Don't put secrets in the system prompt or in message content.** The whole conversation is resent on every request and typically stored in your logs and your backend's history.
- **Cap `max_tokens` per user on the backend**, not just in the client. `max_tokens` is the only hard ceiling on a turn's cost, and the client's value is a suggestion the moment the app is patched.

## The API rules this client encodes

These are the ones that are easy to get wrong, and most of them fail with a 400 rather than degrading:

- **Model.** Default `claude-opus-5` (1M context, 128K max output). **Never append a date suffix to a model id.** Other valid ids: `claude-sonnet-5`, `claude-haiku-4-5`.
- **Thinking.** `thinking: {"type": "adaptive"}` only. **`budget_tokens` is removed and returns 400** — the body builder has no path that emits it. On `claude-opus-5` thinking is *on by default*, so the field is omitted unless you ask for a summary (`display: "summarized"`) or opt out.
- **Disabling thinking is effort-gated.** `{"type": "disabled"}` is accepted only at effort `high` or lower. `ClaudeRepo.buildBody` throws an `ArgumentError` for `disableThinking` + `xhigh`/`max` so you find out locally, not from a 400.
- **Sampling.** `temperature`, `top_p` and `top_k` are removed on `claude-opus-5` and return 400. The body builder never emits them; steer with the prompt instead.
- **Effort** goes inside `output_config`, not top-level: `output_config: {"effort": "high"}`. Default `high`.
- **`max_tokens` is required, and it caps thinking + text together.** 16000 non-streaming, 64000 streaming (`ClaudeApiConstant`). A truncated turn surfaces as `stopReason == maxTokens`, which the chat screen reports rather than silently swallowing.
- **Check `stopReason` before reading `content`.** On a refusal, `content` may be empty or partial, so `content[0]` crashes. `ClaudeResponse.isRefusal`, the tool runner and `ChatController` all check first.
- **`pause_turn` is not an error.** A server tool hit its iteration limit; the runner re-sends the assistant turn to resume and **never** appends a "Continue" user message.
- **All `tool_result`s for one turn go in a single user message.** Splitting them trains the model to stop making parallel calls. `ClaudeMessage.toolResults(...)` enforces the shape.
- **A failed tool still returns its `tool_result`, with `is_error: true`.** Dropping it leaves an unanswered `tool_use` and the next request is rejected.
- **The API is stateless.** The whole conversation is resent every request. Thinking blocks round-trip unchanged (never edit one — the API rejects a modified block), and block types this client doesn't model become `ClaudeUnknownBlock` and are forwarded verbatim rather than dropped.
- **SSE event order** is `message_start` → `content_block_start` → `content_block_delta`* → `content_block_stop` → `message_delta` → `message_stop`. Text arrives as `delta.type == "text_delta"` (`.text`), reasoning as `thinking_delta` (`.thinking`), tool arguments as `input_json_delta` (`.partial_json`, valid JSON only once complete).

## Cost

Priced per million tokens (MTok):

| Model | Input | Output | Context |
| --- | --- | --- | --- |
| `claude-opus-5` (default) | $5 | $25 | 1M |
| `claude-sonnet-5` | $3 | $15 | 1M |
| `claude-haiku-4-5` | $1 | $5 | 200K |

Two things dominate a chat app's bill:

- **Every turn resends the whole conversation**, so per-turn input grows linearly and *cumulative* input over a conversation grows quadratically. Cap history length, or have your backend enable prompt caching (`cache_read_input_tokens` bills at roughly a tenth of input).
- **Thinking tokens are output tokens.** `effort` is the lever: `low` and `medium` are strong on `claude-opus-5` and cost a fraction of `xhigh`.

`ClaudeUsage` exposes all four counters (`inputTokens`, `outputTokens`, `cacheCreationInputTokens`, `cacheReadInputTokens`); `totalInputTokens` sums them, because `input_tokens` alone is only the *uncached* remainder. `ClaudeToolRunResult.usage` sums a whole tool loop. Log them per user — that's your metering input.

## Limitations and caveats

- **A proxy is mandatory for production.** This module is half a feature without a backend endpoint. If you have no backend, you have no safe way to ship a Claude integration, and no amount of client-side cleverness changes that.
- **No official SDK means no SDK guarantees.** This is raw HTTP. When Anthropic adds a response block type or a request field, nothing here breaks (unknown blocks round-trip, unknown `stop_reason`s map to `unknown`), but you won't get the new capability until someone updates this code. Check `claude_api_const.dart` and the rules above against the current API docs before a launch.
- **Streaming requires a streaming proxy.** A backend that buffers, or a CDN/load balancer that does, silently converts this into a slow non-streaming client. Test the real deployed path, not just localhost.
- **`connectivity_plus` is not consulted.** Unlike core `ApiService`, this module's Dio has no internet pre-check, so offline failures surface as a `ClaudeApiException` in the error bar rather than the standard "no internet" snackbar. Install `connectivity_banner` and check `isOnline` before `send()` if you want the template's behaviour.
- **No retry, no backoff, no circuit breaker.** A `429` or `529` surfaces as an error with a Retry button. `ClaudeApiException.isRateLimited` / `.isOverloaded` are there if you want to add backoff — but do it on the backend, where `Retry-After` can be honoured centrally.
- **No prompt caching from the client.** `cache_control` is deliberately not emitted: correct placement depends on your prompt architecture, and a badly placed breakpoint costs money instead of saving it. Add it on the backend, where the system prompt lives.
- **Only `text`, `thinking`, `tool_use` and `tool_result` blocks are modelled.** Images, PDFs, documents, citations, server-side tools (web search, code execution) and structured outputs are not wired up. The wire types are open — `ClaudeBlock`/`ClaudeUnknownBlock` won't fight you — but there is no helper for them here.
- **No conversation persistence.** History lives in the controller and dies with it. Wire `CacheManager` or a database yourself if you need it to survive a restart.
- **No compaction or context editing.** Long conversations will eventually hit the context window and return an error. Trim history, or enable server-side compaction on your backend.
- **The tool loop is sequential.** Parallel `tool_use` blocks are executed one after another before the single results message is sent. Correct, just not maximally fast — swap in `Future.wait` over `_execute` if your handlers are I/O-bound.
- **The iteration cap is a safety net, not a strategy.** Hitting `iterationCapReached` means the model is looping; fix the tool descriptions or the prompt rather than raising the cap.
- **`ChatScreen` renders plain text.** No Markdown, no code-block highlighting, no syntax formatting. Install `html_view` or a Markdown package and swap the `Text` in `_bubble` if you need rendering.
- **Thinking summaries are summaries.** The raw chain of thought is never returned by the API — `display: "summarized"` is the most you can show a user, and the default (`omitted`) yields thinking blocks with empty text.
- **`ClaudeApiConstant` requires `Env.load()` to have run.** `bootstrap()` already does it; a unit test that touches `ClaudeApiConstant` must call `dotenv.loadFromString(...)` first, as `claude_sse_parser_test.dart` does.
- **Verified against the current API contract, not against a live key.** Every request field, header, SSE event shape, model id and price above comes from Anthropic's current documentation; the tests exercise the parser and the body builder offline. Nothing here has been run against `api.anthropic.com` from this repo.

## Why it is not in core

Most projects starting from this template do not ship an LLM feature, and the ones that do need a backend endpoint that does not exist yet. Putting this in `lib/` would mean every new project carries a chat screen, an SSE parser and a tool-loop it will never call — plus a pinned model id and a set of request rules that Anthropic revises every few months, in a file nobody remembers to audit. And the safe path is genuinely half server-side: shipping a client-only Claude integration in `lib/` would invite exactly the mistake this README spends a section warning about. It stays an opt-in you install when the backend is ready.
