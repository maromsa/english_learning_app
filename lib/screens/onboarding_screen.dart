// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/onboarding_personalizer.dart';
import '../services/telemetry_service.dart';
import 'map_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingPersonalizer _personalizer;
  late final Future<OnboardingPersonalization> _personalizationFuture;
  late final DateTime _viewStartedAt;

  OnboardingPersonalization? _latestPersonalization;
  bool _loggedTipImpression = false;

  @override
  void initState() {
    super.initState();
    _personalizer = OnboardingPersonalizer();
    _personalizationFuture = _personalizer.buildPersonalization();
    _viewStartedAt = DateTime.now();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);

    final telemetry = Provider.maybeOf<TelemetryService>(context, listen: false);
    final personalization = _latestPersonalization;
    telemetry?.logOnboardingCompleted(
      tipIds: personalization?.insights.map((tip) => tip.id).toList() ?? const <String>[],
      returningLearner: personalization?.isReturningLearner ?? false,
      appliedRules: personalization?.appliedRules ?? const <String>[],
      millisecondsToComplete: DateTime.now().difference(_viewStartedAt).inMilliseconds,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  void _logImpressionOnce(BuildContext context, OnboardingPersonalization personalization) {
    if (_loggedTipImpression) {
      return;
    }
    _loggedTipImpression = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.maybeOf<TelemetryService>(context, listen: false)?.logOnboardingTipsShown(
        tipIds: personalization.insights.map((tip) => tip.id).toList(),
        appliedRules: personalization.appliedRules,
        returningLearner: personalization.isReturningLearner,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to the App!',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We gathered a few smart tips to get you learning faster.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<OnboardingPersonalization>(
                  future: _personalizationFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final personalization = snapshot.data;
                    if (personalization != null) {
                      _latestPersonalization = personalization;
                      _logImpressionOnce(context, personalization);

                      final insights = personalization.insights;
                      if (insights.isNotEmpty) {
                        return ListView.separated(
                          itemCount: insights.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) => _InsightCard(insight: insights[index]),
                        );
                      }
                    }

                    return const _InsightFallback();
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Let’s Go'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final OnboardingInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(insight.icon, color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            insight.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            insight.body,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InsightFallback extends StatelessWidget {
  const _InsightFallback();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 32),
        _InsightCard(
          insight: OnboardingInsight(
            id: 'fallback_map',
            icon: Icons.lightbulb,
            title: 'Explore the Map',
            body: 'Play through your first level to discover how rewards and quests adapt to you.',
          ),
        ),
      ],
    );
  }
}