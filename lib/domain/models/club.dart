import '../constants.dart';
import 'json_read.dart';

/// A cricket club workspace (`clubs/{clubId}`).
class Club {
  const Club({
    required this.id,
    required this.name,
    this.location = '',
    this.description = '',
    this.ownerUid = '',
    this.status = 'active',
    this.visibility = 'public',
  });

  factory Club.fromMap(String id, Map<String, dynamic> data) => Club(
    id: id,
    name: data.str('name'),
    location: data.str('location'),
    description: data.str('description'),
    ownerUid: data.str('ownerUid'),
    status: data.str('status', 'active'),
    visibility: data.str('visibility', 'public'),
  );

  final String id;
  final String name;
  final String location;
  final String description;
  final String ownerUid;
  final String status;
  final String visibility;

  String get displayName => name.isEmpty ? 'Cricket club' : name;
  String get displayLocation =>
      location.isEmpty ? 'Location not added' : location;

  /// Two-letter avatar text, e.g. "Dhaka Kings" -> "DH".
  String get initials {
    final source = name.isEmpty ? 'C' : name;
    return source
        .substring(0, source.length < 2 ? source.length : 2)
        .toUpperCase();
  }

  /// `Dhaka · Friendly club` style subtitle used under the club heading.
  String get subtitle {
    final parts = [location, description].where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'Teams and squads' : parts.join(' · ');
  }
}

/// A user's membership of a club (`memberships/{uid}_{clubId}`).
class Membership {
  const Membership({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.role,
    required this.status,
  });

  factory Membership.fromMap(String id, Map<String, dynamic> data) =>
      Membership(
        id: id,
        clubId: data.str('clubId'),
        userId: data.str('userId'),
        role: data.str('role', ClubRole.member),
        status: data.str('status'),
      );

  final String id;
  final String clubId;
  final String userId;
  final String role;
  final String status;

  bool get isActive => status == 'active';
  bool get canManage => ClubRole.canManage(role);

  /// The document id convention enforced by the Firestore rules.
  static String idFor(String uid, String clubId) => '${uid}_$clubId';
}

/// What a signed-in user may do inside one club.
class ClubAccess {
  const ClubAccess({required this.club, required this.role});

  final Club club;
  final String role;

  bool get canManage => ClubRole.canManage(role);
}
