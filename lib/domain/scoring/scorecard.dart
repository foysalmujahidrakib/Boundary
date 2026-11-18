import '../constants.dart';
import '../models/innings.dart';
import 'formatters.dart';

/// Extras split by type for one innings.
class ExtrasBreakdown {
  const ExtrasBreakdown({
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.penalties = 0,
  });

  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final int penalties;

  int get total => wides + noBalls + byes + legByes + penalties;

  /// `12 (Wd 4, Nb 2, B 3, Lb 3)`; penalties are appended only when present.
  String get summary {
    final pen = penalties > 0 ? ', P $penalties' : '';
    return '$total (Wd $wides, Nb $noBalls, B $byes, Lb $legByes$pen)';
  }
}

class BattingRow {
  const BattingRow({
    required this.playerId,
    required this.name,
    required this.dismissal,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.isAtCrease,
  });

  final String playerId;
  final String name;

  /// `not out`, `b Bowler`, `run out`, ...
  final String dismissal;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool isAtCrease;

  String get strikeRate => Fmt.strikeRate(runs, balls);
}

class BowlingRow {
  const BowlingRow({
    required this.playerId,
    required this.name,
    required this.legalBalls,
    required this.runs,
    required this.wickets,
  });

  final String playerId;
  final String name;
  final int legalBalls;
  final int runs;
  final int wickets;

  String get overs => Fmt.overs(legalBalls);
  String get economy => Fmt.economy(runs, legalBalls);
}

class FallOfWicket {
  const FallOfWicket({
    required this.wicketNumber,
    required this.score,
    required this.overs,
    required this.batterName,
  });

  final int wicketNumber;
  final int score;
  final String overs;
  final String batterName;

  /// `3-45 (7.2 ov) · A. Khan`
  String get summary => '$wicketNumber-$score ($overs ov) · $batterName';
}

/// Team runs scored between two wicket events.
class Stand {
  const Stand({
    required this.label,
    required this.runs,
    required this.teamScore,
  });

  final String label;
  final int runs;
  final int teamScore;

  String get summary => '$label: $runs runs · team $teamScore';
}

/// The deliveries of one over (wides and no-balls stay in the over they
/// were bowled in).
class OverSummary {
  const OverSummary({
    required this.number,
    required this.deliveries,
    required this.complete,
  });

  /// 1-based over number.
  final int number;
  final List<Delivery> deliveries;

  /// Six legal balls have been bowled.
  final bool complete;

  int get runs => deliveries.fold(0, (sum, d) => sum + d.totalRuns);
  int get wickets => deliveries.where((d) => d.wicket).length;

  /// The bowler of the over's first ball.
  String? get bowlerId => deliveries.isEmpty ? null : deliveries.first.bowlerId;
}

/// Everything a scorecard shows for one innings.
class InningsReport {
  const InningsReport({
    required this.index,
    required this.battingTeamName,
    required this.total,
    required this.wickets,
    required this.oversLabel,
    required this.completed,
    required this.extras,
    required this.batting,
    required this.bowling,
    required this.fallOfWickets,
    required this.stands,
  });

  final int index;
  final String battingTeamName;
  final int total;
  final int wickets;
  final String oversLabel;
  final bool completed;
  final ExtrasBreakdown extras;
  final List<BattingRow> batting;
  final List<BowlingRow> bowling;
  final List<FallOfWicket> fallOfWickets;
  final List<Stand> stands;

  /// `104/6 (14.2 ov)`
  String get scoreLine => '$total/$wickets ($oversLabel ov)';
}

/// A player's batting + bowling totals across both innings of a match.
class PlayerAggregate {
  PlayerAggregate(this.playerId, this.name);

  final String playerId;
  final String name;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int wickets = 0;
  int legalBallsBowled = 0;
  int runsConceded = 0;

  String get strikeRate => Fmt.strikeRate(runs, balls);
  String get overs => Fmt.overs(legalBallsBowled);
  String get economy => Fmt.economy(runsConceded, legalBallsBowled);
}

/// Turns raw innings data into display-ready scorecard reports.
///
/// Used by the private scorecard (names come from the club's teams/players),
/// the public scorecard and the live match centre (names come from the
/// published snapshot).
abstract final class ScorecardBuilder {
  static List<InningsReport> build({
    required List<Innings> innings,
    required String Function(String teamId) teamName,
    required String Function(String playerId) playerName,
  }) {
    return [
      for (var i = 0; i < innings.length; i++)
        buildInnings(innings[i], i, teamName, playerName),
    ];
  }

  static InningsReport buildInnings(
    Innings inn,
    int index,
    String Function(String teamId) teamName,
    String Function(String playerId) playerName,
  ) {
    return InningsReport(
      index: index,
      battingTeamName: teamName(inn.battingTeamId),
      total: inn.total,
      wickets: inn.wickets,
      oversLabel: inn.oversLabel,
      completed: inn.completed,
      extras: extras(inn),
      batting: battingRows(inn, playerName),
      bowling: bowlingRows(inn, playerName),
      fallOfWickets: fallOfWickets(inn, playerName),
      stands: partnerships(inn),
    );
  }

  /// Extras by type.
  ///
  /// (The web's private scorecard summed `batterRuns` for byes/leg-byes, which
  /// is always 0 for those balls, so they always showed 0. The runs live in
  /// `extraRuns`.)
  static ExtrasBreakdown extras(Innings inn) {
    var wides = 0, noBalls = 0, byes = 0, legByes = 0, penalties = 0;
    for (final d in inn.deliveries) {
      switch (d.kind) {
        case DeliveryKind.wide:
          wides += d.extraRuns;
        case DeliveryKind.noBall:
          noBalls += d.extraRuns;
        case DeliveryKind.bye:
          byes += d.extraRuns;
        case DeliveryKind.legBye:
          legByes += d.extraRuns;
        case DeliveryKind.penalty:
          penalties += d.extraRuns;
      }
    }
    return ExtrasBreakdown(
      wides: wides,
      noBalls: noBalls,
      byes: byes,
      legByes: legByes,
      penalties: penalties,
    );
  }

  /// Batters who faced at least one delivery, in order of first appearance.
  static List<BattingRow> battingRows(
    Innings inn,
    String Function(String playerId) playerName,
  ) {
    final ids = <String>{for (final d in inn.deliveries) d.strikerId};
    final out = _dismissals(inn, playerName);
    return [
      for (final id in ids)
        () {
          final s = inn.batters[id] ?? BatterStats();
          return BattingRow(
            playerId: id,
            name: playerName(id),
            dismissal: out[id] ?? 'not out',
            runs: s.runs,
            balls: s.balls,
            fours: s.fours,
            sixes: s.sixes,
            isAtCrease:
                !inn.completed &&
                (id == inn.strikerId || id == inn.nonStrikerId),
          );
        }(),
    ];
  }

  static List<BowlingRow> bowlingRows(
    Innings inn,
    String Function(String playerId) playerName,
  ) {
    final ids = <String>{for (final d in inn.deliveries) d.bowlerId};
    return [
      for (final id in ids)
        () {
          final s = inn.bowlers[id] ?? BowlerStats();
          return BowlingRow(
            playerId: id,
            name: playerName(id),
            legalBalls: s.legalBalls,
            runs: s.runs,
            wickets: s.wickets,
          );
        }(),
    ];
  }

  /// Wicket number, team score and over at each fall.
  ///
  /// The batter shown is the one actually dismissed (`dismissedBatterId`); the
  /// web showed the striker even when the non-striker was run out.
  static List<FallOfWicket> fallOfWickets(
    Innings inn,
    String Function(String playerId) playerName,
  ) {
    final rows = <FallOfWicket>[];
    var score = 0;
    var legal = 0;
    var wickets = 0;
    for (final d in inn.deliveries) {
      score += d.totalRuns;
      if (d.legal) legal++;
      if (d.wicket) {
        wickets++;
        rows.add(
          FallOfWicket(
            wicketNumber: wickets,
            score: score,
            overs: Fmt.overs(legal),
            batterName: playerName(d.outBatterId ?? d.strikerId),
          ),
        );
      }
    }
    return rows;
  }

  /// Team runs between wicket events (individual batter partnerships would
  /// need completed-run tracking that the scorer does not record).
  static List<Stand> partnerships(Innings inn) {
    final rows = <Stand>[];
    var total = 0;
    var stand = 0;
    var wicketNo = 0;
    for (final d in inn.deliveries) {
      total += d.totalRuns;
      stand += d.totalRuns;
      if (d.wicket) {
        wicketNo++;
        rows.add(
          Stand(label: 'Wicket $wicketNo', runs: stand, teamScore: total),
        );
        stand = 0;
      }
    }
    rows.add(
      Stand(
        label: wicketNo > 0 ? 'Current stand' : 'Opening stand',
        runs: stand,
        teamScore: total,
      ),
    );
    return rows;
  }

  /// Groups the ball log into overs, in order.
  static List<OverSummary> overs(Innings inn) {
    final result = <OverSummary>[];
    var current = <Delivery>[];
    var legal = 0;
    for (final d in inn.deliveries) {
      current.add(d);
      if (d.legal) {
        legal++;
        if (legal % 6 == 0) {
          result.add(
            OverSummary(
              number: legal ~/ 6,
              deliveries: current,
              complete: true,
            ),
          );
          current = <Delivery>[];
        }
      }
    }
    if (current.isNotEmpty) {
      result.add(
        OverSummary(
          number: legal ~/ 6 + 1,
          deliveries: current,
          complete: false,
        ),
      );
    }
    return result;
  }

  /// Per-player totals across all innings.
  static List<PlayerAggregate> playerAggregates(
    List<Innings> innings,
    String Function(String playerId) playerName,
  ) {
    final byId = <String, PlayerAggregate>{};
    PlayerAggregate of(String id) =>
        byId.putIfAbsent(id, () => PlayerAggregate(id, playerName(id)));

    for (final inn in innings) {
      for (final e in inn.batters.entries) {
        final p = of(e.key);
        p.runs += e.value.runs;
        p.balls += e.value.balls;
        p.fours += e.value.fours;
        p.sixes += e.value.sixes;
      }
      for (final e in inn.bowlers.entries) {
        final p = of(e.key);
        p.wickets += e.value.wickets;
        p.legalBallsBowled += e.value.legalBalls;
        p.runsConceded += e.value.runs;
      }
    }
    return byId.values.toList();
  }

  // ------------------------------------------------------------- dismissals

  static Map<String, String> _dismissals(
    Innings inn,
    String Function(String playerId) playerName,
  ) {
    final out = <String, String>{};
    for (final d in inn.deliveries) {
      final id = d.outBatterId;
      if (id == null || out.containsKey(id)) continue;
      out[id] = dismissalText(d, playerName);
    }
    return out;
  }

  /// `b Bowler`, `c ? b Bowler` (the fielder is not recorded), `run out`...
  static String dismissalText(
    Delivery d,
    String Function(String playerId) playerName,
  ) {
    final bowler = playerName(d.bowlerId);
    return switch (d.dismissalType) {
      '' => 'b $bowler',
      DismissalType.runOut => 'run out',
      DismissalType.retiredHurt => 'retired hurt',
      DismissalType.caught => 'c ? b $bowler',
      DismissalType.bowled => 'b $bowler',
      DismissalType.lbw => 'lbw b $bowler',
      DismissalType.stumped => 'st ? b $bowler',
      final other => other.replaceAll('_', ' '),
    };
  }
}
