import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = Provider.of<ShopProvider>(context);
    final coinProvider = Provider.of<CoinProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: Text('מטבעות: ${coinProvider.coins}')),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: shop.products.length,
        itemBuilder: (context, index) {
          final product = shop.products[index];
          final isPurchased = shop.isPurchased(product.id);
          final canBuy = coinProvider.coins >= product.price;

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: Image.asset(product.assetImagePath, width: 50),
              title: Text(product.name),
              subtitle: Text('${product.price} coins'),
              trailing: isPurchased
                  ? const Icon(Icons.check, color: Colors.green)
                     : ElevatedButton(
                      onPressed: canBuy && !isPurchased
                          ? () async {
                        // Attempt to spend the coins first
                        final success = await coinProvider.spendCoins(product.price);

                        if (success) {
                          // If spending was successful, mark the item as purchased
                          await shop.purchase(product.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('קנית את ${product.name}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('אין לך מספיק מטבעות'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: const Text('קנה'),
              ),
            ),
          );
        },
      ),
    );
  }
}
