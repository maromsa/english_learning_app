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
    : _prefsFuture = preferences != null
          ? Future.value(preferences)
          : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  Future<OnboardingPersonalization> buildPersonalization() async {
    final prefs = await _prefsFuture;

    final int coins = prefs.getInt('totalCoins') ?? 0;
    final int dailyStreak = prefs.getInt('daily_reward_streak') ?? 0;
    final List<String> purchasedItems =
        prefs.getStringList('purchased_items') ?? const <String>[];
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
          title: 'שמרו על הרצף היומי',
          body:
              'אתם כבר ברצף של $dailyStreak ימים! אספו את המתנה היומית כדי להמשיך להתקדם.',
        ),
      );
      appliedRules.add('daily_streak');
    }

    if (coins >= 100) {
      insights.add(
        OnboardingInsight(
          id: 'coin_bank',
          icon: Icons.auto_awesome,
          title: 'נצלו מטבעות לשדרוגים',
          body:
              'צברתם $coins מטבעות. קפצו לחנות כדי לפתוח ציוד שיעזור לכם להתמודד עם מילים קשות יותר.',
        ),
      );
      appliedRules.add('coin_balance_high');
    }

    if (purchasedItems.isNotEmpty) {
      insights.add(
        OnboardingInsight(
          id: 'shop_collector',
          icon: Icons.style,
          title: 'התאימו את המסע שלכם',
          body:
              'כבר רכשתם ${purchasedItems.length} פריטים. שלבו ציוד חדש עם אתגרים יומיים כדי ללמוד מהר יותר.',
        ),
      );
      appliedRules.add('shop_purchases');
    }

    if (anyAchievements) {
      insights.add(
        const OnboardingInsight(
          id: 'achievement_hunter',
          icon: Icons.emoji_events,
          title: 'לכדו הישגים חדשים',
          body:
              'כל הכבוד על ההישגים! צאו למפת המסע וחפשו משימות חדשות שמתאימות לכישורים שלכם.',
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
          title: 'צלמו מילים מהעולם האמיתי',
          body:
              'השתמשו באתגרי המצלמה כדי לצלם מילים שאתם פוגשים סביבכם. האפליקציה תיתן לכם משוב מיידי ותכוון אתכם קדימה.',
        ),
        const OnboardingInsight(
          id: 'quiz_streak',
          icon: Icons.sports_martial_arts,
          title: 'בנו רצף מנצח',
          body:
              'ענו על שאלות החידון ברצף כדי לחזק את הרצף ולקבל בונוס מטבעות. הרמזים יתאימו את עצמם לקצב שלכם.',
        ),
        const OnboardingInsight(
          id: 'daily_reward',
          icon: Icons.card_giftcard,
          title: 'אספו מתנות יומיות',
          body:
              'חזרו מחר כדי לקבל בונוס יומי. רצפים פותחים תגמולים גדולים יותר ואתגרים חדשים.',
        ),
      ]);
      appliedRules.add('brand_new_defaults');
    } else {
      // Ensure at least one forward-looking suggestion for returning users.
      insights.add(
        const OnboardingInsight(
          id: 'adaptive_levels',
          icon: Icons.explore,
          title: 'גלו שלבים שמתאימים אליכם',
          body:
              'שלבים נפתחים לפי ההתקדמות שלכם. שלבו חידונים ואתגרי מצלמה כדי שנוכל להתאים לכם את המשימה הבאה.',
        ),
      );
    }

    // Keep the insights concise—cap to three items for the onboarding carousel.
    final List<OnboardingInsight> limited = insights
        .take(3)
        .toList(growable: false);
    return OnboardingPersonalization(
      insights: limited,
      isReturningLearner: appliedRules.any(
        (rule) => rule != 'brand_new_defaults',
      ),
      appliedRules: List<String>.unmodifiable(appliedRules),
    );
  }
}
