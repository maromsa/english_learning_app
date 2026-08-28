import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_learning_app/models/shop_item.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoinProvider cloud sync (Firebase users)', () {
    late FakeFirebaseFirestore firestore;
    late CoinProvider provider;

    const uid = 'firebase-user-1';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      provider = CoinProvider(
        userDataService: UserDataService(firestore: firestore),
      );
      provider.setUserId(uid);
    });

    Future<void> seedCloudCoins(int coins) {
      return firestore
          .collection('users')
          .doc(uid)
          .collection('gameData')
          .doc('player')
          .set({'userId': uid, 'coins': coins});
    }

    /// Seeds coins and purchasedItems in one write so neither field clobbers
    /// the other (unlike seedCloudCoins, this uses merge semantics).
    Future<void> seedCloudDoc({int coins = 0, List<String>? purchasedItems}) {
      return firestore
          .collection('users')
          .doc(uid)
          .collection('gameData')
          .doc('player')
          .set({
        'userId': uid,
        'coins': coins,
        if (purchasedItems != null) 'purchasedItems': purchasedItems,
      });
    }

    Future<DocumentSnapshot<Map<String, dynamic>>> cloudPlayerDoc() {
      return firestore
          .collection('users')
          .doc(uid)
          .collection('gameData')
          .doc('player')
          .get();
    }

    test('loadCoins reads the cloud balance so coins roam across devices',
        () async {
      await seedCloudCoins(120);

      await provider.loadCoins();

      expect(provider.coins, 120);
    });

    test('loadCoins falls back to local prefs when no cloud doc exists',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_${uid}_coins', 33);

      await provider.loadCoins();

      expect(provider.coins, 33);
    });

    test('addCoins persists the new balance to the cloud', () async {
      await seedCloudCoins(10);
      await provider.loadCoins();

      await provider.addCoins(15);

      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('gameData')
          .doc('player')
          .get();
      expect(doc.data()?['coins'], 25);
      expect(provider.coins, 25);
    });

    test('spendCoins enforces sufficient balance and syncs the result',
        () async {
      await seedCloudCoins(50);
      await provider.loadCoins();

      expect(await provider.spendCoins(60), isFalse);
      expect(provider.coins, 50);

      expect(await provider.spendCoins(20), isTrue);
      expect(provider.coins, 30);

      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('gameData')
          .doc('player')
          .get();
      expect(doc.data()?['coins'], 30);
    });

    group('shop item sync', () {
      const item = ShopItem(
        id: ShopItem.goldStickerFrameId,
        name: 'מסגרת זהב למדבקות',
        imageUrl: 'assets/images/words/gold_sticker_frame.png',
        cost: 100,
      );

      test('purchaseItem pushes the new ownership to the cloud', () async {
        await seedCloudDoc(coins: 200);
        await provider.loadCoins();

        final success = await provider.purchaseItem(item);

        expect(success, isTrue);
        expect(provider.isOwned(item.id), isTrue);

        final doc = await cloudPlayerDoc();
        expect(doc.data()?['purchasedItems'], contains(item.id));
      });

      test(
          'loadCoins merges a local-only purchase into an existing cloud doc',
          () async {
        await seedCloudDoc(coins: 0, purchasedItems: ['cloud_item']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'user_${uid}_owned_shop_items',
          ['local_item'],
        );

        await provider.loadCoins();

        // Neither side's purchase was lost.
        expect(provider.isOwned('cloud_item'), isTrue);
        expect(provider.isOwned('local_item'), isTrue);

        // The local-only item was pushed up, so a second device would see it.
        final doc = await cloudPlayerDoc();
        expect(
          doc.data()?['purchasedItems'],
          containsAll(['cloud_item', 'local_item']),
        );

        // And the merged set was written back locally too.
        expect(
          prefs.getStringList('user_${uid}_owned_shop_items'),
          containsAll(['cloud_item', 'local_item']),
        );
      });

      test(
          'loadCoins pulls an item purchased on another device into local state',
          () async {
        await seedCloudDoc(coins: 0, purchasedItems: ['other_device_item']);

        await provider.loadCoins();

        expect(provider.isOwned('other_device_item'), isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('user_${uid}_owned_shop_items'),
          contains('other_device_item'),
        );
      });
    });
  });
}
