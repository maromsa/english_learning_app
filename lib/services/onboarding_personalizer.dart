import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data object representing a personalized onboarding insight.
class OnboardingInsight {
  const OnboardingInsight({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String id;
  final IconData icon;
  final String title;
  final String body;
}

class OnboardingPersonalization {
  const OnboardingPersonalization({
    required this.insights,
    required this.isReturningLearner,
    required this.appliedRules,
  });

  final List<OnboardingInsight> insights;
  final bool isReturningLearner;
  final List<String> appliedRules;
}

/// Generates lightweight heuristics to tailor onboarding messaging for each user.
class OnboardingPersonalizer {
  OnboardingPersonalizer({SharedPreferences? preferences})
      : _prefsFuture =
            preferences != null ? Future.value(preferences) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  Future<OnboardingPersonalization> buildPersonalization() async {
    final prefs = await _prefsFuture;

    final int coins = prefs.getInt('totalCoins') ?? 0;
    final int dailyStreak = prefs.getInt('daily_reward_streak') ?? 0;
    final List<String> purchasedItems = prefs.getStringList('purchased_items') ?? const <String>[];
    final bool anyAchievements = prefs
        .getKeys()
        .where((key) => key.startsWith('achievement_'))
        .any((key) => prefs.getBool(key) ?? false);

    final List<OnboardingInsight> insights = <OnboardingInsight>[];
    final List<String> appliedRules = <String>[];

    // Returning learner heuristics.
    if (dailyStreak >= 2) {
      insights.add(
        OnboardingInsight(
          id: 'daily_streak',
          icon: Icons.calendar_today,
          title: 'Keep Your Daily Streak',
          body:
              'You are already on a $dailyStreak-day streak! Keep claiming daily rewards to boost your progress.',
        ),
      );
      appliedRules.add('daily_streak');
    }

    if (coins >= 100) {
      insights.add(
        OnboardingInsight(
          id: 'coin_bank',
          icon: Icons.auto_awesome,
          title: 'Spend Coins for Power-Ups',
          body:
              'You have $coins coins saved. Visit the shop to unlock gear that helps you master tougher words.',
        ),
      );
      appliedRules.add('coin_balance_high');
    }

    if (purchasedItems.isNotEmpty) {
      insights.add(
        OnboardingInsight(
          id: 'shop_collector',
          icon: Icons.style,
          title: 'Customize Your Journey',
          body:
              'You already own ${purchasedItems.length} item(s). Pair new gear with daily challenges for faster learning.',
        ),
      );
      appliedRules.add('shop_purchases');
    }

    if (anyAchievements) {
      insights.add(
        const OnboardingInsight(
          id: 'achievement_hunter',
          icon: Icons.emoji_events,
          title: 'Chase New Achievements',
          body:
              'Nice work unlocking achievements! Explore the map for new quests tailored to your skills.',
        ),
      );
      appliedRules.add('achievements_unlocked');
    }

    // New learner defaults if we captured no returning signals.
    if (insights.isEmpty) {
      insights.addAll(<OnboardingInsight>[
        const OnboardingInsight(
          id: 'camera_intro',
          icon: Icons.lightbulb,
          title: 'Snap Real-World Words',
          body:
              'Use the camera challenges to capture each word in your world. The app gives instant feedback to keep you on track.',
        ),
        const OnboardingInsight(
          id: 'quiz_streak',
          icon: Icons.sports_martial_arts,
          title: 'Build a Winning Streak',
          body:
              'Answer quiz questions in a row to grow your streak and earn bonus coins. Hints adapt based on how you play.',
        ),
        const OnboardingInsight(
          id: 'daily_reward',
          icon: Icons.card_giftcard,
          title: 'Claim Daily Rewards',
          body: 'Come back tomorrow to collect a daily bonus. Streaks unlock higher rewards and new challenges.',
        ),
      ]);
      appliedRules.add('brand_new_defaults');
    } else {
      // Ensure at least one forward-looking suggestion for returning users.
      insights.add(
        const OnboardingInsight(
          id: 'adaptive_levels',
          icon: Icons.explore,
          title: 'Discover Adaptive Levels',
          body:
              'Levels unlock based on your progress. Play a mix of quizzes and camera challenges so the app can tailor what comes next.',
        ),
      );
    }

    // Keep the insights concise—cap to three items for the onboarding carousel.
    final List<OnboardingInsight> limited = insights.take(3).toList(growable: false);
    return OnboardingPersonalization(
      insights: limited,
      isReturningLearner: appliedRules.any((rule) => rule != 'brand_new_defaults'),
      appliedRules: List<String>.unmodifiable(appliedRules),
    );
  }
}
