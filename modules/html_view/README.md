# html_view

Renders HTML strings as Flutter widgets — theme-aware colors, tappable links (tel/mailto/sms/web), chat-style markdown, auto-linkify, plus HTML-to-plain-text utilities.

## What it does

`AppHtmlView` is a static helper class. Renderers:

| Method | Use for |
| --- | --- |
| `applyHtml` | Plain HTML from an API/CMS. Strips hardcoded colors so the content follows your light/dark theme. |
| `applyHtmlWithLinkify` | Chat / comment / description bodies. Converts `\n` to breaks, parses WhatsApp-style markdown (`*bold*`, `_italic_`, `~strike~`, `` `code` ``, `> quote`, bullet + numbered lists), auto-links URLs, emails and phone numbers, then renders with full heading/list/code/quote styling. |
| `applyCustomHtml` | You want to supply your own `Map<String, Style>` overrides and link callback. |
| `applyBibleHtml` | Long-form / Scripture (USFM, api.bible) markup — verse numbers (`sup`, `span.v`), chapter numbers, section titles, poetry indentation, red-letter text, footnotes, cross references. |
| `applyBibleHtmlWithLinkify` | Same as above but auto-links URLs/emails/phones first. |

String utilities (no widgets, safe to call anywhere):

- `stripHtml(html)` — tags, comments and entities removed, whitespace collapsed.
- `extractVerseText(html)` — `stripHtml` plus leading/bracketed verse numbers removed.
- `parseWhatsAppMarkdown(text)` — markdown → HTML.
- `linkifyText(text)` — wraps bare URLs, emails and phone numbers in anchors.
- `containsLinks(text)` / `extractUrls(text)`.

## Install

```bash
dart run tool/add_module.dart html_view
```

Manual steps (equivalent):

1. Copy `modules/html_view/lib/app_html_view.dart` → `lib/app/widgets/app_html_view.dart`
2. Add the dependencies below to `pubspec.yaml`
3. `flutter pub get`

### pubspec.yaml

```yaml
dependencies:
  flutter_html: ^3.0.0
  html_unescape: ^2.0.0
  google_fonts: ^8.2.1
  url_launcher: ^6.3.2
```

`get: ^4.7.3` is already in the template core.

### Platform config

No API keys or permissions of its own. `url_launcher` needs query intents declared so `canLaunchUrl` returns true:

**android/app/src/main/AndroidManifest.xml** — as a direct child of `<manifest>`, outside `<application>`:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
  <intent>
    <action android:name="android.intent.action.DIAL" />
    <data android:scheme="tel" />
  </intent>
  <intent>
    <action android:name="android.intent.action.SENDTO" />
    <data android:scheme="mailto" />
  </intent>
  <intent>
    <action android:name="android.intent.action.SENDTO" />
    <data android:scheme="sms" />
  </intent>
</queries>
```

**ios/Runner/Info.plist** — inside the top-level `<dict>`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>https</string>
  <string>http</string>
  <string>tel</string>
  <string>mailto</string>
  <string>sms</string>
</array>
```

`google_fonts` downloads fonts at runtime, so the app needs network access (already granted on Android; no iOS entry needed). To ship fonts offline instead, bundle them under `assets/google_fonts/` per the `google_fonts` README.

## Usage

```dart
// Plain HTML from an API, theme-aware
AppHtmlView.applyHtml(
  context,
  text: product.descriptionHtml,
  style: CustomTextStyles.regular14.copyWith(color: CustomColors.black()),
  textAlign: TextAlign.start,
)

// Chat message: markdown + auto-linkify
AppHtmlView.applyHtmlWithLinkify(
  context,
  text: message.body,
  style: CustomTextStyles.regular14.copyWith(color: CustomColors.black()),
  textAlign: TextAlign.start,
  maxLine: 8,
)

// Plain-text preview in a list tile
Text(AppHtmlView.stripHtml(post.bodyHtml), maxLines: 2, overflow: TextOverflow.ellipsis);
```

### Optional: open links in an in-app WebView

By default web links open in the external browser. Point `webViewOpener` at any opener (for example the `webview` module's `CustomWebView.open`) once at startup and every renderer uses it:

```dart
AppHtmlView.webViewOpener = CustomWebView.open;
```

`tel:`, `mailto:` and `sms:` always go to the OS handler. Pass `openLinksInWebView: false` / `openInWebView: false` per call to force the external browser.

## Changes applied during repackaging

The recovered file was 1133 lines. Behavior is unchanged, but:

- **Renamed** `AppHtmlView.dart` → `app_html_view.dart` (Dart `lower_snake_case` file naming).
- **Removed the hard dependency on `CustomWebView`**, which the strip deleted from core. Link opening now goes through the optional `AppHtmlView.webViewOpener` hook and falls back to `url_launcher`. This module no longer needs `flutter_inappwebview`.
- **Deduplicated the Scripture style map.** `applyBibleHtml` and `applyBibleHtmlWithLinkify` each carried an identical ~200-line `Map<String, Style>`; both now build it from one private `_scriptureStyles(...)`, and `applyBibleHtmlWithLinkify` delegates to `applyBibleHtml(linkify: true)`. `applyBibleHtml` gained an optional `linkColor` and `openInWebView`.
- **Deduplicated link handling** into one private `_handleLinkTap`, previously copy-pasted into four `onLinkTap` callbacks.
- **Hoisted the URL/email/phone regexes** to static finals — they were recompiled on every `linkifyText` / `containsLinks` / `extractUrls` call.
- Comments shortened; no public API was removed.

The Scripture/Bible renderers were **kept**, not trimmed. They are the only styling in the file that handles USFM class names (`span.v`, `span.wj`, `span.q1`…); if you do not render Scripture you can delete `applyBibleHtml`, `applyBibleHtmlWithLinkify`, `_scriptureStyles` and `extractVerseText` and lose nothing else.

## Why it is not in core

`flutter_html` plus `google_fonts` and `url_launcher` is a heavy chain for a template that mostly renders plain `Text` — add it only when a screen has to display server-supplied HTML.
