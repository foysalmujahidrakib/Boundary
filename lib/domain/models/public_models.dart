import '../constants.dart';
import 'innings.dart';
import 'json_read.dart';

/// `publicTournaments/{id}`: the read-only summary shown on the homepage.
class PublicTournament {
  const PublicTournament({
    required this.id,
    required this.clubId,
    required this.name,
    this.season = '',
    this.format = '',
    this.startDate = '',
    this.endDate = '',
    this.venue = '',
    this.status = 'planned',
    this.teamIds = const [],
    this.teamNames = const {},
  });

  factory PublicTournament.fromMap(String id, Map<String, dynamic> data) =>
      PublicTournament(
        id: id,
        clubId: data.str('clubId'),
        name: data.str('name'),
        season: data.str('season'),
        format: data.str('format'),
        startDate: data.str('startDate'),
        endDate: data.str('endDate'),
        venue: data.str('venue'),
        status: data.str('status', 'planned'),
        teamIds: data.stringList('teamIds'),
        teamNames: {
          for (final e in data.nested('teamNames').entries)
            e.key: e.value.toString(),
        },
      );

  final String id;
  final String clubId;
  final String name;
  final String season;
  final String format;
  final String startDate;
  final String endDate;
  final String venue;
  final String status;
  final List<String> teamIds;
  final Map<String, String> teamNames;

  /// Writable fields in the exact shape the Firestore rules allow
  /// (`hasOnly([...])`, so nothing else may be added; `updatedAt` is added by
  /// the repository).
  Map<String, dynamic> toMap() => {
    'clubId': clubId,
    'name': name,
    'season': season,
    'format': format,
    'startDate': startDate,
    'endDate': endDate,
    'venue': venue,
    'status': status,
    'teamIds': teamIds,
    'teamNames': teamNames,
  };

  /// True when the private tournament differs from this public copy, so it
  /// needs re-publishing (renamed team, edited date, ...).
  bool isStaleComparedTo(PublicTournament other) {
    bool same(String a, String b) => a == b;
    if (!same(name, other.name) ||
        !same(season, other.season) ||
        !same(format, other.format) ||
        !same(startDate, other.startDate) ||
        !same(endDate, other.endDate) ||
        !same(venue, other.venue) ||
        !same(status, other.status)) {
      return true;
    }
    if (teamIds.length != other.teamIds.length) return true;
    for (var i = 0; i < teamIds.length; i++) {
      if (teamIds[i] != other.teamIds[i]) return true;
    }
    if (teamNames.length != other.teamNames.length) return true;
    for (final e in teamNames.entries) {
      if (other.teamNames[e.key] != e.value) return true;
    }
    return false;
  }
}

/// `publicMatchScores/{matchId}`: a curated, world-readable score snapshot.
class PublicMatchScore {
  const PublicMatchScore({
    required this.matchId,
    required this.clubId,
    required this.title,
    required this.teamAId,
    required this.teamBId,
    required this.innings,
    this.tournamentId,
    this.matchDate = '',
    this.startTime = '',
    this.venue = '',
    this.format = '',
    this.overs = 20,
    this.teamNames = const {},
    this.playerNames = const {},
    this.result = '',
    this.status = '',
    this.matchStatus = '',
    this.updatedAt,
  });

  factory PublicMatchScore.fromMap(String id, Map<String, dynamic> data) =>
      PublicMatchScore(
        matchId: data.str('matchId', id),
        clubId: data.str('clubId'),
        tournamentId: data.strOrNull('tournamentId'),
        title: data.str('title'),
        matchDate: data.str('matchDate'),
        startTime: data.str('startTime'),
        venue: data.str('venue'),
        format: data.str('format'),
        overs: data.integer('overs', 20),
        teamAId: data.str('teamAId'),
        teamBId: data.str('teamBId'),
        teamNames: {
          for (final e in data.nested('teamNames').entries)
            e.key: e.value.toString(),
        },
        playerNames: {
          for (final e in data.nested('playerNames').entries)
            e.key: e.value.toString(),
        },
        innings: data.mapList('innings').map(Innings.fromMap).toList(),
        result: data.str('result'),
        status: data.str('status'),
        matchStatus: data.str('matchStatus'),
        updatedAt: data.dateTime('updatedAt'),
      );

  final String matchId;
  final String clubId;
  final String? tournamentId;
  final String title;
  final String matchDate;
  final String startTime;
  final String venue;
  final String format;
  final int overs;
  final String teamAId;
  final String teamBId;
  final Map<String, String> teamNames;
  final Map<String, String> playerNames;
  final List<Innings> innings;
  final String result;

  /// `live` | `completed` | `abandoned` | `cancelled`.
  final String status;

  /// The private fixture status at publish time (normalized).
  final String matchStatus;
  final DateTime? updatedAt;

  String teamName(String? id, [String fallback = 'Team']) =>
      teamNames[id] ?? fallback;

  String playerName(String? id) => playerNames[id] ?? 'Player';

  /// `Dhaka FC vs Rangpur` when the fixture has no custom title.
  String get displayTitle {
    if (title.isNotEmpty) return title;
    return '${teamName(teamAId, 'Team A')} vs ${teamName(teamBId, 'Team B')}';
  }

  /// `2026-11-14 · 14:00 · Mirpur · T20`
  String get meta => [
    matchDate,
    startTime,
    venue,
    format,
  ].where((p) => p.isNotEmpty).join(' · ');

  /// The match is still being played.
  bool get isGenuinelyLive {
    if (PublicStatuses.normalize(status) != PublicStatus.live) return false;
    if (PublicStatus.terminal.contains(PublicStatuses.normalize(matchStatus))) {
      return false;
    }
    if (innings.length > 1 && innings[1].completed) return false;
    return true;
  }
}

/// Status helpers shared by the scorer (when publishing) and the feeds.
abstract final class PublicStatuses {
  static String normalize(String? value) => (value ?? '').trim().toLowerCase();

  /// What `publicMatchScores.status` should be for the current score.
  static String derive({
    required List<Innings> innings,
    required String matchStatus,
  }) {
    final normalized = normalize(matchStatus);
    if (normalized == PublicStatus.completed) return PublicStatus.completed;
    if (normalized == PublicStatus.abandoned ||
        normalized == PublicStatus.cancelled) {
      return normalized;
    }
    final secondDone = innings.length > 1 && innings[1].completed;
    return secondDone ? PublicStatus.completed : PublicStatus.live;
  }

  /// Heading badge on a public scorecard.
  static String scorecardBadge(String status) => switch (normalize(status)) {
    PublicStatus.completed => 'MATCH COMPLETED',
    PublicStatus.abandoned => 'MATCH ABANDONED',
    PublicStatus.cancelled => 'MATCH CANCELLED',
    _ => 'LIVE SCORE',
  };

  /// Short chip on live-match cards: `LIVE`, `INNINGS BREAK` or `RESULT`.
  static String liveChip(PublicMatchScore match) {
    final status = normalize(match.status);
    if (PublicStatus.terminal.contains(status)) return 'RESULT';
    if (match.innings.length == 1 && match.innings.first.completed) {
      return 'INNINGS BREAK';
    }
    return 'LIVE';
  }
}
