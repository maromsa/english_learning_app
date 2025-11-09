import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastSignInAt,
    this.updatedAt,
  });

  factory AppUser.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoURL'] as String?,
      createdAt: toDate(data['createdAt']),
      lastSignInAt: toDate(data['lastSignInAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  final String uid;
  final String email;
  final String role;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email,
      'role': role,
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoURL': photoUrl,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastSignInAt != null) 'lastSignInAt': lastSignInAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
