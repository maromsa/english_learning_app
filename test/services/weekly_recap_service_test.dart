// test/services/weekly_recap_service_test.dart
//
// Unit tests for WeeklyRecapService — the 7-day window boundary is the thing
// that most needs pinning down, so `now` is injected everywhere.

import 'dart:convert';

import 'package:english_learning_app/services/local_user_data_service.dart';
import 'package:english_learning_app/services/weekly_recap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixed "today" for every test. Window = 2026-09-02 .. 2026-09-08 inclusive.
final _now = DateTime(2026, 9, 8);
String _day(DateTime d) => LocalUserDataService.dayKey(d);

Future<WeeklyRecapService> _service({
  List<Map<String, dynamic>> activity = const [],
  Map<String, int> coins = const {},
  Map<String, Map<String, dynamic>> srs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    if (activity.isNotEmpty) 'parent_activity.v1_child1': jsonEncode(activity),
    if (coins.isNotEmpty) 'user_child1_daily_coins_earned': jsonEncode(coins),
    for (final entry in srs.entries)
      'srs.v1.child1.${entry.key}': jsonEncode(entry.value),
  });
  return WeeklyRecapService(prefs: await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty stores → an empty recap with 7 zero days', () async {
    final service = await _service();
    final recap = await service.loadRecap(userId: 'child1', now: _now);

    expect(recap.days, hasLength(7));
    expect(recap.isEmpty, isTrue);
    expect(recap.activeDays, 0);
    expect(recap.wordsPracticed, 0);
    expect(recap.coinsEarned, 0);
    expect(recap.bestDay, isNull);
  });

  test('aggregates words / minutes / active days across the window', () async {
    final service = await _service(activity: [
      {'day': _day(DateTime(2026, 9, 2)), 'words': 5, 'minutes': 4},
      {'day': _day(DateTime(2026, 9, 5)), 'words': 8, 'minutes': 12},
      {'day': _day(_now), 'words': 3, 'minutes': 6},
    ]);
    final recap = await service.loadRecap(userId: 'child1', now: _now);

    expect(recap.activeDays, 3);
    expect(recap.wordsPracticed, 16);
    expect(recap.minutesPracticed, 22);
    expect(recap.bestDay?.words, 8);
  });

  test('the 7-day window boundary is inclusive of now-6, exclusive of now-7',
      () async {
    final service = await _service(activity: [
      {
        'day': _day(DateTime(2026, 9, 2)),
        'words': 10,
        'minutes': 0
      }, // now-6 IN
      {
        'day': _day(DateTime(2026, 9, 1)),
        'words': 99,
        'minutes': 0
      }, // now-7 OUT
    ]);
    final recap = await service.loadRecap(userId: 'child1', now: _now);

    expect(recap.wordsPracticed, 10);
    expect(recap.activeDays, 1);
    // The oldest rendered day is now-6.
    expect(_day(recap.days.first.date), _day(DateTime(2026, 9, 2)));
    expect(_day(recap.days.last.date), _day(_now));
  });

  test('coins earned sums only in-window daily entries', () async {
    final service = await _service(coins: {
      _day(DateTime(2026, 9, 2)): 20,
      _day(_now): 30,
      _day(DateTime(2026, 9, 1)): 500, // out of window
    });
    final recap = await service.loadRecap(userId: 'child1', now: _now);

    expect(recap.coinsEarned, 50);
  });

  group('wordsMasteredThisWeek', () {
    test('counts a mastered card reviewed inside the window', () async {
      final service = await _service(srs: {
        'fruits.apple': {
          'masteryLevel': 1.0,
          'lastReviewDate': DateTime(2026, 9, 5).toIso8601String(),
        },
      });
      final recap = await service.loadRecap(userId: 'child1', now: _now);
      expect(recap.wordsMasteredThisWeek, 1);
    });

    test('ignores a mastered card last reviewed before the window', () async {
      final service = await _service(srs: {
        'fruits.banana': {
          'masteryLevel': 1.0,
          'lastReviewDate': DateTime(2026, 8, 20).toIso8601String(),
        },
      });
      final recap = await service.loadRecap(userId: 'child1', now: _now);
      expect(recap.wordsMasteredThisWeek, 0);
    });

    test('ignores a card that is not yet at mastery', () async {
      final service = await _service(srs: {
        'fruits.pear': {
          'masteryLevel': 0.6,
          'lastReviewDate': DateTime(2026, 9, 6).toIso8601String(),
        },
      });
      final recap = await service.loadRecap(userId: 'child1', now: _now);
      expect(recap.wordsMasteredThisWeek, 0);
    });
  });

  test('state is namespaced per profile id', () async {
    SharedPreferences.setMockInitialValues({
      'parent_activity.v1_child1': jsonEncode([
        {'day': _day(_now), 'words': 7, 'minutes': 3},
      ]),
    });
    final service =
        WeeklyRecapService(prefs: await SharedPreferences.getInstance());

    final other = await service.loadRecap(userId: 'child2', now: _now);
    expect(other.isEmpty, isTrue);
  });
}
