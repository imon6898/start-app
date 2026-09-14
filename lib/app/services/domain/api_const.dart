import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstant {
  //final String apiKey
  static String get gapikey => dotenv.get(
    'GOOGLE_MAPS_API_KEY_ALL_IN_ONE',
    fallback: '',
  );
  static const String googleBaseUrl = "https://maps.googleapis.com";
  //BASE URL
  static String get devBaseUrl => dotenv.get('DEV_BASE_URL', fallback: '');
  static String get baseUrl => dotenv.get('BASE_URL', fallback: '');
  static String get logisticsBaseUrl => dotenv.get('LOGISTICS_BASE_URL', fallback: '');
  static String get devLogisticsBaseUrl => dotenv.get('DEV_LOGISTICS_BASE_URL', fallback: '');
  static String get imageUrl => dotenv.get('IMAGE_URL', fallback: '');
  static String get stripePublishableKey => dotenv.get(
    'STRIPE_PUBLISHABLE_KEY',
    fallback: '',
  );
  static String get bibleApiKey => dotenv.get('BIBLE_API_KEY', fallback: '');
  static String get socketUrl => dotenv.get('SOCKET_URL', fallback: '');
  static String get socketUrlDev => dotenv.get('SOCKET_URL_DEV', fallback: '');

  //common data api end point
  static String getLocationData(String lat, String lang) =>
      "$googleBaseUrl/maps/api/place/nearbysearch/json?location=$lat,$lang&radius=5000&type=church&key=$gapikey";

  ///Base Modules Service
  // Auth lives at https://api.yaad.global/logistics-acc/* and mints tokens
  // in the `logistics` Keycloak realm (azp: logistics-admin) — the same
  // realm the logistics service trusts. Do not switch back to `/acc` unless
  // the backend re-aligns realms.
  static const String acc = "/logistics-acc";
  static const String core = "/core";
  static const String inv = "/inv";
  static const String chat = "/chat";

  ///END POINT
  //Auth
  static const String loginUri = "$acc/auth/login";
}
