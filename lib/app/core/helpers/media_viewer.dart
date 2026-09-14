import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_starter/app/services/domain/api_const.dart';

// ─── Enums & Models ──────────────────────────────────────────────────────────

enum MediaSourceType { network, file, asset }

class MediaModel {
  final String? url;
  final String? thumbnailUrl;
  final bool isEndUrl;

  MediaModel({this.url, this.thumbnailUrl, this.isEndUrl = false});
}

// ─── Shared Helpers ──────────────────────────────────────────────────────────

class _MediaUtils {
  static const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
  static const videoExtensions = ['.mp4', '.mov', '.avi', '.webm'];

  static String resolvePath(String rawPath, {bool isEndUrl = false}) {
    if (isEndUrl &&
        !rawPath.startsWith('http') &&
        !rawPath.startsWith('https')) {
      return '${ApiConstant.imageUrl}/$rawPath';
    }
    return rawPath;
  }

  static MediaSourceType detectSourceType(String path) {
    if (path.startsWith('http')) return MediaSourceType.network;
    if (path.startsWith('assets/')) return MediaSourceType.asset;
    return MediaSourceType.file;
  }

  static String _extension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) return '';
    // Strip query params for URLs
    final ext = path.substring(dotIndex);
    final qIndex = ext.indexOf('?');
    return (qIndex > 0 ? ext.substring(0, qIndex) : ext).toLowerCase();
  }

  static bool isImage(String path) {
    return imageExtensions.contains(_extension(path));
  }

  static bool isVideo(String path) {
    return videoExtensions.contains(_extension(path));
  }

  static VideoPlayerController createVideoController(
    String resolvedPath,
    MediaSourceType sourceType,
  ) {
    switch (sourceType) {
      case MediaSourceType.network:
        return VideoPlayerController.networkUrl(Uri.parse(resolvedPath));
      case MediaSourceType.file:
        return VideoPlayerController.file(File(resolvedPath));
      case MediaSourceType.asset:
        return VideoPlayerController.asset(resolvedPath);
    }
  }

  static String formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }
}

// ─── Double-Tap Seek Ripple ──────────────────────────────────────────────────

class _DoubleTapSeekOverlay extends StatelessWidget {
  final bool visible;
  final bool isForward;

  const _DoubleTapSeekOverlay({
    required this.visible,
    required this.isForward,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: isForward ? Alignment.centerRight : Alignment.centerLeft,
            radius: 0.8,
            colors: [Colors.white.withAlpha(40), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(height: 4),
            Text(
              isForward ? '+5s' : '-5s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── YouTube-like Progress Bar ───────────────────────────────────────────────

class _VideoProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;

  const _VideoProgressBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
  });

  double get _progress =>
      duration.inMilliseconds > 0
          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  double get _bufferedProgress =>
      duration.inMilliseconds > 0
          ? (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  void _seekFromPosition(BuildContext context, double localX) {
    final box = context.findRenderObject() as RenderBox;
    final fraction = (localX / box.size.width).clamp(0.0, 1.0);
    onSeek(Duration(
      milliseconds: (fraction * duration.inMilliseconds).round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        _seekFromPosition(context, d.localPosition.dx);
      },
      onHorizontalDragUpdate: (d) => _seekFromPosition(context, d.localPosition.dx),
      onTapDown: (d) => _seekFromPosition(context, d.localPosition.dx),
      child: Container(
        height: 24,
        alignment: Alignment.bottomCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // Background track
                Container(
                  height: 3,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Buffered track
                Container(
                  height: 3,
                  width: width * _bufferedProgress,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Played track
                Container(
                  height: 3,
                  width: width * _progress,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Thumb
                Positioned(
                  left: (width * _progress) - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Zoomable Image Viewer ───────────────────────────────────────────────────

class _ZoomableImageViewer extends StatefulWidget {
  final String resolvedPath;
  final MediaSourceType sourceType;
  final ValueChanged<bool>? onZoomChanged;

  const _ZoomableImageViewer({
    required this.resolvedPath,
    required this.sourceType,
    this.onZoomChanged,
  });

  @override
  State<_ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<_ZoomableImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_isZoomed != zoomed) {
      _isZoomed = zoomed;
      widget.onZoomChanged?.call(zoomed);
    }
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;

    if (_transformController.value != Matrix4.identity()) {
      // Zoom out
      _zoomAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutCubic,
      ));
    } else {
      // Zoom in to 2.5x at tap position
      // ignore: deprecated_member_use
      final zoomed = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        // ignore: deprecated_member_use
        ..scale(2.5);
      _zoomAnimation = Matrix4Tween(
        begin: Matrix4.identity(),
        end: zoomed,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutCubic,
      ));
    }
    _animController.forward(from: 0);
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Widget _buildImage() {
    switch (widget.sourceType) {
      case MediaSourceType.network:
        return CachedNetworkImage(
          imageUrl: widget.resolvedPath,
          fit: BoxFit.contain,
          placeholder: (_, u) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, er, e) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        );
      case MediaSourceType.file:
        return Image.file(
          File(widget.resolvedPath),
          fit: BoxFit.contain,
          errorBuilder: (_, er, e) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        );
      case MediaSourceType.asset:
        return Image.asset(widget.resolvedPath, fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: _isZoomed,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        child: SizedBox.expand(
          child: Center(child: _buildImage()),
        ),
      ),
    );
  }
}

// ─── Custom Video Player ─────────────────────────────────────────────────────

class _CustomVideoPlayer extends StatefulWidget {
  final String resolvedPath;
  final MediaSourceType sourceType;
  final String? thumbnailUrl;
  final bool isActive;

  const _CustomVideoPlayer({
    required this.resolvedPath,
    required this.sourceType,
    this.thumbnailUrl,
    this.isActive = true,
  });

  @override
  State<_CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<_CustomVideoPlayer> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _showForwardSeek = false;
  bool _showBackwardSeek = false;
  Timer? _hideControlsTimer;
  Timer? _seekResetTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;

  @override
  void initState() {
    super.initState();
    _videoController = _MediaUtils.createVideoController(
      widget.resolvedPath,
      widget.sourceType,
    );
    _videoController!.addListener(_onVideoUpdate);
  }

  @override
  void didUpdateWidget(covariant _CustomVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && _isPlaying) {
      _videoController?.pause();
    }
  }

  void _onVideoUpdate() {
    if (!mounted || _videoController == null) return;
    final value = _videoController!.value;
    setState(() {
      _position = value.position;
      _duration = value.duration;
      _isPlaying = value.isPlaying;
      if (value.buffered.isNotEmpty) {
        _buffered = value.buffered.last.end;
      }
    });
  }

  Future<void> _initializeAndPlay() async {
    try {
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
      _videoController!.play();
      _startHideTimer();
    } catch (_) {
      // initialization failed
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) {
      _initializeAndPlay();
      return;
    }
    if (_isPlaying) {
      _videoController!.pause();
      _hideControlsTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      _videoController!.play();
      _startHideTimer();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _seek(int seconds) {
    if (!_isInitialized) return;
    final newPos = _position + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    _videoController!.seekTo(clamped);

    setState(() {
      if (seconds > 0) {
        _showForwardSeek = true;
      } else {
        _showBackwardSeek = true;
      }
    });

    _seekResetTimer?.cancel();
    _seekResetTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showForwardSeek = false;
          _showBackwardSeek = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekResetTimer?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildPoster() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.contain,
        placeholder: (_, u) => _blackBox(),
        errorWidget: (_, er, e) => _blackBox(),
      );
    }
    return _blackBox();
  }

  Widget _blackBox() {
    return Container(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or poster
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio.clamp(0.5, 3.0),
                    child: VideoPlayer(_videoController!),
                  )
                : _buildPoster(),
          ),

          // Double-tap seek zones
          Row(
            children: [
              // Left half — backward
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => _seek(-5),
                  onTap: _toggleControls,
                  child: _DoubleTapSeekOverlay(
                    visible: _showBackwardSeek,
                    isForward: false,
                  ),
                ),
              ),
              // Right half — forward
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => _seek(5),
                  onTap: _toggleControls,
                  child: _DoubleTapSeekOverlay(
                    visible: _showForwardSeek,
                    isForward: true,
                  ),
                ),
              ),
            ],
          ),

          // Center play/pause button
          if (_showControls || !_isInitialized)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: AnimatedOpacity(
                  opacity: (_showControls || !_isInitialized) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha(120),
                    ),
                    child: Icon(
                      !_isInitialized
                          ? Icons.play_arrow_rounded
                          : _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),

          // Time + progress bar at bottom
          if (_isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _VideoProgressBar(
                        position: _position,
                        duration: _duration,
                        buffered: _buffered,
                        onSeek: (d) => _videoController!.seekTo(d),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _MediaUtils.formatDuration(_position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _MediaUtils.formatDuration(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Always-visible thin progress bar when controls hidden
          if (_isInitialized && !_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _duration.inMilliseconds > 0
                    ? (_position.inMilliseconds / _duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 2,
                backgroundColor: Colors.white.withAlpha(40),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Fullscreen Media Viewer (Gallery) ───────────────────────────────────────

class FullscreenMediaViewer extends StatefulWidget {
  final List<MediaModel> mediaList;
  final int initialIndex;
  final bool isEndUrl;

  const FullscreenMediaViewer({
    super.key,
    required this.mediaList,
    required this.initialIndex,
    this.isEndUrl = true,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.mediaList.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaList.length,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final item = widget.mediaList[index];
          final resolvedPath = _MediaUtils.resolvePath(
            item.url ?? '',
            isEndUrl: item.isEndUrl || widget.isEndUrl,
          );
          final sourceType = _MediaUtils.detectSourceType(resolvedPath);

          if (_MediaUtils.isVideo(resolvedPath)) {
            return _CustomVideoPlayer(
              resolvedPath: resolvedPath,
              sourceType: sourceType,
              thumbnailUrl: item.thumbnailUrl,
              isActive: index == _currentIndex,
            );
          }

          return _ZoomableImageViewer(
            resolvedPath: resolvedPath,
            sourceType: sourceType,
            onZoomChanged: (zoomed) {
              if (_isZoomed != zoomed) {
                setState(() => _isZoomed = zoomed);
              }
            },
          );
        },
      ),
    );
  }
}

// ─── Inline Thumbnail Preview ────────────────────────────────────────────────

class UniversalMediaPreview extends StatefulWidget {
  final String path;
  final double height;
  final double width;
  final bool isEndUrl;
  final MediaSourceType? overrideSourceType;
  final VoidCallback? onTap;
  final String? thumbnailUrl;

  const UniversalMediaPreview({
    super.key,
    required this.path,
    this.height = 200,
    this.width = double.infinity,
    this.isEndUrl = false,
    this.overrideSourceType,
    this.onTap,
    this.thumbnailUrl,
  });

  @override
  State<UniversalMediaPreview> createState() => _UniversalMediaPreviewState();
}

class _UniversalMediaPreviewState extends State<UniversalMediaPreview> {
  late String _resolvedPath;
  late MediaSourceType _sourceType;
  late bool _isImage;
  late bool _isVideo;

  @override
  void initState() {
    super.initState();
    _resolvedPath = _MediaUtils.resolvePath(widget.path, isEndUrl: widget.isEndUrl);
    _sourceType =
        widget.overrideSourceType ?? _MediaUtils.detectSourceType(_resolvedPath);
    _isImage = _MediaUtils.isImage(_resolvedPath);
    _isVideo = _MediaUtils.isVideo(_resolvedPath);
  }

  Widget _buildImage() {
    switch (_sourceType) {
      case MediaSourceType.network:
        return CachedNetworkImage(
          imageUrl: _resolvedPath,
          height: widget.height,
          width: widget.width,
          fit: BoxFit.cover,
          placeholder: (_, u) => _placeholder(),
          errorWidget: (_, er, e) => _errorWidget(),
        );
      case MediaSourceType.file:
        return Image.file(
          File(_resolvedPath),
          height: widget.height,
          width: widget.width,
          fit: BoxFit.cover,
          errorBuilder: (_, er, e) => _errorWidget(),
        );
      case MediaSourceType.asset:
        return Image.asset(
          _resolvedPath,
          height: widget.height,
          width: widget.width,
          fit: BoxFit.cover,
        );
    }
  }

  Widget _buildVideoThumbnail() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              height: widget.height,
              width: widget.width,
              fit: BoxFit.cover,
              placeholder: (_, u) => _videoPlaceholder(),
              errorWidget: (_, er, e) => _videoPlaceholder(),
            )
          else
            _videoPlaceholder(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(120),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoPlaceholder() => Container(
        height: widget.height,
        width: widget.width,
        color: Colors.black87,
      );

  Widget _placeholder() => Container(
        height: widget.height,
        width: widget.width,
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      );

  Widget _errorWidget() => Container(
        height: widget.height,
        width: widget.width,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.error, size: 40)),
      );

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _buildImage(),
      );
    } else if (_isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _buildVideoThumbnail(),
      );
    }
    return _errorWidget();
  }
}