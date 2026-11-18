import 'dart:math' as math;

import '../constants.dart';
import '../models/cricket_match.dart';
import '../models/innings.dart';
import '../models/team.dart';
import 'formatters.dart';

/// A scoring rule was broken (message is safe to show to the scorer).
class ScoringException implements Exception {
  const ScoringException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Match-level limits derived from the fixture.
class MatchRules {
  const MatchRules({required this.format, required this.overs});

  factory MatchRules.fromMatch(CricketMatch match) =>
      MatchRules(format: match.format, overs: match.overs);

  final String format;
  final int overs;

  /// Balls in a full innings.
  int get maxBalls => overs * 6;

  /// Maximum overs one bowler may bowl (same table as the web scorer).
  int get maxOversPerBowler {
    final f = format.toLowerCase();
    if (overs < 15) return 3;
    if (f.contains('t20') || overs == 20) return 4;
    if (f.contains('odi') || overs >= 50) return 10;
    return math.max(1, (overs / 5).ceil());
  }
}

/// What the scorer asked to record (before validation).
class DeliveryRequest {
  const DeliveryRequest({
    this.kind = DeliveryKind.normal,
    this.batterRuns = 0,
    this.extraRunsInput = 0,
    this.wicket = false,
    this.dismissedBatterId,
    this.incomingBatterId,
    this.dismissalType = '',
  });

  final String kind;

  /// Runs off the bat (normal balls and no-balls).
  final int batterRuns;

  /// The number typed in the extras dialog (byes, leg-byes, wide runs,
  /// penalty runs).
  final int extraRunsInput;
  final bool wicket;
  final String? dismissedBatterId;
  final String? incomingBatterId;
  final String dismissalType;
}

/// A validated delivery plus the facts the UI needs before committing it.
class DeliveryPlan {
  const DeliveryPlan({
    required this.delivery,
    required this.overWillEnd,
    required this.inningsWillComplete,
  });

  final Delivery delivery;

  /// This ball completes an over.
  final bool overWillEnd;

  /// This ball ends the innings (all out, overs up, or target chased).
  final bool inningsWillComplete;

  /// The scorer must pick the next bowler before saving.
  bool get needsNextBowler => overWillEnd && !inningsWillComplete;
}

/// The cricket rules of the Boundary scorer, as pure functions.
///
/// No Flutter, no Firebase: everything here can be unit-tested in plain Dart.
abstract final class ScoringEngine {
  // ---------------------------------------------------------------- bowling

  /// Completed overs of [bowlerId] in [innings].
  static int bowlerOvers(Innings innings, String bowlerId) =>
      (innings.bowlers[bowlerId]?.legalBalls ?? 0) ~/ 6;

  /// The bowler of the last *legal* ball, i.e. who bowled the previous over
  /// when a new over is about to start. (Comparing with `innings.bowlerId`
  /// would be wrong: that may already hold the newly chosen bowler.)
  static String? previousOverBowlerId(Innings innings) {
    for (var i = innings.deliveries.length - 1; i >= 0; i--) {
      if (innings.deliveries[i].legal) return innings.deliveries[i].bowlerId;
    }
    return null;
  }

  /// Bowling-side players who have not reached their over limit.
  static List<Player> eligibleBowlers(
    Innings innings,
    List<Player> players,
    MatchRules rules, {
    bool excludeCurrent = false,
  }) {
    final limit = rules.maxOversPerBowler;
    return players
        .where(
          (p) =>
              p.teamId == innings.bowlingTeamId &&
              (!excludeCurrent || p.id != innings.bowlerId) &&
              bowlerOvers(innings, p.id) < limit,
        )
        .toList();
  }

  /// Batting-side players who can still come in.
  static List<Player> incomingBatters(Innings innings, List<Player> players) {
    final dismissed = innings.dismissedBatterIds.toSet();
    return players
        .where(
          (p) =>
              p.teamId == innings.battingTeamId &&
              p.id != innings.strikerId &&
              p.id != innings.nonStrikerId &&
              !dismissed.contains(p.id),
        )
        .toList();
  }

  /// Batters currently at the crease who may be given out.
  static List<Player> battersAtCrease(Innings innings, List<Player> players) {
    final dismissed = innings.dismissedBatterIds.toSet();
    return players
        .where(
          (p) =>
              p.teamId == innings.battingTeamId &&
              !dismissed.contains(p.id) &&
              (p.id == innings.strikerId || p.id == innings.nonStrikerId),
        )
        .toList();
  }

  // --------------------------------------------------------------- delivery

  /// Validates [request] against the live [innings] and builds the
  /// [Delivery]. Throws [ScoringException] with the same messages the web
  /// scorer shows.
  static DeliveryPlan planDelivery({
    required Innings innings,
    required MatchRules rules,
    required DeliveryRequest request,
    int? firstInningsTotal,
    DateTime? now,
  }) {
    if (innings.completed) {
      throw const ScoringException('This innings is already complete.');
    }
    final striker = innings.strikerId;
    final nonStriker = innings.nonStrikerId;
    final bowler = innings.bowlerId;
    if (striker == null ||
        nonStriker == null ||
        bowler == null ||
        striker == nonStriker) {
      throw const ScoringException(
        'Select two different batters and a bowler.',
      );
    }

    final kind = request.kind;
    final isPenalty = kind == DeliveryKind.penalty;

    if (!isPenalty) {
      final atOverStart = innings.legalBalls > 0 && innings.legalBalls % 6 == 0;
      if (atOverStart && bowler == previousOverBowlerId(innings)) {
        throw const ScoringException(
          'A different bowler must bowl the next over.',
        );
      }
      final limit = rules.maxOversPerBowler;
      if (bowlerOvers(innings, bowler) >= limit) {
        throw ScoringException(
          'This bowler has reached the $limit-over limit.',
        );
      }
    }

    var batterRuns = request.batterRuns;
    var extraRuns = 0;
    switch (kind) {
      case DeliveryKind.wide:
        batterRuns = 0;
        extraRuns = 1 + request.extraRunsInput;
      case DeliveryKind.noBall:
        extraRuns = 1;
      case DeliveryKind.bye:
      case DeliveryKind.legBye:
        batterRuns = 0;
        extraRuns = request.extraRunsInput;
      case DeliveryKind.penalty:
        batterRuns = 0;
        // Like the web scorer, an empty/zero value means the standard 5.
        extraRuns = request.extraRunsInput == 0 ? 5 : request.extraRunsInput;
    }
    if (batterRuns < 0 || extraRuns < 0) {
      throw const ScoringException('Enter valid whole-number runs.');
    }

    final totalRuns = batterRuns + extraRuns;
    final legal =
        kind != DeliveryKind.wide &&
        kind != DeliveryKind.noBall &&
        kind != DeliveryKind.penalty;
    final overWillEnd = legal && (innings.legalBalls + 1) % 6 == 0;

    final wicket = request.wicket;
    final dismissedId = wicket ? (request.dismissedBatterId ?? striker) : null;
    final incomingId = wicket ? request.incomingBatterId : null;
    if (wicket && dismissedId != striker && dismissedId != nonStriker) {
      throw const ScoringException('Choose a batter currently at the crease.');
    }
    if (wicket &&
        innings.wickets < 9 &&
        (incomingId == null || incomingId.isEmpty)) {
      throw const ScoringException('Choose the incoming batter.');
    }

    final projectedTotal = innings.total + totalRuns;
    final projectedWickets = innings.wickets + (wicket ? 1 : 0);
    final projectedBalls = innings.legalBalls + (legal ? 1 : 0);
    final targetReached =
        innings.number == 2 &&
        firstInningsTotal != null &&
        projectedTotal > firstInningsTotal;
    final inningsWillComplete =
        projectedWickets >= 10 ||
        projectedBalls >= rules.maxBalls ||
        targetReached;

    final label = wicket
        ? 'W'
        : switch (kind) {
            DeliveryKind.wide => 'Wd$extraRuns',
            DeliveryKind.noBall => 'Nb$totalRuns',
            DeliveryKind.bye => 'B$extraRuns',
            DeliveryKind.legBye => 'Lb$extraRuns',
            DeliveryKind.penalty => 'P$extraRuns',
            _ => '$batterRuns',
          };

    final delivery = Delivery(
      kind: kind,
      batterRuns: batterRuns,
      extraRuns: extraRuns,
      totalRuns: totalRuns,
      wicket: wicket,
      legal: legal,
      label: label,
      strikerId: striker,
      nonStrikerId: nonStriker,
      bowlerId: bowler,
      dismissedBatterId: dismissedId,
      incomingBatterId: incomingId,
      dismissalType: request.dismissalType,
      at: _isoNow(now),
    );

    return DeliveryPlan(
      delivery: delivery,
      overWillEnd: overWillEnd,
      inningsWillComplete: inningsWillComplete,
    );
  }

  /// Applies [d] to a copy of [source] and returns it.
  ///
  /// This is the body of the Firestore transaction in the web scorer: it runs
  /// against the *latest* server state of the innings.
  static Innings applyDelivery(
    Innings source,
    Delivery d, {
    required MatchRules rules,
    required bool overWillEnd,
    int? firstInningsTotal,
    String? nextBowlerId,
  }) {
    if (source.completed) {
      throw const ScoringException('This innings is already complete.');
    }
    final i = source.clone();

    // Batter figures. Wides are not faced; penalties never involve the bat.
    if (d.kind != DeliveryKind.penalty && d.kind != DeliveryKind.wide) {
      final batter = i.batters[d.strikerId] ?? BatterStats();
      if (d.legal) batter.balls++;
      batter.runs += d.batterRuns;
      if (d.batterRuns == 4) batter.fours++;
      if (d.batterRuns == 6) batter.sixes++;
      i.batters[d.strikerId] = batter;
    }

    // Bowler figures. Byes/leg-byes and penalties are not charged to him.
    if (d.kind != DeliveryKind.penalty) {
      final bowler = i.bowlers[d.bowlerId] ?? BowlerStats();
      if (d.kind != DeliveryKind.bye && d.kind != DeliveryKind.legBye) {
        bowler.runs += d.totalRuns;
      }
      if (d.legal) bowler.legalBalls++;
      if (d.wicket &&
          !DismissalType.notCreditedToBowler.contains(d.dismissalType)) {
        bowler.wickets++;
      }
      i.bowlers[d.bowlerId] = bowler;
    }

    i.total += d.totalRuns;
    i.extras += d.extraRuns;
    i.extrasByType[d.kind] = (i.extrasByType[d.kind] ?? 0) + d.extraRuns;
    if (d.legal) i.legalBalls++;
    i.deliveries.add(d);

    if (d.wicket) {
      i.wickets++;
      final out = d.outBatterId;
      if (out != null) i.dismissedBatterIds.add(out);
      final incoming = d.incomingBatterId;
      final replacement = (incoming == null || incoming.isEmpty)
          ? null
          : incoming;
      if (out == i.strikerId) {
        i.strikerId = replacement;
      } else {
        i.nonStrikerId = replacement;
      }
    } else {
      final runsForRotation = switch (d.kind) {
        DeliveryKind.bye || DeliveryKind.legBye => d.extraRuns,
        DeliveryKind.wide => math.max(0, d.extraRuns - 1),
        _ => d.batterRuns,
      };
      if (runsForRotation.isOdd) _swapEnds(i);
    }

    if (overWillEnd) _swapEnds(i);

    final reached =
        i.number == 2 &&
        firstInningsTotal != null &&
        i.total > firstInningsTotal;
    if (i.wickets >= 10 || i.legalBalls >= rules.maxBalls || reached) {
      i.completed = true;
    }
    if (overWillEnd && !i.completed && nextBowlerId != null) {
      i.bowlerId = nextBowlerId;
    }
    return i;
  }

  /// Rebuilds [innings] without its last delivery (undo).
  ///
  /// All totals are recomputed from the remaining ball log, and the crease
  /// positions / bowler are restored from the removed ball's snapshot.
  static Innings undoLastDelivery(
    Innings innings, {
    required MatchRules rules,
    int? firstInningsTotal,
  }) {
    if (innings.deliveries.isEmpty) {
      throw const ScoringException('There is no delivery to undo.');
    }
    final last = innings.deliveries.last;
    final events = innings.deliveries.sublist(0, innings.deliveries.length - 1);

    final r = innings.clone()
      ..total = 0
      ..wickets = 0
      ..legalBalls = 0
      ..extras = 0
      ..extrasByType = {}
      ..batters = {}
      ..bowlers = {}
      ..deliveries = events
      ..dismissedBatterIds = []
      ..completed = false;

    for (final d in events) {
      r.total += d.totalRuns;
      r.extras += d.extraRuns;
      r.extrasByType[d.kind] = (r.extrasByType[d.kind] ?? 0) + d.extraRuns;
      if (d.legal) r.legalBalls++;

      if (d.kind != DeliveryKind.wide && d.kind != DeliveryKind.penalty) {
        final b = r.batters[d.strikerId] ?? BatterStats();
        if (d.legal) b.balls++;
        b.runs += d.batterRuns;
        if (d.batterRuns == 4) b.fours++;
        if (d.batterRuns == 6) b.sixes++;
        r.batters[d.strikerId] = b;
      }
      if (d.kind != DeliveryKind.penalty) {
        final b = r.bowlers[d.bowlerId] ?? BowlerStats();
        if (d.kind != DeliveryKind.bye && d.kind != DeliveryKind.legBye) {
          b.runs += d.totalRuns;
        }
        if (d.legal) b.legalBalls++;
        if (d.wicket &&
            !DismissalType.notCreditedToBowler.contains(d.dismissalType)) {
          b.wickets++;
        }
        r.bowlers[d.bowlerId] = b;
      }
      if (d.wicket) {
        r.wickets++;
        final out = d.outBatterId;
        if (out != null) r.dismissedBatterIds.add(out);
      }
    }

    r.strikerId = last.strikerId.isNotEmpty
        ? last.strikerId
        : (innings.openingStrikerId ?? innings.strikerId);
    r.nonStrikerId = last.nonStrikerId.isNotEmpty
        ? last.nonStrikerId
        : (innings.openingNonStrikerId ?? innings.nonStrikerId);
    r.bowlerId = last.bowlerId.isNotEmpty ? last.bowlerId : innings.bowlerId;

    r.completed =
        r.wickets >= 10 ||
        r.legalBalls >= rules.maxBalls ||
        (r.number == 2 &&
            firstInningsTotal != null &&
            r.total > firstInningsTotal);
    return r;
  }

  // ----------------------------------------------------------------- result

  /// `Team A wins by 12 runs.` once the second innings is complete, else `''`.
  static String matchResult(
    List<Innings> innings,
    String Function(String teamId) teamName,
  ) {
    if (innings.length < 2) return '';
    final first = innings[0];
    final second = innings[1];
    if (!second.completed) return '';

    if (second.total > first.total) {
      final left = math.max(0, 10 - second.wickets);
      return '${teamName(second.battingTeamId)} wins by ${Fmt.plural(left, 'wicket')}.';
    }
    if (second.total < first.total) {
      final margin = first.total - second.total;
      return '${teamName(first.battingTeamId)} wins by ${Fmt.plural(margin, 'run')}.';
    }
    return 'Match tied.';
  }

  // ---------------------------------------------------------------- helpers

  static void _swapEnds(Innings i) {
    final s = i.strikerId;
    i.strikerId = i.nonStrikerId;
    i.nonStrikerId = s;
  }

  /// ISO-8601 UTC with millisecond precision, like JavaScript's
  /// `Date#toISOString`.
  static String _isoNow(DateTime? now) {
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(
      ms,
      isUtc: true,
    ).toIso8601String();
  }
}
