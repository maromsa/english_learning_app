import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';

import '../models/shop_item.dart';
import '../providers/coin_provider.dart';
import '../utils/app_theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  ShopItemType? _selectedType;
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _confettiInitialized = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    try {
      _confettiController = ConfettiController(
        duration: const Duration(seconds: 2),
      );
      _confettiInitialized = true;
    } catch (e) {
      debugPrint('Error initializing confetti: $e');
    }
  }

  @override
  void dispose() {
    if (_confettiInitialized) {
      _confettiController.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPurchaseSound() async {
    try {
      await _audioPlayer.setAsset('assets/audio/startup_chime.wav');
      await _audioPlayer.setVolume(0.3);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing purchase sound: $e');
    }
  }

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
          SnackBar(
            content: const Text('אופס! אין מספיק מטבעות 🪙'),
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
      if (_confettiInitialized) {
        try {
          _confettiController.play();
        } catch (e) {
          debugPrint('Error playing confetti: $e');
        }
      }
      await _playPurchaseSound();
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
    final items = _filteredItems();

    return Scaffold(
      body: Stack(
        children: [
          // Whimsical background
          const _WhimsicalBackground(),

          if (_confettiInitialized)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: math.pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [
                  Color(0xFF50C878),
                  Color(0xFF4A90E2),
                  Color(0xFFFFD93D),
                  Color(0xFFFF6B6B),
                  Color(0xFF7B68EE),
                ],
              ),
            ),

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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        onTap: () =>
                            setState(() => _selectedType = ShopItemType.sticker),
                      ),
                      const SizedBox(width: 10),
                      _TypeChip(
                        label: 'שדרוגים',
                        icon: Icons.bolt,
                        isSelected: _selectedType == ShopItemType.upgrade,
                        onTap: () =>
                            setState(() => _selectedType = ShopItemType.upgrade),
                      ),
                    ],
                  ),
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
                              onTap: () =>
                                  _showItemDetailsSheet(context, item),
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
                Text(
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
                            color: isOwned
                                ? Colors.grey
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOwned ? 'בבעלותך' : '${item.cost}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isOwned
                                  ? Colors.grey
                                  : Colors.black87,
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: isOwned
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
                : FilledButton.icon(
                    onPressed: onPurchase,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text('קנה עכשיו - ${item.cost}'),
                  ),
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
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('איזה כיף!'),
            ),
          ],
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
