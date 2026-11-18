import 'package:boundary/domain/constants.dart';
import 'package:boundary/domain/models/innings.dart';
import 'package:boundary/domain/models/team.dart';
import 'package:boundary/domain/scoring/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const rules = MatchRules(format: 'T20', overs: 20);

Innings newInnings({int number = 1}) => Innings.start(
  number: number,
  battingTeamId: 'A',
  bowlingTeamId: 'B',
  strikerId: 'a1',
  nonStrikerId: 'a2',
  bowlerId: 'b1',
);

/// Plans and applies one delivery, like the scoring controller does.
Innings play(
  Innings innings,
  DeliveryRequest request, {
  String? nextBowler,
  int? firstTotal,
  MatchRules matchRules = rules,
}) {
  final plan = ScoringEngine.planDelivery(
    innings: innings,
    rules: matchRules,
    request: request,
    firstInningsTotal: firstTotal,
  );
  return ScoringEngine.applyDelivery(
    innings,
    plan.delivery,
    rules: matchRules,
    overWillEnd: plan.overWillEnd,
    firstInningsTotal: firstTotal,
    nextBowlerId: nextBowler,
  );
}

Innings runs(Innings i, int r, {String? nextBowler}) =>
    play(i, DeliveryRequest(batterRuns: r), nextBowler: nextBowler);

String? errorOf(void Function() action) {
  try {
    action();
    return null;
  } on ScoringException catch (e) {
    return e.message;
  }
}

/// Six dot balls by the current bowler, handing over to [next].
Innings dotOver(Innings i, String next) {
  var x = i;
  for (var n = 0; n < 5; n++) {
    x = runs(x, 0);
  }
  return runs(x, 0, nextBowler: next);
}

Player player(String id, String team) =>
    Player(id: id, clubId: 'c', fullName: id, teamId: team);

void main() {
  group('runs off the bat', () {
    test('adds runs, balls and boundaries to striker and bowler', () {
      var i = runs(newInnings(), 4);
      i = runs(i, 6);
      expect(i.total, equals(10));
      expect(i.legalBalls, equals(2));
      final b = i.batters['a1']!;
      expect([b.runs, b.balls, b.fours, b.sixes], equals([10, 2, 1, 1]));
      final bw = i.bowlers['b1']!;
      expect([bw.runs, bw.legalBalls, bw.wickets], equals([10, 2, 0]));
    });

    test('odd runs swap the batters, even runs do not', () {
      var i = runs(newInnings(), 1);
      expect([i.strikerId, i.nonStrikerId], equals(['a2', 'a1']));
      i = runs(i, 2);
      expect([i.strikerId, i.nonStrikerId], equals(['a2', 'a1']));
      i = runs(i, 3);
      expect([i.strikerId, i.nonStrikerId], equals(['a1', 'a2']));
    });

    test('the original innings is never mutated', () {
      final before = newInnings();
      runs(before, 4);
      expect(before.total, equals(0));
      expect(before.deliveries, isEmpty);
    });
  });

  group('extras', () {
    test(
      'wide: 1 + extra runs, not a legal ball, not faced, bowler charged',
      () {
        final i = play(
          newInnings(),
          const DeliveryRequest(kind: DeliveryKind.wide, extraRunsInput: 2),
        );
        expect(i.total, equals(3));
        expect(i.legalBalls, equals(0));
        expect(i.extras, equals(3));
        expect(i.deliveries.single.label, equals('Wd3'));
        expect(i.batters.containsKey('a1'), isFalse);
        expect(i.bowlers['b1']!.runs, equals(3));
        // 2 run-wide: 2 extra runs completed => odd? (3 - 1) = 2, no swap
        expect(i.strikerId, equals('a1'));
      },
    );

    test('wide with one run off it swaps the batters', () {
      final i = play(
        newInnings(),
        const DeliveryRequest(kind: DeliveryKind.wide, extraRunsInput: 1),
      );
      expect(i.strikerId, equals('a2'));
    });

    test('no-ball: batter keeps his runs, ball not legal and not faced', () {
      final i = play(
        newInnings(),
        const DeliveryRequest(kind: DeliveryKind.noBall, batterRuns: 4),
      );
      expect(i.total, equals(5));
      expect(i.extras, equals(1));
      expect(i.legalBalls, equals(0));
      expect(i.deliveries.single.label, equals('Nb5'));
      final b = i.batters['a1']!;
      expect([b.runs, b.balls, b.fours], equals([4, 0, 1]));
      expect(i.bowlers['b1']!.runs, equals(5));
    });

    test('bye: legal ball faced, not charged to the bowler, rotates', () {
      final i = play(
        newInnings(),
        const DeliveryRequest(kind: DeliveryKind.bye, extraRunsInput: 1),
      );
      expect(i.total, equals(1));
      expect(i.extras, equals(1));
      expect(i.legalBalls, equals(1));
      expect(i.batters['a1']!.balls, equals(1));
      expect(i.batters['a1']!.runs, equals(0));
      expect(i.bowlers['b1']!.runs, equals(0));
      expect(i.bowlers['b1']!.legalBalls, equals(1));
      expect(i.strikerId, equals('a2'));
      expect(i.deliveries.single.label, equals('B1'));
    });

    test('penalty: adds to the total only', () {
      final i = play(
        newInnings(),
        const DeliveryRequest(kind: DeliveryKind.penalty, extraRunsInput: 5),
      );
      expect(i.total, equals(5));
      expect(i.legalBalls, equals(0));
      expect(i.batters, isEmpty);
      expect(i.bowlers, isEmpty);
      expect(i.deliveries.single.label, equals('P5'));
    });

    test('penalty with 0 means the standard 5, like the web scorer', () {
      final i = play(
        newInnings(),
        const DeliveryRequest(kind: DeliveryKind.penalty),
      );
      expect(i.total, equals(5));
    });
  });

  group('overs and bowlers', () {
    test('the over ends after 6 legal balls and the ends swap', () {
      final i = dotOver(newInnings(), 'b2');
      expect(i.legalBalls, equals(6));
      expect([i.strikerId, i.nonStrikerId], equals(['a2', 'a1']));
      expect(i.bowlerId, equals('b2'));
    });

    test('wides do not count towards the over', () {
      var i = newInnings();
      for (var n = 0; n < 3; n++) {
        i = play(i, const DeliveryRequest(kind: DeliveryKind.wide));
      }
      expect(i.legalBalls, equals(0));
      expect(i.total, equals(3));
    });

    test('plan flags the end of an over and asks for a new bowler', () {
      var i = newInnings();
      for (var n = 0; n < 5; n++) {
        i = runs(i, 0);
      }
      final plan = ScoringEngine.planDelivery(
        innings: i,
        rules: rules,
        request: const DeliveryRequest(),
      );
      expect(plan.overWillEnd, isTrue);
      expect(plan.needsNextBowler, isTrue);
    });

    test('the same bowler may not bowl consecutive overs', () {
      var i = dotOver(newInnings(), 'b1'); // scorer "kept" the bowler
      expect(
        errorOf(
          () => ScoringEngine.planDelivery(
            innings: i,
            rules: rules,
            request: const DeliveryRequest(),
          ),
        ),
        equals('A different bowler must bowl the next over.'),
      );
      i = dotOver(newInnings(), 'b2');
      expect(
        errorOf(
          () => ScoringEngine.planDelivery(
            innings: i,
            rules: rules,
            request: const DeliveryRequest(),
          ),
        ),
        isNull,
      );
    });

    test('a wide by the new bowler at the start of an over is allowed', () {
      final i = dotOver(newInnings(), 'b2');
      expect(
        errorOf(() => play(i, const DeliveryRequest(kind: DeliveryKind.wide))),
        isNull,
      );
    });

    test('a T20 bowler is limited to 4 overs', () {
      // b1 and b2 alternate; b1 bowls overs 1, 3, 5 and 7.
      var i = newInnings();
      for (var pair = 0; pair < 4; pair++) {
        i = dotOver(i, 'b2'); // b1 finishes an over
        i = dotOver(i, 'b1'); // b2 finishes an over
      }
      expect(ScoringEngine.bowlerOvers(i, 'b1'), equals(4));
      expect(i.bowlerId, equals('b1'));
      expect(
        errorOf(
          () => ScoringEngine.planDelivery(
            innings: i,
            rules: rules,
            request: const DeliveryRequest(),
          ),
        ),
        contains('4-over limit'),
      );
    });

    test('over-limit table matches the web scorer', () {
      expect(
        const MatchRules(format: 'T10', overs: 10).maxOversPerBowler,
        equals(3),
      );
      expect(
        const MatchRules(format: 'T20', overs: 20).maxOversPerBowler,
        equals(4),
      );
      expect(
        const MatchRules(format: 'ODI', overs: 50).maxOversPerBowler,
        equals(10),
      );
      expect(
        const MatchRules(format: 'Custom', overs: 30).maxOversPerBowler,
        equals(6),
      );
      expect(
        const MatchRules(format: 'Custom', overs: 15).maxOversPerBowler,
        equals(3),
      );
    });

    test(
      'eligible bowlers exclude the current bowler and those at the limit',
      () {
        final i = dotOver(newInnings(), 'b2');
        final players = [
          player('b1', 'B'),
          player('b2', 'B'),
          player('b3', 'B'),
          player('a1', 'A'),
        ];
        final ids = ScoringEngine.eligibleBowlers(
          i,
          players,
          rules,
          excludeCurrent: true,
        ).map((p) => p.id).toList();
        expect(ids, equals(['b1', 'b3']));
      },
    );
  });

  group('wickets', () {
    DeliveryRequest out({
      String? dismissed,
      String type = DismissalType.bowled,
      String? incoming = 'a3',
    }) => DeliveryRequest(
      wicket: true,
      dismissedBatterId: dismissed,
      incomingBatterId: incoming,
      dismissalType: type,
    );

    test('striker out: bowler credited, new batter takes strike', () {
      final i = play(newInnings(), out());
      expect(i.wickets, equals(1));
      expect(i.strikerId, equals('a3'));
      expect(i.nonStrikerId, equals('a2'));
      expect(i.dismissedBatterIds, equals(['a1']));
      expect(i.bowlers['b1']!.wickets, equals(1));
      expect(i.deliveries.single.label, equals('W'));
    });

    test('non-striker run out: replaced at his end, bowler not credited', () {
      final i = play(
        newInnings(),
        out(dismissed: 'a2', type: DismissalType.runOut),
      );
      expect(i.strikerId, equals('a1'));
      expect(i.nonStrikerId, equals('a3'));
      expect(i.dismissedBatterIds, equals(['a2']));
      expect(i.bowlers['b1']!.wickets, equals(0));
    });

    test('an incoming batter is required before the 10th wicket', () {
      expect(
        errorOf(() => play(newInnings(), out(incoming: null))),
        equals('Choose the incoming batter.'),
      );
    });

    test('only a batter at the crease can be given out', () {
      expect(
        errorOf(() => play(newInnings(), out(dismissed: 'zz'))),
        equals('Choose a batter currently at the crease.'),
      );
    });

    test('the 10th wicket completes the innings with no incoming batter', () {
      final i = newInnings()
        ..wickets = 9
        ..legalBalls = 12;
      final done = play(i, out(incoming: null));
      expect(done.wickets, equals(10));
      expect(done.completed, isTrue);
      expect(done.strikerId, isNull);
    });
  });

  group('innings completion', () {
    test('a full allocation of overs completes the innings', () {
      const short = MatchRules(format: 'Custom', overs: 1);
      var i = newInnings();
      for (var n = 0; n < 6; n++) {
        i = play(i, const DeliveryRequest(batterRuns: 1), matchRules: short);
      }
      expect(i.completed, isTrue);
      expect(
        errorOf(() => play(i, const DeliveryRequest(), matchRules: short)),
        equals('This innings is already complete.'),
      );
    });

    test('the chasing side ends the innings by passing the target', () {
      final i = newInnings(number: 2)..total = 98;
      final plan = ScoringEngine.planDelivery(
        innings: i,
        rules: rules,
        request: const DeliveryRequest(batterRuns: 4),
        firstInningsTotal: 100,
      );
      expect(plan.inningsWillComplete, isTrue);
      final done = play(
        i,
        const DeliveryRequest(batterRuns: 4),
        firstTotal: 100,
      );
      expect(done.completed, isTrue);
    });

    test('scoring exactly the target does not finish the match (a tie)', () {
      final i = newInnings(number: 2)..total = 98;
      final done = play(
        i,
        const DeliveryRequest(batterRuns: 2),
        firstTotal: 100,
      );
      expect(done.completed, isFalse);
    });

    test(
      'no bowler change is asked for when the innings ends with the over',
      () {
        const short = MatchRules(format: 'Custom', overs: 1);
        var i = newInnings();
        for (var n = 0; n < 5; n++) {
          i = play(i, const DeliveryRequest(), matchRules: short);
        }
        final plan = ScoringEngine.planDelivery(
          innings: i,
          rules: short,
          request: const DeliveryRequest(),
        );
        expect(plan.overWillEnd, isTrue);
        expect(plan.needsNextBowler, isFalse);
      },
    );
  });

  group('validation', () {
    test('needs two different batters and a bowler', () {
      final i = newInnings()..nonStrikerId = 'a1';
      expect(
        errorOf(
          () => ScoringEngine.planDelivery(
            innings: i,
            rules: rules,
            request: const DeliveryRequest(),
          ),
        ),
        equals('Select two different batters and a bowler.'),
      );
    });

    test('negative runs are rejected', () {
      expect(
        errorOf(
          () => play(newInnings(), const DeliveryRequest(batterRuns: -1)),
        ),
        equals('Enter valid whole-number runs.'),
      );
    });
  });

  group('undo', () {
    test('restores totals, batters, bowler figures, ends and bowler', () {
      var i = newInnings();
      i = runs(i, 1);
      i = runs(i, 4);
      i = play(i, const DeliveryRequest(kind: DeliveryKind.wide));
      final before = i.clone();
      i = runs(i, 6);
      final undone = ScoringEngine.undoLastDelivery(i, rules: rules);

      expect(undone.total, equals(before.total));
      expect(undone.legalBalls, equals(before.legalBalls));
      expect(undone.extras, equals(before.extras));
      expect(undone.strikerId, equals(before.strikerId));
      expect(undone.nonStrikerId, equals(before.nonStrikerId));
      expect(undone.batters['a2']!.runs, equals(before.batters['a2']!.runs));
      expect(undone.batters['a2']!.sixes, equals(0));
      expect(undone.bowlers['b1']!.runs, equals(before.bowlers['b1']!.runs));
      expect(undone.deliveries.length, equals(before.deliveries.length));
    });

    test('undoing a wicket brings the batter back and reopens the innings', () {
      final i = newInnings()
        ..wickets = 9
        ..dismissedBatterIds = List.generate(9, (n) => 'x$n');
      final out = play(
        i,
        const DeliveryRequest(
          wicket: true,
          dismissalType: DismissalType.bowled,
        ),
      );
      expect(out.completed, isTrue);
      final undone = ScoringEngine.undoLastDelivery(out, rules: rules);
      expect(undone.completed, isFalse);
      expect(undone.strikerId, equals('a1'));
    });

    test('undoing the only delivery restores the openers', () {
      final i = runs(newInnings(), 1);
      final undone = ScoringEngine.undoLastDelivery(i, rules: rules);
      expect(undone.total, equals(0));
      expect(undone.deliveries, isEmpty);
      expect([undone.strikerId, undone.nonStrikerId], equals(['a1', 'a2']));
    });

    test('undo across an over boundary restores the previous bowler', () {
      var i = dotOver(newInnings(), 'b2');
      expect(i.bowlerId, equals('b2'));
      i = ScoringEngine.undoLastDelivery(i, rules: rules);
      expect(i.bowlerId, equals('b1'));
      expect(i.legalBalls, equals(5));
    });
  });

  group('match result', () {
    String name(String id) => 'Team $id';

    test('chasing side wins by wickets in hand', () {
      final first = newInnings()
        ..total = 120
        ..completed = true;
      final second =
          Innings.start(
              number: 2,
              battingTeamId: 'B',
              bowlingTeamId: 'A',
              strikerId: 'b1',
              nonStrikerId: 'b2',
              bowlerId: 'a1',
            )
            ..total = 121
            ..wickets = 7
            ..completed = true;
      expect(
        ScoringEngine.matchResult([first, second], name),
        equals('Team B wins by 3 wickets.'),
      );
      second.wickets = 9;
      expect(
        ScoringEngine.matchResult([first, second], name),
        equals('Team B wins by 1 wicket.'),
      );
    });

    test('defending side wins by runs; equal totals tie', () {
      final first = newInnings()
        ..total = 120
        ..completed = true;
      final second = newInnings(number: 2)
        ..battingTeamId = 'B'
        ..total = 100
        ..completed = true;
      expect(
        ScoringEngine.matchResult([first, second], name),
        equals('Team A wins by 20 runs.'),
      );
      second.total = 120;
      expect(
        ScoringEngine.matchResult([first, second], name),
        equals('Match tied.'),
      );
      second.total = 119;
      expect(
        ScoringEngine.matchResult([first, second], name),
        equals('Team A wins by 1 run.'),
      );
    });

    test('no result until the second innings is complete', () {
      final first = newInnings()
        ..total = 120
        ..completed = true;
      final second = newInnings(number: 2)..total = 50;
      expect(ScoringEngine.matchResult([first], name), equals(''));
      expect(ScoringEngine.matchResult([first, second], name), equals(''));
    });
  });

  group('serialization', () {
    test('an innings survives a toMap/fromMap round trip', () {
      var i = newInnings();
      i = runs(i, 4);
      i = play(
        i,
        const DeliveryRequest(kind: DeliveryKind.wide, extraRunsInput: 1),
      );
      i = play(
        i,
        const DeliveryRequest(
          wicket: true,
          incomingBatterId: 'a3',
          dismissalType: DismissalType.caught,
        ),
      );
      final copy = Innings.fromMap(i.toMap());
      expect(copy.toMap(), equals(i.toMap()));
      expect(copy.deliveries.length, equals(3));
      expect(
        copy.dismissedBatterIds,
        equals(['a2']),
      ); // the wide's single run swapped the ends
    });

    test('unknown fields written by another client are preserved', () {
      final map = newInnings().toMap()..['futureField'] = {'x': 1};
      expect(Innings.fromMap(map).toMap()['futureField'], equals({'x': 1}));
    });

    test('numbers stored as doubles by Firestore are tolerated', () {
      final map = newInnings().toMap()
        ..['total'] = 12.0
        ..['legalBalls'] = 7.0;
      final i = Innings.fromMap(map);
      expect([i.total, i.legalBalls], equals([12, 7]));
    });
  });
}
