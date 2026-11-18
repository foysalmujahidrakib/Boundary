import '../text_utils.dart';
import 'json_read.dart';

/// A team inside a club (`teams/{teamId}`).
class Team {
  const Team({
    required this.id,
    required this.clubId,
    required this.name,
    this.category = 'University',
    this.description = '',
  });

  factory Team.fromMap(String id, Map<String, dynamic> data) => Team(
    id: id,
    clubId: data.str('clubId'),
    name: data.str('name'),
    category: data.str('category'),
    description: data.str('description'),
  );

  final String id;
  final String clubId;
  final String name;
  final String category;
  final String description;

  String get displayName => name.isEmpty ? 'Unnamed team' : name;

  String get initials {
    final source = name.isEmpty ? 'T' : name;
    return source
        .substring(0, source.length < 2 ? source.length : 2)
        .toUpperCase();
  }

  /// `University · Our first team` style subtitle.
  String get subtitle {
    final parts = [
      category.isEmpty ? 'Team' : category,
      description,
    ].where((p) => p.isNotEmpty);
    return parts.join(' · ');
  }

  /// Writable fields (timestamps / creator are added by the repository).
  Map<String, dynamic> toMap() => {
    'clubId': clubId,
    'name': name,
    'category': category,
    'description': description,
  };
}

/// A registered player (`players/{playerId}`).
class Player {
  const Player({
    required this.id,
    required this.clubId,
    required this.fullName,
    this.teamId,
    this.jerseyNumber,
    this.role = 'Batter',
    this.battingStyle = 'Right-handed',
    this.bowlingStyle = '',
  });

  factory Player.fromMap(String id, Map<String, dynamic> data) => Player(
    id: id,
    clubId: data.str('clubId'),
    fullName: data.str('fullName'),
    teamId: _blankToNull(data.strOrNull('teamId')),
    jerseyNumber: data.integerOrNull('jerseyNumber'),
    role: data.str('role', 'Batter'),
    battingStyle: data.str('battingStyle'),
    bowlingStyle: data.str('bowlingStyle'),
  );

  final String id;
  final String clubId;
  final String fullName;

  /// Legacy players saved before teams were mandatory have no team.
  final String? teamId;
  final int? jerseyNumber;
  final String role;
  final String battingStyle;
  final String bowlingStyle;

  Map<String, dynamic> toMap() => {
    'clubId': clubId,
    'fullName': fullName,
    'jerseyNumber': jerseyNumber,
    'role': role,
    'teamId': teamId,
    'battingStyle': battingStyle,
    'bowlingStyle': bowlingStyle,
  };

  /// Sort order used for squads: jersey number first, then name.
  static int byJerseyThenName(Player a, Player b) {
    final an = a.jerseyNumber ?? 1 << 30;
    final bn = b.jerseyNumber ?? 1 << 30;
    final byNumber = an.compareTo(bn);
    return byNumber != 0 ? byNumber : compareNames(a.fullName, b.fullName);
  }
}

String? _blankToNull(String? value) =>
    (value == null || value.isEmpty) ? null : value;
