import 'package:flutter/material.dart';

/// show progress loader if isLoading is true
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading ? const Center(child: CircularProgressIndicator()) : child;
  }
}
