import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A reusable widget that listens to map interaction gestures
/// and updates a reactive boolean observable or calls a callback.
///
/// Usage with GetX:
/// ```dart
/// MapInteractionListener(
///   isInteracting: myController.isMapInteracting,
///   child: GoogleMap(...),
/// )
/// ```
///
/// Usage with callbacks:
/// ```dart
/// MapInteractionListener.withCallback(
///   onInteractionStart: () => setState(() => _isInteracting = true),
///   onInteractionEnd: () => setState(() => _isInteracting = false),
///   child: GoogleMap(...),
/// )
/// ```
class MapInteractionListener extends StatelessWidget {
  /// The child widget (typically a GoogleMap)
  final Widget child;

  /// A reactive boolean observable that will be updated based on map interaction (GetX)
  final RxBool? isInteracting;

  /// Callback when interaction starts (pointer down or move)
  final VoidCallback? onInteractionStart;

  /// Callback when interaction ends (pointer up or cancel)
  final VoidCallback? onInteractionEnd;

  /// Constructor for GetX usage
  const MapInteractionListener({
    Key? key,
    required this.child,
    required RxBool isInteracting,
  })  : isInteracting = isInteracting,
        onInteractionStart = null,
        onInteractionEnd = null,
        super(key: key);

  /// Constructor for callback-based usage (without GetX)
  const MapInteractionListener.withCallback({
    Key? key,
    required this.child,
    required this.onInteractionStart,
    required this.onInteractionEnd,
  })  : isInteracting = null,
        super(key: key);

  void _handleInteractionStart() {
    if (isInteracting != null) {
      isInteracting!.value = true;
    }
    onInteractionStart?.call();
  }

  void _handleInteractionEnd() {
    if (isInteracting != null) {
      isInteracting!.value = false;
    }
    onInteractionEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _handleInteractionStart(),
      onPointerMove: (_) => _handleInteractionStart(),
      onPointerUp: (_) => _handleInteractionEnd(),
      onPointerCancel: (_) => _handleInteractionEnd(),
      child: child,
    );
  }
}
