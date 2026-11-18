import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts raw Firestore data into plain Dart values.
///
/// The only Firestore-specific type that leaks into documents is `Timestamp`;
/// it is turned into [DateTime] here so the domain models stay free of any
/// Firebase import.
Map<String, dynamic> decodeData(Map<String, dynamic> raw) => {
  for (final e in raw.entries) e.key: _decode(e.value),
};

Object? _decode(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is Map) {
    return {for (final e in value.entries) e.key.toString(): _decode(e.value)};
  }
  if (value is List) return value.map(_decode).toList();
  return value;
}

extension DecodedSnapshot on DocumentSnapshot<Map<String, dynamic>> {
  /// The document's data with timestamps converted, or `null` if missing.
  Map<String, dynamic>? get decoded {
    final raw = data();
    return raw == null ? null : decodeData(raw);
  }
}

extension DecodedQueryDoc on QueryDocumentSnapshot<Map<String, dynamic>> {
  Map<String, dynamic> get decodedData => decodeData(data());
}
