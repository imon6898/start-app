import 'package:flutter/material.dart';

class GuestHelper {
  static bool requiresLogin({
    required BuildContext context,
    required String featureName,
    VoidCallback? onLogin,
  }) {
    return true;
  }
}
