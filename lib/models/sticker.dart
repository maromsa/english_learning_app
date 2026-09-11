// lib/models/sticker.dart

/// A single collectible sticker offered in the Digital Sticker Album shop.
///
/// Deserialization is tolerant (§2.3): a document written before a field
/// existed must still parse — unknown / missing keys default rather than
/// throw.
class Sticker {
  const Sticker({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.cost,
  });

  final String id;
  final String name;
  final String assetPath;
  final int cost;

  factory Sticker.fromJson(Map<String, dynamic> json) {
    return Sticker(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      assetPath: (json['assetPath'] as String?) ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assetPath': assetPath,
        'cost': cost,
      };

  Sticker copyWith({
    String? id,
    String? name,
    String? assetPath,
    int? cost,
  }) {
    return Sticker(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      cost: cost ?? this.cost,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sticker &&
          other.id == id &&
          other.name == name &&
          other.assetPath == assetPath &&
          other.cost == cost);

  @override
  int get hashCode => Object.hash(id, name, assetPath, cost);
}
