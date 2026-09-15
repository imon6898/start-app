/// What the gate decided to do with the running build.
enum AppUpdateAction {
  /// Current build is fine — show nothing.
  none,

  /// Newer build exists; dismissible sheet, snoozable.
  soft,

  /// Below the minimum supported build; non-dismissible screen.
  force,
}

/// The version gate payload returned by your backend.
class AppUpdateInfo {
  /// Oldest build still allowed to run. Anything below it is force-updated.
  final String minSupportedVersion;

  /// Newest build in the stores.
  final String latestVersion;

  /// Store link used when no platform-specific link is sent.
  final String updateUrl;

  /// Optional per-platform overrides of [updateUrl].
  final String androidUpdateUrl;
  final String iosUpdateUrl;

  /// Optional App Store numeric id, used to build a link when none was sent.
  final String iosAppId;

  /// Backend kill-switch — forces the update even above the minimum version.
  final bool force;

  /// Optional copy shown on the screen/sheet instead of the defaults.
  final String title;
  final String message;
  final List<String> releaseNotes;

  const AppUpdateInfo({
    this.minSupportedVersion = '',
    this.latestVersion = '',
    this.updateUrl = '',
    this.androidUpdateUrl = '',
    this.iosUpdateUrl = '',
    this.iosAppId = '',
    this.force = false,
    this.title = '',
    this.message = '',
    this.releaseNotes = const [],
  });

  AppUpdateInfo copyWith({
    String? minSupportedVersion,
    String? latestVersion,
    String? updateUrl,
    String? androidUpdateUrl,
    String? iosUpdateUrl,
    String? iosAppId,
    bool? force,
    String? title,
    String? message,
    List<String>? releaseNotes,
  }) {
    return AppUpdateInfo(
      minSupportedVersion: minSupportedVersion ?? this.minSupportedVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      updateUrl: updateUrl ?? this.updateUrl,
      androidUpdateUrl: androidUpdateUrl ?? this.androidUpdateUrl,
      iosUpdateUrl: iosUpdateUrl ?? this.iosUpdateUrl,
      iosAppId: iosAppId ?? this.iosAppId,
      force: force ?? this.force,
      title: title ?? this.title,
      message: message ?? this.message,
      releaseNotes: releaseNotes ?? this.releaseNotes,
    );
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      minSupportedVersion: _str(
        json['min_supported_version'] ?? json['minSupportedVersion'],
      ),
      latestVersion: _str(json['latest_version'] ?? json['latestVersion']),
      updateUrl: _str(json['update_url'] ?? json['updateUrl']),
      androidUpdateUrl: _str(
        json['android_update_url'] ?? json['androidUpdateUrl'],
      ),
      iosUpdateUrl: _str(json['ios_update_url'] ?? json['iosUpdateUrl']),
      iosAppId: _str(json['ios_app_id'] ?? json['iosAppId']),
      force: _bool(
        json['force'] ?? json['force_update'] ?? json['forceUpdate'],
      ),
      title: _str(json['title']),
      message: _str(json['message']),
      releaseNotes: _strList(json['release_notes'] ?? json['releaseNotes']),
    );
  }

  Map<String, dynamic> toJson() => {
    'min_supported_version': minSupportedVersion,
    'latest_version': latestVersion,
    'update_url': updateUrl,
    'android_update_url': androidUpdateUrl,
    'ios_update_url': iosUpdateUrl,
    'ios_app_id': iosAppId,
    'force': force,
    'title': title,
    'message': message,
    'release_notes': releaseNotes,
  };

  /// Platform override when the backend sent one, else the generic link.
  String urlFor({required bool isIOS}) {
    final specific = isIOS ? iosUpdateUrl : androidUpdateUrl;
    return specific.isNotEmpty ? specific : updateUrl;
  }

  static String _str(dynamic v) => v == null ? '' : v.toString().trim();

  // Backends send booleans as true, "true", 1 or "1" — accept all of them.
  static bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = _str(v).toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static List<String> _strList(dynamic v) {
    if (v is List) {
      return v.map(_str).where((e) => e.isNotEmpty).toList(growable: false);
    }
    final s = _str(v);
    return s.isEmpty ? const [] : [s];
  }
}
