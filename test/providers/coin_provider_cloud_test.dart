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
  });
}
