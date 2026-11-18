import 'package:boundary/domain/constants.dart';
import 'package:boundary/domain/models/innings.dart';
import 'package:boundary/domain/models/public_models.dart';
import 'package:boundary/domain/scoring/formatters.dart';
import 'package:boundary/domain/scoring/scorecard.dart';
import 'package:boundary/domain/scoring/scoring_engine.dart';
import 'package:boundary/domain/scoring/standings.dart';
import 'package:flutter_test/flutter_test.dart';

Innings inningsOf(
  String batting, {
  required int total,
  required int wickets,
  required int balls,
  int number = 1,
  bool completed = true,
}) => Innings(
  number: number,
  battingTeamId: batting,
  bowlingTeamId: batting == 'A' ? 'B' : 'A',
  total: total,
  wickets: wickets,
  legalBalls: balls,
  completed: completed,
);

PublicMatchScore match(
  String id,
  List<Innings> innings, {
  String status = 'completed',
  String? tournamentId = 't1',
  int overs = 20,
}) => PublicMatchScore(
  matchId: id,
  clubId: 'c',
  title: id,
  teamAId: 'A',
  teamBId: 'B',
  innings: innings,
  status: status,
  tournamentId: tournamentId,
  overs: overs,
);

const tournament = PublicTournament(
  id: 't1',
  clubId: 'c',
  name: 'Cup',
  teamIds: ['A', 'B', 'C'],
  teamNames: {'A': 'Alpha', 'B': 'Bravo', 'C': 'Charlie'},
);

void main() {
  group('formatters', () {
    test('overs notation', () {
      expect(Fmt.overs(0), equals('0.0'));
      expect(Fmt.overs(20), equals('3.2'));
      expect(Fmt.overs(120), equals('20.0'));
    });

    test('strike rate and economy use two decimals and guard zero', () {
      expect(Fmt.strikeRate(50, 30), equals('166.67'));
      expect(Fmt.strikeRate(0, 0), equals('0.00'));
      expect(Fmt.economy(30, 24), equals('7.50'));
      expect(Fmt.economy(5, 0), equals('0.00'));
    });

    test('ordinals, plurals and signed NRR', () {
      expect(Fmt.ordinal(1), equals('1st'));
      expect(Fmt.ordinal(2), equals('2nd'));
      expect(Fmt.ordinal(4), equals('4th'));
      expect(Fmt.plural(1, 'wicket'), equals('1 wicket'));
      expect(Fmt.plural(2, 'wicket'), equals('2 wickets'));
      expect(Fmt.nrr(0.5), equals('+0.500'));
      expect(Fmt.nrr(-0.25), equals('-0.250'));
      expect(Fmt.nrr(-0.0), equals('0.000'));
    });
  });

  group('standings', () {
    test('2 points per win, ranked by points then net run rate', () {
      final table = Standings.calculate(tournament, [
        match('m1', [
          inningsOf('A', total: 150, wickets: 5, balls: 120),
          inningsOf('B', total: 140, wickets: 8, balls: 120, number: 2),
        ]),
        match('m2', [
          inningsOf('C', total: 100, wickets: 6, balls: 120),
          inningsOf('A', total: 101, wickets: 2, balls: 90, number: 2),
        ]),
      ]);
      expect(
        table.map((r) => r.name).toList(),
        equals(['Alpha', 'Bravo', 'Charlie']),
      );
      final alpha = table.first;
      expect([
        alpha.played,
        alpha.wins,
        alpha.losses,
        alpha.points,
      ], equals([2, 2, 0, 4]));
      // 251 runs off 210 balls scored, 240 off 240 balls conceded
      expect(alpha.netRunRate, closeTo(251 * 6 / 210 - 240 * 6 / 240, 1e-9));
    });

    test('an all-out innings is charged the full quota of overs', () {
      final table = Standings.calculate(tournament, [
        match('m1', [
          inningsOf(
            'A',
            total: 100,
            wickets: 10,
            balls: 60,
          ), // all out in 10 overs
          inningsOf('B', total: 90, wickets: 4, balls: 120, number: 2),
        ]),
      ]);
      final alpha = table.firstWhere((r) => r.teamId == 'A');
      expect(alpha.ballsFaced, equals(120));
    });

    test('a tie counts as played with no points', () {
      final table = Standings.calculate(tournament, [
        match('m1', [
          inningsOf('A', total: 100, wickets: 5, balls: 120),
          inningsOf('B', total: 100, wickets: 5, balls: 120, number: 2),
        ]),
      ]);
      expect(table.every((r) => r.points == 0), isTrue);
      expect(table.where((r) => r.played == 1).length, equals(2));
    });

    test('ignores other tournaments, unfinished matches and unknown teams', () {
      final table = Standings.calculate(tournament, [
        match('other', [
          inningsOf('A', total: 10, wickets: 1, balls: 12),
          inningsOf('B', total: 5, wickets: 1, balls: 12, number: 2),
        ], tournamentId: 'zzz'),
        match('live', [
          inningsOf('A', total: 10, wickets: 1, balls: 12),
          inningsOf('B', total: 5, wickets: 1, balls: 12, number: 2),
        ], status: 'live'),
        match('unfinished', [
          inningsOf('A', total: 10, wickets: 1, balls: 12),
          inningsOf(
            'B',
            total: 5,
            wickets: 1,
            balls: 12,
            number: 2,
            completed: false,
          ),
        ]),
        match('stranger', [
          inningsOf('A', total: 10, wickets: 1, balls: 12),
          inningsOf('Z', total: 5, wickets: 1, balls: 12, number: 2),
        ]),
      ]);
      expect(table.every((r) => r.played == 0), isTrue);
      // equal on everything: alphabetical
      expect(
        table.map((r) => r.name).toList(),
        equals(['Alpha', 'Bravo', 'Charlie']),
      );
    });
  });

  group('public status', () {
    test('derive: live until the second innings completes', () {
      expect(
        PublicStatuses.derive(innings: [], matchStatus: 'scheduled'),
        equals('live'),
      );
      expect(
        PublicStatuses.derive(
          innings: [
            inningsOf('A', total: 1, wickets: 0, balls: 1),
            inningsOf('B', total: 2, wickets: 0, balls: 1),
          ],
          matchStatus: 'in_progress',
        ),
        equals('completed'),
      );
      expect(
        PublicStatuses.derive(innings: [], matchStatus: ' Abandoned '),
        equals('abandoned'),
      );
      expect(
        PublicStatuses.derive(innings: [], matchStatus: 'completed'),
        equals('completed'),
      );
    });

    test('isGenuinelyLive filters finished matches', () {
      expect(match('a', [], status: 'live').isGenuinelyLive, isTrue);
      expect(match('a', [], status: 'completed').isGenuinelyLive, isFalse);
      final done = [
        inningsOf('A', total: 1, wickets: 0, balls: 1),
        inningsOf('B', total: 2, wickets: 0, balls: 1, number: 2),
      ];
      expect(match('a', done, status: 'live').isGenuinelyLive, isFalse);
    });
  });

  group('scorecard', () {
    String team(String id) => 'Team $id';
    String name(String id) => 'P-$id';

    Innings sample() {
      const rules = MatchRules(format: 'T20', overs: 20);
      var i = Innings.start(
        number: 1,
        battingTeamId: 'A',
        bowlingTeamId: 'B',
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      );
      Innings go(DeliveryRequest r) {
        final plan = ScoringEngine.planDelivery(
          innings: i,
          rules: rules,
          request: r,
        );
        return ScoringEngine.applyDelivery(
          i,
          plan.delivery,
          rules: rules,
          overWillEnd: plan.overWillEnd,
        );
      }

      i = go(const DeliveryRequest(batterRuns: 4));
      i = go(const DeliveryRequest(kind: DeliveryKind.bye, extraRunsInput: 2));
      i = go(
        const DeliveryRequest(kind: DeliveryKind.legBye, extraRunsInput: 1),
      );
      i = go(const DeliveryRequest(kind: DeliveryKind.wide, extraRunsInput: 1));
      i = go(const DeliveryRequest(kind: DeliveryKind.noBall));
      i = go(
        const DeliveryRequest(kind: DeliveryKind.penalty, extraRunsInput: 5),
      );
      return i;
    }

    test(
      'byes and leg-byes are counted (they were always 0 in the web app)',
      () {
        final x = ScorecardBuilder.extras(sample());
        expect([
          x.wides,
          x.noBalls,
          x.byes,
          x.legByes,
          x.penalties,
        ], equals([2, 1, 2, 1, 5]));
        expect(x.total, equals(sample().extras));
        expect(x.summary, equals('11 (Wd 2, Nb 1, B 2, Lb 1, P 5)'));
      },
    );

    test('fall of wickets names the batter who was actually dismissed', () {
      const rules = MatchRules(format: 'T20', overs: 20);
      var i = Innings.start(
        number: 1,
        battingTeamId: 'A',
        bowlingTeamId: 'B',
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      );
      final plan = ScoringEngine.planDelivery(
        innings: i,
        rules: rules,
        request: const DeliveryRequest(
          wicket: true,
          dismissedBatterId: 'a2',
          incomingBatterId: 'a3',
          dismissalType: DismissalType.runOut,
        ),
      );
      i = ScoringEngine.applyDelivery(
        i,
        plan.delivery,
        rules: rules,
        overWillEnd: false,
      );

      final fow = ScorecardBuilder.fallOfWickets(i, name);
      expect(fow.single.summary, equals('1-0 (0.1 ov) · P-a2'));
    });

    test('batting rows show dismissals and who is still in', () {
      const rules = MatchRules(format: 'T20', overs: 20);
      var i = Innings.start(
        number: 1,
        battingTeamId: 'A',
        bowlingTeamId: 'B',
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      );
      final plan = ScoringEngine.planDelivery(
        innings: i,
        rules: rules,
        request: const DeliveryRequest(
          wicket: true,
          incomingBatterId: 'a3',
          dismissalType: DismissalType.bowled,
        ),
      );
      i = ScoringEngine.applyDelivery(
        i,
        plan.delivery,
        rules: rules,
        overWillEnd: false,
      );
      final p2 = ScoringEngine.planDelivery(
        innings: i,
        rules: rules,
        request: const DeliveryRequest(batterRuns: 1),
      );
      i = ScoringEngine.applyDelivery(
        i,
        p2.delivery,
        rules: rules,
        overWillEnd: false,
      );

      final rows = ScorecardBuilder.battingRows(i, name);
      expect(rows.map((r) => r.name).toList(), equals(['P-a1', 'P-a3']));
      expect(rows[0].dismissal, equals('b P-b1'));
      expect(rows[1].dismissal, equals('not out'));
      expect(rows[1].isAtCrease, isTrue);
    });

    test('partnership sequence splits team runs at each wicket', () {
      final inn = sample();
      final stands = ScorecardBuilder.partnerships(inn);
      expect(stands.single.label, equals('Opening stand'));
      expect(stands.single.runs, equals(inn.total));
    });

    test('overs group the ball log; wides stay in their over', () {
      const rules = MatchRules(format: 'T20', overs: 20);
      var i = Innings.start(
        number: 1,
        battingTeamId: 'A',
        bowlingTeamId: 'B',
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      );
      void go(DeliveryRequest r, {String? next}) {
        final plan = ScoringEngine.planDelivery(
          innings: i,
          rules: rules,
          request: r,
        );
        i = ScoringEngine.applyDelivery(
          i,
          plan.delivery,
          rules: rules,
          overWillEnd: plan.overWillEnd,
          nextBowlerId: next,
        );
      }

      go(const DeliveryRequest(kind: DeliveryKind.wide));
      for (var n = 0; n < 5; n++) {
        go(const DeliveryRequest(batterRuns: 1));
      }
      go(const DeliveryRequest(batterRuns: 4), next: 'b2');
      go(const DeliveryRequest(batterRuns: 2));

      final overs = ScorecardBuilder.overs(i);
      expect(overs.length, equals(2));
      expect(overs[0].number, equals(1));
      expect(overs[0].complete, isTrue);
      expect(overs[0].deliveries.length, equals(7)); // wide + 6 legal balls
      expect(overs[0].runs, equals(1 + 5 + 4));
      expect(overs[0].bowlerId, equals('b1'));
      expect(overs[1].number, equals(2));
      expect(overs[1].complete, isFalse);
      expect(overs[1].bowlerId, equals('b2'));
    });

    test('player aggregates combine both innings', () {
      final first = Innings(
        number: 1,
        battingTeamId: 'A',
        bowlingTeamId: 'B',
        batters: {'x': BatterStats(runs: 10, balls: 5, fours: 1)},
        bowlers: {'y': BowlerStats(runs: 20, wickets: 1, legalBalls: 12)},
      );
      final second = Innings(
        number: 2,
        battingTeamId: 'B',
        bowlingTeamId: 'A',
        batters: {'x': BatterStats(runs: 5, balls: 5, sixes: 1)},
        bowlers: {'y': BowlerStats(runs: 10, wickets: 2, legalBalls: 6)},
      );
      final all = ScorecardBuilder.playerAggregates([first, second], name);
      final x = all.firstWhere((p) => p.playerId == 'x');
      final y = all.firstWhere((p) => p.playerId == 'y');
      expect([x.runs, x.balls, x.fours, x.sixes], equals([15, 10, 1, 1]));
      expect(x.strikeRate, equals('150.00'));
      expect([
        y.wickets,
        y.legalBallsBowled,
        y.runsConceded,
      ], equals([3, 18, 30]));
      expect(y.economy, equals('10.00'));
      expect(team('A'), equals('Team A'));
    });
  });
}
