import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/background_music_service.dart';
import 'map_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.hasSeenOnboarding});

  final bool hasSeenOnboarding;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _musicStarted = false;

  @override
  void initState() {
    super.initState();
    // Start background music when app starts
    _startAppMusic();
  }

  Future<void> _startAppMusic() async {
    if (_musicStarted) return;
    _musicStarted = true;
    
    try {
      // Start with app startup music
      await BackgroundMusicService().playMusic('assets/audio/app_startup.mp3');
    } catch (e) {
      // Music file might not exist yet, fail silently
      debugPrint('Could not play app startup music: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.initializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authProvider.isAuthenticated) {
          return const SignInScreen();
        }

        if (!widget.hasSeenOnboarding) {
          return const OnboardingScreen();
        }

        return const MapScreen();
      },
    );
  }
}
