// test/screens/leaderboard_screen_test.dart
//
// Widget tests for LeaderboardScreen: renders the ranked list with the new
// animal-emoji avatars (via OptimizedAvatar), highlights the active player,
// and re-queries the service when the Coins/Streak toggle flips.

import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/leaderboard_entry.dart';
import 'package:english_learning_app/providers/child_profile_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/leaderboard_screen.dart';
import 'package:english_learning_app/services/child_profile_service.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/services/leaderboard_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLeaderboardService extends LeaderboardService {
  _FakeLeaderboardService() : super(firestore: FakeFirebaseFirestore());

  final List<LeaderboardSortMode> requestedModes = [];

  LeaderboardEntry _entry(
    int rank,
    String name,
    String emoji,
    int coins,
    int streak, {
    bool isCurrentUser = false,
  }) {
    return LeaderboardEntry(
      profileId: name,
      displayName: name,
      totalCoins: coins,
      currentStreak: streak,
      avatarColor: 0xFF2196F3,
      avatarId: emoji,
      rank: rank,
      isCurrentUser: isCurrentUser,
    );
  }

  @override
  Future<LeaderboardResult> fetchLeaderboard({
    String? currentProfileId,
    int limit = LeaderboardService.defaultLimit,
    LeaderboardSortMode sortMode = LeaderboardSortMode.coins,
  }) async {
    requestedModes.add(sortMode);
    final entries = sortMode == LeaderboardSortMode.coins
        ? [
            _entry(1, 'Coinly', '🦊', 500, 2),
            _entry(2, 'Otter', '🦦', 400, 1),
            _entry(3, 'Lowish', '🐰', 100, 4),
            _entry(4, 'Middle', '🐼', 90, 9, isCurrentUser: true),
          ]
        : [
            _entry(1, 'Middle', '🐼', 90, 9, isCurrentUser: true),
            _entry(2, 'Lowish', '🐰', 100, 4),
            _entry(3, 'Coinly', '🦊', 500, 2),
            _entry(4, 'Otter', '🦦', 400, 1),
          ];
    return LeaderboardResult(
      entries: entries,
      currentUserEntry: entries.firstWhere((e) => e.isCurrentUser),
    );
  }
}

Future<_FakeLeaderboardService> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final profileService = ChildProfileService(prefs: prefs);
  final service = _FakeLeaderboardService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ChildProfileProvider>(
          create: (_) => ChildProfileProvider(
            profileService: profileService,
            syncService: ChildProfileSyncService(
              firestore: FakeFirebaseFirestore(),
              profileService: profileService,
            ),
          ),
        ),
        ChangeNotifierProvider<UserSessionProvider>(
          create: (_) => UserSessionProvider(),
        ),
      ],
      child: MaterialApp(
        home: LeaderboardScreen(leaderboardService: service),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders players with their animal-emoji avatars', (tester) async {
    await _pump(tester);

    expect(find.text('Coinly'), findsOneWidget);
    expect(find.text('Middle'), findsOneWidget);
    expect(find.text('Otter'), findsOneWidget);
    // Emoji avatars come straight from avatarId.
    expect(find.text('🦊'), findsOneWidget);
    expect(find.text('🐼'), findsOneWidget);
    expect(find.text('🦦'), findsOneWidget);
  });

  testWidgets('highlights the active player with the "you" badge',
      (tester) async {
    await _pump(tester);
    expect(find.text(SparkStrings.leaderboardYouBadge), findsOneWidget);
  });

  testWidgets('flipping the toggle re-queries the service by streak',
      (tester) async {
    final service = await _pump(tester);
    expect(service.requestedModes, [LeaderboardSortMode.coins]);

    await tester.tap(find.text(SparkStrings.leaderboardSortByStreak));
    await tester.pumpAndSettle();

    expect(service.requestedModes.last, LeaderboardSortMode.streak);
  });
}
