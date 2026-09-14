import 'package:flutter/foundation.dart';

import '../models/sticker.dart';
import '../models/sticker_album.dart';
import '../services/sticker_album_service.dart';
import 'coin_provider.dart';

/// Reactive owner of the Digital Sticker Album: which stickers a child has
/// bought and where each one has been placed on the canvas.
///
/// Coins are never mutated here — [purchase] delegates the debit to
/// [CoinProvider], the single source of truth for the balance. Persistence
/// is per-child and local-only (see [StickerAlbumService]); cloud mirroring
/// is a follow-up, matching [ShopCustomizationProvider]'s v1.
class StickerAlbumProvider with ChangeNotifier {
  StickerAlbumProvider({StickerAlbumService? service})
      : _service = service ?? StickerAlbumService();

  final StickerAlbumService _service;

  String? _userId;
  bool _disposed = false;
  StickerAlbum _album = StickerAlbum.empty();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  StickerAlbum get album => _album;

  bool isOwned(String stickerId) => _album.isPurchased(stickerId);

  bool isPlaced(String stickerId) => _album.isPlaced(stickerId);

  StickerPlacement? placementOf(String stickerId) =>
      _album.placements[stickerId];

  /// Owned stickers that have not (or no longer) been placed on the canvas —
  /// what the inventory tray shows.
  List<Sticker> get unplacedStickers => Sticker.defaultCatalog
      .where((s) => _album.isPurchased(s.id) && !_album.isPlaced(s.id))
      .toList();

  /// Every sticker currently on the canvas, paired with its placement.
  List<(Sticker, StickerPlacement)> get placedStickers => [
        for (final placement in _album.placements.values)
          if (Sticker.byId(placement.stickerId) case final sticker?)
            (sticker, placement),
      ];

  /// Points persistence at [userId]'s namespace (guest when null).
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Loads the persisted album for the current profile. Best-effort: a read
  /// failure leaves the previous (or empty) album in place.
  Future<void> load() async {
    try {
      _album = await _service.load(_userId);
      _notify();
    } catch (e) {
      debugPrint('Error loading sticker album: $e');
    }
  }

  /// Buys [sticker] with coins from [coinProvider].
  ///
  /// Returns `true` if the child now owns the sticker (already-owned is a
  /// no-op success), `false` if they can't afford it or the debit failed.
  Future<bool> purchase(Sticker sticker, CoinProvider coinProvider) async {
    if (isOwned(sticker.id)) return true;
    if (coinProvider.coins < sticker.cost) return false;

    final paid = await coinProvider.spendCoins(sticker.cost);
    if (!paid) return false;

    _album = _album.purchase(sticker.id);
    await _service.save(_userId, _album);
    _notify();
    return true;
  }

  /// Places an owned sticker on the canvas at normalized (0.0-1.0)
  /// coordinates [x]/[y], replacing any existing placement for it. A no-op
  /// if the sticker hasn't been purchased.
  Future<void> place(String stickerId,
      {required double x, required double y}) async {
    if (!_album.isPurchased(stickerId)) return;
    _album = _album.place(stickerId, x: x, y: y);
    await _service.save(_userId, _album);
    _notify();
  }

  /// Removes a sticker's placement from the canvas without revoking
  /// ownership — it goes back to the inventory tray.
  Future<void> removePlacement(String stickerId) async {
    if (!_album.isPlaced(stickerId)) return;
    _album = _album.removePlacement(stickerId);
    await _service.save(_userId, _album);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
