import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Wraps a map and reports when the user is touching it (blocks parent scrolling).
class MapInteractionListener extends StatelessWidget {
  final Widget child;

  /// Flipped true while the user touches the map (GetX constructor).
  final RxBool? isInteracting;

  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  /// GetX: drives an RxBool.
  const MapInteractionListener({
    super.key,
    required this.child,
    required RxBool this.isInteracting,
  }) : onInteractionStart = null,
       onInteractionEnd = null;

  /// Plain Flutter: drives callbacks instead.
  const MapInteractionListener.withCallback({
    super.key,
    required this.child,
    required this.onInteractionStart,
    required this.onInteractionEnd,
  }) : isInteracting = null;

  void _start() {
    isInteracting?.value = true;
    onInteractionStart?.call();
  }

  void _end() {
    isInteracting?.value = false;
    onInteractionEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _start(),
      onPointerMove: (_) => _start(),
      onPointerUp: (_) => _end(),
      onPointerCancel: (_) => _end(),
      child: child,
    );
  }
}
