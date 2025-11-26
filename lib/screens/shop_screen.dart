import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';
import '../models/product.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  ProductCategory? _selectedCategory;
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isDeductingCoins = false;

  @override
  void initState() {
    super.initState();
    try {
      _confettiController = ConfettiController(
        duration: const Duration(seconds: 2),
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing confetti: $e');
      _isInitialized = false;
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
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
      // Don't crash if sound fails
    }
  }

  Future<void> _handlePurchase(Product product) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    if (coinProvider.coins >= product.price) {
      setState(() => _isDeductingCoins = true);

      // Simulate network/processing delay
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await coinProvider.spendCoins(product.price);
      if (success) {
        await shopProvider.purchase(product.id);
        if (_isInitialized) {
          try {
            _confettiController.play();
          } catch (e) {
            debugPrint('Error playing confetti: $e');
          }
        }
        await _playPurchaseSound();

        if (mounted) {
          setState(() => _isDeductingCoins = false);
          Navigator.pop(context); // Close sheet
          _showSuccessOverlay(product);
        }
      } else {
        if (mounted) {
          setState(() => _isDeductingCoins = false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("אופס! אין מספיק מטבעות"),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccessOverlay(Product product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PurchaseSuccessDialog(product: product),
    );
  }

  void _showProductDetailsSheet(BuildContext context, Product product) {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final isPurchased = shopProvider.isPurchased(product.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailsSheet(
        product: product,
        isPurchased: isPurchased,
        onPurchase: () => _handlePurchase(product),
      ),
    );
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.accessories:
        return Icons.checkroom;
      case ProductCategory.powerUps:
        return Icons.bolt;
      case ProductCategory.pets:
        return Icons.pets;
      case ProductCategory.magical:
        return Icons.auto_awesome;
      case ProductCategory.special:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final coinProvider = Provider.of<CoinProvider>(context);

    final filteredProducts = _selectedCategory == null
        ? shopProvider.products
        : shopProvider.getProductsByCategory(_selectedCategory!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF), // Light purple tint background
      body: Stack(
        children: [
          // 1. Background Elements
          const _BackgroundPattern(),

          // 2. Confetti Layer (Behind UI)
          if (_isInitialized)
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
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _ShopHeader(
                  coinCount: coinProvider.coins,
                  isDeducting: _isDeductingCoins,
                  onBack: () => Navigator.pop(context),
                ),

                // Categories
                Container(
                  height: 80,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _CategoryTab(
                        label: "הכל",
                        icon: Icons.grid_view_rounded,
                        isSelected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      ...shopProvider.categories.map((cat) {
                        final categoryProducts =
                            shopProvider.getProductsByCategory(cat);
                        if (categoryProducts.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _CategoryTab(
                          label: cat.categoryName,
                          icon: _getCategoryIcon(cat),
                          isSelected: _selectedCategory == cat,
                          onTap: () => setState(() => _selectedCategory = cat),
                        );
                      }),
                    ],
                  ),
                ),

                // Products Grid
                Expanded(
                  child: filteredProducts.isEmpty
                      ? _EmptyShopState(category: _selectedCategory)
                      : Consumer2<ShopProvider, CoinProvider>(
                          builder: (context, shopProvider, coinProvider, child) {
                            // Recalculate filtered products inside Consumer
                            final products = _selectedCategory == null
                                ? shopProvider.products
                                : shopProvider.getProductsByCategory(_selectedCategory!);

                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7, // Taller cards
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final isPurchased =
                                    shopProvider.isPurchased(product.id);

                                return _EnhancedProductCard(
                                  product: product,
                                  isPurchased: isPurchased,
                                  canBuy: coinProvider.coins >= product.price,
                                  onTap: () =>
                                      _showProductDetailsSheet(context, product),
                                );
                              },
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

// ----------------------------------------------------------------
// COMPONENT WIDGETS
// ----------------------------------------------------------------

class _ShopHeader extends StatelessWidget {
  final int coinCount;
  final bool isDeducting;
  final VoidCallback onBack;

  const _ShopHeader({
    required this.coinCount,
    required this.isDeducting,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
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
                  "חנות הקסמים",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
                Text(
                  "שדרגו את החוויה!",
                  style: TextStyle(fontSize: 14, color: Colors.purple.shade700),
                ),
              ],
            ),
          ),
          // Coin Wallet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade700.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              children: [
                AnimatedScale(
                  scale: isDeducting ? 1.3 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.monetization_on_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  '$coinCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                    fontFamily: 'Nunito',
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

class _CategoryTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
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
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                  )
                ],
          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey.shade600, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnhancedProductCard extends StatelessWidget {
  final Product product;
  final bool isPurchased;
  final bool canBuy;
  final VoidCallback onTap;

  const _EnhancedProductCard({
    required this.product,
    required this.isPurchased,
    required this.canBuy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: product.rarityColor.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isPurchased
                ? Colors.grey.shade300
                : product.rarityColor.withValues(alpha: 0.5),
            width: isPurchased ? 1 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Container(
                      color: Colors.grey.shade50,
                      width: double.infinity,
                      child: Image.asset(
                        product.assetImagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  if (isPurchased)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.white, size: 40),
                      ),
                    ),
                  if (!isPurchased && product.specialEffect != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Info Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.rarityName,
                          style: TextStyle(
                            color: product.rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPurchased
                            ? Colors.grey.shade100
                            : (canBuy
                                ? Colors.amber.shade100
                                : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 14,
                            color: isPurchased
                                ? Colors.grey
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPurchased ? "בבעלותך" : '${product.price}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isPurchased ? Colors.grey : Colors.black87,
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

class _ProductDetailsSheet extends StatelessWidget {
  final Product product;
  final bool isPurchased;
  final VoidCallback onPurchase;

  const _ProductDetailsSheet({
    required this.product,
    required this.isPurchased,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Hero Image
          Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: product.rarityColor, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Image.asset(
                product.assetImagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            product.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            product.englishName,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: product.rarityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: product.rarityColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  product.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                if (product.specialEffect != null) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        product.specialEffect!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: isPurchased
                ? OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text("כבר בבעלותך"),
                  )
                : FilledButton.icon(
                    onPressed: onPurchase,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF50C878), // Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      "קנה עכשיו - ${product.price}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _EmptyShopState extends StatelessWidget {
  final ProductCategory? category;
  const _EmptyShopState({this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "המדפים ריקים בקטגוריה זו",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "נסה לחפש בקטגוריה אחרת!",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _PurchaseSuccessDialog extends StatelessWidget {
  final Product product;

  const _PurchaseSuccessDialog({required this.product});

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
          border: Border.all(color: Colors.amber, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 60, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              "תתחדש!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "רכשת בהצלחה את ${product.name}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Image.asset(
              product.assetImagePath,
              height: 100,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                size: 80,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("איזה כיף!"),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundPattern extends StatelessWidget {
  const _BackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.05,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
        itemBuilder: (context, index) =>
            const Icon(Icons.star_rounded, size: 40),
      ),
    );
  }
}
