import '../constants.dart';
import '../scoring/formatters.dart';
import 'json_read.dart';

/// Batting figures for one batter in one innings.
class BatterStats {
  BatterStats({this.runs = 0, this.balls = 0, this.fours = 0, this.sixes = 0});

  factory BatterStats.fromMap(Map<String, dynamic> data) => BatterStats(
    runs: data.integer('runs'),
    balls: data.integer('balls'),
    fours: data.integer('fours'),
    sixes: data.integer('sixes'),
  );

  int runs;
  int balls;
  int fours;
  int sixes;

  double get strikeRate => balls == 0 ? 0 : runs / balls * 100;

  BatterStats clone() =>
      BatterStats(runs: runs, balls: balls, fours: fours, sixes: sixes);

  Map<String, dynamic> toMap() => {
    'runs': runs,
    'balls': balls,
    'fours': fours,
    'sixes': sixes,
  };
}

/// Bowling figures for one bowler in one innings.
class BowlerStats {
  BowlerStats({this.runs = 0, this.wickets = 0, this.legalBalls = 0});

  factory BowlerStats.fromMap(Map<String, dynamic> data) => BowlerStats(
    runs: data.integer('runs'),
    wickets: data.integer('wickets'),
    legalBalls: data.integer('legalBalls'),
  );

  int runs;
  int wickets;
  int legalBalls;

  double get economy => legalBalls == 0 ? 0 : runs / (legalBalls / 6);

  BowlerStats clone() =>
      BowlerStats(runs: runs, wickets: wickets, legalBalls: legalBalls);

  Map<String, dynamic> toMap() => {
    'runs': runs,
    'wickets': wickets,
    'legalBalls': legalBalls,
  };
}

/// One recorded ball (or penalty). Immutable: the ball log is append-only and
/// undo rebuilds an innings from it.
class Delivery {
  const Delivery({
    required this.kind,
    required this.batterRuns,
    required this.extraRuns,
    required this.totalRuns,
    required this.wicket,
    required this.legal,
    required this.label,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    this.dismissedBatterId,
    this.incomingBatterId,
    this.dismissalType = '',
    this.at = '',
  });

  factory Delivery.fromMap(Map<String, dynamic> data) => Delivery(
    kind: data.str('kind', DeliveryKind.normal),
    batterRuns: data.integer('batterRuns'),
    extraRuns: data.integer('extraRuns'),
    totalRuns: data.integer('totalRuns'),
    wicket: data.flag('wicket'),
    legal: data.flag('legal'),
    label: data.str('label'),
    strikerId: data.str('strikerId'),
    nonStrikerId: data.str('nonStrikerId'),
    bowlerId: data.str('bowlerId'),
    dismissedBatterId: data.strOrNull('dismissedBatterId'),
    incomingBatterId: data.strOrNull('incomingBatterId'),
    dismissalType: data.str('dismissalType'),
    at: data.str('at'),
  );

  final String kind;
  final int batterRuns;
  final int extraRuns;
  final int totalRuns;
  final bool wicket;

  /// Legal deliveries count towards the over; wides, no-balls and penalties
  /// do not.
  final bool legal;

  /// Short ball-log text: `4`, `W`, `Wd2`, `Nb5`, `B1`, `Lb1`, `P5`.
  final String label;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final String? dismissedBatterId;
  final String? incomingBatterId;
  final String dismissalType;

  /// ISO-8601 UTC timestamp, as written by the web app.
  final String at;

  /// The batter who was dismissed on this ball (the striker unless the
  /// scorer picked the non-striker, e.g. a run out).
  String? get outBatterId => wicket ? (dismissedBatterId ?? strikerId) : null;

  Map<String, dynamic> toMap() => {
    'kind': kind,
    'batterRuns': batterRuns,
    'extraRuns': extraRuns,
    'totalRuns': totalRuns,
    'wicket': wicket,
    'legal': legal,
    'label': label,
    'strikerId': strikerId,
    'nonStrikerId': nonStrikerId,
    'bowlerId': bowlerId,
    'dismissedBatterId': dismissedBatterId,
    'incomingBatterId': incomingBatterId,
    'dismissalType': dismissalType,
    'at': at,
  };
}

/// One team's innings (an element of `matchScores/{matchId}.innings`).
///
/// This class is intentionally **mutable** (it mirrors the JavaScript objects
/// the web scorer edits inside a Firestore transaction). The scoring engine
/// never changes an instance it was handed; it always works on a [clone].
class Innings {
  Innings({
    required this.number,
    required this.battingTeamId,
    required this.bowlingTeamId,
    this.strikerId,
    this.nonStrikerId,
    this.openingStrikerId,
    this.openingNonStrikerId,
    this.bowlerId,
    this.total = 0,
    this.wickets = 0,
    this.legalBalls = 0,
    this.extras = 0,
    this.completed = false,
    Map<String, int>? extrasByType,
    Map<String, BatterStats>? batters,
    Map<String, BowlerStats>? bowlers,
    List<Delivery>? deliveries,
    List<String>? dismissedBatterIds,
    Map<String, dynamic>? passthrough,
  }) : extrasByType = extrasByType ?? {},
       batters = batters ?? {},
       bowlers = bowlers ?? {},
       deliveries = deliveries ?? [],
       dismissedBatterIds = dismissedBatterIds ?? [],
       passthrough = passthrough ?? {};

  /// Starts a fresh innings with the chosen openers and opening bowler.
  factory Innings.start({
    required int number,
    required String battingTeamId,
    required String bowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) => Innings(
    number: number,
    battingTeamId: battingTeamId,
    bowlingTeamId: bowlingTeamId,
    strikerId: strikerId,
    nonStrikerId: nonStrikerId,
    openingStrikerId: strikerId,
    openingNonStrikerId: nonStrikerId,
    bowlerId: bowlerId,
  );

  static const _knownKeys = {
    'number',
    'battingTeamId',
    'bowlingTeamId',
    'strikerId',
    'nonStrikerId',
    'openingStrikerId',
    'openingNonStrikerId',
    'bowlerId',
    'total',
    'wickets',
    'legalBalls',
    'extras',
    'extrasByType',
    'batters',
    'bowlers',
    'deliveries',
    'dismissedBatterIds',
    'completed',
  };

  factory Innings.fromMap(Map<String, dynamic> data) => Innings(
    number: data.integer('number', 1),
    battingTeamId: data.str('battingTeamId'),
    bowlingTeamId: data.str('bowlingTeamId'),
    strikerId: data.strOrNull('strikerId'),
    nonStrikerId: data.strOrNull('nonStrikerId'),
    openingStrikerId: data.strOrNull('openingStrikerId'),
    openingNonStrikerId: data.strOrNull('openingNonStrikerId'),
    bowlerId: data.strOrNull('bowlerId'),
    total: data.integer('total'),
    wickets: data.integer('wickets'),
    legalBalls: data.integer('legalBalls'),
    extras: data.integer('extras'),
    completed: data.flag('completed'),
    extrasByType: {
      for (final e in data.nested('extrasByType').entries)
        e.key: (e.value is num) ? (e.value as num).toInt() : 0,
    },
    batters: {
      for (final e in data.nested('batters').entries)
        e.key: BatterStats.fromMap(
          e.value is Map ? Map<String, dynamic>.from(e.value as Map) : {},
        ),
    },
    bowlers: {
      for (final e in data.nested('bowlers').entries)
        e.key: BowlerStats.fromMap(
          e.value is Map ? Map<String, dynamic>.from(e.value as Map) : {},
        ),
    },
    deliveries: data.mapList('deliveries').map(Delivery.fromMap).toList(),
    dismissedBatterIds: data.stringList('dismissedBatterIds'),
    // Fields this app does not know about are kept and written back, so
    // data added by a newer web version is never silently dropped.
    passthrough: {
      for (final e in data.entries)
        if (!_knownKeys.contains(e.key)) e.key: e.value,
    },
  );

  int number;
  String battingTeamId;
  String bowlingTeamId;
  String? strikerId;
  String? nonStrikerId;
  String? openingStrikerId;
  String? openingNonStrikerId;
  String? bowlerId;
  int total;
  int wickets;

  /// Legal balls bowled (6 per over).
  int legalBalls;
  int extras;
  bool completed;
  Map<String, int> extrasByType;
  Map<String, BatterStats> batters;
  Map<String, BowlerStats> bowlers;
  List<Delivery> deliveries;
  List<String> dismissedBatterIds;
  Map<String, dynamic> passthrough;

  /// `12.3` style overs label.
  String get oversLabel => Fmt.overs(legalBalls);

  /// Runs per over, 0 before the first legal ball.
  double get runRate => legalBalls == 0 ? 0 : total / (legalBalls / 6);

  /// A deep copy that can be modified without touching this instance.
  Innings clone() => Innings(
    number: number,
    battingTeamId: battingTeamId,
    bowlingTeamId: bowlingTeamId,
    strikerId: strikerId,
    nonStrikerId: nonStrikerId,
    openingStrikerId: openingStrikerId,
    openingNonStrikerId: openingNonStrikerId,
    bowlerId: bowlerId,
    total: total,
    wickets: wickets,
    legalBalls: legalBalls,
    extras: extras,
    completed: completed,
    extrasByType: Map.of(extrasByType),
    batters: {for (final e in batters.entries) e.key: e.value.clone()},
    bowlers: {for (final e in bowlers.entries) e.key: e.value.clone()},
    deliveries: List.of(deliveries),
    dismissedBatterIds: List.of(dismissedBatterIds),
    passthrough: Map.of(passthrough),
  );

  Map<String, dynamic> toMap() => {
    ...passthrough,
    'number': number,
    'battingTeamId': battingTeamId,
    'bowlingTeamId': bowlingTeamId,
    'strikerId': strikerId,
    'nonStrikerId': nonStrikerId,
    'openingStrikerId': openingStrikerId,
    'openingNonStrikerId': openingNonStrikerId,
    'bowlerId': bowlerId,
    'total': total,
    'wickets': wickets,
    'legalBalls': legalBalls,
    'extras': extras,
    'extrasByType': extrasByType,
    'batters': {for (final e in batters.entries) e.key: e.value.toMap()},
    'bowlers': {for (final e in bowlers.entries) e.key: e.value.toMap()},
    'deliveries': deliveries.map((d) => d.toMap()).toList(),
    'dismissedBatterIds': dismissedBatterIds,
    'completed': completed,
  };
}

/// The live scoring document (`matchScores/{matchId}`).
class MatchScore {
  const MatchScore({
    required this.matchId,
    required this.clubId,
    required this.innings,
  });

  factory MatchScore.fromMap(String id, Map<String, dynamic> data) =>
      MatchScore(
        matchId: data.str('matchId', id),
        clubId: data.str('clubId'),
        innings: data.mapList('innings').map(Innings.fromMap).toList(),
      );

  final String matchId;
  final String clubId;
  final List<Innings> innings;

  /// The innings being scored (the last one), or `null` before the toss.
  Innings? get current => innings.isEmpty ? null : innings.last;

  int get currentIndex => innings.length - 1;

  /// Total of the first innings, i.e. the target to beat minus one.
  int? get firstInningsTotal => innings.isEmpty ? null : innings.first.total;
}
