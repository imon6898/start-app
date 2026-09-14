import 'package:dio/dio.dart';
import 'package:get/get.dart';

class IpLocationService extends GetxService {
  static IpLocationService get to => Get.find();

  final Dio _dio = Dio();

  /// HTTPS, no API key, returns `{"ip":"...","country":"US"}`. We use it
  /// only for the country-ISO lookup — the values flow into
  /// [CustomPhoneTextField] which only needs the ISO code.
  static const String _countryIsUrl = 'https://api.country.is/';

  /// In-memory cache. Populated by [preload] or by the first successful
  /// [getCountryIso] call. Read synchronously by
  /// `CountryData.fromIpCached()`.
  static String? cachedCountryIso;

  @override
  void onInit() {
    super.onInit();
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 5);
  }

  /// Lightweight ISO-only lookup over HTTPS. Caches the result.
  /// Returns null on any failure (no exceptions thrown).
  Future<String?> getCountryIso() async {
    if (cachedCountryIso != null) return cachedCountryIso;
    try {
      final response = await _dio.get(_countryIsUrl);
      if (response.statusCode == 200 && response.data is Map) {
        final iso = (response.data as Map)['country'];
        if (iso is String && iso.length == 2) {
          cachedCountryIso = iso.toUpperCase();
          return cachedCountryIso;
        }
      }
    } catch (_) {
      // Swallow — IP lookup is best-effort.
    }
    return null;
  }

  /// Fire-and-forget. Call from `main()` after Get is wired up so the
  /// cache is warm by the time the first phone field renders. Safe to
  /// call multiple times — no-ops if already cached.
  static Future<void> preload() async {
    if (cachedCountryIso != null) return;
    try {
      // Resolve via Get if registered, otherwise create a one-shot instance.
      final svc = Get.isRegistered<IpLocationService>()
          ? IpLocationService.to
          : (IpLocationService()..onInit());
      await svc.getCountryIso();
    } catch (_) {
      // Best-effort preload; never throws.
    }
  }
}
