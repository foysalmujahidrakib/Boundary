import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../domain/scoring/scoring_engine.dart';

/// The signed-in user is not an active member of the club.
class AccessDeniedException implements Exception {
  const AccessDeniedException([
    this.message = 'You do not have access to this club workspace.',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// A referenced club / match does not exist.
class NotFoundException implements Exception {
  const NotFoundException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns any error into a message that is safe to show to the user.
///
/// [fallback] is used for unexpected errors; the technical detail is never
/// shown. Firestore's `permission-denied` gets a hint about the security
/// rules, which is the most common setup problem.
String describeError(Object error, {required String fallback}) {
  if (error is ScoringException) return error.message;
  if (error is AccessDeniedException) return error.message;
  if (error is NotFoundException) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firestore blocked this action. Check that the Boundary security '
        'rules (firestore.rules) are published for your Firebase project.';
  }
  if (error is FirebaseException && error.code == 'unavailable') {
    return 'You appear to be offline. Check your connection and try again.';
  }
  return fallback;
}

/// Friendly sign-in / registration errors (same wording as the web app).
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'email-already-in-use' =>
        'An account already exists with this email. Try logging in.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' =>
        'Please choose a stronger password (at least 6 characters).',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'user-disabled' =>
        'This account has been disabled. Contact the platform administrator.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' =>
        'Network error. Check your connection and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
