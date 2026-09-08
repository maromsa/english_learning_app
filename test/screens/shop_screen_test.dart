// test/screens/shop_screen_test.dart
//
// Widget tests for ShopScreen: renders the catalog, shows the live coin
// balance from CoinProvider, and exercises the full purchase flow
// (success and insufficient-funds paths).

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/customization_item.dart';
import 'package:english_learning_app/models/shop_item.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/shop_customization_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/screens/shop_screen.dart';
import 'package:english_learning_app/services/shop_customization_service.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/streak_shield_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goldFrameId = 'gold_sticker_frame';
const _goldFrameName = 'מסגרת זהב למדבקות'; // cost: 100
const _sparkHatName = 'כובע לספארק'; // cost: 250
const _streakShieldName = 'מגן רצף'; // cost: 150, consumable

typedef _ShopHandles = ({
  CoinProvider coins,
  ShopCustomizationProvider customization,
});

Future<_ShopHandles> _pumpShop(
  WidgetTester tester, {
  required int coins,
  StreakShieldService? shieldService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final shield = shieldService ?? StreakShieldService();
  final coinProvider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
    streakShieldService: shield,
  );
  await coinProvider.setCoins(coins);

  final customization = ShopCustomizationProvider(
    service: ShopCustomizationService(
      prefs: await SharedPreferences.getInstance(),
    ),
  );
  await customization.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoinProvider>.value(value: coinProvider),
        ChangeNotifierProvider<StreakShieldService>.value(value: shield),
        ChangeNotifierProvider<ShopCustomizationProvider>.value(
          value: customization,
        ),
        // Purchase success runs Celebration.fire, which reads both of these.
        Provider<SoundService>.value(value: SoundService()),
        ChangeNotifierProvider<SparkOverlayController>(
          create: (_) => SparkOverlayController(),
        ),
      ],
      child: const MaterialApp(home: ShopScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (coins: coinProvider, customization: customization);
}

void main() {
  testWidgets('renders the shop header and the live coin balance',
      (tester) async {
    await _pumpShop(tester, coins: 500);

    expect(find.text('חנות הקסמים'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
  });

  testWidgets('renders items from ShopItem.defaultCatalog', (tester) async {
    await _pumpShop(tester, coins: 0);

    expect(find.text(_goldFrameName), findsOneWidget);
    expect(find.text(_sparkHatName), findsOneWidget);
  });

  testWidgets(
      'successfully completes a purchase when the balance is sufficient',
      (tester) async {
    final coinProvider = (await _pumpShop(tester, coins: 150)).coins;

    // Open the item details sheet for the Gold Sticker Frame (100 coins).
    // The Themes & Sounds strip sits above the grid, so scroll it into view.
    await tester.ensureVisible(find.text(_goldFrameName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_goldFrameName));
    await tester.pumpAndSettle();
    expect(find.textContaining('קנה עכשיו'), findsOneWidget);

    await tester.tap(find.textContaining('קנה עכשיו'));
    await tester.pumpAndSettle();

    // Purchase succeeded: celebration dialog, provider state, and balance.
    expect(find.text('תתחדש! 🎉'), findsOneWidget);
    expect(coinProvider.isOwned(_goldFrameId), isTrue);
    expect(coinProvider.coins, 50);

    await tester.tap(find.text('איזה כיף!'));
    await tester.pumpAndSettle();

    // Back on the grid, the purchased item now shows as owned.
    expect(find.text('בבעלותך'), findsWidgets);
  });

  testWidgets(
      'shows a friendly message and does not charge when coins are insufficient',
      (tester) async {
    final coinProvider = (await _pumpShop(tester, coins: 10)).coins;

    await tester.ensureVisible(find.text(_goldFrameName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_goldFrameName));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('קנה עכשיו'));
    await tester.pumpAndSettle();

    expect(find.text(SparkStrings.shopNotEnoughCoins), findsOneWidget);
    expect(coinProvider.isOwned(_goldFrameId), isFalse);
    expect(coinProvider.coins, 10);
  });

  testWidgets('tapping an already-owned item offers no purchase button',
      (tester) async {
    final coinProvider = (await _pumpShop(tester, coins: 500)).coins;
    final goldFrame =
        ShopItem.defaultCatalog.firstWhere((item) => item.id == _goldFrameId);
    await coinProvider.purchaseItem(goldFrame);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_goldFrameName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_goldFrameName));
    await tester.pumpAndSettle();

    expect(find.text('כבר בבעלותך'), findsOneWidget);
    expect(find.textContaining('קנה עכשיו'), findsNothing);
  });

  testWidgets(
      'buying "מגן רצף" grants a shield via the service, costs 150, stays out '
      'of the cosmetic list, and the card then reads as owned', (tester) async {
    final shield = StreakShieldService();
    final coinProvider =
        (await _pumpShop(tester, coins: 300, shieldService: shield)).coins;

    final shieldItem = ShopItem.defaultCatalog
        .firstWhere((i) => i.id == ShopItem.streakShieldId);
    final ok = await coinProvider.purchaseItem(shieldItem);
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(coinProvider.coins, 150);
    expect(shield.hasShield, isTrue);
    // Consumable — never enters the cosmetic list.
    expect(coinProvider.ownedShopItemsCount, 0);

    // Narrow to upgrades, bring the card on-screen, and confirm the shop now
    // reflects it as owned (via context.watch<StreakShieldService>()).
    await tester.tap(find.text('שדרוגים'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(_streakShieldName),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text(_streakShieldName));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_streakShieldName));
    await tester.pumpAndSettle();
    expect(find.text('כבר בבעלותך'), findsOneWidget);
    expect(find.textContaining('קנה עכשיו'), findsNothing);
  });

  group('Themes & Sounds section', () {
    testWidgets('renders the section with the default theme active',
        (tester) async {
      await _pumpShop(tester, coins: 0);

      expect(find.text('ערכות נושא וסאונד'), findsOneWidget);
      expect(find.text('חלל'), findsOneWidget); // Space theme card
      expect(find.text('פעיל'), findsWidgets); // default theme + sound active
    });

    testWidgets('buying a theme deducts coins, equips it, and persists',
        (tester) async {
      final handles = await _pumpShop(tester, coins: 400);

      // Space theme costs 300.
      await tester.tap(find.text('קנה · 300'));
      await tester.pumpAndSettle();

      expect(handles.coins.coins, 100);
      expect(
        handles.customization.equippedThemeId,
        CustomizationItem.spaceThemeId,
      );
      expect(
        handles.customization.isOwned(CustomizationItem.spaceTheme),
        isTrue,
      );

      // Reloading from SharedPreferences keeps the purchase + equipped state.
      final reloaded = ShopCustomizationProvider(
        service: ShopCustomizationService(
          prefs: await SharedPreferences.getInstance(),
        ),
      );
      await reloaded.load();
      expect(reloaded.equippedThemeId, CustomizationItem.spaceThemeId);
      expect(reloaded.isOwned(CustomizationItem.spaceTheme), isTrue);
    });

    testWidgets('does not buy a theme the child cannot afford', (tester) async {
      final handles = await _pumpShop(tester, coins: 50);

      // "קנה · 300" is disabled (grey) — tapping it is a no-op.
      await tester.tap(find.text('קנה · 300'));
      await tester.pumpAndSettle();

      expect(handles.coins.coins, 50);
      expect(
        handles.customization.equippedThemeId,
        CustomizationItem.defaultThemeId,
      );
    });

    testWidgets('an owned-but-not-equipped item shows הפעל and can be equipped',
        (tester) async {
      final handles = await _pumpShop(tester, coins: 400);

      // Buy the gold theme (250), which auto-equips it...
      await tester.tap(find.text('קנה · 250'));
      await tester.pumpAndSettle();
      expect(
        handles.customization.equippedThemeId,
        CustomizationItem.goldThemeId,
      );

      // ...now the default "קלאסי" theme is owned but not equipped → הפעל.
      expect(find.text('הפעל'), findsWidgets);
      await tester.tap(find.text('הפעל').first);
      await tester.pumpAndSettle();
      expect(
        handles.customization.equippedThemeId,
        CustomizationItem.defaultThemeId,
      );
    });
  });
}
