import "package:get/get.dart";

import "../themes/theme_controller.dart";

class ViewModelBinding extends Bindings {
  @override
  void dependencies() {

    // ── Home ─────────────────────────────────────────────────────────────
    _lazy<ThemeController>(() => ThemeController());
    // ── Home ─────────────────────────────────────────────────────────────
    //_lazy<HomeController>(() => HomeController());

  }

  /// Register a permanent singleton once.
  void _put<T>(T Function() create) {
    if (!Get.isRegistered<T>()) Get.put<T>(create(), permanent: true);
  }

  /// Register a screen-scoped controller once; rebuilt after a `Get.delete`.
  void _lazy<T>(T Function() create) {
    if (!Get.isRegistered<T>()) Get.lazyPut<T>(create, fenix: true);
  }
}
