/// Model for local user profiles (linked to Google account)
class LocalUser {
  LocalUser({
    required this.id,
    required this.name,
    required this.age,
    this.photoUrl,
    this.createdAt,
    this.lastPlayedAt,
    this.isActive = false,
    this.googleUid,
    this.googleEmail,
    this.googleDisplayName,
  });

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    DateTime? toDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    return LocalUser(
      id: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      photoUrl: map['photoUrl'] as String?,
      createdAt: toDate(map['createdAt']),
      lastPlayedAt: toDate(map['lastPlayedAt']),
      isActive: map['isActive'] as bool? ?? false,
      googleUid: map['googleUid'] as String?,
      googleEmail: map['googleEmail'] as String?,
      googleDisplayName: map['googleDisplayName'] as String?,
    );
  }

  final String id;
  final String name;
  final int age;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastPlayedAt;
  final bool isActive;
  final String? googleUid;
  final String? googleEmail;
  final String? googleDisplayName;

  bool get isLinkedToGoogle => googleUid != null && googleUid!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'age': age,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (lastPlayedAt != null) 'lastPlayedAt': lastPlayedAt!.toIso8601String(),
      'isActive': isActive,
      if (googleUid != null) 'googleUid': googleUid,
      if (googleEmail != null) 'googleEmail': googleEmail,
      if (googleDisplayName != null) 'googleDisplayName': googleDisplayName,
    };
  }

  LocalUser copyWith({
    String? id,
    String? name,
    int? age,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    bool? isActive,
    String? googleUid,
    String? googleEmail,
    String? googleDisplayName,
  }) {
    return LocalUser(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isActive: isActive ?? this.isActive,
      googleUid: googleUid ?? this.googleUid,
      googleEmail: googleEmail ?? this.googleEmail,
      googleDisplayName: googleDisplayName ?? this.googleDisplayName,
    );
  }
}
