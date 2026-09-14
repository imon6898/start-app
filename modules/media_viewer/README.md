# media_viewer

Fullscreen image/video gallery plus an inline media thumbnail — zoomable images, a custom video player with double-tap seek, and network / file / asset sources.

## Install

```bash
dart run tool/add_module.dart media_viewer
```

Manual, if you prefer:

1. Copy `modules/media_viewer/lib/app/core/helpers/media_viewer.dart` to `lib/app/core/helpers/media_viewer.dart` (the module mirrors the project tree, so the relative path is the destination).
2. Add the dependencies below to `pubspec.yaml`.
3. `flutter pub get`.

## Dependencies

Paste into `pubspec.yaml` under `dependencies:`:

```yaml
  cached_network_image: ^4.0.0
  video_player: ^2.14.0
```

Already in the template core and required: `lib/app/services/domain/api_const.dart` (`ApiConstant.imageUrl`).

## Platform config

No API keys, no runtime permissions — this module only displays media, it never picks or records it.

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

`video_player` needs `minSdk` 21+, which Flutter's default already satisfies. If any media URL is plain HTTP, add `android:usesCleartextTraffic="true"` to the `<application>` tag.

**iOS** — nothing required for HTTPS media. For plain-HTTP media add an ATS exception to `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```

**.env** — only if you use `isEndUrl: true` (relative paths resolved against the CDN base):

```
IMAGE_URL=https://cdn.example.com
```

## Supported media

| Kind | Extensions | Widget used |
| --- | --- | --- |
| Image | `.jpg` `.jpeg` `.png` `.webp` `.gif` | `InteractiveViewer` + `CachedNetworkImage` / `Image.file` / `Image.asset` |
| Video | `.mp4` `.mov` `.avi` `.webm` | `video_player` with custom controls |

Source type is auto-detected from the path: `http…` → network, `assets/…` → asset, anything else → local file. Query strings are stripped before the extension check, so signed URLs work. Anything with an unrecognised extension renders the error placeholder.

Video controls: tap to toggle controls, tap centre to play/pause, double-tap left/right half to seek ∓5s, drag or tap the progress bar to scrub. Buffered range is drawn behind the played track, and a thin always-on progress line shows while controls are hidden. Images: pinch to zoom (1x–4x), double-tap to toggle 2.5x at the tap point; page swiping is disabled while zoomed.

## Usage

```dart
import 'package:flutter_starter/app/core/helpers/media_viewer.dart';

final media = [
  MediaModel(url: 'https://example.com/photo.jpg'),
  MediaModel(url: 'https://example.com/clip.mp4',
             thumbnailUrl: 'https://example.com/clip-thumb.jpg'),
];

// Inline thumbnail that opens the gallery.
UniversalMediaPreview(
  path: media[0].url!,
  height: 180,
  onTap: () => Get.to(() => FullscreenMediaViewer(
        mediaList: media,
        initialIndex: 0,
      )),
);
```

Pass `isEndUrl: true` on `MediaModel` / `UniversalMediaPreview` when the API returns a relative path that should be prefixed with `ApiConstant.imageUrl`.

## Why it is not in core

`video_player` pulls in ExoPlayer/AVPlayer native code and inflates every build, so the template stays lean and you add it only when the app actually shows media.

## Notes

Recovered verbatim from `lib/app/core/helpers/media_viewer.dart` at commit `b860a8e`; only the divider-art comments were shortened.
