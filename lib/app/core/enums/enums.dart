enum UserType { user, vendor, guest, unknown }

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.user:
        return 'User';
      case UserType.vendor:
        return 'Vendor';
      case UserType.guest:
        return 'Guest';
      case UserType.unknown:
        return 'Unknown';
    }
  }

  bool get isGuest => this == UserType.guest;
  bool get isLoggedIn => this != UserType.guest && this != UserType.unknown;
}

/// Source a [CustomImage] renders from.
enum ImageType { file, network, asset, removeable }
