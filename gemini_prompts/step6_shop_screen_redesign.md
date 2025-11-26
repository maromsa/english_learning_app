# Gemini 3 Pro Prompt - Step 6: Shop Screen Redesign

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. This step focuses on the **Shop Screen** - a gamification feature where children can spend coins to purchase items (characters, accessories, power-ups, etc.).

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Current Shop Screen Code

The complete ShopScreen implementation is in `lib/screens/shop_screen.dart`. Key parts:

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  final shopProvider = Provider.of<ShopProvider>(context, listen: false);
  final coinProvider = Provider.of<CoinProvider>(context, listen: false);
  final filteredProducts = _selectedCategory == null
      ? shopProvider.products
      : shopProvider.getProductsByCategory(_selectedCategory!);
  return _buildShopContent(context, shopProvider, coinProvider, filteredProducts);
}
```

### Shop Content Structure
```dart
Widget _buildShopContent(...) {
  return Scaffold(
    body: Stack(
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade300, Colors.blue.shade300, Colors.pink.shade300],
            ),
          ),
        ),
        // Confetti
        ConfettiWidget(...),
        SafeArea(
          child: Column(
            children: [
              // Header with title and coin display
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    Expanded(child: Text('🏪 חנות הקסמים', ...)),
                    Consumer<CoinProvider>(
                      builder: (context, coinProvider, child) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.white, size: 24),
                              Text('${coinProvider.coins}', ...),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Category Tabs (horizontal scrollable)
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: shopProvider.categories.length + 1,
                  itemBuilder: (context, index) {
                    // FilterChip for "הכל" (All) and each category
                  },
                ),
              ),
              // Products Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    return _ProductCard(
                      product: products[index],
                      isPurchased: shopProvider.isPurchased(product.id),
                      canBuy: coinProvider.coins >= product.price,
                      onTap: () => _showProductDetails(context, product),
                      onPurchase: () => _purchaseProduct(product),
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
```

### Product Card Widget
```dart
class _ProductCard extends StatefulWidget {
  final Product product;
  final bool isPurchased;
  final bool canBuy;
  final VoidCallback onTap;
  final VoidCallback onPurchase;
}

class _ProductCardState extends State<_ProductCard> with SingleTickerProviderStateMixin {
  // Has scale animation on tap
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.product.rarityColor.withValues(alpha: 0.8),
                widget.product.rarityColor.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [...],
          ),
          child: Column(
            children: [
              // Product Image (Expanded flex: 3)
              Expanded(
                flex: 3,
                child: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Image.asset(widget.product.assetImagePath, fit: BoxFit.cover),
                ),
              ),
              // Product Info (Expanded flex: 2)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Name and Rarity
                      Text(widget.product.name, ...),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(widget.product.rarityName, ...),
                      ),
                      // Price and Buy Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.white, size: 16),
                              Text('${widget.product.price}', ...),
                            ],
                          ),
                          if (widget.isPurchased)
                            Icon(Icons.check_circle, color: Colors.green, size: 20)
                          else
                            GestureDetector(
                              onTap: widget.canBuy ? widget.onPurchase : null,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.canBuy ? Colors.amber : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('קנה', ...),
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
```

### Product Details Dialog
```dart
void _showProductDetails(BuildContext context, Product product) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              product.rarityColor.withValues(alpha: 0.9),
              product.rarityColor.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product Image (Hero widget)
            Hero(
              tag: product.id,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(...),
                child: Image.asset(product.assetImagePath, fit: BoxFit.cover),
              ),
            ),
            // Product Name (Hebrew and English)
            Text(product.name, ...),
            Text(product.englishName, ...),
            // Rarity Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: product.rarityColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(product.rarityName, ...),
            ),
            // Description
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(product.description, ...),
            ),
            // Special Effect (if exists)
            if (product.specialEffect != null) ...[
              Row(
                children: [
                  Icon(Icons.star, color: Colors.yellow, size: 20),
                  Text(product.specialEffect!, ...),
                ],
              ),
            ],
            // Price
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.white),
                  Text('${product.price} מטבעות', ...),
                ],
              ),
            ),
            // Close Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('סגור', ...),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### Purchase Logic
```dart
Future<void> _purchaseProduct(Product product) async {
  final coinProvider = Provider.of<CoinProvider>(context, listen: false);
  final shopProvider = Provider.of<ShopProvider>(context, listen: false);
  
  if (coinProvider.coins >= product.price) {
    final success = await coinProvider.spendCoins(product.price);
    if (success) {
      await shopProvider.purchase(product.id);
      _confettiController.play();
      await _playPurchaseSound();
      // Show success SnackBar
    }
  } else {
    // Show error SnackBar: "אין לך מספיק מטבעות!"
  }
}
```

## Current Issues
1. **Basic Header** - Simple container with title and coin badge, could be more engaging
2. **Category Tabs** - Basic FilterChips, could be more visually appealing
3. **Product Cards** - Gradient cards are nice but could be more game-like
4. **Product Details Dialog** - Functional but could be more exciting
5. **Purchase Feedback** - Confetti and sound exist, but could be more celebratory
6. **No Empty States** - Doesn't handle empty categories well
7. **Limited Visual Hierarchy** - All products look similar, hard to distinguish rarity
8. **No Search/Filter** - Only category filtering, no search functionality

## Redesign Goals

### 1. Epic Shop Header
- Large, prominent header with shop theme
- Floating coin display with animation
- Better visual hierarchy
- Shop mascot or icon

### 2. Enhanced Category Navigation
- More engaging category chips/cards
- Visual icons for each category
- Smooth animations when switching
- Active category clearly highlighted

### 3. Gamified Product Cards
- More prominent rarity indicators
- Better visual distinction between rarities
- Animated "New" or "Popular" badges
- Clearer purchased state
- More engaging hover/tap effects

### 4. Improved Product Details
- Full-screen or bottom sheet modal
- Better product showcase
- More engaging purchase button
- Preview of product effects
- Social proof (if applicable)

### 5. Enhanced Purchase Experience
- More celebratory animations
- Better success feedback
- Purchase confirmation dialog
- Visual coin deduction animation

### 6. Better Empty States
- Friendly empty category messages
- Suggestions for earning more coins
- Visual illustrations

### 7. Visual Polish
- Better spacing and layout
- Smooth animations
- Loading states
- Error handling

## Design Requirements
- **Child-friendly**: Bright, colorful, playful, engaging
- **Accessible**: Large touch targets (min 48x48dp), clear contrast, readable text
- **RTL Support**: All layouts must work correctly in Hebrew
- **Performance**: Smooth 60fps animations, optimized rendering
- **Responsive**: Works on different screen sizes (phones, tablets)
- **Material 3**: Follow Material 3 design guidelines
- **Consistent**: Match the design language of other redesigned screens

## Your Task
Redesign the Shop Screen with:

### 1. Hero Shop Header
- Large, engaging header section
- Prominent coin display with pulsing animation
- Shop title with emoji/icon
- Back button integrated nicely
- Optional: Shop mascot or decorative elements

### 2. Enhanced Category Navigation
- Visual category cards/chips with icons
- Smooth scrollable horizontal list
- Active category with special styling
- Animation when switching categories
- "All" category as a special option

### 3. Gamified Product Grid
- Better product cards with:
  - Prominent rarity border/glow
  - Animated rarity indicator
  - Clear purchased badge/overlay
  - Better image display
  - Engaging buy button
  - Price clearly visible
- Grid layout optimized for different screen sizes
- Smooth card animations
- Loading states

### 4. Enhanced Product Details
- Full-screen modal or bottom sheet
- Large product image with zoom
- Clear rarity display
- Description in readable format
- Special effects highlighted
- Prominent purchase button
- Close button easily accessible

### 5. Purchase Flow
- Confirmation dialog (optional but recommended)
- Coin deduction animation
- Success celebration (enhanced confetti)
- Product unlock animation
- Success message with product preview

### 6. Empty States
- Friendly message when category is empty
- Illustration or icon
- Call-to-action to earn more coins

### 7. Visual Enhancements
- Better background (gradient or pattern)
- Smooth transitions
- Loading indicators
- Error handling with friendly messages

## Output Format
Provide:
1. Complete refactored `ShopScreen` widget code
2. Any new helper widgets/components needed (e.g., `_ShopHeader`, `_CategoryChip`, `_EnhancedProductCard`, `_ProductDetailsSheet`)
3. Brief explanation of design decisions
4. List of any new dependencies needed (if any)

## Code Style
- Use Material 3 components
- Follow Flutter best practices
- Use const constructors where possible
- Add meaningful comments
- Keep code readable and maintainable
- Preserve all existing functionality

## Important Notes
- **Preserve all functionality**: Purchase logic, category filtering, coin management, confetti, sound - all must work exactly as before
- **Keep widget properties**: Don't change the constructor parameters
- **Maintain state management**: Keep all existing state variables and providers
- **RTL Support**: Ensure all layouts work correctly in Hebrew (RTL)
- **Animations**: Use smooth, child-friendly animations
- **Error Handling**: Preserve all error handling and validation
- **Product Model**: The `Product` model has: `id`, `name`, `englishName`, `description`, `price`, `rarityColor`, `rarityName`, `assetImagePath`, `specialEffect` (optional), `category`

## Current Data Available
- `shopProvider.products` - List of all products
- `shopProvider.categories` - List of product categories
- `shopProvider.getProductsByCategory(category)` - Filter products by category
- `shopProvider.isPurchased(productId)` - Check if product is purchased
- `shopProvider.purchase(productId)` - Purchase a product
- `coinProvider.coins` - Current coin balance
- `coinProvider.spendCoins(amount)` - Spend coins
- `_selectedCategory` - Currently selected category (null = all)

## Design Inspiration
Think of:
- Mobile game shops (like Clash Royale, Brawl Stars)
- E-commerce apps for kids
- Collectible card game interfaces
- Treasure chest/prize opening animations
- Reward shops in educational games

Please provide the complete redesigned ShopScreen code.


