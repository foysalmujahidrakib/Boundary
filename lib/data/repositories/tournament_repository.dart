import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/constants.dart';
import '../../domain/models/public_models.dart';
import '../../domain/models/team.dart';
import '../../domain/models/tournament.dart';
import '../firestore_codec.dart';

/// Tournaments and their public standings summaries (port of `tournaments.js`).
///
/// Every private tournament is mirrored to `publicTournaments/{id}` so the
/// homepage can show standings without signing in.
class TournamentRepository {
  TournamentRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<Tournament>> watchTournaments(String clubId) => _db
      .collection(Collections.tournaments)
      .where('clubId', isEqualTo: clubId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs
                .map((d) => Tournament.fromMap(d.id, d.decodedData))
                .toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate)),
      );

  /// Creates or updates a tournament and publishes its public summary.
  Future<void> save(
    Tournament tournament, {
    String? tournamentId,
    required String userId,
    required List<Team> teams,
  }) async {
    final payload = {
      ...tournament.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final collection = _db.collection(Collections.tournaments);
    var id = tournamentId;
    if (id != null) {
      await collection.doc(id).update(payload);
    } else {
      final created = await collection.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
      id = created.id;
    }
    await _publish(id, tournament, teams);
  }

  /// Deletes the public copy first, then the tournament.
  Future<void> delete(String tournamentId) async {
    final publicRef = _db
        .collection(Collections.publicTournaments)
        .doc(tournamentId);
    if ((await publicRef.get()).exists) await publicRef.delete();
    await _db.collection(Collections.tournaments).doc(tournamentId).delete();
  }

  /// Keeps every public summary current. Covers tournaments created before
  /// publishing existed and renamed teams. Failures are ignored (best effort).
  Future<void> syncPublicCopies(
    List<Tournament> tournaments,
    List<Team> teams,
  ) async {
    await Future.wait(
      tournaments.map((tournament) async {
        try {
          final publicDoc = await _db
              .collection(Collections.publicTournaments)
              .doc(tournament.id)
              .get();
          final data = publicDoc.decoded;
          final desired = _toPublic(tournament.id, tournament, teams);
          if (data == null ||
              PublicTournament.fromMap(
                tournament.id,
                data,
              ).isStaleComparedTo(desired)) {
            await _publish(tournament.id, tournament, teams);
          }
        } catch (_) {
          // Best effort: standings simply stay as they were.
        }
      }),
    );
  }

  PublicTournament _toPublic(String id, Tournament t, List<Team> teams) =>
      PublicTournament(
        id: id,
        clubId: t.clubId,
        name: t.name,
        season: t.season,
        format: t.format,
        startDate: t.startDate,
        endDate: t.endDate,
        venue: t.venue,
        status: t.status,
        teamIds: t.teamIds,
        teamNames: {
          for (final teamId in t.teamIds)
            teamId:
                teams.where((x) => x.id == teamId).firstOrNull?.name ??
                'Unknown team',
        },
      );

  Future<void> _publish(String id, Tournament t, List<Team> teams) {
    final data = _toPublic(id, t, teams).toMap();
    return _db.collection(Collections.publicTournaments).doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
