import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/ui.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/club_repository.dart';
import 'data/repositories/match_repository.dart';
import 'data/repositories/public_repository.dart';
import 'data/repositories/roster_repository.dart';
import 'data/repositories/score_repository.dart';
import 'data/repositories/tournament_repository.dart';

/// Holds every repository. Created once in `main` and exposed to the widget
/// tree with [AppScope]; tests can build one around fake Firebase instances.
class AppServices {
  AppServices({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance {
    this.auth = AuthRepository(_auth);
    clubs = ClubRepository(_db);
    roster = RosterRepository(_db);
    tournaments = TournamentRepository(_db);
    matches = MatchRepository(_db);
    scores = ScoreRepository(_db);
    public = PublicRepository(_db);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  late final AuthRepository auth;
  late final ClubRepository clubs;
  late final RosterRepository roster;
  late final TournamentRepository tournaments;
  late final MatchRepository matches;
  late final ScoreRepository scores;
  late final PublicRepository public;
}

/// Makes [AppServices] available anywhere below the app root:
/// `AppScope.of(context).clubs`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
