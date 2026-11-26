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

  /// Removes score documents while their parent fixture still exists.
  ///
  /// The Firestore rules intentionally require a linked fixture for score
  /// deletes. Deleting the fixture first would leave an orphaned private score
  /// and, potentially, a public scorecard that can no longer be cleaned up.
  Future<void> delete(String matchId) async {
    await Future.wait([
      _db.collection(Collections.matchScores).doc(matchId).delete(),
      _db.collection(Collections.publicMatchScores).doc(matchId).delete(),
    ]);
    await _db.collection(Collections.matches).doc(matchId).delete();
  }
}
