// test/widgets/user/user_switch_sheet_test.dart
//
// Widget tests for UserSwitchSheet (lib/widgets/user/user_switch_sheet.dart) —
// the quick "מי משחק עכשיו?" profile switcher opened from the map app bar.
//
// A fake ChildProfileProvider stands in for the real one so selectProfile /
// createProfile don't run the heavy ActiveProfileScope reload machinery
// (which would need CoinProvider, AchievementService, Firestore, etc.).

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/providers/child_profile_provider.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/widgets/user/child_profile_create_dialog.dart';
import 'package:english_learning_app/widgets/user/user_switch_sheet.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChildProfile _profile(String id, String name, {int stars = 0, int streak = 0}) {
  return ChildProfile(
    id: id,
    displayName: name,
    avatarColor: ChildProfile.defaultAvatarColors.first,
    totalStars: stars,
    dailyStreak: streak,
  );
}

class _FakeChildProfileProvider extends ChildProfileProvider {
  _FakeChildProfileProvider({List<ChildProfile>? profiles, this.activeId})
      : _profiles = profiles ?? <ChildProfile>[],
        super(
          syncService:
              ChildProfileSyncService(firestore: FakeFirebaseFirestore()),
        );

  final List<ChildProfile> _profiles;
  String? activeId;

  int selectCalls = 0;
  ChildProfile? lastSelected;
  int createCalls = 0;
  String? lastCreatedName;
  int? lastCreatedColor;

  @override
  bool get initialized => true;

  @override
  bool get loading => false;

  @override
  List<ChildProfile> get profiles => List.unmodifiable(_profiles);

  @override
  String? get activeProfileId => activeId;

  @override
  Future<void> initialize({String? parentUid}) async {}

  @override
  Future<void> selectProfile(BuildContext context, ChildProfile profile) async {
    selectCalls++;
    lastSelected = profile;
    activeId = profile.id;
    notifyListeners();
  }

  @override
  Future<ChildProfile> createProfile({
    required String displayName,
    required int avatarColor,
    String? avatarUrl,
  }) async {
    createCalls++;
    lastCreatedName = displayName;
    lastCreatedColor = avatarColor;
    final created = _profile('new_${_profiles.length}', displayName);
    _profiles.add(created);
    notifyListeners();
    return created;
  }
}

/// Pumps the sheet directly as a Scaffold body — for render-only assertions.
Future<void> _pumpDirect(
  WidgetTester tester,
  _FakeChildProfileProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ChildProfileProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(body: UserSwitchSheet()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a host screen that opens the sheet as a real modal bottom sheet — for
/// interaction assertions (select / create / dismiss / snackbar).
Future<void> _openSheet(
  WidgetTester tester,
  _FakeChildProfileProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ChildProfileProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChangeNotifierProvider<ChildProfileProvider>
                      .value(value: provider, child: const UserSwitchSheet()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UserSwitchSheet', () {
    testWidgets('lists every profile and marks the active one', (tester) async {
      final provider = _FakeChildProfileProvider(
        profiles: [_profile('a', 'אלכס', stars: 5), _profile('b', 'דנה')],
        activeId: 'a',
      );

      await _pumpDirect(tester, provider);

      expect(find.text('מי משחק עכשיו?'), findsOneWidget);
      expect(find.text('אלכס'), findsOneWidget);
      expect(find.text('דנה'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // active only
      expect(find.text('הוסף שחקן חדש'), findsOneWidget);
    });

    testWidgets('shows an empty state plus the add action when there are no '
        'profiles', (tester) async {
      final provider = _FakeChildProfileProvider(profiles: []);

      await _pumpDirect(tester, provider);

      expect(
        find.text('עדיין אין שחקנים. הוסיפו את הראשון!'),
        findsOneWidget,
      );
      expect(find.text('הוסף שחקן חדש'), findsOneWidget);
    });

    testWidgets('selecting a different profile switches, closes and welcomes',
        (tester) async {
      final provider = _FakeChildProfileProvider(
        profiles: [_profile('a', 'אלכס'), _profile('b', 'דנה')],
        activeId: 'a',
      );

      await _openSheet(tester, provider);
      await tester.tap(find.text('דנה'));
      await tester.pumpAndSettle();

      expect(provider.selectCalls, 1);
      expect(provider.lastSelected?.id, 'b');
      expect(find.text('מי משחק עכשיו?'), findsNothing); // sheet dismissed
      expect(
        find.text(SparkStrings.welcomeBackUser('דנה')),
        findsOneWidget,
      );
    });

    testWidgets('tapping the already-active profile just closes the sheet',
        (tester) async {
      final provider = _FakeChildProfileProvider(
        profiles: [_profile('a', 'אלכס')],
        activeId: 'a',
      );

      await _openSheet(tester, provider);
      await tester.tap(find.text('אלכס'));
      await tester.pumpAndSettle();

      expect(provider.selectCalls, 0);
      expect(find.text('מי משחק עכשיו?'), findsNothing);
    });

    testWidgets('"add new player" creates a profile inline and switches to it',
        (tester) async {
      final provider = _FakeChildProfileProvider(
        profiles: [_profile('a', 'אלכס')],
        activeId: 'a',
      );

      await _openSheet(tester, provider);
      await tester.tap(find.text('הוסף שחקן חדש'));
      await tester.pumpAndSettle();

      expect(find.byType(ChildProfileCreateDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'רון');
      await tester.pump();
      await tester.tap(find.text('צור'));
      await tester.pumpAndSettle();

      expect(provider.createCalls, 1);
      expect(provider.lastCreatedName, 'רון');
      expect(provider.selectCalls, 1);
      expect(provider.lastSelected?.displayName, 'רון');
      expect(find.text('מי משחק עכשיו?'), findsNothing);
    });
  });
}
