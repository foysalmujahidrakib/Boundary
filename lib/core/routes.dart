/// Route names and their typed arguments.
///
/// The web app passed `?clubId=...&matchId=...` in the URL; the Flutter app
/// passes small argument objects through `Navigator.pushNamed(..., arguments:)`.
abstract final class AppRoutes {
  static const landing = '/';
  static const dashboard = '/dashboard';
  static const club = '/club';
  static const matches = '/matches';
  static const tournaments = '/tournaments';
  static const scoring = '/scoring';
  static const scorecard = '/scorecard';
  static const liveMatches = '/live';
  static const publicScorecard = '/public-scorecard';
  static const tournament = '/tournament';
  static const tournamentMatches = '/tournament-matches';
  //static const tournament = '/tournament';
  static const allMatches = '/all-matches';

}

/// Arguments for routes that work inside one club.
class ClubArgs {
  const ClubArgs(this.clubId);
  final String clubId;
}

/// Arguments for routes about one match of a club (scoring, scorecard).
class MatchArgs {
  const MatchArgs({required this.clubId, required this.matchId});
  final String clubId;
  final String matchId;
}

/// Arguments for the public (signed-out) scorecard.
class PublicMatchArgs {
  const PublicMatchArgs(this.matchId);
  final String matchId;
}
/// Arguments for the public list of one tournament's matches.
class TournamentMatchesArgs {
  const TournamentMatchesArgs({
    required this.tournamentId,
    required this.tournamentName,
  });
  final String tournamentId;
  final String tournamentName;
}