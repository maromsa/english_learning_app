// lib/models/avatar_item.dart

/// The customization slot an [AvatarItem] can be equipped into.
enum AvatarItemType { hat, shirt, accessory, background }

/// A single purchasable/equippable item for the Avatar Customization
/// feature.
///
/// Deserialization is tolerant (§2.3): a document written before a field
/// existed, or with an unrecognized [type] string, must still parse rather
/// than throw — unknown [type] values fall back to [AvatarItemType.hat].
class AvatarItem {
  const AvatarItem({
    required this.id,
    required this.name,
    required this.type,
    required this.assetPath,
    required this.cost,
  });

  final String id;
  final String name;
  final AvatarItemType type;
  final String assetPath;
  final int cost;

  factory AvatarItem.fromJson(Map<String, dynamic> json) {
    return AvatarItem(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      type: _typeFromString(json['type'] as String?),
      assetPath: (json['assetPath'] as String?) ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
    );
  }

  static AvatarItemType _typeFromString(String? raw) {
    if (raw == null) return AvatarItemType.hat;
    for (final value in AvatarItemType.values) {
      if (value.name == raw) return value;
    }
    // Unknown / future type — fall back rather than throw.
    return AvatarItemType.hat;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'assetPath': assetPath,
        'cost': cost,
      };

  AvatarItem copyWith({
    String? id,
    String? name,
    AvatarItemType? type,
    String? assetPath,
    int? cost,
  }) {
    return AvatarItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      assetPath: assetPath ?? this.assetPath,
      cost: cost ?? this.cost,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarItem &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          other.assetPath == assetPath &&
          other.cost == cost);

  @override
  int get hashCode => Object.hash(id, name, type, assetPath, cost);
}
