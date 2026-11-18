import '../constants.dart';
import '../models/innings.dart';
import '../models/public_models.dart';
import '../text_utils.dart';

/// One row of a tournament table.
class StandingRow {
  StandingRow({required this.teamId, required this.name});

  final String teamId;
  final String name;
  int played = 0;
  int wins = 0;
  int losses = 0;
  int runsScored = 0;
  int ballsFaced = 0;
  int runsConceded = 0;
  int ballsBowled = 0;

  /// 2 points per win; ties and no-results score nothing.
  int get points => wins * 2;

  double get netRunRate {
    final rateFor = ballsFaced > 0 ? runsScored * 6 / ballsFaced : 0.0;
    final rateAgainst = ballsBowled > 0 ? runsConceded * 6 / ballsBowled : 0.0;
    return rateFor - rateAgainst;
  }
}

/// Computes a tournament table from published match snapshots
/// (port of `calculateStandings` in `public-tournaments.js`).
abstract final class Standings {
  static List<StandingRow> calculate(
    PublicTournament tournament,
    Iterable<PublicMatchScore> matches,
  ) {
    final rows = <String, StandingRow>{
      for (final id in tournament.teamIds)
        id: StandingRow(teamId: id, name: tournament.teamNames[id] ?? 'Team'),
    };

    for (final match in matches) {
      if (match.tournamentId != tournament.id ||
          match.status != PublicStatus.completed ||
          match.innings.length < 2 ||
          !match.innings[0].completed ||
          !match.innings[1].completed) {
        continue;
      }
      final first = match.innings[0];
      final second = match.innings[1];
      final a = rows[first.battingTeamId];
      final b = rows[second.battingTeamId];
      if (first.battingTeamId.isEmpty ||
          second.battingTeamId.isEmpty ||
          first.battingTeamId == second.battingTeamId ||
          a == null ||
          b == null) {
        continue;
      }

      final allocated = match.overs < 1 ? 1 : match.overs;
      final firstBalls = _ballsForNrr(first, allocated);
      final secondBalls = _ballsForNrr(second, allocated);

      a.played++;
      b.played++;
      a.runsScored += first.total;
      a.ballsFaced += firstBalls;
      b.runsConceded += first.total;
      b.ballsBowled += firstBalls;

      b.runsScored += second.total;
      b.ballsFaced += secondBalls;
      a.runsConceded += second.total;
      a.ballsBowled += secondBalls;

      if (first.total > second.total) {
        a.wins++;
        b.losses++;
      } else if (second.total > first.total) {
        b.wins++;
        a.losses++;
      }
      // A tie counts as played, with no win/loss.
    }

    final table = rows.values.toList()
      ..sort((x, y) {
        final byPoints = y.points.compareTo(x.points);
        if (byPoints != 0) return byPoints;
        final byNrr = y.netRunRate.compareTo(x.netRunRate);
        if (byNrr != 0) return byNrr;
        final byWins = y.wins.compareTo(x.wins);
        return byWins != 0 ? byWins : compareNames(x.name, y.name);
      });
    return table;
  }

  /// Standard NRR rule: an all-out side is charged the full quota of overs.
  static int _ballsForNrr(Innings innings, int allocatedOvers) {
    if (innings.wickets >= 10) return allocatedOvers * 6;
    return innings.legalBalls < 0 ? 0 : innings.legalBalls;
  }
}
