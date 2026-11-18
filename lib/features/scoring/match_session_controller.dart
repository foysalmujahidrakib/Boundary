import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../domain/models/club.dart';
import '../../domain/models/cricket_match.dart';
import '../../domain/models/innings.dart';
import '../../domain/models/team.dart';
import '../../domain/scoring/scoring_engine.dart';

/// Loads everything about one match for a club member: access, fixture, both
/// squads and the live score (as a stream).
///
/// Used directly by the private scorecard; the scorer extends it with
/// actions ([ScoringController]).
class MatchSessionController extends ChangeNotifier {
  MatchSessionController({
    required this.services,
    required this.clubId,
    required this.matchId,
    required this.user,
  }) {
    unawaited(_load());
  }

  final AppServices services;
  final String clubId;
  final String matchId;
  final User user;

  StreamSubscription<MatchScore?>? _scoreSub;
  bool _disposed = false;

  ClubAccess? access;
  CricketMatch? match;
  List<Team> teams = const [];
  List<Player> players = const [];
  MatchScore? score;
  bool scoreLoaded = false;
  String? error;

  bool get ready => access != null && match != null;
  bool get canManage => access?.canManage ?? false;
  Club? get club => access?.club;

  List<Innings> get innings => score?.innings ?? const [];
  Innings? get current => score?.current;

  /// The two squads of this fixture.
  List<Player> get matchPlayers => players
      .where((p) => p.teamId == match?.teamAId || p.teamId == match?.teamBId)
      .toList();

  List<Team> get matchTeams => [
    for (final id in [match?.teamAId, match?.teamBId])
      for (final t in teams)
        if (t.id == id) t,
  ];

  String teamName(String? id, [String fallback = 'Unknown team']) {
    for (final t in teams) {
      if (t.id == id) return t.displayName;
    }
    return fallback;
  }

  String playerName(String? id) {
    if (id == null) return 'Player';
    for (final p in players) {
      if (p.id == id) return p.fullName;
    }
    return 'Player';
  }

  List<Player> playersOf(String? teamId) =>
      (players.where((p) => p.teamId == teamId).toList()
        ..sort(Player.byJerseyThenName));

  /// `Team A wins by 12 runs.` once both innings are complete.
  String get result => ScoringEngine.matchResult(innings, (id) => teamName(id));

  String get title {
    final m = match;
    if (m == null) return '';
    return m.title.isNotEmpty
        ? m.title
        : '${teamName(m.teamAId)} vs ${teamName(m.teamBId)}';
  }

  Future<void> _load() async {
    try {
      access = await services.clubs.loadAccess(uid: user.uid, clubId: clubId);
      final loaded = await Future.wait<Object?>([
        services.matches.getMatch(matchId),
        services.roster.loadTeams(clubId),
        services.roster.loadPlayers(clubId),
      ]);
      final fixture = loaded[0] as CricketMatch?;
      if (fixture == null || fixture.clubId != clubId) {
        throw const NotFoundException('This match could not be found.');
      }
      match = fixture;
      teams = loaded[1]! as List<Team>;
      players = loaded[2]! as List<Player>;
      await onReady();
    } catch (e) {
      error = describeError(e, fallback: 'The match could not be loaded.');
      notify();
      return;
    }

    _scoreSub = services.scores
        .watchScore(matchId)
        .listen(
          (value) {
            score = value;
            scoreLoaded = true;
            onScoreChanged();
            notify();
          },
          onError: (Object e) {
            error = describeError(
              e,
              fallback: 'The live score could not be loaded.',
            );
            notify();
          },
        );
    notify();
  }

  /// Hook for subclasses, called once access, match and squads are loaded.
  Future<void> onReady() async {}

  /// Hook for subclasses, called whenever a new score arrives.
  void onScoreChanged() {}

  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_scoreSub?.cancel());
    super.dispose();
  }
}
