// test/widgets/collection_item_card_test.dart
//
// Widget tests for CollectionItemCard's gold-frame cosmetic: mastered
// words the player owns the "מסגרת זהב למדבקות" (Gold Sticker Frame) for
// should render wrapped in a gold gradient frame; every other combination
// (not mastered, not owned) must fall back to the plain image, unchanged.

import 'package:english_learning_app/models/collection_word_item.dart';
import 'package:english_learning_app/models/shop_item.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:english_learning_app/widgets/collection_item_card.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

CollectionWordItem _word({required bool mastered}) {
  return CollectionWordItem(
    word: WordData(word: 'Apple', imageUrl: 'assets/images/words/apple.png'),
    levelId: 'level_fruits',
    mastery: WordMasteryEntry(masteryLevel: mastered ? 1.0 : 0.2),
    isCompleted: mastered,
  );
}

/// True if the tree contains a Container decorated with the exact gold
/// gradient _buildFramedImage applies (see collection_item_card.dart).
bool _hasGoldFrameDecoration(WidgetTester tester) {
  const goldGold = Color(0xFFFFD700);
  for (final element in tester.elementList(find.byType(Container))) {
    final widget = element.widget as Container;
    final decoration = widget.decoration;
    if (decoration is BoxDecoration &&
        decoration.gradient is LinearGradient &&
        (decoration.gradient! as LinearGradient).colors.contains(goldGold)) {
      return true;
    }
  }
  return false;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required bool mastered,
  required bool ownsGoldFrame,
}) async {
  SharedPreferences.setMockInitialValues({});
  final coinProvider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );
  if (ownsGoldFrame) {
    final goldFrame = ShopItem.defaultCatalog
        .firstWhere((item) => item.id == ShopItem.goldStickerFrameId);
    await coinProvider.setCoins(goldFrame.cost);
    await coinProvider.purchaseItem(goldFrame);
  }

  await tester.pumpWidget(
    ChangeNotifierProvider<CoinProvider>.value(
      value: coinProvider,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 200,
            child: CollectionItemCard(item: _word(mastered: mastered)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'renders the gold frame when the word is mastered and the frame is owned',
      (tester) async {
    await _pumpCard(tester, mastered: true, ownsGoldFrame: true);

    expect(_hasGoldFrameDecoration(tester), isTrue);
  });

  testWidgets('does not render the gold frame when the frame is not owned',
      (tester) async {
    await _pumpCard(tester, mastered: true, ownsGoldFrame: false);

    expect(_hasGoldFrameDecoration(tester), isFalse);
  });

  testWidgets(
      'does not render the gold frame on a locked word, even if it is owned',
      (tester) async {
    await _pumpCard(tester, mastered: false, ownsGoldFrame: true);

    expect(_hasGoldFrameDecoration(tester), isFalse);
    // Locked-state affordance is unaffected by owning the cosmetic.
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('mastered word still shows its three-star badge with the frame',
      (tester) async {
    await _pumpCard(tester, mastered: true, ownsGoldFrame: true);

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
  });
}
