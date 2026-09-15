import 'package:get/get.dart';

import 'domain/dev_tools.dart';
import 'domain/http_cache_store.dart';

/// Rx mirror of the HTTP cache for a settings screen: size, hit rate, clear().
///
/// Optional — the interceptor works without it. Register it with
/// Get.put(HttpCacheService(), permanent: true) if a screen needs the numbers.
class HttpCacheService extends GetxService {
  final Rx<HttpCacheStats> stats = const HttpCacheStats.empty().obs;
  final RxBool isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadStats();
  }

  Future<void> loadStats() async {
    try {
      stats.value = await HttpCache.stats();
    } catch (e) {
      devPrint('HttpCacheService: stats failed: $e');
    }
  }

  /// Wipes stored responses and the counters. Session data is untouched.
  Future<void> clear() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      await HttpCache.reset();
    } catch (e) {
      devPrint('HttpCacheService: clear failed: $e');
    } finally {
      await loadStats();
      isBusy.value = false;
    }
  }

  /// Drops cached responses whose url contains [urlPart] — use after a write
  /// that invalidates a list the server does not version.
  Future<int> invalidate(String urlPart) async {
    try {
      final dropped = await HttpCache.store.invalidatePrefix(urlPart);
      await loadStats();
      return dropped;
    } catch (e) {
      devPrint('HttpCacheService: invalidate failed: $e');
      return 0;
    }
  }

  @override
  void onClose() {
    stats.close();
    isBusy.close();
    super.onClose();
  }
}
