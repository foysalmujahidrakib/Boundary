import 'json_read.dart';

/// A competition (`tournaments/{tournamentId}`), private to the club.
class Tournament {
  const Tournament({
    required this.id,
    required this.clubId,
    required this.name,
    this.season = '',
    this.format = 'T20',
    this.startDate = '',
    this.endDate = '',
    this.venue = '',
    this.status = 'planned',
    this.teamIds = const [],
  });

  factory Tournament.fromMap(String id, Map<String, dynamic> data) =>
      Tournament(
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
      );

  final String id;
  final String clubId;
  final String name;
  final String season;
  final String format;

  /// ISO dates (`yyyy-MM-dd`), stored as strings exactly like the web app.
  final String startDate;
  final String endDate;
  final String venue;
  final String status;
  final List<String> teamIds;

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
  };
}
