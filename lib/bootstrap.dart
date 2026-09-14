import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/bindings/view_model_binding.dart';
import 'app/core/config/env.dart';
import 'app/services/domain/dev_tools.dart';
import 'app/services/ip_location_service.dart';
import 'app/services/local_data/cache_manager.dart';
import 'app/widgets/appbar_widgets/app_status_bar.dart';

/// Everything that must happen before the first frame. Keep `main()` a
/// one-liner so startup order lives in exactly one place.
void bootstrap() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      devPrint(
        '${details.exceptionAsString()}\n${details.stack}',
        tag: 'FlutterError',
      );
    };
    ErrorWidget.builder = _errorWidget;

    try {
      await Env.load();
    } on EnvException catch (e) {
      runApp(_FatalErrorApp(message: e.message));
      return;
    }

    await CacheManager.init();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Global default only; per-screen styling goes through AppStatusBar.
    SystemChrome.setSystemUIOverlayStyle(AppStatusBar.darkIconsStyle);

    // Warms the country cache the phone field reads. Never awaited — startup
    // must not be gated on network.
    unawaited(IpLocationService.preload());

    // App.build reads ThemeController, so register before the first frame.
    ViewModelBinding().dependencies();

    runApp(const App());
  }, (error, stack) => devPrint('$error\n$stack', tag: 'Uncaught'));
}

/// Red-screen replacement: keeps the debug details, hides them in release.
Widget _errorWidget(FlutterErrorDetails details) {
  if (kDebugMode) return ErrorWidget(details.exception);
  return const _ErrorBox(message: 'Something went wrong.');
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFFAFAFA),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ),
    );
  }
}

/// Shown instead of a black screen when startup config is unusable.
class _FatalErrorApp extends StatelessWidget {
  final String message;

  const _FatalErrorApp({required this.message});

  @override
  Widget build(BuildContext context) =>
      _ErrorBox(message: kReleaseMode ? 'Something went wrong.' : message);
}
