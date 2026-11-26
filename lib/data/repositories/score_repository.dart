import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/constants.dart';
import '../../domain/models/cricket_match.dart';
import '../../domain/models/innings.dart';
import '../../domain/models/public_models.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../firestore_codec.dart';

/// Live scoring storage (port of the Firestore parts of `scoring.js`).
///
/// All writes to `matchScores/{matchId}` happen inside transactions that
/// re-read the latest innings first, so two scorers can never overwrite each
/// other's deliveries with stale data.
class ScoreRepository {
  ScoreRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _scoreRef(String matchId) =>
      _db.collection(Collections.matchScores).doc(matchId);

  /// Live view of the score document (`null` until the first innings starts).
  Stream<MatchScore?> watchScore(String matchId) =>
      _scoreRef(matchId).snapshots().map((doc) {
        final data = doc.decoded;
        return data == null ? null : MatchScore.fromMap(doc.id, data);
      });

  /// Starts the first or second innings.
  Future<MatchScore> startInnings({
    required String clubId,
    required String matchId,
    required Innings innings,
    required String userId,
  }) {
    final ref = _scoreRef(matchId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.exists ? snap.decoded : null;
      final existing = data == null
          ? const <Innings>[]
          : MatchScore.fromMap(snap.id, data).innings;

      if (innings.number == 1 && snap.exists) {
        throw const ScoringException('An innings already exists.');
      }
      if (innings.number == 2 &&
          (existing.length != 1 || !existing.first.completed)) {
        throw const ScoringException(
          'Complete the first innings before starting the second.',
        );
      }

      final all = [...existing, innings];
      final encoded = all.map((i) => i.toMap()).toList();
      if (snap.exists) {
        tx.update(ref, {
          'innings': encoded,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'clubId': clubId,
          'matchId': matchId,
          'innings': encoded,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return MatchScore(matchId: matchId, clubId: clubId, innings: all);
    });
  }

  /// Applies [change] to the latest version of one innings, atomically.
  ///
  /// [change] receives the freshly read innings and the whole score, and may
  /// throw a [ScoringException] to abort. Returns the saved score.
  Future<MatchScore> mutateInnings({
    required String matchId,
    required int inningsIndex,
    required String userId,
    required Innings Function(Innings current, MatchScore score) change,
  }) {
    final ref = _scoreRef(matchId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.decoded;
      if (data == null) throw const ScoringException('Score record missing.');
      final score = MatchScore.fromMap(snap.id, data);
      if (inningsIndex < 0 || inningsIndex >= score.innings.length) {
        throw const ScoringException('This innings could not be found.');
      }

      final updated = change(score.innings[inningsIndex], score);
      final all = [
        for (var i = 0; i < score.innings.length; i++)
          i == inningsIndex ? updated : score.innings[i],
      ];
      tx.update(ref, {
        'innings': all.map((i) => i.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
      return MatchScore(
        matchId: score.matchId,
        clubId: score.clubId,
        innings: all,
      );
    });
  }

  // ----------------------------------------------------------- public copy

  /// Publishes the curated, world-readable snapshot of the match
  /// (`publicMatchScores/{matchId}`) shown on the homepage and live centre.
  Future<void> publishPublicScore({
    required CricketMatch match,
    required MatchScore score,
    required Map<String, String> teamNames,
    required Map<String, String> playerNames,
    required String result,
  }) {
    String nameOf(String id) => teamNames[id] ?? 'Unknown team';
    final title = match.title.isNotEmpty
        ? match.title
        : '${nameOf(match.teamAId)} vs ${nameOf(match.teamBId)}';

    return _db.collection(Collections.publicMatchScores).doc(match.id).set({
      'matchId': match.id,
      'clubId': match.clubId,
      'tournamentId': match.tournamentId,
      'title': title,
      'matchDate': match.matchDate,
      'startTime': match.startTime,
      'venue': match.venue,
      'format': match.format,
      'overs': match.overs,
      'teamAId': match.teamAId,
      'teamBId': match.teamBId,
      'teamNames': teamNames,
      'playerNames': playerNames,
      'innings': score.innings.map((i) => i.toMap()).toList(),
      'result': result,
      'status': PublicStatuses.derive(
        innings: score.innings,
        matchStatus: match.status,
      ),
      'matchStatus': PublicStatuses.normalize(match.status),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fixes public snapshots that still say `live` although the fixture was
  /// marked completed/abandoned (port of `repairClubPublicStatuses`).
  /// Best effort: errors are swallowed.
  Future<void> repairClubPublicStatuses(String clubId) async {
    try {
      final results = await Future.wait([
        _db
            .collection(Collections.publicMatchScores)
            // Restrict housekeeping to this club. Querying every live match
            // becomes increasingly expensive as other clubs use the app.
            .where('clubId', isEqualTo: clubId)
            .get(),
        _db
            .collection(Collections.matches)
            .where('clubId', isEqualTo: clubId)
            .get(),
      ]);
      final liveSnap = results[0];
      final matchStatusById = {
        for (final d in results[1].docs)
          d.id: PublicStatuses.normalize(d.data()['status']?.toString()),
      };

      final updates = <Future<void>>[];
      for (final doc in liveSnap.docs) {
        final data = doc.decodedData;
        if (data['clubId'] != clubId) continue;

        final public = PublicMatchScore.fromMap(doc.id, data);
        if (public.status != PublicStatus.live) continue;
        final linked =
            matchStatusById[public.matchId] ??
            PublicStatuses.normalize(public.matchStatus);
        final expected = PublicStatuses.derive(
          innings: public.innings,
          matchStatus: linked,
        );
        if (expected == PublicStatus.live &&
            PublicStatuses.normalize(public.matchStatus) == linked) {
          continue;
        }
        updates.add(
          doc.reference.set({
            'status': expected,
            'matchStatus': linked,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
      }
      await Future.wait(updates);
    } catch (_) {
      // Housekeeping only; never block scoring.
    }
  }
}
