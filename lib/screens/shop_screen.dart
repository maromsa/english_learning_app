import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customization_item.dart';
import '../models/shop_item.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_customization_provider.dart';
import '../services/streak_shield_service.dart';
import '../utils/app_theme.dart';
import '../widgets/ui/_barrel.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  ShopItemType? _selectedType;
  bool _isPurchasing = false;

  Future<void> _handlePurchase(ShopItem item) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    if (coinProvider.isOwned(item.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} כבר בבעלותך!'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (coinProvider.coins < item.cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(SparkStrings.shopNotEnoughCoins),
            backgroundColor: AppTheme.primaryOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isPurchasing = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final success = await coinProvider.purchaseItem(item);
    if (!mounted) return;

    setState(() => _isPurchasing = false);

    if (success) {
      await Celebration.fire(context, tier: CelebrationTier.small);
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(item);
    }
  }

  void _showSuccessDialog(ShopItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PurchaseSuccessDialog(item: item),
    );
  }

  Future<void> _handleCustomizationBuy(CustomizationItem item) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final customization =
        Provider.of<ShopCustomizationProvider>(context, listen: false);

    if (coinProvider.coins < item.cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(SparkStrings.shopNotEnoughCoins),
            backgroundColor: AppTheme.primaryOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isPurchasing = true);
    final success = await customization.buy(item, coinProvider);
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (success) {
      await Celebration.fire(context, tier: CelebrationTier.small);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} נרכש והופעל!'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCustomizationEquip(CustomizationItem item) async {
    final customization =
        Provider.of<ShopCustomizationProvider>(context, listen: false);
    await customization.equip(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} הופעל!'),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showItemDetailsSheet(BuildContext context, ShopItem item) {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final isOwned = coinProvider.isOwned(item.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemDetailsSheet(
        item: item,
        isOwned: isOwned,
        onPurchase: () => _handlePurchase(item),
      ),
    );
  }

  List<ShopItem> _filteredItems() {
    final list = ShopItem.defaultCatalog;
    if (_selectedType == null) return list;
    return list.where((e) => e.type == _selectedType!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final coinProvider = Provider.of<CoinProvider>(context);
    // Depend on the shield service too: buying or consuming "מגן רצף" flips
    // coinProvider.isOwned(streakShieldId), and its card must re-render.
    context.watch<StreakShieldService>();
    final items = _filteredItems();

    return Scaffold(
      body: Stack(
        children: [
          // Whimsical background
          const _WhimsicalBackground(),

          SafeArea(
            child: Column(
              children: [
                _ShopHeader(
                  coinCount: coinProvider.coins,
                  isPurchasing: _isPurchasing,
                  onBack: () => Navigator.pop(context),
                ),

                // Category chips (stickers / upgrades)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _TypeChip(
                        label: 'הכל',
                        icon: Icons.grid_view_rounded,
                        isSelected: _selectedType == null,
                        onTap: () => setState(() => _selectedType = null),
                      ),
                      const SizedBox(width: 10),
                      _TypeChip(
                        label: 'סטיקרים',
                        icon: Icons.emoji_emotions_outlined,
                        isSelected: _selectedType == ShopItemType.sticker,
                        onTap: () => setState(
                          () => _selectedType = ShopItemType.sticker,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TypeChip(
                        label: 'שדרוגים',
                        icon: Icons.bolt,
                        isSelected: _selectedType == ShopItemType.upgrade,
                        onTap: () => setState(
                          () => _selectedType = ShopItemType.upgrade,
                        ),
                      ),
                    ],
                  ),
                ),

                _CustomizationSection(
                  isPurchasing: _isPurchasing,
                  onBuy: _handleCustomizationBuy,
                  onEquip: _handleCustomizationEquip,
                ),

                Expanded(
                  child: items.isEmpty
                      ? _EmptyState(selectedType: _selectedType)
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isOwned = coinProvider.isOwned(item.id);
                            final canBuy = coinProvider.coins >= item.cost;

                            return _ShopItemCard(
                              item: item,
                              isOwned: isOwned,
                              canBuy: canBuy,
                              onTap: () => _showItemDetailsSheet(context, item),
                            );
                          },
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
// Header
// ---------------------------------------------------------------------------

class _ShopHeader extends StatelessWidget {
  final int coinCount;
  final bool isPurchasing;
  final VoidCallback onBack;

  const _ShopHeader({
    required this.coinCount,
    required this.isPurchasing,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'חנות הקסמים',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                Text(
                  'סטickers ושדרוגים מגניבים!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryPurple.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD93D), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isPurchasing ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
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
// Type filter chips
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? AppTheme.primaryPurple : Colors.grey)
                  .withValues(alpha: isSelected ? 0.4 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurple : Colors.grey.shade300,
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid card
// ---------------------------------------------------------------------------

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final bool isOwned;
  final bool canBuy;
  final VoidCallback onTap;

  const _ShopItemCard({
    required this.item,
    required this.isOwned,
    required this.canBuy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = item.type == ShopItemType.upgrade
        ? AppTheme.primaryPurple
        : AppTheme.primaryGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isOwned
                ? Colors.grey.shade300
                : accentColor.withValues(alpha: 0.6),
            width: isOwned ? 1 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Image.asset(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      // Decode hint: grid thumbnails render well under
                      // ~150 logical px — cap decode cost regardless of
                      // how large the source art file actually is.
                      cacheWidth: 240,
                      cacheHeight: 240,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: Icon(
                          item.type == ShopItemType.upgrade
                              ? Icons.bolt
                              : Icons.emoji_emotions,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  if (isOwned)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOwned
                            ? Colors.grey.shade100
                            : (canBuy
                                ? Colors.amber.shade100
                                : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 14,
                            color:
                                isOwned ? Colors.grey : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOwned ? 'בבעלותך' : '${item.cost}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isOwned ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet: item details
// ---------------------------------------------------------------------------

class _ItemDetailsSheet extends StatelessWidget {
  final ShopItem item;
  final bool isOwned;
  final VoidCallback onPurchase;

  const _ItemDetailsSheet({
    required this.item,
    required this.isOwned,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = item.type == ShopItemType.upgrade
        ? AppTheme.primaryPurple
        : AppTheme.primaryGreen;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.asset(
                item.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 280,
                cacheHeight: 280,
                errorBuilder: (_, __, ___) => Icon(
                  item.type == ShopItemType.upgrade ? Icons.bolt : Icons.star,
                  size: 56,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFB8860B)),
                const SizedBox(width: 6),
                Text(
                  '${item.cost} מטבעות',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          isOwned
              ? OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('כבר בבעלותך'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              : KidButton.success(
                  label: 'קנה עכשיו - ${item.cost}',
                  onPressed: onPurchase,
                  leadingIcon: Icons.shopping_bag_outlined,
                  fullWidth: true,
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final ShopItemType? selectedType;

  const _EmptyState({this.selectedType});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'אין פריטים בקטגוריה הזו',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'נסה קטגוריה אחרת!',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success dialog
// ---------------------------------------------------------------------------

class _PurchaseSuccessDialog extends StatelessWidget {
  final ShopItem item;

  const _PurchaseSuccessDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryYellow, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 64,
              color: AppTheme.primaryYellow,
            ),
            const SizedBox(height: 16),
            const Text(
              'תתחדש! 🎉',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'רכשת בהצלחה את ${item.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                item.imageUrl,
                height: 90,
                width: 90,
                fit: BoxFit.cover,
                cacheWidth: 180,
                cacheHeight: 180,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            KidButton.primary(
              label: 'איזה כיף!',
              onPressed: () => Navigator.pop(context),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Themes & Sounds customization
// ---------------------------------------------------------------------------

class _CustomizationSection extends StatelessWidget {
  final bool isPurchasing;
  final Future<void> Function(CustomizationItem) onBuy;
  final Future<void> Function(CustomizationItem) onEquip;

  const _CustomizationSection({
    required this.isPurchasing,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<CoinProvider>().coins;
    final customization = context.watch<ShopCustomizationProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_rounded, color: AppTheme.primaryPurple),
              SizedBox(width: 8),
              Text(
                'ערכות נושא וסאונד',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CustomizationItem.catalog.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = CustomizationItem.catalog[index];
                return _CustomizationCard(
                  item: item,
                  isOwned: customization.isOwned(item),
                  isEquipped: customization.isEquipped(item),
                  canAfford: coins >= item.cost,
                  isBusy: isPurchasing,
                  onBuy: () => onBuy(item),
                  onEquip: () => onEquip(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizationCard extends StatelessWidget {
  final CustomizationItem item;
  final bool isOwned;
  final bool isEquipped;
  final bool canAfford;
  final bool isBusy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _CustomizationCard({
    required this.item,
    required this.isOwned,
    required this.isEquipped,
    required this.canAfford,
    required this.isBusy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.kind == CustomizationKind.theme
        ? AppTheme.primaryPurple
        : AppTheme.primaryOrange;

    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEquipped ? accent : Colors.grey.shade300,
          width: isEquipped ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(item.icon, color: accent, size: 28),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            item.kind == CustomizationKind.theme ? 'ערכת נושא' : 'סאונד ניצחון',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          _buildActionButton(accent),
        ],
      ),
    );
  }

  Widget _buildActionButton(Color accent) {
    if (isEquipped) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 15, color: accent),
            const SizedBox(width: 4),
            Text(
              'פעיל',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: accent,
              ),
            ),
          ],
        ),
      );
    }

    if (isOwned) {
      return _MiniButton(
        label: 'הפעל',
        color: accent,
        onPressed: isBusy ? null : onEquip,
      );
    }

    return _MiniButton(
      label: 'קנה · ${item.cost}',
      color: canAfford ? AppTheme.primaryGreen : Colors.grey,
      onPressed: (isBusy || !canAfford) ? null : onBuy,
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _MiniButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? Colors.grey.shade300 : color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------

class _WhimsicalBackground extends StatelessWidget {
  const _WhimsicalBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5F0FF),
            Color(0xFFEDE7F6),
            Color(0xFFE8E0F0),
          ],
        ),
      ),
      child: Opacity(
        opacity: 0.06,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
          ),
          itemCount: 48,
          itemBuilder: (context, index) {
            final icons = [
              Icons.star_rounded,
              Icons.auto_awesome,
              Icons.emoji_emotions,
            ];
            return Icon(icons[index % 3], size: 36, color: Colors.purple);
          },
        ),
      ),
    );
  }
}
