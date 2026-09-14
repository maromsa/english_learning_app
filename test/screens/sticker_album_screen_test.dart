// test/screens/sticker_album_screen_test.dart
//
// Widget tests for StickerAlbumScreen: renders the header/canvas/tray,
// exercises the purchase flow (success and insufficient-funds paths), and
// drags a sticker from the inventory tray onto the canvas (and back).

import 'package:english_learning_app/models/sticker.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/sticker_album_provider.dart';
import 'package:english_learning_app/screens/sticker_album_screen.dart';
import 'package:english_learning_app/services/sticker_album_service.dart';
import 'package:english_learning_app/services/user_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _fox = Sticker.defaultCatalog[0]; // cost 30

typedef _Handles = ({CoinProvider coins, StickerAlbumProvider album});

Future<_Handles> _pumpScreen(WidgetTester tester, {required int coins}) async {
  SharedPreferences.setMockInitialValues({});
  final coinProvider = CoinProvider(
    userDataService: UserDataService(firestore: FakeFirebaseFirestore()),
  );
  await coinProvider.setCoins(coins);

  final albumProvider = StickerAlbumProvider(
    service: StickerAlbumService(prefs: await SharedPreferences.getInstance()),
  );
  await albumProvider.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoinProvider>.value(value: coinProvider),
        ChangeNotifierProvider<StickerAlbumProvider>.value(
            value: albumProvider),
      ],
      child: const MaterialApp(home: StickerAlbumScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (coins: coinProvider, album: albumProvider);
}

void main() {
  testWidgets('renders the header, empty canvas, and shop row', (tester) async {
    await _pumpScreen(tester, coins: 500);

    expect(find.text('אלבום המדבקות'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('גררו מדבקות לכאן'), findsOneWidget);
    expect(find.byKey(Key('buy_sticker_${_fox.id}')), findsOneWidget);
  });

  testWidgets('buying a sticker deducts coins and moves it into the tray',
      (tester) async {
    final handles = await _pumpScreen(tester, coins: 500);

    await tester.tap(find.byKey(Key('buy_sticker_${_fox.id}')));
    await tester.pumpAndSettle();

    expect(handles.coins.coins, 500 - _fox.cost);
    expect(handles.album.isOwned(_fox.id), isTrue);
    expect(find.byKey(Key('sticker_tray_${_fox.id}')), findsOneWidget);
    expect(find.text('${_fox.name} נוסף לאלבום!'), findsOneWidget);
  });

  testWidgets(
      'buying with insufficient coins shows an error and charges nothing',
      (tester) async {
    final handles = await _pumpScreen(tester, coins: 1);

    await tester.tap(find.byKey(Key('buy_sticker_${_fox.id}')));
    await tester.pumpAndSettle();

    expect(handles.coins.coins, 1);
    expect(handles.album.isOwned(_fox.id), isFalse);
    expect(find.text('אין מספיק מטבעות'), findsOneWidget);
  });

  testWidgets(
      'dragging an owned sticker from the tray onto the canvas places it',
      (tester) async {
    final handles = await _pumpScreen(tester, coins: 500);
    await handles.album.purchase(_fox, handles.coins);
    await tester.pumpAndSettle();

    final trayKey = Key('sticker_tray_${_fox.id}');
    expect(find.byKey(trayKey), findsOneWidget);

    final start = tester.getCenter(find.byKey(trayKey));
    final canvasCenter =
        tester.getCenter(find.byKey(const GlobalObjectKey('sticker_canvas')));

    final gesture = await tester.startGesture(start);
    await gesture.moveTo(canvasCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(handles.album.isPlaced(_fox.id), isTrue);
    expect(find.byKey(Key('placed_sticker_${_fox.id}')), findsOneWidget);
    expect(find.byKey(trayKey), findsNothing);
  });

  testWidgets('dragging a placed sticker back onto the tray removes it',
      (tester) async {
    final handles = await _pumpScreen(tester, coins: 500);
    await handles.album.purchase(_fox, handles.coins);
    await handles.album.place(_fox.id, x: 0.5, y: 0.5);
    await tester.pumpAndSettle();

    final placedKey = Key('placed_sticker_${_fox.id}');
    expect(find.byKey(placedKey), findsOneWidget);

    final start = tester.getCenter(find.byKey(placedKey));
    final trayCenter = tester.getCenter(find.byKey(const Key('sticker_tray')));

    final gesture = await tester.startGesture(start);
    await gesture.moveTo(trayCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(handles.album.isPlaced(_fox.id), isFalse);
    expect(handles.album.isOwned(_fox.id), isTrue);
    expect(find.byKey(Key('sticker_tray_${_fox.id}')), findsOneWidget);
  });
}
