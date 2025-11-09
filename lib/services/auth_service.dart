import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<AppUser> upsertUser(User user) async {
    final docRef = _usersCollection.doc(user.uid);
    final existingSnapshot = await docRef.get();

    final data = <String, dynamic>{
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'lastSignInAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existingSnapshot.exists) {
      data['role'] = 'user';
      data['createdAt'] = FieldValue.serverTimestamp();
    } else {
      final existing = existingSnapshot.data() ?? <String, dynamic>{};
      data['role'] = existing['role'] ?? 'user';
    }

    await docRef.set(data, SetOptions(merge: true));

    final updatedSnapshot = await docRef.get();
    return AppUser.fromDocument(updatedSnapshot);
  }

  Future<AppUser?> getUser(String uid) async {
    final snapshot = await _usersCollection.doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }
    return AppUser.fromDocument(snapshot);
  }
}
