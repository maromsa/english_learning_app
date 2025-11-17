import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authProvider.isAuthenticated) {
          return const SignInScreen();
        }

        if (!hasSeenOnboarding) {
          return const OnboardingScreen();
        }

        // Wrap MapScreen in error boundary to prevent crashes
        return Builder(
          builder: (context) {
            try {
              return const MapScreen();
            } catch (e, stackTrace) {
              debugPrint('Error building MapScreen: $e');
              debugPrint('Stack trace: $stackTrace');
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'שגיאה בטעינת המפה',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'נסו לסגור ולפתוח את האפליקציה שוב.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            // Try to rebuild
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const MapScreen()),
                            );
                          },
                          child: const Text('נסה שוב'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
