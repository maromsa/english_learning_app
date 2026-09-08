import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard for `firestore.rules`.
///
/// We have no Firestore emulator / `@firebase/rules-unit-testing` setup, and the
/// Dart tests use `fake_cloud_firestore`, which does **not** enforce security
/// rules. So a mismatch between what the client writes and what the rules allow
/// (the exact class of bug that silently broke leaderboard avatar sync) would
/// pass every existing test.
///
/// This test parses the deployed rules text and asserts the
/// `/leaderboard/{entryId}` field whitelist stays in lock-step with the payload
/// that [ChildProfileSyncService] publishes. If you add a field to the
/// leaderboard write, add it here and to `firestore.rules` in the same change.
void main() {
  /// Every key the client is allowed to publish to a leaderboard entry.
  /// Keep in sync with `ChildProfileSyncService._publishLeaderboardEntry`.
  const publishableLeaderboardFields = <String>{
    'profileId',
    'displayName',
    'coins',
    'dailyStreak',
    'avatarColor',
    'avatarId',
    'updatedAt',
  };

  late String rulesText;

  setUpAll(() {
    rulesText = _findProjectRoot()
        .listSync()
        .whereType<File>()
        .firstWhere(
          (f) => f.uri.pathSegments.last == 'firestore.rules',
          orElse: () => fail('firestore.rules not found at project root'),
        )
        .readAsStringSync();
  });

  test('leaderboard hasOnly() whitelist matches the publishable field set', () {
    final whitelist = _leaderboardHasOnlyFields(rulesText);

    expect(
      whitelist,
      equals(publishableLeaderboardFields),
      reason:
          'firestore.rules leaderboard whitelist is out of sync with what the '
          'client publishes. Update the hasOnly([...]) list in firestore.rules '
          '(and redeploy rules) or adjust the publisher.',
    );
  });

  test('avatarId in the leaderboard rule carries a type guard', () {
    final leaderboardBlock = _leaderboardMatchBlock(rulesText);
    expect(
      leaderboardBlock.contains('avatarId is string'),
      isTrue,
      reason: 'avatarId must be validated as a string in firestore.rules',
    );
  });

  test('shop customization fields never enter the leaderboard whitelist', () {
    // Purchases (unlocked themes / sounds, equipped ids) sync via the private
    // childProfiles document, never the public leaderboard (privacy contract,
    // CLAUDE.md §2.3). This guards against someone wiring them into the
    // leaderboard publisher + widening the whitelist to match.
    final whitelist = _leaderboardHasOnlyFields(rulesText);
    const shopFields = <String>{
      'unlockedThemes',
      'unlockedSounds',
      'equippedTheme',
      'equippedSound',
    };
    expect(
      whitelist.intersection(shopFields),
      isEmpty,
      reason:
          'shop customization data must not be published to the leaderboard',
    );
  });
}

Directory _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not locate project root (pubspec.yaml) from ${dir.path}');
    }
    dir = parent;
  }
}

/// Returns the source of the `match /leaderboard/{entryId} { ... }` block.
String _leaderboardMatchBlock(String rules) {
  // Match the statement itself, skipping the `{entryId}` path-param braces so
  // the brace walk below starts at the block-opening `{`.
  final matchStmt =
      RegExp(r'match\s+/leaderboard/\{[^}]+\}\s*\{').firstMatch(rules);
  expect(
    matchStmt,
    isNotNull,
    reason: 'no /leaderboard/ match block in firestore.rules',
  );

  final open = matchStmt!.end - 1; // index of the block-opening brace
  var depth = 0;
  for (var i = open; i < rules.length; i++) {
    final c = rules[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return rules.substring(open, i + 1);
    }
  }
  fail('unbalanced braces in /leaderboard/ block');
}

/// Extracts the string literals inside the leaderboard `hasOnly([...])` call.
Set<String> _leaderboardHasOnlyFields(String rules) {
  final block = _leaderboardMatchBlock(rules);
  final hasOnly = RegExp(r'hasOnly\(\s*\[([^\]]*)\]').firstMatch(block);
  expect(
    hasOnly,
    isNotNull,
    reason: 'no hasOnly([...]) whitelist in the /leaderboard/ block',
  );
  return RegExp("'([^']+)'")
      .allMatches(hasOnly!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}
