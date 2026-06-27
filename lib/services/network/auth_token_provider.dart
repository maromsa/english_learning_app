import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Returns a Firebase ID token for the signed-in user, or `null` when no user
/// is signed in (or Firebase is unavailable, e.g. in unit tests).
typedef AuthTokenProvider = Future<String?> Function();

/// Default [AuthTokenProvider] backed by [FirebaseAuth].
///
/// The geminiProxy Cloud Function requires a valid Firebase ID token in the
/// `Authorization: Bearer <token>` header. Token retrieval failures are
/// swallowed so callers degrade gracefully (the server responds 401).
Future<String?> firebaseAuthTokenProvider() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    return await user.getIdToken();
  } catch (e) {
    debugPrint('[AuthTokenProvider] Failed to obtain ID token: $e');
    return null;
  }
}
