import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/constants.dart';
import '../../domain/models/team.dart';
import '../../domain/text_utils.dart';
import '../firestore_codec.dart';

/// Teams and players of a club (port of the data code in `club.js`).
///
/// Both collections are exposed as live streams: any add / edit / delete from
/// this device or another one re-renders the squads automatically.
class RosterRepository {
  RosterRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<Team>> watchTeams(String clubId) => _db
      .collection(Collections.teams)
      .where('clubId', isEqualTo: clubId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Team.fromMap(d.id, d.decodedData)).toList()
              ..sort((a, b) => compareNames(a.name, b.name)),
      );

  Stream<List<Player>> watchPlayers(String clubId) => _db
      .collection(Collections.players)
      .where('clubId', isEqualTo: clubId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Player.fromMap(d.id, d.decodedData)).toList()
              ..sort((a, b) => compareNames(a.fullName, b.fullName)),
      );

  /// One-off read (used by screens that do not need live updates).
  Future<List<Team>> loadTeams(String clubId) async {
    final snap = await _db
        .collection(Collections.teams)
        .where('clubId', isEqualTo: clubId)
        .get();
    return snap.docs.map((d) => Team.fromMap(d.id, d.decodedData)).toList()
      ..sort((a, b) => compareNames(a.name, b.name));
  }

  Future<List<Player>> loadPlayers(String clubId) async {
    final snap = await _db
        .collection(Collections.players)
        .where('clubId', isEqualTo: clubId)
        .get();
    return snap.docs.map((d) => Player.fromMap(d.id, d.decodedData)).toList()
      ..sort((a, b) => compareNames(a.fullName, b.fullName));
  }

  /// Creates a team (when [teamId] is null) or updates it.
  Future<void> saveTeam(
    Team team, {
    String? teamId,
    required String userId,
  }) async {
    final payload = {
      ...team.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final teams = _db.collection(Collections.teams);
    if (teamId != null) {
      await teams.doc(teamId).update(payload);
    } else {
      await teams.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
    }
  }

  Future<void> deleteTeam(String teamId) =>
      _db.collection(Collections.teams).doc(teamId).delete();

  Future<void> savePlayer(
    Player player, {
    String? playerId,
    required String userId,
  }) async {
    final payload = {
      ...player.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final players = _db.collection(Collections.players);
    if (playerId != null) {
      await players.doc(playerId).update(payload);
    } else {
      await players.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
    }
  }

  Future<void> deletePlayer(String playerId) =>
      _db.collection(Collections.players).doc(playerId).delete();
}
