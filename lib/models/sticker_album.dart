// lib/models/sticker_album.dart

/// Where a purchased sticker has been dropped on the album canvas.
///
/// [x] and [y] are normalized (0.0–1.0) canvas coordinates rather than raw
/// pixels, so a placement survives a resize or a different device's screen.
class StickerPlacement {
  const StickerPlacement({
    required this.stickerId,
    required this.x,
    required this.y,
  });

  final String stickerId;
  final double x;
  final double y;

  factory StickerPlacement.fromJson(Map<String, dynamic> json) {
    return StickerPlacement(
      stickerId: (json['stickerId'] as String?) ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'stickerId': stickerId,
        'x': x,
        'y': y,
      };

  StickerPlacement copyWith({String? stickerId, double? x, double? y}) {
    return StickerPlacement(
      stickerId: stickerId ?? this.stickerId,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StickerPlacement &&
          other.stickerId == stickerId &&
          other.x == x &&
          other.y == y);

  @override
  int get hashCode => Object.hash(stickerId, x, y);
}

/// A child's Digital Sticker Album: which stickers they own and where each
/// one has been placed on the canvas.
///
/// Ownership and placement are tracked separately — a purchased sticker
/// isn't placed until the child drags it onto the canvas — so [placements]
/// is always a subset of [purchasedStickerIds]. Deserialization is tolerant
/// (§2.3): a malformed or pre-existing document parses to an empty album
/// rather than throwing.
class StickerAlbum {
  StickerAlbum({
    Set<String>? purchasedStickerIds,
    Map<String, StickerPlacement>? placements,
  })  : purchasedStickerIds = purchasedStickerIds ?? const {},
        placements = placements ?? const {};

  factory StickerAlbum.empty() => StickerAlbum();

  factory StickerAlbum.fromJson(Map<String, dynamic> json) {
    final purchasedRaw = json['purchasedStickerIds'];
    final purchasedStickerIds = purchasedRaw is List
        ? purchasedRaw.whereType<String>().where((e) => e.isNotEmpty).toSet()
        : <String>{};

    final placementsRaw = json['placements'];
    final placements = <String, StickerPlacement>{};
    if (placementsRaw is List) {
      for (final entry in placementsRaw) {
        if (entry is! Map<String, dynamic> && entry is! Map) continue;
        final placement =
            StickerPlacement.fromJson(Map<String, dynamic>.from(entry as Map));
        if (placement.stickerId.isEmpty) continue;
        // A placement for a sticker the album doesn't (or no longer) own is
        // dropped rather than kept dangling.
        if (!purchasedStickerIds.contains(placement.stickerId)) continue;
        placements[placement.stickerId] = placement;
      }
    }

    return StickerAlbum(
      purchasedStickerIds: purchasedStickerIds,
      placements: placements,
    );
  }

  /// Ids of every sticker the child has purchased, whether placed or not.
  final Set<String> purchasedStickerIds;

  /// Placements keyed by sticker id — at most one placement per sticker.
  final Map<String, StickerPlacement> placements;

  bool isPurchased(String stickerId) => purchasedStickerIds.contains(stickerId);

  bool isPlaced(String stickerId) => placements.containsKey(stickerId);

  Map<String, dynamic> toJson() => {
        'purchasedStickerIds': purchasedStickerIds.toList(),
        'placements': placements.values.map((p) => p.toJson()).toList(),
      };

  /// Records a purchase. Idempotent — buying an already-owned sticker is a
  /// no-op.
  StickerAlbum purchase(String stickerId) {
    if (purchasedStickerIds.contains(stickerId)) return this;
    return copyWith(
      purchasedStickerIds: {...purchasedStickerIds, stickerId},
    );
  }

  /// Places an owned sticker on the canvas at normalized coordinates
  /// [x]/[y], replacing any existing placement for it. Placing a sticker
  /// that hasn't been purchased is a no-op — the album never gains a
  /// placement without ownership.
  StickerAlbum place(String stickerId, {required double x, required double y}) {
    if (!purchasedStickerIds.contains(stickerId)) return this;
    return copyWith(
      placements: {
        ...placements,
        stickerId: StickerPlacement(stickerId: stickerId, x: x, y: y),
      },
    );
  }

  /// Removes a sticker's placement from the canvas without revoking
  /// ownership — it goes back to the child's unplaced tray.
  StickerAlbum removePlacement(String stickerId) {
    if (!placements.containsKey(stickerId)) return this;
    final next = {...placements}..remove(stickerId);
    return copyWith(placements: next);
  }

  StickerAlbum copyWith({
    Set<String>? purchasedStickerIds,
    Map<String, StickerPlacement>? placements,
  }) {
    return StickerAlbum(
      purchasedStickerIds: purchasedStickerIds ?? this.purchasedStickerIds,
      placements: placements ?? this.placements,
    );
  }
}
