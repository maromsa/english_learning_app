import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_provider.dart';
import '../models/product.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = Provider.of<ShopProvider>(context);
    final coins = 120; // לדוגמה בלבד, נחליף בעתיד ב־Provider אחר

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: Text('Coins: $coins')),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: shop.products.length,
        itemBuilder: (context, index) {
          final product = shop.products[index];
          final isPurchased = shop.isPurchased(product.id);
          final canBuy = shop.canBuy(coins, product.price);

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: Image.asset(product.assetImagePath, width: 50),
              title: Text(product.name),
              subtitle: Text('${product.price} coins'),
              trailing: isPurchased
                  ? const Icon(Icons.check, color: Colors.green)
                  : ElevatedButton(
                onPressed: canBuy
                    ? () {
                  final success = shop.purchase(product.id, coins);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Purchased ${product.name}')),
                    );
                  }
                }
                    : null,
                child: const Text('Buy'),
              ),
            ),
          );
        },
      ),
    );
  }
}
