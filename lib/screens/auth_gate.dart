import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';
import '../services/achievement_service.dart';
import '../services/player_data_sync_service.dart';
import '../services/local_user_service.dart';
import 'map_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';
import 'user_selection_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.hasSeenOnboarding});

  final bool hasSeenOnboarding;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _syncService = PlayerDataSyncService();
  final _localUserService = LocalUserService();
  bool _syncing = false;
  bool _hasSynced = false;
  bool _checkingCharacter = false;
  bool _hasCharacter = false;
  bool _checkingLocalUser = false;
  bool _hasLocalUser = false;

  Future<void> _syncPlayerData(BuildContext context) async {
    if (_syncing || _hasSynced) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.firebaseUser == null) {
      return;
    }

    setState(() => _syncing = true);

    try {
      final userId = authProvider.firebaseUser!.uid;
      final coinProvider = Provider.of<CoinProvider>(context, listen: false);
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final achievementService =
          Provider.of<AchievementService>(context, listen: false);

      // Set user IDs for cloud sync
      coinProvider.setUserId(userId);
      shopProvider.setUserId(userId);
      achievementService.setUserId(userId);

      final characterProvider =
          Provider.of<CharacterProvider>(context, listen: false);
      characterProvider.setUserId(userId);

      // Sync from cloud with timeout to prevent hanging
      await _syncService
          .syncFromCloud(
        userId,
        coinProvider: coinProvider,
        shopProvider: shopProvider,
        achievementService: achievementService,
        characterProvider: characterProvider,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Cloud sync timed out, continuing with local data');
        },
      ).catchError((e) {
        debugPrint('Cloud sync error: $e');
      });

      // Character is already synced in syncFromCloud, just check if exists
      if (mounted) {
        setState(() {
          _hasCharacter = characterProvider.hasCharacter;
          _hasSynced = true;
        });
      }

      // If still no character after sync, try loading from local (non-blocking)
      if (!characterProvider.hasCharacter) {
        try {
          await characterProvider.loadCharacter().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              debugPrint('Character local load timed out');
            },
          );
          if (mounted) {
            setState(() {
              _hasCharacter = characterProvider.hasCharacter;
            });
          }
        } catch (e) {
          debugPrint('Error loading character locally: $e');
          // Continue without character - it's optional
        }
      }
    } catch (e) {
      debugPrint('Error syncing player data: $e');
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _checkCharacter(BuildContext context) async {
    if (_checkingCharacter) return;

    if (!mounted) return;
    setState(() => _checkingCharacter = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.firebaseUser == null) {
        if (mounted) {
          setState(() {
            _checkingCharacter = false;
            _hasCharacter = false; // No user, no character needed
          });
        }
        return;
      }

      final userId = authProvider.firebaseUser!.uid;
      final characterProvider =
          Provider.of<CharacterProvider>(context, listen: false);

      // Try loading from local first (faster)
      try {
        await characterProvider.loadCharacter().timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            debugPrint('Character local load timed out');
          },
        );
      } catch (e) {
        debugPrint('Error loading character locally: $e');
      }

      // If still no character, try cloud (with shorter timeout)
      if (!characterProvider.hasCharacter) {
        try {
          await characterProvider.loadCharacterFromCloud(userId).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('Character cloud load timed out');
            },
          );
        } catch (e) {
          debugPrint('Error loading character from cloud: $e');
        }
      }

      if (mounted) {
        setState(() {
          _hasCharacter = characterProvider.hasCharacter;
          _checkingCharacter = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking character: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _checkingCharacter = false;
          // Allow app to continue even if character check fails
          _hasCharacter = false;
        });
      }
    }
  }

  Future<void> _checkLocalUser() async {
    if (_checkingLocalUser) return;

    if (!mounted) return;
    setState(() => _checkingLocalUser = true);

    try {
      final activeUser = await _localUserService.getActiveUser();
      if (mounted) {
        setState(() {
          _hasLocalUser = activeUser != null;
          _checkingLocalUser = false;
        });

        // Update providers with local user ID
        if (activeUser != null) {
          // If user is linked to Google, sign in automatically
          if (activeUser.isLinkedToGoogle && activeUser.googleUid != null) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            if (!authProvider.isAuthenticated) {
              try {
                await authProvider.signInWithGoogle();
                // Verify it's the same Google account
                if (authProvider.firebaseUser?.uid != activeUser.googleUid) {
                  debugPrint(
                    'Warning: Google account mismatch. Expected: ${activeUser.googleUid}, Got: ${authProvider.firebaseUser?.uid}',
                  );
                }
              } catch (e) {
                debugPrint('Error auto-signing in with Google: $e');
                // Continue without Google sign-in
              }
            }
          }

          final coinProvider =
              Provider.of<CoinProvider>(context, listen: false);
          final shopProvider =
              Provider.of<ShopProvider>(context, listen: false);
          final achievementService =
              Provider.of<AchievementService>(context, listen: false);

          coinProvider.setUserId(activeUser.id, isLocalUser: true);
          shopProvider.setUserId(activeUser.id);
          achievementService.setUserId(activeUser.id);

          // Load coins for local user
          await coinProvider.loadCoins();
        }
      }
    } catch (e) {
      debugPrint('Error checking local user: $e');
      if (mounted) {
        setState(() {
          _hasLocalUser = false;
          _checkingLocalUser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        try {
          // Sync when user becomes authenticated
          if (authProvider.isAuthenticated && !_hasSynced && !_syncing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _syncPlayerData(context);
              }
            });
          }

          // Check for local user if not authenticated
          if (!authProvider.isAuthenticated &&
              !_checkingLocalUser &&
              !_hasLocalUser) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkLocalUser();
              }
            });
          }

          if (authProvider.initializing || _syncing || _checkingLocalUser) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Show user selection if no auth and no local user
          if (!authProvider.isAuthenticated && !_hasLocalUser) {
            return const UserSelectionScreen();
          }

          if (!authProvider.isAuthenticated) {
            return const SignInScreen();
          }

          if (!widget.hasSeenOnboarding) {
            return const OnboardingScreen();
          }

          // Check if user has selected a character (non-blocking, with timeout)
          if (_hasSynced && !_checkingCharacter && !_hasCharacter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkCharacter(context);
              }
            });
          }

          // Show character selection only if we're sure there's no character and not checking
          // Skip character selection for now - allow app to work without it
          // User can select character later from settings
          // if (_hasSynced && !_hasCharacter && authProvider.firebaseUser != null && !_checkingCharacter) {
          //   return CharacterSelectionScreen(
          //     userId: authProvider.firebaseUser!.uid,
          //     onCharacterSelected: (character) {
          //       if (mounted) {
          //         final characterProvider = Provider.of<CharacterProvider>(context, listen: false);
          //         characterProvider.setCharacter(character);
          //         setState(() => _hasCharacter = true);
          //       }
          //     },
          //   );
          // }

          // Wrap MapScreen in error boundary to prevent crashes
          // If character check failed, allow app to continue without character
          return Builder(
            builder: (context) {
              try {
                return const MapScreen();
              } catch (e, stackTrace) {
                debugPrint('Error building MapScreen: $e');
                debugPrint('Stack trace: $stackTrace');
                return Scaffold(
                  appBar: AppBar(title: const Text('שגיאה')),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'שגיאה בטעינת המפה',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
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
                              if (mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const MapScreen()),
                                );
                              }
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
        } catch (e, stackTrace) {
          debugPrint('Error in AuthGate build: $e');
          debugPrint('Stack trace: $stackTrace');
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'שגיאה בטעינת האפליקציה',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'נסו לסגור ולפתוח את האפליקציה שוב.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
