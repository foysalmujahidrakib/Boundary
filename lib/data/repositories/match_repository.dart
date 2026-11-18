import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/constants.dart';
import '../../domain/models/cricket_match.dart';
import '../firestore_codec.dart';

/// Fixtures (port of `matches.js`).
class MatchRepository {
  MatchRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<CricketMatch>> watchMatches(String clubId) => _db
      .collection(Collections.matches)
      .where('clubId', isEqualTo: clubId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs
                .map((d) => CricketMatch.fromMap(d.id, d.decodedData))
                .toList()
              ..sort(CricketMatch.byDateThenTime),
      );

  Future<CricketMatch?> getMatch(String matchId) async {
    final doc = await _db.collection(Collections.matches).doc(matchId).get();
    final data = doc.decoded;
    return data == null ? null : CricketMatch.fromMap(doc.id, data);
  }

  Future<void> save(
    CricketMatch match, {
    String? matchId,
    required String userId,
  }) async {
    final payload = {
      ...match.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final matches = _db.collection(Collections.matches);
    if (matchId != null) {
      await matches.doc(matchId).update(payload);
    } else {
      await matches.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
    }
  }

  Future<void> delete(String matchId) =>
      _db.collection(Collections.matches).doc(matchId).delete();
}
