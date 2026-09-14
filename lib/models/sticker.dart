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

  /// Default catalog offered in the Digital Sticker Album shop.
  ///
  /// Reuses existing Magic Shop art (`assets/images/words/`) rather than
  /// shipping new sticker-specific assets for this first cut.
  static const List<Sticker> defaultCatalog = [
    Sticker(
      id: 'sticker_magic_hat',
      name: 'כובע קסמים',
      assetPath: 'assets/images/words/magic_hat.png',
      cost: 30,
    ),
    Sticker(
      id: 'sticker_crystal_ball',
      name: 'כדור קריסטל',
      assetPath: 'assets/images/words/crystal_ball.png',
      cost: 40,
    ),
    Sticker(
      id: 'sticker_potion',
      name: 'שיקוי קסמים',
      assetPath: 'assets/images/words/potion.png',
      cost: 25,
    ),
    Sticker(
      id: 'sticker_magic_wand',
      name: 'שרביט קסמים',
      assetPath: 'assets/images/words/magic_wand.png',
      cost: 50,
    ),
    Sticker(
      id: 'sticker_spell_book',
      name: 'ספר קסמים',
      assetPath: 'assets/images/words/spell_book.png',
      cost: 60,
    ),
    Sticker(
      id: 'sticker_treasure_map',
      name: 'מפת אוצר',
      assetPath: 'assets/images/words/treasure_map.png',
      cost: 45,
    ),
    Sticker(
      id: 'sticker_magic_amulet',
      name: 'קמע קסום',
      assetPath: 'assets/images/words/magic_amulet.png',
      cost: 70,
    ),
    Sticker(
      id: 'sticker_flying_broom',
      name: 'מטאטא מעופף',
      assetPath: 'assets/images/words/flying_broom.png',
      cost: 80,
    ),
  ];

  /// Looks up a catalog sticker by id, or `null` if it isn't in
  /// [defaultCatalog].
  static Sticker? byId(String id) {
    for (final sticker in defaultCatalog) {
      if (sticker.id == id) return sticker;
    }
    return null;
  }
}
