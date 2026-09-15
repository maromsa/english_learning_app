// lib/models/equipped_avatar.dart

/// The set of [AvatarItem] ids currently worn by a child, one per slot.
///
/// A `null` field means that slot is empty (nothing equipped). Deserialization
/// is tolerant (§2.3): a malformed or pre-existing document parses to an
/// all-empty avatar rather than throwing.
class EquippedAvatar {
  const EquippedAvatar({
    this.hatId,
    this.shirtId,
    this.accessoryId,
    this.backgroundId,
  });

  factory EquippedAvatar.empty() => const EquippedAvatar();

  final String? hatId;
  final String? shirtId;
  final String? accessoryId;
  final String? backgroundId;

  factory EquippedAvatar.fromJson(Map<String, dynamic> json) {
    return EquippedAvatar(
      hatId: json['hatId'] as String?,
      shirtId: json['shirtId'] as String?,
      accessoryId: json['accessoryId'] as String?,
      backgroundId: json['backgroundId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (hatId != null) 'hatId': hatId,
        if (shirtId != null) 'shirtId': shirtId,
        if (accessoryId != null) 'accessoryId': accessoryId,
        if (backgroundId != null) 'backgroundId': backgroundId,
      };

  /// Returns a copy with the given slots updated.
  ///
  /// Passing a new id for a slot updates it; passing `null` (the default)
  /// leaves that slot unchanged. To explicitly clear a slot (unequip it),
  /// set its `clear*` flag to `true` — this takes precedence over the slot's
  /// value argument.
  EquippedAvatar copyWith({
    String? hatId,
    String? shirtId,
    String? accessoryId,
    String? backgroundId,
    bool clearHat = false,
    bool clearShirt = false,
    bool clearAccessory = false,
    bool clearBackground = false,
  }) {
    return EquippedAvatar(
      hatId: clearHat ? null : (hatId ?? this.hatId),
      shirtId: clearShirt ? null : (shirtId ?? this.shirtId),
      accessoryId: clearAccessory ? null : (accessoryId ?? this.accessoryId),
      backgroundId:
          clearBackground ? null : (backgroundId ?? this.backgroundId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquippedAvatar &&
          other.hatId == hatId &&
          other.shirtId == shirtId &&
          other.accessoryId == accessoryId &&
          other.backgroundId == backgroundId);

  @override
  int get hashCode => Object.hash(hatId, shirtId, accessoryId, backgroundId);
}
