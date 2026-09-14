import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sticker.dart';
import '../models/sticker_album.dart';
import '../providers/coin_provider.dart';
import '../providers/sticker_album_provider.dart';
import '../utils/app_theme.dart';

/// Digital Sticker Album: buy stickers with coins, then drag them from the
/// inventory tray onto the canvas to decorate it.
///
/// Placement coordinates are normalized (0.0-1.0) against the canvas size
/// (see [StickerPlacement]), so a layout survives a resize or a different
/// device's screen.
class StickerAlbumScreen extends StatefulWidget {
  const StickerAlbumScreen({super.key});

  @override
  State<StickerAlbumScreen> createState() => _StickerAlbumScreenState();
}

class _StickerAlbumScreenState extends State<StickerAlbumScreen> {
  static const GlobalKey _canvasKey = GlobalObjectKey('sticker_canvas');
  bool _isBusy = false;

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handlePurchase(Sticker sticker) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final album = Provider.of<StickerAlbumProvider>(context, listen: false);

    if (coinProvider.coins < sticker.cost) {
      _showSnack('אין מספיק מטבעות', color: AppTheme.primaryOrange);
      return;
    }

    setState(() => _isBusy = true);
    final success = await album.purchase(sticker, coinProvider);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (success) {
      _showSnack('${sticker.name} נוסף לאלבום!', color: AppTheme.primaryGreen);
    } else {
      _showSnack('הרכישה נכשלה, נסו שוב', color: AppTheme.primaryOrange);
    }
  }

  void _handleDrop(String stickerId, Offset globalPosition) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final local = box.globalToLocal(globalPosition);
    final x = (local.dx / box.size.width).clamp(0.0, 1.0);
    final y = (local.dy / box.size.height).clamp(0.0, 1.0);
    Provider.of<StickerAlbumProvider>(context, listen: false)
        .place(stickerId, x: x, y: y);
  }

  @override
  Widget build(BuildContext context) {
    final coinProvider = context.watch<CoinProvider>();
    final album = context.watch<StickerAlbumProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: Column(
          children: [
            _AlbumHeader(
              coinCount: coinProvider.coins,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _StickerCanvas(
                canvasKey: _canvasKey,
                placedStickers: album.placedStickers,
                onDrop: _handleDrop,
              ),
            ),
            _InventoryTray(
              unplacedStickers: album.unplacedStickers,
              shopStickers: Sticker.defaultCatalog
                  .where((s) => !album.isOwned(s.id))
                  .toList(),
              coins: coinProvider.coins,
              isBusy: _isBusy,
              onBuy: _handlePurchase,
              onRemove: (id) =>
                  Provider.of<StickerAlbumProvider>(context, listen: false)
                      .removePlacement(id),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.coinCount, required this.onBack});

  final int coinCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            elevation: 2,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'אלבום המדבקות',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD93D), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 6),
                Text(
                  '$coinCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Canvas
// ---------------------------------------------------------------------------

class _StickerCanvas extends StatelessWidget {
  const _StickerCanvas({
    required this.canvasKey,
    required this.placedStickers,
    required this.onDrop,
  });

  final GlobalKey canvasKey;
  final List<(Sticker, StickerPlacement)> placedStickers;
  final void Function(String stickerId, Offset globalPosition) onDrop;

  static const double _stickerSize = 64;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DragTarget<String>(
        onAcceptWithDetails: (details) => onDrop(details.data, details.offset),
        builder: (context, candidateData, rejectedData) {
          return Container(
            key: canvasKey,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: candidateData.isNotEmpty
                    ? AppTheme.primaryGreen
                    : Colors.grey.shade300,
                width: candidateData.isNotEmpty ? 3 : 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (placedStickers.isEmpty) {
                  return Center(
                    child: Text(
                      'גררו מדבקות לכאן',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                final canvasSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    for (final (sticker, placement) in placedStickers)
                      _PlacedSticker(
                        key: Key('placed_sticker_${sticker.id}'),
                        sticker: sticker,
                        placement: placement,
                        stickerSize: _stickerSize,
                        canvasSize: canvasSize,
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlacedSticker extends StatelessWidget {
  const _PlacedSticker({
    super.key,
    required this.sticker,
    required this.placement,
    required this.stickerSize,
    required this.canvasSize,
  });

  final Sticker sticker;
  final StickerPlacement placement;
  final double stickerSize;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final maxLeft =
        (canvasSize.width - stickerSize).clamp(0.0, double.infinity);
    final maxTop =
        (canvasSize.height - stickerSize).clamp(0.0, double.infinity);
    final left =
        (placement.x * canvasSize.width - stickerSize / 2).clamp(0.0, maxLeft);
    final top =
        (placement.y * canvasSize.height - stickerSize / 2).clamp(0.0, maxTop);
    return Positioned(
      left: left,
      top: top,
      child: Draggable<String>(
        data: sticker.id,
        feedback: _StickerThumb(sticker: sticker, size: stickerSize * 1.15),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _StickerThumb(sticker: sticker, size: stickerSize),
        ),
        child: _StickerThumb(sticker: sticker, size: stickerSize),
      ),
    );
  }
}

class _StickerThumb extends StatelessWidget {
  const _StickerThumb({required this.sticker, required this.size});

  final Sticker sticker;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      sticker.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * 2).round(),
      cacheHeight: (size * 2).round(),
      errorBuilder: (_, __, ___) => Icon(
        Icons.emoji_emotions,
        size: size,
        color: AppTheme.primaryPurple,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory tray
// ---------------------------------------------------------------------------

class _InventoryTray extends StatelessWidget {
  const _InventoryTray({
    required this.unplacedStickers,
    required this.shopStickers,
    required this.coins,
    required this.isBusy,
    required this.onBuy,
    required this.onRemove,
  });

  final List<Sticker> unplacedStickers;
  final List<Sticker> shopStickers;
  final int coins;
  final bool isBusy;
  final void Function(Sticker sticker) onBuy;
  final void Function(String stickerId) onRemove;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onRemove(details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          key: const Key('sticker_tray'),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? AppTheme.primaryOrange.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? AppTheme.primaryOrange
                  : Colors.grey.shade200,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'המדבקות שלי',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: unplacedStickers.isEmpty
                    ? Center(
                        child: Text(
                          'עדיין אין מדבקות בתיק',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: unplacedStickers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final sticker = unplacedStickers[index];
                          return Draggable<String>(
                            key: Key('sticker_tray_${sticker.id}'),
                            data: sticker.id,
                            feedback: _StickerThumb(sticker: sticker, size: 64),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _StickerThumb(sticker: sticker, size: 56),
                            ),
                            child: _StickerThumb(sticker: sticker, size: 56),
                          );
                        },
                      ),
              ),
              if (shopStickers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'לקנייה',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shopStickers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final sticker = shopStickers[index];
                      final canAfford = coins >= sticker.cost;
                      return _ShopStickerCard(
                        key: Key('buy_sticker_${sticker.id}'),
                        sticker: sticker,
                        canAfford: canAfford,
                        isBusy: isBusy,
                        onBuy: () => onBuy(sticker),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ShopStickerCard extends StatelessWidget {
  const _ShopStickerCard({
    super.key,
    required this.sticker,
    required this.canAfford,
    required this.isBusy,
    required this.onBuy,
  });

  final Sticker sticker;
  final bool canAfford;
  final bool isBusy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    // The whole card is the tap target (not just the price pill) — a bigger
    // hit area matches the app's kid-facing tap-target conventions.
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        // Stays tappable even when the child can't afford it yet — onBuy
        // surfaces the "not enough coins" feedback rather than the card
        // going silently inert (CLAUDE.md §2.2: every tap gets a response).
        onTap: isBusy ? null : onBuy,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StickerThumb(sticker: sticker, size: 36),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: (isBusy || !canAfford)
                      ? Colors.grey.shade300
                      : AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${sticker.cost}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
