import 'dart:async';

import '../../data/errors.dart';
import '../../domain/models/innings.dart';
import '../../domain/models/team.dart';
import '../../domain/scoring/scoring_engine.dart';
import 'match_session_controller.dart';

/// Asks the scorer who bowls next. Resolves to a player id, or `null` to
/// cancel (the delivery is then not recorded).
typedef NextBowlerPicker = Future<String?> Function(List<Player> eligible);

/// The live scorer: turns taps into Firestore transactions.
///
/// This is the Flutter counterpart of the page-level state and handlers in
/// `scoring.js`. All cricket rules live in [ScoringEngine]; this class only
/// sequences validate -> (ask UI) -> transaction -> publish.
///
/// Every action returns an error message to show, or `null` on success.
class ScoringController extends MatchSessionController {
  ScoringController({
    required super.services,
    required super.clubId,
    required super.matchId,
    required super.user,
  });

  bool busy = false;

  /// The last attempt to publish the public scorecard failed.
  bool publishFailed = false;

  bool _publishedOnLoad = false;

  MatchRules get rules => MatchRules.fromMatch(match!);

  bool get hasInnings => innings.isNotEmpty;

  /// Innings 1 is over and the second has not started.
  bool get awaitingSecondInnings =>
      innings.length == 1 && innings.first.completed;

  /// Both innings are finished.
  bool get matchFinished => innings.length >= 2 && innings[1].completed;

  /// An innings is in progress and can be scored.
  bool get canScoreNow =>
      canManage && current != null && !current!.completed && !busy;

  /// Number of the innings the setup card would start (1 or 2), or `null`.
  int? get nextInningsNumber {
    if (!hasInnings) return 1;
    if (awaitingSecondInnings) return 2;
    return null;
  }

  /// Team that must bat in the next innings, if the rules force it.
  String? get forcedBattingTeamId =>
      nextInningsNumber == 2 ? innings.first.bowlingTeamId : null;

  // ------------------------------------------------------------- lifecycle

  @override
  Future<void> onReady() async {
    if (!canManage) return;
    unawaited(services.scores.repairClubPublicStatuses(clubId));
  }

  @override
  void onScoreChanged() {
    // Keep the public copy current for matches scored before this app (or
    // before publishing existed), once per visit.
    if (!_publishedOnLoad && canManage && score != null && match != null) {
      _publishedOnLoad = true;
      unawaited(_publish(score!));
    }
  }

  // --------------------------------------------------------------- actions

  Future<String?> startInnings({
    required String battingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) {
    return _run('The innings could not be started.', () async {
      final number = nextInningsNumber;
      final fixture = match!;
      if (!canManage || number == null) {
        throw const ScoringException('An innings is already in progress.');
      }
      final bowlingTeamId = battingTeamId == fixture.teamAId
          ? fixture.teamBId
          : fixture.teamAId;

      final batters = playersOf(battingTeamId).map((p) => p.id).toSet();
      final bowlers = playersOf(bowlingTeamId).map((p) => p.id).toSet();
      if (strikerId == nonStrikerId ||
          !batters.contains(strikerId) ||
          !batters.contains(nonStrikerId) ||
          !bowlers.contains(bowlerId) ||
          (forcedBattingTeamId != null &&
              battingTeamId != forcedBattingTeamId)) {
        throw const ScoringException(
          'Choose valid teams, two different opening batters and a bowler.',
        );
      }

      final saved = await services.scores.startInnings(
        clubId: clubId,
        matchId: matchId,
        userId: user.uid,
        innings: Innings.start(
          number: number,
          battingTeamId: battingTeamId,
          bowlingTeamId: bowlingTeamId,
          strikerId: strikerId,
          nonStrikerId: nonStrikerId,
          bowlerId: bowlerId,
        ),
      );
      _accept(saved);
    });
  }

  /// Records one delivery. [pickNextBowler] is called when the ball finishes
  /// an over and the innings goes on; cancelling it aborts the delivery.
  Future<String?> recordDelivery(
    DeliveryRequest request, {
    required NextBowlerPicker pickNextBowler,
  }) {
    return _run('The delivery could not be saved.', () async {
      final inn = current;
      if (!canManage || inn == null || inn.completed) {
        throw const ScoringException('This innings is already complete.');
      }

      // 1. Validate against what the scorer sees on screen.
      final plan = ScoringEngine.planDelivery(
        innings: inn,
        rules: rules,
        request: request,
        firstInningsTotal: inn.number == 2 ? innings.first.total : null,
      );

      // 2. End of over: ask who bowls next *before* writing anything.
      String? nextBowlerId;
      if (plan.needsNextBowler) {
        final eligible = ScoringEngine.eligibleBowlers(
          inn,
          players,
          rules,
          excludeCurrent: true,
        );
        if (eligible.isEmpty) {
          throw const ScoringException(
            'No eligible bowler is available for the next over.',
          );
        }
        nextBowlerId = await pickNextBowler(eligible);
        if (nextBowlerId == null) return; // cancelled: nothing is recorded
      }

      // 3. Apply to the latest server state, atomically.
      final saved = await services.scores.mutateInnings(
        matchId: matchId,
        inningsIndex: score!.currentIndex,
        userId: user.uid,
        change: (latest, all) => ScoringEngine.applyDelivery(
          latest,
          plan.delivery,
          rules: rules,
          overWillEnd: plan.overWillEnd,
          firstInningsTotal: latest.number == 2 ? all.firstInningsTotal : null,
          nextBowlerId: nextBowlerId,
        ),
      );
      _accept(saved);
    });
  }

  Future<String?> undoLastDelivery() {
    return _run('The delivery could not be undone.', () async {
      final inn = current;
      if (!canManage || inn == null) return;
      final saved = await services.scores.mutateInnings(
        matchId: matchId,
        inningsIndex: score!.currentIndex,
        userId: user.uid,
        change: (latest, all) => ScoringEngine.undoLastDelivery(
          latest,
          rules: rules,
          firstInningsTotal: latest.number == 2 ? all.firstInningsTotal : null,
        ),
      );
      _accept(saved);
    });
  }

  Future<String?> endInnings() {
    return _run('The innings could not be ended.', () async {
      final inn = current;
      if (!canManage || inn == null || inn.completed) return;
      final saved = await services.scores.mutateInnings(
        matchId: matchId,
        inningsIndex: score!.currentIndex,
        userId: user.uid,
        change: (latest, _) => latest.clone()..completed = true,
      );
      _accept(saved);
    });
  }

  // --------------------------------------------------------------- helpers

  Future<String?> _run(String fallback, Future<void> Function() action) async {
    if (busy) return null;
    busy = true;
    notify();
    try {
      await action();
      return null;
    } catch (e) {
      return describeError(e, fallback: fallback);
    } finally {
      busy = false;
      notify();
    }
  }

  /// Shows a freshly saved score immediately and publishes it.
  void _accept(MatchScore saved) {
    score = saved;
    notify();
    unawaited(_publish(saved));
  }

  Future<void> _publish(MatchScore saved) async {
    final fixture = match;
    if (fixture == null) return;
    final squads = matchPlayers;
    try {
      await services.scores.publishPublicScore(
        match: fixture,
        score: saved,
        teamNames: {for (final t in matchTeams) t.id: t.displayName},
        playerNames: {for (final p in squads) p.id: p.fullName},
        result: ScoringEngine.matchResult(saved.innings, (id) => teamName(id)),
      );
      publishFailed = false;
    } catch (_) {
      publishFailed = true;
    }
    notify();
  }
}
