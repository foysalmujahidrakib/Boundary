import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../domain/models/club.dart';
import '../../domain/models/cricket_match.dart';
import '../../domain/models/team.dart';
import '../../domain/models/tournament.dart';

/// Loads one club for the signed-in user and keeps its data live.
///
/// This replaces the membership-check + `getDocs` boilerplate that
/// `club.js`, `matches.js` and `tournaments.js` each repeated. A screen asks
/// only for the collections it needs; every one is a Firestore snapshot
/// stream, so changes made on another device appear immediately.
class ClubWorkspaceController extends ChangeNotifier {
  ClubWorkspaceController({
    required AppServices services,
    required this.clubId,
    required this.user,
    this.watchPlayers = false,
    this.watchTournaments = false,
    this.watchMatches = false,
  }) : _services = services {
    unawaited(_load());
  }

  final AppServices _services;
  final String clubId;
  final User user;
  final bool watchPlayers;
  final bool watchTournaments;
  final bool watchMatches;

  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;

  ClubAccess? access;
  String? error;

  List<Team> teams = const [];
  List<Player> players = const [];
  List<Tournament> tournaments = const [];
  List<CricketMatch> matches = const [];

  bool teamsLoaded = false;
  bool playersLoaded = false;
  bool tournamentsLoaded = false;
  bool matchesLoaded = false;

  Club? get club => access?.club;
  bool get canManage => access?.canManage ?? false;
  String get role => access?.role ?? 'member';

  /// Access check finished successfully.
  bool get ready => access != null;

  /// Everything requested has arrived at least once.
  bool get dataLoaded =>
      teamsLoaded &&
      (!watchPlayers || playersLoaded) &&
      (!watchTournaments || tournamentsLoaded) &&
      (!watchMatches || matchesLoaded);

  String teamName(String? id, [String fallback = 'Unknown team']) {
    if (id == null) return fallback;
    for (final t in teams) {
      if (t.id == id) return t.name;
    }
    return fallback;
  }

  Future<void> _load() async {
    try {
      access = await _services.clubs.loadAccess(uid: user.uid, clubId: clubId);
    } catch (e) {
      error = describeError(e, fallback: 'The club could not be loaded.');
      _notify();
      return;
    }
    _notify();

    _listen<List<Team>>(_services.roster.watchTeams(clubId), (v) {
      teams = v;
      teamsLoaded = true;
    });
    if (watchPlayers) {
      _listen<List<Player>>(_services.roster.watchPlayers(clubId), (v) {
        players = v;
        playersLoaded = true;
      });
    }
    if (watchTournaments) {
      _listen<List<Tournament>>(
        _services.tournaments.watchTournaments(clubId),
        (v) {
          tournaments = v;
          tournamentsLoaded = true;
        },
      );
    }
    if (watchMatches) {
      _listen<List<CricketMatch>>(_services.matches.watchMatches(clubId), (v) {
        matches = v;
        matchesLoaded = true;
      });
    }
  }

  void _listen<T>(Stream<T> stream, void Function(T value) onData) {
    _subscriptions.add(
      stream.listen(
        (value) {
          onData(value);
          _notify();
        },
        onError: (Object e) {
          error = describeError(e, fallback: 'Could not load club data.');
          _notify();
        },
      ),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
