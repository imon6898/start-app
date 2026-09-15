/// Numeric semver comparison. String compare gets "1.10.0" < "1.9.0" wrong —
/// this does not.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  /// Dot-separated pre-release identifiers, e.g. ["beta", "2"].
  final List<String> preRelease;

  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = const [],
  });

  static const SemanticVersion zero = SemanticVersion(0, 0, 0);

  /// Returns null when [raw] is missing or not a version at all.
  static SemanticVersion? tryParse(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    // Tolerate a "v" prefix.
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);

    // Build metadata is not part of precedence: "1.2.3+45", "1.2.3 (45)".
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    final space = s.indexOf(' ');
    if (space >= 0) s = s.substring(0, space);

    // Pre-release tail: "1.2.3-beta.2".
    var pre = const <String>[];
    final dash = s.indexOf('-');
    if (dash >= 0) {
      pre = s
          .substring(dash + 1)
          .split('.')
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      s = s.substring(0, dash);
    }

    final parts = s.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final nums = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p.trim());
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    // "1" and "1.4" are treated as "1.0.0" and "1.4.0".
    while (nums.length < 3) {
      nums.add(0);
    }

    return SemanticVersion(nums[0], nums[1], nums[2], preRelease: pre);
  }

  /// Lenient parse — junk becomes [zero] so a bad payload never blocks anyone.
  factory SemanticVersion.parse(String? raw) => tryParse(raw) ?? zero;

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major < other.major ? -1 : 1;
    if (minor != other.minor) return minor < other.minor ? -1 : 1;
    if (patch != other.patch) return patch < other.patch ? -1 : 1;
    return _comparePreRelease(preRelease, other.preRelease);
  }

  // Semver 2.0: a pre-release ranks BELOW its own release.
  static int _comparePreRelease(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;
    for (var i = 0; i < a.length && i < b.length; i++) {
      final c = _compareIdentifier(a[i], b[i]);
      if (c != 0) return c;
    }
    return a.length.compareTo(b.length);
  }

  // Numeric identifiers compare numerically and rank below alphanumeric ones.
  static int _compareIdentifier(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final core = '$major.$minor.$patch';
    return preRelease.isEmpty ? core : '$core-${preRelease.join('.')}';
  }
}
