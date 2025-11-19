import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';
import '../models/product.dart';
import 'package:google_fonts/google_fonts.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with TickerProviderStateMixin {
  ProductCategory? _selectedCategory;
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    try {
      _confettiController = ConfettiController(
        duration: const Duration(seconds: 3),
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
      // Using a simple beep-like sound effect
      // You can replace this with an actual sound file if available
      await _audioPlayer.setAsset('assets/audio/startup_chime.wav');
      await _audioPlayer.setVolume(0.3);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing purchase sound: $e');
      // Don't crash if sound fails
    }
  }

  void _showProductDetails(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                product.rarityColor.withValues(alpha: 0.9),
                product.rarityColor.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: product.rarityColor.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product Image
              Hero(
                tag: product.id,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      product.assetImagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error loading image ${product.assetImagePath}: $error');
                        return const Icon(Icons.image, size: 80);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Product Name
              Text(
                product.name,
                style: GoogleFonts.assistant(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                product.englishName,
                style: GoogleFonts.assistant(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Rarity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: product.rarityColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  product.rarityName,
                  style: GoogleFonts.assistant(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  product.description,
                  style: GoogleFonts.assistant(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (product.specialEffect != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.yellow, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      product.specialEffect!,
                      style: GoogleFonts.assistant(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow.shade100,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // Price
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '${product.price} מטבעות',
                      style: GoogleFonts.assistant(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Close Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'סגור',
                  style: GoogleFonts.assistant(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

  Future<void> _purchaseProduct(Product product) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    if (coinProvider.coins >= product.price) {
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🎉 קנית את ${product.name}!',
                      style: GoogleFonts.assistant(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
                                      backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
                                    ),
                                  );
        }
                                }
                              } else {
      if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'אין לך מספיק מטבעות!',
                    style: GoogleFonts.assistant(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
                                      backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
                                    ),
                                  );
                                }
                              }
                            }

  @override
  Widget build(BuildContext context) {
    try {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final coinProvider = Provider.of<CoinProvider>(context, listen: false);

      final filteredProducts = _selectedCategory == null
          ? shopProvider.products
          : shopProvider.getProductsByCategory(_selectedCategory!);

      return _buildShopContent(context, shopProvider, coinProvider, filteredProducts);
    } catch (e, stackTrace) {
      debugPrint('Error building shop screen: $e');
      debugPrint('Stack trace: $stackTrace');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'שגיאה בטעינת החנות',
                style: GoogleFonts.assistant(fontSize: 18),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('חזור'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildShopContent(BuildContext context, ShopProvider shopProvider, CoinProvider coinProvider, List<Product> filteredProducts) {
    // Recalculate filtered products based on current selection
    final currentFilteredProducts = _selectedCategory == null
        ? shopProvider.products
        : shopProvider.getProductsByCategory(_selectedCategory!);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade300,
                  Colors.blue.shade300,
                  Colors.pink.shade300,
                ],
              ),
            ),
          ),
          // Confetti
          if (_isInitialized)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          '🏪 חנות הקסמים',
                          style: GoogleFonts.assistant(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Consumer<CoinProvider>(
                        builder: (context, coinProvider, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '${coinProvider.coins}',
                                  style: GoogleFonts.assistant(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Category Tabs
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: shopProvider.categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: const Text('הכל'),
                            selected: _selectedCategory == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                            selectedColor: Colors.white,
                            checkmarkColor: Colors.purple,
                            labelStyle: GoogleFonts.assistant(
                              fontWeight: FontWeight.bold,
                              color: _selectedCategory == null
                                  ? Colors.purple
                                  : Colors.black87,
                            ),
                          ),
                        );
                      }
                      final category =
                          shopProvider.categories[index - 1];
                      final categoryProducts =
                          shopProvider.getProductsByCategory(category);
                      if (categoryProducts.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(category.categoryName),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                          selectedColor: Colors.white,
                          checkmarkColor: Colors.purple,
                          labelStyle: GoogleFonts.assistant(
                            fontWeight: FontWeight.bold,
                            color: _selectedCategory == category
                                ? Colors.purple
                                : Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Products Grid
                Expanded(
                  child: currentFilteredProducts.isEmpty
                      ? Center(
                          child: Text(
                            'אין מוצרים בקטגוריה זו',
                            style: GoogleFonts.assistant(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Consumer2<ShopProvider, CoinProvider>(
                          builder: (context, shopProvider, coinProvider, child) {
                            // Recalculate filtered products inside Consumer to ensure latest data
                            final products = _selectedCategory == null
                                ? shopProvider.products
                                : shopProvider.getProductsByCategory(_selectedCategory!);
                            
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final isPurchased =
                                    shopProvider.isPurchased(product.id);
                                final canBuy = coinProvider.coins >= product.price;

                                return _ProductCard(
                                  product: product,
                                  isPurchased: isPurchased,
                                  canBuy: canBuy,
                                  onTap: () => _showProductDetails(context, product),
                                  onPurchase: () => _purchaseProduct(product),
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

class _ProductCard extends StatefulWidget {
  final Product product;
  final bool isPurchased;
  final bool canBuy;
  final VoidCallback onTap;
  final VoidCallback onPurchase;

  const _ProductCard({
    required this.product,
    required this.isPurchased,
    required this.canBuy,
    required this.onTap,
    required this.onPurchase,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.product.rarityColor.withValues(alpha: 0.8),
                widget.product.rarityColor.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.product.rarityColor.withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      widget.product.assetImagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image, size: 50);
                      },
                    ),
                  ),
                ),
              ),
              // Product Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name and Rarity
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: GoogleFonts.assistant(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.product.rarityName,
                              style: GoogleFonts.assistant(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Price and Buy Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.product.price}',
                                style: GoogleFonts.assistant(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (widget.isPurchased)
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 20)
                          else
                            GestureDetector(
                              onTap: widget.canBuy ? widget.onPurchase : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.canBuy
                                      ? Colors.amber
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'קנה',
                                  style: GoogleFonts.assistant(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
