import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/constants.dart';
import '../../domain/models/public_models.dart';
import '../firestore_codec.dart';

/// Everything visitors can read without signing in (port of
/// `public-live.js`, `livematches.js`, `public-scorecard.js` and
/// `public-tournaments.js`).
class PublicRepository {
  PublicRepository(this._db);

  final FirebaseFirestore _db;

  /// Matches currently being played, most recently updated first.
  Stream<List<PublicMatchScore>> watchLiveMatches() => _db
      .collection(Collections.publicMatchScores)
      .where('status', isEqualTo: PublicStatus.live)
      .snapshots()
      .map((snap) {
        final matches = snap.docs
            .map((d) => PublicMatchScore.fromMap(d.id, d.decodedData))
            .where((m) => m.isGenuinelyLive)
            .toList();
        matches.sort(
          (a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
            a.updatedAt?.millisecondsSinceEpoch ?? 0,
          ),
        );
        return matches;
      });

  /// Finished matches, used for tournament standings. (The web app read the
  /// whole collection and filtered on the client; the standings only ever use
  /// `completed` matches, so filtering on the server reads far fewer
  /// documents.)
  Stream<List<PublicMatchScore>> watchCompletedMatches() => _db
      .collection(Collections.publicMatchScores)
      .where('status', isEqualTo: PublicStatus.completed)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => PublicMatchScore.fromMap(d.id, d.decodedData))
            .toList(),
      );

  Stream<List<PublicTournament>> watchTournaments() => _db
      .collection(Collections.publicTournaments)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => PublicTournament.fromMap(d.id, d.decodedData))
            .toList(),
      );

      /// Tournaments currently in progress (`status == ongoing`).
  Stream<List<PublicTournament>> watchOngoingTournaments() => _db
      .collection(Collections.publicTournaments)
      .where('status', isEqualTo: TournamentStatus.ongoing)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => PublicTournament.fromMap(d.id, d.decodedData))
          .toList());

  /// One published match (`null` while nothing has been published).
  Stream<PublicMatchScore?> watchMatch(String matchId) => _db
      .collection(Collections.publicMatchScores)
      .doc(matchId)
      .snapshots()
      .map((doc) {
        final data = doc.decoded;
        return data == null ? null : PublicMatchScore.fromMap(doc.id, data);
      });
}
  