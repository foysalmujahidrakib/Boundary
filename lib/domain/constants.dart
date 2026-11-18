/// String vocabularies shared with the web app.
///
/// Firestore stores these as plain strings, and the security rules compare
/// against the exact literals below, so they must not change.
library;

/// Firestore collection names (identical to the web app).
abstract final class Collections {
  static const users = 'users';
  static const memberships = 'memberships';
  static const clubs = 'clubs';
  static const teams = 'teams';
  static const players = 'players';
  static const tournaments = 'tournaments';
  static const matches = 'matches';
  static const matchScores = 'matchScores';
  static const publicTournaments = 'publicTournaments';
  static const publicMatchScores = 'publicMatchScores';
}

/// A member's role inside a club.
abstract final class ClubRole {
  static const admin = 'club_admin';
  static const owner = 'club_owner';
  static const member = 'member';

  /// Only admins and owners may create/edit/delete data and score matches.
  static bool canManage(String role) => role == admin || role == owner;

  /// `club_admin` -> `CLUB ADMIN`
  static String label(String role) => role.replaceAll('_', ' ').toUpperCase();
}

abstract final class MatchFormat {
  static const t10 = 'T10';
  static const t20 = 'T20';
  static const odi = 'ODI';
  static const custom = 'Custom';

  /// (value, label) pairs for the match form.
  static const options = <(String, String)>[
    (t10, 'T10'),
    (t20, 'T20'),
    (odi, 'ODI (50 overs)'),
    (custom, 'Custom'),
  ];
}

abstract final class MatchStatus {
  static const scheduled = 'scheduled';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const abandoned = 'abandoned';

  static const options = <(String, String)>[
    (scheduled, 'Scheduled'),
    (inProgress, 'In progress'),
    (completed, 'Completed'),
    (abandoned, 'Abandoned'),
  ];
}

abstract final class TossDecision {
  static const bat = 'bat';
  static const bowl = 'bowl';

  static const options = <(String, String)>[
    ('', 'Not decided'),
    (bat, 'Bat'),
    (bowl, 'Bowl'),
  ];
}

abstract final class TournamentFormat {
  static const options = <(String, String)>[
    ('T10', 'T10'),
    ('T20', 'T20'),
    ('ODI', 'One Day (50 overs)'),
    ('Other', 'Other / custom'),
  ];
}

abstract final class TournamentStatus {
  static const planned = 'planned';
  static const ongoing = 'ongoing';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const options = <(String, String)>[
    (planned, 'Planned'),
    (ongoing, 'Ongoing'),
    (completed, 'Completed'),
    (cancelled, 'Cancelled'),
  ];

  /// Display order on the public standings list: active first.
  static int sortRank(String status) => switch (status) {
    ongoing => 0,
    planned => 1,
    completed => 2,
    cancelled => 3,
    _ => 4,
  };
}

abstract final class TeamCategory {
  static const values = <String>[
    'University',
    'Department',
    'Academy',
    'Local',
    'Other',
  ];
}

abstract final class PlayerRole {
  static const values = <String>[
    'Batter',
    'Bowler',
    'All-rounder',
    'Wicketkeeper',
  ];
}

abstract final class BattingStyle {
  static const values = <String>['Right-handed', 'Left-handed'];
}

abstract final class BowlingStyle {
  /// The web form's "None" option accidentally stored `Left-arm medium`
  /// (several options shared that value). Here "None" is stored as an empty
  /// string and every style has its own value.
  static const none = '';

  static const options = <(String, String)>[
    (none, 'None'),
    ('Right-arm fast', 'Right-arm fast'),
    ('Left-arm fast', 'Left-arm fast'),
    ('Right-arm medium', 'Right-arm medium'),
    ('Left-arm medium', 'Left-arm medium'),
    ('Right-arm off spin', 'Right-arm off spin'),
    ('Left-arm off spin', 'Left-arm off spin'),
    ('Right-arm leg spin', 'Right-arm leg spin'),
  ];
}

/// The kind of a recorded delivery.
abstract final class DeliveryKind {
  static const normal = 'normal';
  static const wide = 'wide';
  static const noBall = 'no_ball';
  static const bye = 'bye';
  static const legBye = 'leg_bye';
  static const penalty = 'penalty';

  /// Kinds shown as "extras" in the ball-by-ball log.
  static const extras = {wide, noBall, bye, legBye};
}

abstract final class DismissalType {
  static const bowled = 'bowled';
  static const caught = 'caught';
  static const lbw = 'lbw';
  static const runOut = 'run_out';
  static const stumped = 'stumped';
  static const hitWicket = 'hit_wicket';
  static const retiredHurt = 'retired_hurt';

  static const options = <(String, String)>[
    (bowled, 'Bowled'),
    (caught, 'Caught'),
    (lbw, 'LBW'),
    (runOut, 'Run out'),
    (stumped, 'Stumped'),
    (hitWicket, 'Hit wicket'),
    (retiredHurt, 'Retired hurt'),
  ];

  /// Dismissals that are not credited to the bowler.
  static const notCreditedToBowler = {runOut, retiredHurt};
}

/// Status values of a public score snapshot (`publicMatchScores.status`).
abstract final class PublicStatus {
  static const live = 'live';
  static const completed = 'completed';
  static const abandoned = 'abandoned';
  static const cancelled = 'cancelled';

  static const terminal = {completed, abandoned, cancelled};
}
