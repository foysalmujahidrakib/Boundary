import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/constants.dart';
import '../../domain/models/club.dart';
import '../errors.dart';
import '../firestore_codec.dart';

/// A club the user belongs to, with their membership.
class ClubMembership {
  const ClubMembership({required this.membership, required this.club});
  final Membership membership;
  final Club club;
}

class MyClubs {
  const MyClubs({required this.entries, required this.membershipCount});

  /// Clubs that still exist.
  final List<ClubMembership> entries;

  /// Number of membership documents (the dashboard counter).
  final int membershipCount;
}

/// Clubs and memberships (port of `dashboard.js` and the access checks that
/// every club page repeats).
class ClubRepository {
  ClubRepository(this._db);

  final FirebaseFirestore _db;

  Future<MyClubs> loadMyClubs(String uid) async {
    final snapshot = await _db
        .collection(Collections.memberships)
        .where('userId', isEqualTo: uid)
        .get();

    final entries = await Future.wait(
      snapshot.docs.map((doc) async {
        final membership = Membership.fromMap(doc.id, doc.decodedData);
        final clubDoc = await _db
            .collection(Collections.clubs)
            .doc(membership.clubId)
            .get();
        final data = clubDoc.decoded;
        if (data == null) return null;
        return ClubMembership(
          membership: membership,
          club: Club.fromMap(clubDoc.id, data),
        );
      }),
    );

    return MyClubs(
      entries: entries.whereType<ClubMembership>().toList(),
      membershipCount: snapshot.size,
    );
  }

  /// Creates the club, the creator's admin membership and their profile
  /// document in one atomic batch (the security rules require them together).
  Future<String> createClub({
    required User user,
    required String name,
    String location = '',
    String description = '',
  }) async {
    final clubRef = _db.collection(Collections.clubs).doc();
    final membershipRef = _db
        .collection(Collections.memberships)
        .doc(Membership.idFor(user.uid, clubRef.id));

    final batch = _db.batch();
    batch.set(clubRef, {
      'name': name,
      'location': location,
      'description': description,
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'visibility': 'public',
    });
    batch.set(membershipRef, {
      'clubId': clubRef.id,
      'userId': user.uid,
      'role': ClubRole.admin,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection(Collections.users).doc(user.uid), {
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return clubRef.id;
  }

  /// Verifies the user is an active member and loads the club.
  ///
  /// Throws [AccessDeniedException] / [NotFoundException] with the same
  /// messages the web pages show.
  Future<ClubAccess> loadAccess({
    required String uid,
    required String clubId,
  }) async {
    final membershipDoc = await _db
        .collection(Collections.memberships)
        .doc(Membership.idFor(uid, clubId))
        .get();
    final membershipData = membershipDoc.decoded;
    if (membershipData == null) throw const AccessDeniedException();
    final membership = Membership.fromMap(membershipDoc.id, membershipData);
    if (!membership.isActive) throw const AccessDeniedException();

    final clubDoc = await _db.collection(Collections.clubs).doc(clubId).get();
    final clubData = clubDoc.decoded;
    if (clubData == null) {
      throw const NotFoundException('This club could not be found.');
    }
    return ClubAccess(
      club: Club.fromMap(clubDoc.id, clubData),
      role: membership.role,
    );
  }
}
