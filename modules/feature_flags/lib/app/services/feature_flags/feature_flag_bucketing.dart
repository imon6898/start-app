// Deterministic bucketing. The same (id, key) pair must land in the same bucket
// on every launch, every device and on the server — otherwise a user flips
// between variants and the experiment measures nothing.

import 'dart:convert';

class FlagBucketing {
  FlagBucketing._();

  /// FNV-1a, 32 bit, over the UTF-8 bytes. Picked because it is a dozen lines
  /// in any backend language, so the server can reproduce a bucket exactly.
  /// Not a cryptographic hash and not meant to be one.
  static int hash(String input) {
    var h = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      h ^= byte;
      h = _mul32(h, 0x01000193);
    }
    return h;
  }

  /// Enrolment bucket, 0-99: `hash('<id>:<key>') % 100`.
  static int bucketOf(String id, String key) => hash('$id:$key') % 100;

  /// Variant bucket uses a second salt, so changing `exposure` moves who is
  /// enrolled without reshuffling which variant the enrolled users see.
  static int variantBucketOf(String id, String key) =>
      hash('$id:$key#variant') % 100;

  /// Even split of the 0-99 space across [variants]; null when there are none.
  static String? variantOf(String id, String key, List<String> variants) {
    if (variants.isEmpty) return null;
    final index = (variantBucketOf(id, key) * variants.length) ~/ 100;
    return variants[index >= variants.length ? variants.length - 1 : index];
  }

  /// True when [id] falls inside a [percent] rollout of [key].
  static bool inRollout(String id, String key, int percent) {
    if (percent <= 0) return false;
    if (percent >= 100) return true;
    return bucketOf(id, key) < percent;
  }

  // 32-bit multiply that also holds on JS, where int is a double and a plain
  // a * b would lose the low bits.
  static int _mul32(int a, int b) {
    final lo = (a & 0xFFFF) * b;
    final hi = ((a >> 16) * b) & 0xFFFF;
    return (lo + (hi << 16)) & 0xFFFFFFFF;
  }
}
