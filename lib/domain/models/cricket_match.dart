import 'json_read.dart';

/// A scheduled/played fixture (`matches/{matchId}`).
class CricketMatch {
  const CricketMatch({
    required this.id,
    required this.clubId,
    required this.teamAId,
    required this.teamBId,
    this.title = '',
    this.tournamentId,
    this.matchDate = '',
    this.startTime = '',
    this.venue = '',
    this.format = 'T20',
    this.overs = 20,
    this.status = 'scheduled',
    this.tossWinnerId,
    this.tossDecision,
    this.notes = '',
  });

  factory CricketMatch.fromMap(String id, Map<String, dynamic> data) {
    final overs = data.integer('overs', 20);
    return CricketMatch(
      id: id,
      clubId: data.str('clubId'),
      teamAId: data.str('teamAId'),
      teamBId: data.str('teamBId'),
      title: data.str('title'),
      tournamentId: _blankToNull(data.strOrNull('tournamentId')),
      matchDate: data.str('matchDate'),
      startTime: data.str('startTime'),
      venue: data.str('venue'),
      format: data.str('format'),
      // The web scorer treats a missing/zero value as a 20-over match.
      overs: overs <= 0 ? 20 : overs,
      status: data.str('status', 'scheduled'),
      tossWinnerId: _blankToNull(data.strOrNull('tossWinnerId')),
      tossDecision: _blankToNull(data.strOrNull('tossDecision')),
      notes: data.str('notes'),
    );
  }

  final String id;
  final String clubId;
  final String teamAId;
  final String teamBId;
  final String title;
  final String? tournamentId;
  final String matchDate;
  final String startTime;
  final String venue;
  final String format;
  final int overs;
  final String status;
  final String? tossWinnerId;
  final String? tossDecision;
  final String notes;

  Map<String, dynamic> toMap() => {
    'clubId': clubId,
    'title': title,
    'tournamentId': tournamentId,
    'teamAId': teamAId,
    'teamBId': teamBId,
    'matchDate': matchDate,
    'startTime': startTime,
    'venue': venue,
    'format': format,
    'overs': overs,
    'status': status,
    'tossWinnerId': tossWinnerId,
    'tossDecision': tossDecision,
    'notes': notes,
  };

  /// Fixtures sort by date, then start time (both ISO strings).
  static int byDateThenTime(CricketMatch a, CricketMatch b) {
    final byDate = a.matchDate.compareTo(b.matchDate);
    return byDate != 0 ? byDate : a.startTime.compareTo(b.startTime);
  }
}

String? _blankToNull(String? value) =>
    (value == null || value.isEmpty) ? null : value;
