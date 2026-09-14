import 'package:dio/dio.dart';
import 'package:flutter_starter/app/services/ip_location_service.dart';

/// Adds lat/lon IP lookup back to the core [IpLocationService] (core only keeps the ISO lookup).
extension IpGeoLocation on IpLocationService {
  static const String _ipApiUrl = 'http://ip-api.com/json/';

  /// Approximate location from IP. Returns null on any failure.
  Future<Map<String, dynamic>?> getApproximateLocation() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    try {
      final response = await dio.get(_ipApiUrl);
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'success') {
          // Warm the core ISO cache while we are here.
          final iso = data['countryCode'];
          if (iso is String && iso.length == 2) {
            IpLocationService.cachedCountryIso = iso.toUpperCase();
          }
          return {
            'latitude': data['lat'],
            'longitude': data['lon'],
            'city': data['city'],
            'country': data['country'],
            'countryCode': data['countryCode'],
            'ip': data['query'],
          };
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
