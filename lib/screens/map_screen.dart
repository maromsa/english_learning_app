// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/character_provider.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/screens/ai_conversation_screen.dart';
import 'package:english_learning_app/screens/ai_practice_pack_screen.dart';
import 'package:english_learning_app/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background_music_service.dart';
import '../services/daily_reward_service.dart';
import '../services/level_repository.dart';
import '../services/local_user_data_service.dart';
import '../services/local_user_service.dart';
import '../services/level_progress_service.dart';
import '../providers/auth_provider.dart';
import '../providers/user_session_provider.dart';
import '../utils/page_transitions.dart';
import '../utils/route_observer.dart';
import '../widgets/character_avatar.dart';
import '../widgets/user/current_user_avatar.dart';
import 'ai_adventure_screen.dart';
import 'daily_missions_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'user_selection_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  List<LevelData> levels = [];
  late final DailyRewardService _dailyRewardService;
  late final LevelRepository _levelRepository;
  late final LocalUserDataService _localUserDataService;
  late final LocalUserService _localUserService;
  final LevelProgressService _levelProgressService = LevelProgressService();
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  bool _isLocalUser = false;
  int _selectedNavIndex = 0; // For bottom navigation
  UserSessionProvider? _userSessionProvider;

  // New layout constants for snake algorithm
  final double _levelHeightSpacing = 140.0; // Vertical gap between nodes
  final double _pathAmplitude = 80.0; // How wide the snake path is
  final double _topPadding = 160.0; // Space for AppBar & Stats
  final double _bottomPadding = 120.0; // Space for BottomNavBar

  late ScrollController _scrollController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _dailyRewardService = DailyRewardService();
    _levelRepository = LevelRepository();
    _localUserDataService = LocalUserDataService();
    _localUserService = LocalUserService();

    // Initialize scroll controller and animation
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Don't block UI - play music in background
      BackgroundMusicService().playMapLoop().catchError((error) {
        debugPrint('Failed to play map loop: $error');
      });
      _loadCurrentUser();
    });
    _initialize();

    // Listen to user session changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _userSessionProvider =
            Provider.of<UserSessionProvider>(context, listen: false);
        _userSessionProvider?.addListener(_onUserSessionChanged);
      }
    });
  }

  void _onUserSessionChanged() {
    if (!mounted) return;
    // Reload user data when session changes
    _loadCurrentUser().then((_) {
      if (mounted) {
        _loadProgress();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    RouteObserverService.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Called when returning to this route from another route
    // Add a small delay to check if we're actually returning to map
    // or if we're just closing a modal before navigating to AI screen
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      // Check if we're still on the map screen (not navigating away)
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        // We can still pop, meaning we're not at the root
        // This might mean we're about to navigate to another screen
        // Don't resume music yet - wait a bit more
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          // Check again - if we're still on map, resume music
          if (navigator.canPop()) {
            // Still can pop, probably navigating away - don't resume
            return;
          }
          // Can't pop anymore, we're at root - resume music
          BackgroundMusicService().playMapLoop().catchError((error) {
            debugPrint('Failed to resume map loop: $error');
          });
        });
      } else {
        // Can't pop - we're at the root, definitely returning to map
        // Resume music when returning to map screen
        BackgroundMusicService().playMapLoop().catchError((error) {
          debugPrint('Failed to resume map loop: $error');
        });
      }
    });

    // Scroll to current level when returning to map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToCurrentLevel();
        }
      });
    });
  }

  @override
  void didPushNext() {
    // Called when navigating away from this route
    // Stop music when leaving map screen
    BackgroundMusicService().stop().catchError((error) {
      debugPrint('Failed to stop map music: $error');
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userSessionProvider =
          Provider.of<UserSessionProvider>(context, listen: false);
      final currentSessionUser = userSessionProvider.currentUser;

      if (currentSessionUser != null) {
        _currentUserId = currentSessionUser.id;
        _isLocalUser = !currentSessionUser.isGoogle;
      } else {
        // Fallback to old logic if session provider doesn't have a user
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated && authProvider.firebaseUser != null) {
          _currentUserId = authProvider.firebaseUser!.uid;
          _isLocalUser = false;
        } else {
          final localUser = await _localUserService.getActiveUser();
          if (localUser != null) {
            _currentUserId = localUser.id;
            _isLocalUser = true;
          }
        }
      }

      // Update coin provider with user ID
      if (_currentUserId != null) {
        final coinProvider = Provider.of<CoinProvider>(context, listen: false);
        coinProvider.setUserId(_currentUserId, isLocalUser: _isLocalUser);
        await coinProvider.loadCoins();
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _initialize() async {
    try {
      // Add timeout to prevent hanging
      final loadedLevels = await _levelRepository
          .loadLevels()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Level loading timed out, using fallback levels');
        return <LevelData>[];
      });
      levels = loadedLevels.isEmpty ? _fallbackLevels() : loadedLevels;

      // Load progress with timeout - don't let it block
      try {
        await _loadProgress().timeout(const Duration(seconds: 5),
            onTimeout: () {
          debugPrint('Progress loading timed out, continuing anyway');
          _updateUnlockStatuses(); // Ensure unlock statuses are updated
        });
      } catch (e) {
        debugPrint('Error in _loadProgress: $e');
        _updateUnlockStatuses(); // Ensure unlock statuses are updated
      }

      // Always set loading to false, even if there were errors
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = loadedLevels.isEmpty
              ? 'נשתמש במסלול ברירת המחדל עד לחיבור לשרת.'
              : null;
        });
        // Scroll to current level after build
        // Use a small delay to ensure scroll controller is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _scrollToCurrentLevel();
            }
          });
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing MapScreen: $e');
      debugPrint('Stack trace: $stackTrace');
      levels = _fallbackLevels();
      _updateUnlockStatuses(); // Ensure unlock statuses are updated
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'לא ניתן לטעון את המפה מהקובץ. מוצג מסלול ברירת מחדל.';
        });
      }
    }
  }

  List<LevelData> _fallbackLevels() {
    WordData createWord(String word, String hint, String assetFileName) {
      return WordData(
        word: word,
        searchHint: hint,
        imageUrl: 'assets/images/words/$assetFileName',
      );
    }

    return [
      LevelData(
        id: 'fallback_fruits',
        name: 'שלב 1: פירות',
        description: 'למדו מילים מתוקות של פירות צבעוניים',
        unlockStars: 0,
        reward: 30,
        positionX: 0.6,
        positionY: 0.85,
        isUnlocked: true,
        words: [
          createWord('Apple', 'ripe red apple fruit', 'apple.png'),
          createWord('Banana', 'yellow banana fruit bunch', 'banana.png'),
          createWord('Orange', 'fresh orange citrus fruit', 'orange.png'),
          createWord('Strawberry', 'sweet strawberry fruit', 'strawberry.png'),
          createWord('Pineapple', 'pineapple tropical fruit', 'pineapple.png'),
          createWord('Grapes', 'grapes fruit bunch purple', 'grapes.png'),
        ],
      ),
      LevelData(
        id: 'fallback_animals',
        name: 'שלב 2: חיות',
        description: 'מי נובח ומי מגרגר?',
        unlockStars: 3,
        reward: 45,
        positionX: 0.2,
        positionY: 0.68,
        words: [
          createWord('Dog', 'happy dog pet', 'dog.png'),
          createWord('Cat', 'curious cat kitty', 'cat.png'),
          createWord('Elephant', 'elephant safari animal', 'elephant.png'),
          createWord('Lion', 'roaring lion wildlife', 'lion.png'),
          createWord('Penguin', 'penguin waddling arctic', 'penguin.png'),
          createWord('Monkey', 'playful monkey jungle', 'monkey.png'),
        ],
      ),
      LevelData(
        id: 'fallback_magic_items',
        name: 'שלב 3: פריטי קסם',
        description: 'תלבשו את הפריט הנכון למשימה',
        unlockStars: 7,
        reward: 55,
        positionX: 0.74,
        positionY: 0.46,
        words: [
          createWord('Magic Hat', 'wizard magic hat', 'magic_hat.png'),
          createWord(
            'Crystal Ball',
            'glowing crystal ball magic',
            'crystal_ball.png',
          ),
          createWord('Spell Book', 'ancient spell book', 'spell_book.png'),
          createWord('Magic Wand', 'sparkling magic wand', 'magic_wand.png'),
          createWord('Potion', 'magical potion bottle', 'potion.png'),
          createWord(
            'Flying Broom',
            'witch flying broomstick',
            'flying_broom.png',
          ),
        ],
      ),
      LevelData(
        id: 'fallback_power_items',
        name: 'שלב 4: כוח מיוחד',
        description: 'אספו פריטי כוח מיוחדים',
        unlockStars: 11,
        reward: 65,
        positionX: 0.32,
        positionY: 0.32,
        words: [
          createWord('Power Sword', 'shining power sword', 'power_sword.png'),
          createWord(
            'Treasure Map',
            'ancient treasure map',
            'treasure_map.png',
          ),
          createWord('Hero Shield', 'bright hero shield', 'hero_shield.png'),
          createWord(
            'Energy Gauntlet',
            'futuristic energy gauntlet',
            'energy_gauntlet.png',
          ),
          createWord(
            'Magic Amulet',
            'glowing magic amulet',
            'magic_amulet.png',
          ),
          createWord('Dragon Armor', 'dragon scale armor', 'dragon_armor.png'),
        ],
      ),
      LevelData(
        id: 'fallback_vehicles',
        name: 'שלב 5: כלי תחבורה',
        description: 'איזה כלי יביא אתכם להרפתקה הבאה?',
        unlockStars: 15,
        reward: 75,
        positionX: 0.15,
        positionY: 0.18,
        words: [
          createWord('Car', 'red family car road', 'car.png'),
          createWord('Train', 'passenger train railway', 'train.png'),
          createWord('Helicopter', 'helicopter flying sky', 'helicopter.png'),
          createWord(
            'Submarine',
            'yellow submarine underwater',
            'submarine.png',
          ),
          createWord('Bicycle', 'kid bicycle ride', 'bicycle.png'),
          createWord(
            'Hot Air Balloon',
            'colorful hot air balloon',
            'hot_air_balloon.png',
          ),
        ],
      ),
      LevelData(
        id: 'fallback_space',
        name: 'שלב 6: חקר החלל',
        description: 'צאו למסע בין הכוכבים',
        unlockStars: 20,
        reward: 90,
        positionX: 0.85,
        positionY: 0.18,
        words: [
          createWord('Astronaut', 'astronaut space suit', 'astronaut.png'),
          createWord('Rocket', 'rocket launch space', 'rocket.png'),
          createWord('Moon', 'full moon night sky', 'moon.png'),
          createWord(
            'Space Station',
            'international space station',
            'space_station.png',
          ),
          createWord('Satellite', 'satellite orbit earth', 'satellite.png'),
          createWord('Mars Rover', 'mars rover exploration', 'mars_rover.png'),
        ],
      ),
    ];
  }

  Future<void> _loadProgress() async {
    try {
      if (!mounted) return;

      // Add timeout to SharedPreferences access
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      if (!mounted) return;

      final coinProvider = Provider.of<CoinProvider>(context, listen: false);
      // Coin loading already has timeout in main.dart, but add another safety check
      try {
        await coinProvider.loadCoins().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Coin loading in MapScreen timed out: $e');
        // Continue without coins
      }

      // Load progress with timeout
      if (_currentUserId != null) {
        // Load stars per user
        if (_isLocalUser) {
          final allStars = await _localUserDataService
              .getAllLevelStars(_currentUserId!)
              .timeout(const Duration(seconds: 2));
          for (final level in levels) {
            level.stars = allStars[level.id] ?? 0;
          }
        } else {
          // For Firebase users, load from SharedPreferences with user prefix
          for (int i = 0; i < levels.length; i++) {
            if (!mounted) return;
            final level = levels[i];
            try {
              // Try user-specific key first, then legacy keys
              final persistedStars = prefs.getInt(
                      'user_${_currentUserId}_${_starsKey(level.id)}') ??
                  prefs.getInt(_starsKey(level.id)) ??
                  prefs.getInt(_legacyStarsKey(i)) ??
                  0;
              level.stars = persistedStars;
              debugPrint('Loaded stars for ${level.name}: ${level.stars}');
            } catch (e) {
              debugPrint('Error loading stars for level ${level.id}: $e');
              // Continue with default stars
            }
          }
        }
      } else {
        // Fallback to legacy loading for backward compatibility
        for (int i = 0; i < levels.length; i++) {
          if (!mounted) return;
          final level = levels[i];
          try {
            final persistedStars = prefs.getInt(_starsKey(level.id)) ??
                prefs.getInt(_legacyStarsKey(i));
            if (persistedStars != null) {
              level.stars = persistedStars;
            }
          } catch (e) {
            debugPrint('Error loading stars for level ${level.id}: $e');
            // Continue with default stars
          }
        }
      }

      // If user has coins but no stars, try to calculate stars from total coins
      // This handles the case where user earned coins but stars weren't saved
      await _recalculateStarsFromCoins();

      _updateUnlockStatuses();
      if (mounted) {
        setState(() {});
      }
    } on TimeoutException {
      debugPrint('Progress loading timed out, using defaults');
      // Continue anyway - use default progress
      await _recalculateStarsFromCoins();
      _updateUnlockStatuses();
      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading progress: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continue anyway - use default progress
      await _recalculateStarsFromCoins();
      _updateUnlockStatuses();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _saveProgress() async {
    debugPrint('=== Saving Progress ===');
    debugPrint('Current user ID: $_currentUserId');
    debugPrint('Is local user: $_isLocalUser');

    if (_currentUserId == null) {
      // Fallback to legacy saving
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < levels.length; i++) {
        final level = levels[i];
        await prefs.setInt(_starsKey(level.id), level.stars);
        await prefs.remove(_legacyStarsKey(i));
        debugPrint(
            'Saved ${level.name}: ${level.stars} stars (legacy, no user)');
      }
      return;
    }

    if (_isLocalUser) {
      // Save stars per user for local users
      for (final level in levels) {
        await _localUserDataService.saveLevelStars(
          _currentUserId!,
          level.id,
          level.stars,
        );
        debugPrint(
            'Saved ${level.name}: ${level.stars} stars (local user: $_currentUserId)');
      }
    } else {
      // For Firebase users, save to SharedPreferences with user prefix
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < levels.length; i++) {
        final level = levels[i];
        final key = 'user_${_currentUserId}_${_starsKey(level.id)}';
        await prefs.setInt(key, level.stars);
        await prefs.remove(_legacyStarsKey(i));
        debugPrint(
            'Saved ${level.name}: ${level.stars} stars (Firebase user: $_currentUserId, key: $key)');
      }
    }
    debugPrint('=== Progress Saved ===');
  }

  String _starsKey(String levelId) => 'level_${levelId}_stars';
  String _legacyStarsKey(int index) => 'level_${index}_stars';

  /// Recalculate stars from total coins if user has coins but no stars
  /// This fixes the issue where coins were earned but stars weren't saved
  Future<void> _recalculateStarsFromCoins() async {
    try {
      final coinProvider = Provider.of<CoinProvider>(context, listen: false);
      final totalCoins = coinProvider.coins;
      final totalStars = _totalStars;

      debugPrint('=== Recalculating Stars from Coins ===');
      debugPrint('Total coins: $totalCoins');
      debugPrint('Total stars: $totalStars');

      // If user has coins but very few or no stars, distribute coins to levels
      // This happens when coins were earned but stars weren't saved properly
      if (totalCoins > 0 && totalStars < (totalCoins / 30).ceil()) {
        debugPrint(
            'User has $totalCoins coins but only $totalStars stars. Recalculating...');

        // Distribute coins to levels: each level can get up to 30 coins (3 stars max)
        int remainingCoins = totalCoins;
        bool updatedAny = false;

        for (final level in levels) {
          if (remainingCoins <= 0) break;

          // Give each level up to 30 coins (3 stars max)
          final coinsForThisLevel = remainingCoins > 30 ? 30 : remainingCoins;
          final starsForThisLevel =
              ((coinsForThisLevel / 10).floor()).clamp(0, 3).toInt();

          // Only update if we're giving more stars than currently have
          if (starsForThisLevel > level.stars) {
            level.stars = starsForThisLevel;
            updatedAny = true;
            debugPrint(
                'Updated ${level.name}: ${level.stars} stars (from $coinsForThisLevel coins)');
          }

          remainingCoins -= coinsForThisLevel;
        }

        // Save the recalculated stars
        if (updatedAny) {
          await _saveProgress();
          debugPrint('✅ Recalculated and saved stars from coins');
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        debugPrint(
            'No recalculation needed: $totalCoins coins, $totalStars stars');
      }
    } catch (e) {
      debugPrint('Error recalculating stars from coins: $e');
    }
  }

  /// Update unlock statuses based on level completion (not stars)
  /// A level is unlocked only if the previous level is completed
  Future<void> _updateUnlockStatuses() async {
    if (_currentUserId == null) {
      // Fallback: unlock first level only
      if (levels.isNotEmpty) {
        levels.first.isUnlocked = true;
        for (int i = 1; i < levels.length; i++) {
          levels[i].isUnlocked = false;
        }
      }
      return;
    }

    // First level is always unlocked
    if (levels.isNotEmpty) {
      levels.first.isUnlocked = true;
    }

    // Check each subsequent level - unlock only if previous is completed
    for (int i = 1; i < levels.length; i++) {
      final previousLevel = levels[i - 1];
      final isPreviousCompleted = await _levelProgressService.isLevelCompleted(
        _currentUserId!,
        previousLevel.id,
        previousLevel.words.length,
        isLocalUser: _isLocalUser,
      );
      levels[i].isUnlocked = isPreviousCompleted;

      debugPrint(
        'Level ${levels[i].name}: Unlocked=${levels[i].isUnlocked} '
        '(Previous ${previousLevel.name} completed: $isPreviousCompleted)',
      );
    }
  }

  int get _totalStars => levels.fold<int>(0, (sum, level) => sum + level.stars);

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(const SettingsScreen()),
    );
    if (!mounted) return;
    await _loadProgress();
  }

  void _showLockedMessage(LevelData level) async {
    // Find previous level
    final levelIndex = levels.indexWhere((l) => l.id == level.id);
    if (levelIndex <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('השלב הזה נעול.'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    final previousLevel = levels[levelIndex - 1];

    // Check if previous level is completed
    if (_currentUserId != null) {
      final isCompleted = await _levelProgressService.isLevelCompleted(
        _currentUserId!,
        previousLevel.id,
        previousLevel.words.length,
        isLocalUser: _isLocalUser,
      );

      if (!isCompleted) {
        final completedWords = await _levelProgressService.getCompletedWords(
          _currentUserId!,
          previousLevel.id,
          isLocalUser: _isLocalUser,
        );
        final remaining = previousLevel.words.length - completedWords.length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'סיימו את ${previousLevel.name} כדי לפתוח את ${level.name}.\n'
              'נותרו ${remaining} מילים להשלמה.',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${level.name} נעול.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'סיימו את ${previousLevel.name} כדי לפתוח את ${level.name}.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _claimDailyReward() async {
    final result = await _dailyRewardService.claimReward();
    if (!mounted) {
      return;
    }

    if (result.claimed) {
      await Provider.of<CoinProvider>(
        context,
        listen: false,
      ).addCoins(result.reward);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎁 קיבלת ${result.reward} מטבעות! רצף יומי: ${result.streak}',
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('כבר אספת את המתנה היום! רצף יומי: ${result.streak}'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    }
  }

  void _navigateToLevel(LevelData level, int levelIndex) async {
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final backgroundMusic = BackgroundMusicService();
    // Load level start coins first, then set it
    await coinProvider.loadLevelStartCoins(level.id);
    await coinProvider.startLevel(level.id);

    try {
      await backgroundMusic.fadeOut();
      await backgroundMusic.stop();
    } catch (error, stackTrace) {
      debugPrint('Failed to stop map music before entering level: $error');
      debugPrint('$stackTrace');
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      PageTransitions.fadeScale(
        MyHomePage(
          title: level.name,
          levelId: level.id,
          wordsForLevel: level.words,
        ),
      ),
    );

    // Music will be resumed automatically by RouteAware when returning to map

    final coinsEarnedInLevel = coinProvider.levelCoins;
    final levelData = levels[levelIndex];
    final previousStars = levelData.stars;

    debugPrint('=== Level Completion Debug ===');
    debugPrint('Level: ${levelData.name}');
    debugPrint('Coins earned in level: $coinsEarnedInLevel');
    debugPrint('Previous stars: $previousStars');
    debugPrint('Total coins: ${coinProvider.coins}');
    debugPrint(
        'Coins at level start: ${coinProvider.coins - coinsEarnedInLevel}');

    // Calculate stars: 10 coins = 1 star, max 3 stars per level
    final starsEarned = ((coinsEarnedInLevel / 10).floor()).clamp(0, 3).toInt();

    debugPrint('Stars earned: $starsEarned');

    // Always update stars if we earned more than before, or if we have any stars and didn't have any before
    // This ensures stars are always saved when earned
    final bool shouldUpdateStars =
        starsEarned >= previousStars && starsEarned > 0;
    final bool shouldReward =
        shouldUpdateStars && previousStars == 0 && levelData.reward > 0;

    if (shouldUpdateStars) {
      levelData.stars = starsEarned;
      debugPrint('Updated stars to: ${levelData.stars}');
    } else {
      debugPrint(
          'No star update needed (earned: $starsEarned, previous: $previousStars)');
    }

    // Force save even if stars didn't change but we have coins
    if (coinsEarnedInLevel > 0 && levelData.stars == 0) {
      // If we earned coins but stars are still 0, something is wrong
      debugPrint('WARNING: Earned $coinsEarnedInLevel coins but stars are 0!');
      // Recalculate and force update
      final recalculatedStars =
          ((coinsEarnedInLevel / 10).floor()).clamp(0, 3).toInt();
      if (recalculatedStars > 0) {
        levelData.stars = recalculatedStars;
        debugPrint('Force updated stars to: ${levelData.stars}');
      }
    }

    // Reset level start coins for next time
    await coinProvider.resetLevelStartCoins(level.id);

    _updateUnlockStatuses();
    setState(() {});
    await _saveProgress();

    if (mounted) {
      // Show feedback about stars earned
      if (shouldUpdateStars) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              starsEarned == 3
                  ? '⭐ כל הכבוד! קיבלתם 3 כוכבים! ($coinsEarnedInLevel מטבעות)'
                  : '⭐ קיבלתם $starsEarned כוכבים! ($coinsEarnedInLevel מטבעות)',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (coinsEarnedInLevel > 0) {
        // Show progress if no new stars but earned coins
        final coinsNeeded = 10 - (coinsEarnedInLevel % 10);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'קיבלתם $coinsEarnedInLevel מטבעות. עוד $coinsNeeded מטבעות לכוכב הבא!',
            ),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (shouldReward) {
        await coinProvider.addCoins(levelData.reward);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎁 בונוס! קיבלתם ${levelData.reward} מטבעות נוספים!',
              ),
              backgroundColor: Colors.amber.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _openDailyMissions() async {
    // Music will be stopped/resumed automatically by RouteAware
    final result = await Navigator.push(
      context,
      PageTransitions.slideFromRight(const DailyMissionsScreen()),
    );

    if (!mounted) {
      return;
    }

    if (result == 'lightning') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'פתחו שלב ובחרו באפשרות "ריצת ברק" כדי להשלים את המשימה!',
          ),
          backgroundColor: Colors.blueGrey.shade700,
        ),
      );
    } else if (result == 'quiz') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'היכנסו לשלב ולחצו על אייקון החידון כדי לשחק מיד.',
          ),
          backgroundColor: Colors.blueGrey.shade700,
        ),
      );
    }
  }

  void _handleAiShortcut(_QuickAiAction action) async {
    // Stop music before navigating to AI screen
    BackgroundMusicService().stop().catchError((error) {
      debugPrint('Failed to stop music before AI shortcut: $error');
    });

    switch (action) {
      case _QuickAiAction.chatBuddy:
        await Navigator.push(
          context,
          PageTransitions.slideFromRight(const AiConversationScreen()),
        );
        break;
      case _QuickAiAction.practicePack:
        await Navigator.push(
          context,
          PageTransitions.slideFromRight(const AiPracticePackScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show loading indicator if still initializing
    if (_isLoading) {
      return Scaffold(
        body: Container(
          color: Colors.blue.shade900,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // Defensive check - ensure we have a valid context
    if (!mounted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final coinProvider = context.watch<CoinProvider>();
      final colorScheme = Theme.of(context).colorScheme;

      return Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true, // Allows map to go behind bottom nav

        // 1. Minimal AppBar - Redesigned by Gemini 3 Pro
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: const Padding(
            padding: EdgeInsets.all(4.0),
            child: CurrentUserAvatar(),
          ),
          leadingWidth: 180,
          title: const _MapTitleCard(),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings, color: Colors.grey),
              ),
              onPressed: () async {
                // Music will be stopped/resumed automatically by RouteAware
                await Navigator.push(
                  context,
                  PageTransitions.slideFromRight(const SettingsScreen()),
                );

                if (mounted) {
                  await _loadProgress();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),

        // 2. Bottom Navigation for Secondary Actions - Redesigned by Gemini 3 Pro
        bottomNavigationBar: _buildBottomNav(context),

        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : levels.isEmpty
                ? const Center(
                    child: Text(
                      'אין שלבים זמינים כרגע. נסו שוב מאוחר יותר.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Stack(
                    children: [
                      // 1. Fixed Background (Does not scroll, parallax effect)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: Image.asset(
                            'assets/images/map/map_background.jpg',
                            fit: BoxFit.cover,
                            cacheWidth: 1920,
                            cacheHeight: 1080,
                            // Use ColorFilter to dim background slightly for better contrast
                            color: Colors.white.withValues(alpha: 0.85),
                            colorBlendMode: BlendMode.modulate,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.blue.shade300,
                                    Colors.purple.shade300
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. Scrollable Map Content
                      SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = MediaQuery.of(context).size;
                            final totalMapHeight = _topPadding +
                                (levels.length * _levelHeightSpacing) +
                                _bottomPadding;

                            return SizedBox(
                              height: math.max(size.height, totalMapHeight),
                              width: size.width,
                              child: Stack(
                                children: [
                                  // A. The Path Line (Drawn behind nodes)
                                  CustomPaint(
                                    size: Size(size.width, totalMapHeight),
                                    painter: _MapPathPainter(
                                      levelCount: levels.length,
                                      getPosition: (i) =>
                                          _calculateLevelPosition(
                                              i, size.width),
                                      completedColor: const Color(0xFF50C878),
                                      lockedColor:
                                          Colors.grey.withValues(alpha: 0.5),
                                      levels: levels,
                                    ),
                                  ),

                                  // B. The Level Nodes
                                  ...List.generate(levels.length, (index) {
                                    final level = levels[index];
                                    final pos = _calculateLevelPosition(
                                        index, size.width);

                                    // Determine status
                                    final isCompleted = level.stars > 0;
                                    final isCurrent =
                                        level.isUnlocked && !isCompleted;
                                    // Logic: if previous level is not completed, this is not current
                                    bool actualIsCurrent = isCurrent;
                                    if (index > 0 &&
                                        !_isLevelCompleted(levels[index - 1])) {
                                      actualIsCurrent = false;
                                    }

                                    return Positioned(
                                      left: pos.dx - 40, // Center the 80px node
                                      top: pos.dy - 40,
                                      child: _LevelNode(
                                        levelNumber: index + 1,
                                        level: level,
                                        isCurrent: actualIsCurrent,
                                        isCompleted: isCompleted,
                                        animation: actualIsCurrent
                                            ? _pulseController
                                            : null,
                                        onTap: () =>
                                            _navigateToLevel(level, index),
                                        onLockedTap: () =>
                                            _showLockedMessage(level),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // 3. Floating Stats Pill (Fixed Position, safe from scrolling)
                      Positioned(
                        top: kToolbarHeight + 20, // Below AppBar
                        left: 20,
                        child: _StatsPill(
                          totalStars: _totalStars,
                          coins: coinProvider.coins,
                        ),
                      ),

                      // Error banner
                      if (_errorMessage != null && !_isLoading)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 100, // Above bottom nav
                          child: _InfoBanner(message: _errorMessage!),
                        ),
                    ],
                  ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error in MapScreen build: $e');
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
                    if (mounted) {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _initialize();
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
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBar(
          height: 70,
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: _handleBottomNav,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'מפה',
            ),
            NavigationDestination(
              icon: Icon(Icons.store_outlined),
              selectedIcon: Icon(Icons.store),
              label: 'חנות',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'משימות',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToShop() async {
    // Music will be stopped/resumed automatically by RouteAware
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(const ShopScreen()),
    );
  }

  void _handleBottomNav(int index) async {
    setState(() => _selectedNavIndex = index);
    switch (index) {
      case 0: // Map - already here
        break;
      case 1: // Shop
        _navigateToShop();
        break;
      case 2: // AI Tools
        _showAiToolsMenu();
        break;
      case 3: // Missions
        await _openDailyMissions();
        break;
    }
  }

  void _showAiToolsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat, size: 32),
                title: const Text('חבר שיחה של ספרק'),
                subtitle: const Text('שיחה אינטראקטיבית עם AI'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    PageTransitions.slideFromRight(
                        const AiConversationScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, size: 32),
                title: const Text('מסע קסם עם Spark'),
                subtitle: const Text('הרפתקה אינטראקטיבית'),
                onTap: () {
                  Navigator.pop(context);
                  // Stop music before navigating to AI screen
                  BackgroundMusicService().stop().catchError((error) {
                    debugPrint(
                        'Failed to stop music before AI adventure: $error');
                  });
                  Navigator.push(
                    context,
                    PageTransitions.fadeScale(
                      AiAdventureScreen(
                        levels: List<LevelData>.unmodifiable(levels),
                        totalStars: _totalStars,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.school, size: 32),
                title: const Text('חבילת אימון AI'),
                subtitle: const Text('תרגול מותאם אישית'),
                onTap: () {
                  Navigator.pop(context);
                  // Stop music before navigating to AI screen
                  BackgroundMusicService().stop().catchError((error) {
                    debugPrint(
                        'Failed to stop music before AI practice pack: $error');
                  });
                  Navigator.push(
                    context,
                    PageTransitions.slideFromRight(
                        const AiPracticePackScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    RouteObserverService.routeObserver.unsubscribe(this);
    // Unsubscribe from user session provider
    _userSessionProvider?.removeListener(_onUserSessionChanged);
    _scrollController.dispose();
    _pulseController.dispose();
    // Stop music when leaving MapScreen
    BackgroundMusicService().stop().catchError((e) {
      debugPrint('Failed to stop music on dispose: $e');
    });
    super.dispose();
  }

  // Calculate level position using sine wave algorithm (snake pattern)
  Offset _calculateLevelPosition(int index, double screenWidth) {
    // Center X coordinate
    double centerX = screenWidth / 2;

    // Calculate horizontal offset using Sine wave (alternating left and right)
    double xOffset = math.sin(index * math.pi / 1.5) * _pathAmplitude;

    double x = centerX + xOffset;
    double y = _topPadding + (index * _levelHeightSpacing);

    return Offset(x, y);
  }

  // Scroll to current level after levels are loaded
  void _scrollToCurrentLevel() {
    if (levels.isEmpty) return;

    // Wait for scroll controller to be ready
    if (!_scrollController.hasClients) {
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _scrollController.hasClients) {
          _scrollToCurrentLevel();
        }
      });
      return;
    }

    // Find the first unlocked level that is not completed (current level)
    int currentIndex =
        levels.indexWhere((l) => l.isUnlocked && !_isLevelCompleted(l));

    if (currentIndex == -1) {
      // All levels are completed, start at the top (first level)
      // Don't scroll - just ensure we're at the top
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    // Calculate position to show the current level near the top
    // Position it at about 1/4 from the top so user can see previous levels too
    final screenHeight = MediaQuery.of(context).size.height;
    double targetOffset = (_topPadding + (currentIndex * _levelHeightSpacing)) -
        (screenHeight * 0.25);

    // Ensure we don't scroll below 0 (top of map)
    targetOffset =
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    // If we're already close to the target, don't animate
    final currentOffset = _scrollController.offset;
    if ((currentOffset - targetOffset).abs() < 50) {
      return; // Already close enough
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );
  }

  bool _isLevelCompleted(LevelData level) {
    return level.stars > 0;
  }
}

// --- Enhanced Level Node Widget - Redesigned by Gemini 3 Pro V2 ---

class _LevelNode extends StatelessWidget {
  final int levelNumber;
  final LevelData level;
  final bool isCurrent;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback? onLockedTap;
  final Animation<double>? animation;

  const _LevelNode({
    required this.levelNumber,
    required this.level,
    required this.isCurrent,
    required this.isCompleted,
    required this.onTap,
    this.onLockedTap,
    this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLocked = !level.isUnlocked;

    // Colors
    final Color lockedColor = Colors.grey.shade400;
    final Color activeColor = const Color(0xFF4A90E2); // Blue
    final Color completedColor = const Color(0xFF50C878); // Green

    Color baseColor =
        isLocked ? lockedColor : (isCompleted ? completedColor : activeColor);

    return GestureDetector(
      onTap: () {
        if (!isLocked) {
          onTap();
        } else {
          onLockedTap?.call();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The Circle Node
          AnimatedBuilder(
            animation: animation ?? const AlwaysStoppedAnimation(0),
            builder: (context, child) {
              double scale = 1.0;
              double elevation = 4.0;

              if (isCurrent && animation != null) {
                scale = 1.0 +
                    (animation!.value * 0.15); // Pulse between 1.0 and 1.15
                elevation = 4.0 + (animation!.value * 6);
              }

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withValues(alpha: 0.4),
                        blurRadius: elevation,
                        offset: Offset(0, elevation / 2),
                      )
                    ],
                  ),
                  child: Center(
                    child: isLocked
                        ? const Icon(Icons.lock, color: Colors.white, size: 32)
                        : isCompleted
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 40)
                            : Text(
                                "$levelNumber",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Level Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              level.name,
              style: TextStyle(
                color: isLocked ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          // Star Rating (if completed)
          if (isCompleted && level.stars > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Icon(
                          Icons.star,
                          size: 14,
                          color: i < level.stars
                              ? const Color(0xFFFFD93D)
                              : Colors.grey.shade300,
                        )),
              ),
            )
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// --- Components - Redesigned by Gemini 3 Pro ---

class _MapTitleCard extends StatelessWidget {
  const _MapTitleCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            provider.hasCharacter
                ? "המסע של ${provider.character!.characterName}"
                : "מסע המילים",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      },
    );
  }
}

class _StatsPill extends StatelessWidget {
  final int totalStars;
  final int coins;

  const _StatsPill({
    required this.totalStars,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatItem(
            icon: Icons.monetization_on,
            color: Colors.yellow.shade700,
            value: coins.toString(),
          ),
          Container(
            height: 20,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          _StatItem(
            icon: Icons.star_rounded,
            color: Colors.amber,
            value: totalStars.toString(),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

enum _QuickAiAction { chatBuddy, practicePack }

// -----------------------------------------------------------------------------
// Custom Painter for the Map Path
// -----------------------------------------------------------------------------

class _MapPathPainter extends CustomPainter {
  final int levelCount;
  final Offset Function(int) getPosition;
  final Color completedColor;
  final Color lockedColor;
  final List<LevelData> levels;

  _MapPathPainter({
    required this.levelCount,
    required this.getPosition,
    required this.completedColor,
    required this.lockedColor,
    required this.levels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // Draw dashed line between levels
    for (int i = 0; i < levelCount - 1; i++) {
      final start = getPosition(i);
      final end = getPosition(i + 1);

      // Bezier Curve for smooth path
      Path path = Path();
      path.moveTo(start.dx, start.dy);

      // Control point creates the curve.
      // Simple Cubic Bezier for "S" shapes
      path.cubicTo(
        start.dx,
        start.dy + 60, // Control point 1 (down from start)
        end.dx,
        end.dy - 60, // Control point 2 (up from end)
        end.dx,
        end.dy, // End point
      );

      // Choose color based on level completion
      final isSegmentCompleted = i < levels.length &&
          i + 1 < levels.length &&
          levels[i].stars > 0 &&
          levels[i + 1].stars > 0;
      paint.color = isSegmentCompleted ? completedColor : lockedColor;

      _drawDashedLine(canvas, path, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Path path, Paint paint) {
    // Simple implementation of dashed path
    final ui.PathMetrics pathMetrics = path.computeMetrics();
    for (ui.PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double length = 10.0; // Dash length
        final double gap = 10.0; // Gap length

        canvas.drawPath(
          pathMetric.extractPath(distance, distance + length),
          paint,
        );
        distance += (length + gap);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
