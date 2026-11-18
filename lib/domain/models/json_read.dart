/// Tolerant readers for Firestore document maps.
///
/// Firestore data is loosely typed (a number may come back as `int` or
/// `double`, fields may be missing on legacy documents, ...). The web app
/// copes with that through JavaScript's coercion rules (`Number(x || 0)`,
/// `x ?? ''`); these helpers give the Dart models the same forgiving behaviour.
extension JsonRead on Map<String, dynamic> {
  /// A string field, or [fallback] when missing / null.
  String str(String key, [String fallback = '']) {
    final value = this[key];
    return value == null ? fallback : value.toString();
  }

  /// A nullable string field. Empty strings are returned as-is.
  String? strOrNull(String key) {
    final value = this[key];
    return value?.toString();
  }

  /// A whole-number field, or [fallback] when missing / not numeric.
  int integer(String key, [int fallback = 0]) {
    final value = this[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// A nullable whole-number field.
  int? integerOrNull(String key) {
    final value = this[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// A boolean field, or [fallback] when missing / not a bool.
  bool flag(String key, [bool fallback = false]) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  /// A list of strings (empty when missing).
  List<String> stringList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<Object>().map((e) => e.toString()).toList();
  }

  /// A nested map field (empty when missing).
  Map<String, dynamic> nested(String key) {
    final value = this[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// A list of nested maps (non-map entries are skipped).
  List<Map<String, dynamic>> mapList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// A timestamp field. The data layer converts Firestore `Timestamp`s to
  /// [DateTime] before models are built, so the domain stays Firebase-free.
  DateTime? dateTime(String key) {
    final value = this[key];
    return value is DateTime ? value : null;
  }
}
