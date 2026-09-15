import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/avatar_catalog.dart';
import '../models/avatar_item.dart';
import '../providers/avatar_inventory_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/equipped_avatar_provider.dart';
import '../utils/aurora_tokens.dart';
import '../widgets/ui/glass_card.dart';

/// Avatar Customization screen: a preview of the currently equipped items on
/// top, and a store/inventory grid below.
///
/// Tapping a tile equips it if already owned; if not owned, it attempts a
/// purchase via [AvatarInventoryProvider.purchaseItem] (debiting
/// [CoinProvider]) and equips it on success, or shows a SnackBar if the
/// child can't afford it.
class AvatarCustomizationScreen extends StatelessWidget {
  const AvatarCustomizationScreen({
    super.key,
    List<AvatarItem>? catalog,
  }) : _catalog = catalog ?? AvatarCatalog.items;

  final List<AvatarItem> _catalog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'התאמת דמות',
          style: GoogleFonts.baloo2(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AuroraTokens.ink,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E1), Color(0xFFF3E5F5), Color(0xFFE8F5E9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _AvatarPreview(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _AvatarStoreGrid(catalog: _catalog),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview
// ---------------------------------------------------------------------------

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview();

  @override
  Widget build(BuildContext context) {
    final equipped = context.watch<EquippedAvatarProvider>().equipped;

    return GlassCard(
      borderRadius: AuroraTokens.rXl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            'הדמות שלי',
            style: GoogleFonts.heebo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AuroraTokens.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PreviewSlot(
                type: AvatarItemType.hat,
                id: equipped.hatId,
                icon: Icons.checkroom_rounded,
              ),
              _PreviewSlot(
                type: AvatarItemType.shirt,
                id: equipped.shirtId,
                icon: Icons.dry_cleaning_rounded,
              ),
              _PreviewSlot(
                type: AvatarItemType.accessory,
                id: equipped.accessoryId,
                icon: Icons.face_retouching_natural_rounded,
              ),
              _PreviewSlot(
                type: AvatarItemType.background,
                id: equipped.backgroundId,
                icon: Icons.landscape_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSlot extends StatelessWidget {
  const _PreviewSlot({
    required this.type,
    required this.id,
    required this.icon,
  });

  final AvatarItemType type;
  final String? id;
  final IconData icon;

  static const Map<AvatarItemType, String> _labels = {
    AvatarItemType.hat: 'כובע',
    AvatarItemType.shirt: 'חולצה',
    AvatarItemType.accessory: 'אביזר',
    AvatarItemType.background: 'רקע',
  };

  bool get _isEmpty => id == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isEmpty
                ? Colors.grey.shade200
                : AuroraTokens.plum.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AuroraTokens.rMd),
            border: Border.all(
              color: _isEmpty ? Colors.grey.shade300 : AuroraTokens.plum,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 26,
            color: _isEmpty ? Colors.grey.shade400 : AuroraTokens.plum,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _labels[type]!,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Store / inventory grid
// ---------------------------------------------------------------------------

class _AvatarStoreGrid extends StatelessWidget {
  const _AvatarStoreGrid({required this.catalog});

  final List<AvatarItem> catalog;

  @override
  Widget build(BuildContext context) {
    final equippedProvider = context.watch<EquippedAvatarProvider>();
    final inventoryProvider = context.watch<AvatarInventoryProvider>();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: catalog.length,
      itemBuilder: (context, index) {
        final item = catalog[index];
        final isEquipped = _isEquipped(equippedProvider, item);
        final isOwned = inventoryProvider.isOwned(item);
        return _AvatarStoreTile(
          item: item,
          isEquipped: isEquipped,
          isOwned: isOwned,
          onTap: () => unawaited(_handleTap(
            context: context,
            item: item,
            isEquipped: isEquipped,
            isOwned: isOwned,
          )),
        );
      },
    );
  }

  bool _isEquipped(EquippedAvatarProvider provider, AvatarItem item) {
    final equipped = provider.equipped;
    return switch (item.type) {
      AvatarItemType.hat => equipped.hatId == item.id,
      AvatarItemType.shirt => equipped.shirtId == item.id,
      AvatarItemType.accessory => equipped.accessoryId == item.id,
      AvatarItemType.background => equipped.backgroundId == item.id,
    };
  }

  /// If [item] is owned, equips/unequips it. If not, attempts to purchase
  /// it with coins and equips it on success; otherwise shows a SnackBar
  /// telling the child they don't have enough coins.
  Future<void> _handleTap({
    required BuildContext context,
    required AvatarItem item,
    required bool isEquipped,
    required bool isOwned,
  }) async {
    final equippedProvider =
        Provider.of<EquippedAvatarProvider>(context, listen: false);

    if (isOwned) {
      await (isEquipped
          ? equippedProvider.unequipItem(item.type)
          : equippedProvider.equipItem(item));
      return;
    }

    final inventoryProvider =
        Provider.of<AvatarInventoryProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    final purchased = await inventoryProvider.purchaseItem(item, coinProvider);

    if (!context.mounted) return;

    if (purchased) {
      await equippedProvider.equipItem(item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('אין לך מספיק מטבעות (${item.cost} 🪙)'),
        ),
      );
    }
  }
}

class _AvatarStoreTile extends StatelessWidget {
  const _AvatarStoreTile({
    required this.item,
    required this.isEquipped,
    required this.isOwned,
    required this.onTap,
  });

  final AvatarItem item;
  final bool isEquipped;
  final bool isOwned;
  final VoidCallback onTap;

  static const Map<AvatarItemType, IconData> _icons = {
    AvatarItemType.hat: Icons.checkroom_rounded,
    AvatarItemType.shirt: Icons.dry_cleaning_rounded,
    AvatarItemType.accessory: Icons.face_retouching_natural_rounded,
    AvatarItemType.background: Icons.landscape_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AuroraTokens.rLg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AuroraTokens.rLg),
            border: Border.all(
              color: isEquipped ? AuroraTokens.mint : Colors.grey.shade200,
              width: isEquipped ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    _icons[item.type],
                    size: 30,
                    color: !isOwned
                        ? Colors.grey.shade400
                        : (isEquipped ? AuroraTokens.mint : AuroraTokens.plum),
                  ),
                  if (!isOwned)
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.heebo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isOwned ? AuroraTokens.ink : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              if (isEquipped)
                const Icon(Icons.check_circle,
                    size: 16, color: AuroraTokens.mint)
              else
                Text(
                  '${item.cost} 🪙',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
