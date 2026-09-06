// test/widgets/user/current_user_avatar_test.dart
//
// Widget tests for CurrentUserAvatar — the map app-bar pill. It shows the
// active child profile's emoji avatar when the profile matches the session
// user, and falls back to the coloured initial otherwise.

import 'package:english_learning_app/models/child_profile.dart';
import 'package:english_learning_app/providers/child_profile_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/child_profile_sync_service.dart';
import 'package:english_learning_app/widgets/user/current_user_avatar.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSession extends UserSessionProvider {
  _FakeSession(this._user);
  final AppSessionUser? _user;
  @override
  AppSessionUser? get currentUser => _user;
}

class _FakeProfiles extends ChildProfileProvider {
  _FakeProfiles(this._active)
      : super(
          syncService:
              ChildProfileSyncService(firestore: FakeFirebaseFirestore()),
        );
  final ChildProfile? _active;
  @override
  bool get initialized => true;
  @override
  bool get loading => false;
  @override
  ChildProfile? get activeProfile => _active;
  @override
  String? get activeProfileId => _active?.id;
  @override
  List<ChildProfile> get profiles => _active == null ? const [] : [_active];
  @override
  Future<void> initialize({String? parentUid}) async {}
}

AppSessionUser _user(String id, String name) =>
    AppSessionUser(id: id, name: name, isGoogle: false);

ChildProfile _profile(String id, String name, {String? avatarId}) =>
    ChildProfile(
      id: id,
      displayName: name,
      avatarColor: ChildProfile.defaultAvatarColors.first,
      avatarId: avatarId,
    );

Future<void> _pump(
  WidgetTester tester, {
  required AppSessionUser? user,
  required ChildProfile? activeProfile,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserSessionProvider>.value(
          value: _FakeSession(user),
        ),
        ChangeNotifierProvider<ChildProfileProvider>.value(
          value: _FakeProfiles(activeProfile),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CurrentUserAvatar()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the active profile emoji when it matches the session user',
      (tester) async {
    await _pump(
      tester,
      user: _user('kid1', 'רון'),
      activeProfile: _profile('kid1', 'רון', avatarId: '🐼'),
    );

    expect(find.text('🐼'), findsOneWidget);
    expect(find.text('רון'), findsOneWidget); // name label still shown
  });

  testWidgets('falls back to the initial when the profile has no emoji',
      (tester) async {
    await _pump(
      tester,
      user: _user('kid1', 'Dana'),
      activeProfile: _profile('kid1', 'Dana'),
    );

    expect(find.text('🐼'), findsNothing);
    expect(find.text('D'), findsOneWidget); // coloured initial
  });

  testWidgets('ignores a stale profile emoji when ids do not match',
      (tester) async {
    await _pump(
      tester,
      user: _user('kid2', 'Amit'),
      activeProfile: _profile('kid1', 'רון', avatarId: '🦊'),
    );

    expect(find.text('🦊'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('renders an account icon when there is no session user',
      (tester) async {
    await _pump(tester, user: null, activeProfile: null);

    expect(find.byIcon(Icons.account_circle), findsOneWidget);
  });
}
