import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/background_music_service.dart';
import 'map_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.hasSeenOnboarding});

  final bool hasSeenOnboarding;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.initializing) {
          context.read<BackgroundMusicService>().playStartupTheme();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authProvider.isAuthenticated) {
          context.read<BackgroundMusicService>().playStartupTheme();
          return const SignInScreen();
        }

        if (!hasSeenOnboarding) {
          context.read<BackgroundMusicService>().playStartupTheme();
          return const OnboardingScreen();
        }

        return const MapScreen();
      },
    );
  }
}
