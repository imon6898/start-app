import 'dart:developer';

import 'package:flutter/foundation.dart';

void devPrint(String logMessage, {String? tag}) {
  if (kDebugMode) log(tag != null ? "$tag => $logMessage" : logMessage);
}