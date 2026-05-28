import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../providers/child_profile_provider.dart';
import '../providers/coin_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/spark_overlay_controller.dart';
import '../services/achievement_service.dart';
import '../services/child_profile_sync_service.dart';
import '../services/player_data_sync_service.dart';
import '../utils/active_profile_scope.dart';
import '../widgets/achievement_notification.dart';
import '../widgets/spark_overlay_suppressor.dart';
import 'child_profile_selection_screen.dart';
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
  final _syncService = PlayerDataSyncService();
  final _childProfileSyncService = ChildProfileSyncService();
  bool _syncing = false;
  bool _hasSynced = false;
  bool _checkingCharacter = false;
  bool _hasCharacter = false;
  bool _profilesInitialized = false;
  bool _initializingProfiles = false;

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
        setState(() {
          _syncing = false;
          // Unblock UI after sync attempt (success, timeout, or error).
          _hasSynced = true;
        });
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

  Future<void> _initializeChildProfiles(BuildContext context) async {
    if (_initializingProfiles || _profilesInitialized) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _initializingProfiles = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider =
          Provider.of<ChildProfileProvider>(context, listen: false);
      final parentUid = authProvider.firebaseUser?.uid;

      await profileProvider.initialize(parentUid: parentUid);

      final activeProfile = profileProvider.activeProfile;
      if (activeProfile != null && context.mounted) {
        await ActiveProfileScope.apply(
          context,
          activeProfile,
          parentUid: parentUid,
          syncService: _childProfileSyncService,
        );
      }
    } catch (e) {
      debugPrint('Error initializing child profiles: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initializingProfiles = false;
          _profilesInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ChildProfileProvider>(
      builder: (context, authProvider, profileProvider, _) {
        try {
          // Sync legacy player data when user becomes authenticated
          if (authProvider.isAuthenticated && !_hasSynced && !_syncing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _syncPlayerData(context);
              }
            });
          }

          if (!_profilesInitialized && !_initializingProfiles) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeChildProfiles(context);
              }
            });
          }

          if (authProvider.initializing ||
              _syncing ||
              _initializingProfiles ||
              !profileProvider.initialized ||
              (authProvider.isAuthenticated && !_hasSynced)) {
            return const SparkOverlaySuppressor(
              child: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (!authProvider.isAuthenticated) {
            return const SignInScreen();
          }

          if (!widget.hasSeenOnboarding) {
            return const OnboardingScreen();
          }

          if (!profileProvider.hasActiveProfile) {
            return const ChildProfileSelectionScreen();
          }

          // Check if user has selected a character (non-blocking, with timeout)
          if (_hasSynced && !_checkingCharacter && !_hasCharacter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _checkCharacter(context);
              }
            });
          }

          return Builder(
            builder: (context) {
              try {
                return const _AchievementOverlayScope(
                  child: MapScreen(),
                );
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
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'שגיאה בטעינת המפה',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
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
                                    builder: (_) => const MapScreen(),
                                  ),
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
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
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

/// Wraps the main app content and sets the achievement-unlocked callback
/// so the glassmorphism toast shows from any screen (Home, Image Quiz, etc.).
class _AchievementOverlayScope extends StatefulWidget {
  const _AchievementOverlayScope({required this.child});

  final Widget child;

  @override
  State<_AchievementOverlayScope> createState() =>
      _AchievementOverlayScopeState();
}

class _AchievementOverlayScopeState extends State<_AchievementOverlayScope> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachCallback());
  }

  void _attachCallback() {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final achievementService = context.read<AchievementService>();
    // Keep a reference to SparkOverlayController so we can trigger celebration
    // from here as well — this makes the global toast + spark dance guaranteed
    // even if AchievementService's internal reference is ever null.
    final sparkController = context.read<SparkOverlayController>();

    achievementService.setAchievementUnlockedCallback((achievement) {
      if (!mounted) return;

      // Trigger the global spark celebration animation.
      sparkController.markCelebrating();

      _overlayEntry?.remove();
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AchievementNotification(
              achievement: achievement,
              onDismiss: () {
                entry.remove();
                if (_overlayEntry == entry) _overlayEntry = null;
                // Return Spark to idle after the toast is dismissed.
                sparkController.markIdle();
              },
            ),
          ),
        ),
      );
      _overlayEntry = entry;
      overlay.insert(entry);
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
