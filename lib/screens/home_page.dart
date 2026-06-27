import 'dart:async';
import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/daily_mission.dart';
import 'package:english_learning_app/models/object_identification_result.dart';
import 'package:english_learning_app/models/pronunciation_feedback.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/ai_practice_pack_screen.dart';
import 'package:english_learning_app/screens/chat_buddy_screen.dart';
import 'package:english_learning_app/screens/daily_missions_screen.dart';
import 'package:english_learning_app/screens/image_quiz_screen.dart';
import 'package:english_learning_app/screens/level_completion_screen.dart';
import 'package:english_learning_app/screens/lightning_practice_screen.dart';
import 'package:english_learning_app/screens/scavenger_hunt_screen.dart';
import 'package:english_learning_app/screens/shop_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/services/web_image_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/utils/level_target_category.dart';
import 'package:english_learning_app/utils/word_image_url.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/utils/device_connectivity.dart';
import 'package:english_learning_app/utils/hero_tags.dart';
import 'package:english_learning_app/utils/offline_word_loader.dart';
import 'package:english_learning_app/utils/page_transitions.dart';
import 'package:english_learning_app/widgets/living_spark.dart';
import 'package:english_learning_app/widgets/pronunciation_mic_button.dart';
import 'package:english_learning_app/widgets/word_display_card.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.levelId,
    required this.wordsForLevel,
    this.targetCategory,
    this.categoryLabelHe,
    this.isChapterEnd = false,
  });

  final String title;
  final String levelId;
  final List<WordData> wordsForLevel;
  final String? targetCategory;
  final String? categoryLabelHe;

  /// True when completing this level closes a chapter (triggers epic celebration).
  final bool isChapterEnd;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  FlutterTts? flutterTts;
  SpeechFeedbackService? _speechFeedbackService;
  final SparkVoiceService _sparkVoiceService = SparkVoiceService();
  final ImagePicker _picker = ImagePicker();
  late final WordRepository _wordRepository;
  late final OfflineWordLoader _offlineWordLoader;
  final LevelProgressService _levelProgressService = LevelProgressService();
  final WordMasteryService _wordMasteryService = WordMasteryService();
  WebImageService? _webImageService;
  final AiImageValidator _cameraValidator = const PassthroughAiImageValidator();
  HttpFunctionAiImageValidator? _httpImageValidator;
  GeminiProxyService? _geminiProxy;

  bool _isLoading = true;
  List<WordData> _words = [];
  int _currentIndex = 0;
  int _attemptsForCurrentWord = 0;
  bool _isListening = false;
  String _feedbackText = SparkStrings.micPrompt;
  int _streak = 0;
  bool _isEvaluating = false;
  // AI features are always enabled since geminiProxyEndpoint always returns a valid endpoint
  Uri get proxyEndpoint => AppConfig.geminiProxyEndpoint;

  bool _showFeedback = false;
  bool _lastResultSuccess = false;

  // Spark emotion state
  SparkEmotion _sparkEmotion = SparkEmotion.neutral;

  // Sound service
  final SoundService _soundService = SoundService();
  TelemetryService? _telemetry;

  late final ConfettiController _confettiController;

  static const List<Color> _confettiColors = [
    Color(0xFF6EE7B7), // mint
    Color(0xFFC084FC), // plum
    Color(0xFFFDE68A), // butter
    Color(0xFFFB7185), // coral
    Color(0xFF93C5FD), // blueberry
    Color(0xFFF472B6), // pink
    Color(0xFFFBBF24), // gold
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _words = widget.wordsForLevel;
    _initializeServices().then((_) async {
      // Load progress after services are initialized
      await _loadLevelProgress();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _telemetry ??= TelemetryService.maybeOf(context);
      _telemetry?.startScreenSession('home');
    });
  }

  @override
  void dispose() {
    _telemetry?.endScreenSession(
      'home',
      extra: {
        'words_total': _words.length,
        'words_completed': _words.where((word) => word.isCompleted).length,
        'streak': _streak,
      },
    );
    flutterTts?.stop();
    unawaited(_speechFeedbackService?.cancelListening());
    _audioPlayer.dispose();
    _httpImageValidator?.dispose();
    _webImageService?.dispose();
    _geminiProxy?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _speechFeedbackService = context.read<SpeechFeedbackService>();
    final bool cloudinaryAvailable = AppConfig.hasCloudinary;

    // Always initialize Gemini proxy - it's always available
    _geminiProxy = GeminiProxyService(proxyEndpoint);

    // Pixabay is now routed through the proxy (key never ships in the app).
    _webImageService = WebImageService(
      proxyService: _geminiProxy!,
      imageValidator: _cameraValidator,
    );

    flutterTts = FlutterTts();
    await _configureTts();

    if (!cloudinaryAvailable) {
      AppConfig.debugWarnIfMissing('Cloudinary word sync', false);
    }

    _wordRepository = WordRepository(webImageProvider: _webImageService);
    _offlineWordLoader = OfflineWordLoader(wordRepository: _wordRepository);

    await _loadWords(remoteCapable: cloudinaryAvailable);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _speak(String text,
      {String languageCode = 'he-IL',
      SparkEmotion emotion = SparkEmotion.neutral}) async {
    if (text.isEmpty) return;

    try {
      if (AppConfig.hasGoogleTts) {
        final online = await DeviceConnectivity.current.isOnline();
        final spoke = await _sparkVoiceService.speak(
          text: text,
          isEnglish: languageCode == 'en-US',
          emotion: emotion,
          networkAllowed: online,
        );
        if (spoke) {
          return;
        }
        debugPrint(
          'Google TTS failed or unavailable, using FlutterTts fallback',
        );
      } else {
        debugPrint('Google TTS not available, using FlutterTts fallback');
      }

      await _speakWithFlutterTts(text, languageCode: languageCode);
    } catch (e) {
      debugPrint('Error in _speak function: $e');
      try {
        await _speakWithFlutterTts(text, languageCode: languageCode);
      } catch (fallbackError) {
        debugPrint('FlutterTts fallback also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _feedbackText = SparkStrings.ttsError;
          });
        }
      }
    }
  }

  Future<void> _speakWithFlutterTts(
    String text, {
    required String languageCode,
  }) async {
    final tts = flutterTts;
    if (tts == null) return;

    await tts.setLanguage(languageCode);
    if (languageCode == 'he-IL') {
      await tts.setSpeechRate(0.4);
      await tts.setPitch(1.1);
    } else {
      await tts.setSpeechRate(0.9);
      await tts.setPitch(1.0);
    }
    await tts.speak(text);
  }

  Future<void> _loadWords({required bool remoteCapable}) async {
    debugPrint('--- Loading lesson words (remoteCapable=$remoteCapable) ---');
    try {
      final words = await _offlineWordLoader.loadWords(
        remoteCapable: remoteCapable,
        fallbackWords: widget.wordsForLevel,
        cloudName: AppConfig.cloudinaryCloudName,
        tagName: 'english_kids_app',
        maxResults: 50,
        cacheNamespace: widget.levelId,
      );

      if (mounted) {
        setState(() {
          _words = words.isEmpty ? widget.wordsForLevel : words;
        });
      }
    } catch (e) {
      debugPrint('An exception occurred loading words: $e');
      if (mounted) {
        setState(() {
          _words = widget.wordsForLevel;
        });
      }
    }
  }

  Future<void> _configureTts() async {
    final tts = flutterTts;
    if (tts == null) return;

    try {
      if (kIsWeb) {
        await tts.awaitSpeakCompletion(true);
      }
      await tts.setLanguage('en-US');
    } catch (error, stackTrace) {
      debugPrint('TTS setLanguage failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      // Set slower speech rate for children (0.4-0.45 is ideal for kids learning)
      await tts.setSpeechRate(0.4);
    } catch (error, stackTrace) {
      debugPrint('TTS setSpeechRate failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      // Set pitch for friendly, child-appropriate voice (slightly higher for warmth)
      await tts.setPitch(1.1);
    } catch (error, stackTrace) {
      debugPrint('TTS setPitch failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      // Set volume to comfortable level
      await tts.setVolume(0.9);
    } catch (error, stackTrace) {
      debugPrint('TTS setVolume failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _takePictureAndIdentify() async {
    if (_geminiProxy == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(SparkStrings.aiUnavailable),
          ),
        );
      }
      return;
    }

    final telemetry = TelemetryService.maybeOf(context);

    final XFile? imageFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (imageFile == null) {
      return;
    }

    final imageBytes = await readPickedImageBytes(imageFile);
    if (imageBytes == null) {
      debugPrint('Error identifying image: could not read picked image bytes');
      if (mounted) {
        setState(() {
          _feedbackText = SparkStrings.cameraGenericFail;
        });
        await _speak(SparkStrings.cameraGenericFail, languageCode: 'he-IL');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _feedbackText = SparkStrings.imageAnalyzing;
    });

    try {
      final levelCategory = LevelTargetCategory.resolve(
        widget.levelId,
        targetCategoryFromLevel: widget.targetCategory,
        categoryLabelHeFromLevel: widget.categoryLabelHe,
      );
      final ObjectIdentificationResult? identification;

      if (levelCategory != null) {
        identification = await _geminiProxy!.identifyObjectInCategory(
          imageBytes,
          targetCategory: levelCategory.geminiCategory,
          mimeType: 'image/jpeg',
        );
      } else {
        const prompt =
            "Identify the main, single object in this image. Respond with only the object's name in English, in singular form. For example: 'Apple', 'Car', 'Dog'. If you cannot identify a single clear object, respond with the word 'unclear'.";
        final proxyResult = await _geminiProxy!.identifyMainObject(
          imageBytes,
          prompt: prompt,
          mimeType: 'image/jpeg',
        );
        identification = GeminiProxyService.parseCategoryIdentifyResponse(
          proxyResult,
        );
      }

      if (identification == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(SparkStrings.aiUnavailable)),
          );
          setState(() {
            _feedbackText = SparkStrings.cameraGenericFail;
          });
        }
        await _speak(SparkStrings.cameraGenericFail, languageCode: 'he-IL');
        return;
      }

      switch (identification) {
        case ObjectIdentificationCategoryMismatch(:final identified):
          final categoryHe = levelCategory?.displayHe ?? '';
          debugPrint(
            'Gemini category mismatch: $identified (expected ${levelCategory?.geminiCategory})',
          );
          unawaited(telemetry?.logCameraValidation(
            word: identified,
            accepted: false,
            validatorType: _cameraValidatorType,
            confidence: null,
          ));
          if (mounted) {
            final message = SparkStrings.cameraCategoryMismatch(
              identified,
              categoryHe,
            );
            setState(() {
              _feedbackText = message;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
          await _speak(
            SparkStrings.cameraCategoryMismatchSpeak(identified, categoryHe),
            languageCode: 'he-IL',
          );
          return;
        case ObjectIdentificationUnclear():
          unawaited(telemetry?.logCameraValidation(
            word: 'unclear',
            accepted: false,
            validatorType: _cameraValidatorType,
            confidence: null,
          ));
          if (!mounted) return;
          setState(() {
            _feedbackText = SparkStrings.cameraUnclearUi;
          });
          await _speak(SparkStrings.cameraUnclearSpeak, languageCode: 'he-IL');
          return;
        case ObjectIdentificationSuccess(:final word):
          await _acceptIdentifiedCameraWord(
            word,
            imageBytes: imageBytes,
            imageFile: imageFile,
            telemetry: telemetry,
          );
      }
    } catch (e) {
      debugPrint('Error identifying image: $e');
      if (mounted) {
        setState(() {
          _feedbackText = SparkStrings.cameraGenericFail;
        });
        await _speak(SparkStrings.cameraGenericFail, languageCode: 'he-IL');
      }
      rethrow;
    }
  }

  Future<void> _acceptIdentifiedCameraWord(
    String identifiedWord, {
    required Uint8List imageBytes,
    required XFile? imageFile,
    TelemetryService? telemetry,
  }) async {
    debugPrint('Gemini identified: $identifiedWord');

    final bool validationPassed = await _cameraValidator.validate(
      imageBytes,
      identifiedWord,
      mimeType: 'image/jpeg',
    );
    debugPrint(
      'Camera validation for "$identifiedWord": $validationPassed',
    );

    if (!validationPassed) {
      if (mounted) {
        setState(() {
          _feedbackText = SparkStrings.cameraCenterWord(identifiedWord);
        });
      }
      unawaited(telemetry?.logCameraValidation(
        word: identifiedWord,
        accepted: false,
        validatorType: _cameraValidatorType,
        confidence: _currentValidationConfidence(),
      ));
      await _speak(
        SparkStrings.cameraCenterWord(identifiedWord),
        languageCode: 'he-IL',
      );
      return;
    }

    final newWord = await _saveImageAndCreateWordData(
      identifiedWord,
      imageBytes: imageBytes,
      imageFile: imageFile,
    );
    if (!mounted) return;
    setState(() {
      _words.add(newWord);
      _currentIndex = _words.length - 1;
      _feedbackText = SparkStrings.cameraFoundWord(newWord.word);
    });
    await _wordRepository.cacheWords(
      _words,
      cacheNamespace: widget.levelId,
    );
    if (mounted) {
      Provider.of<AchievementService>(
        context,
        listen: false,
      ).checkForAchievements(streak: _streak, wordAdded: true);
    }
    await _speak(
      SparkStrings.cameraSpeakFound(newWord.word),
      languageCode: 'he-IL',
    );
    await _speak(
      newWord.word,
      languageCode: 'en-US',
      emotion: SparkEmotion.happy,
    );
    unawaited(telemetry?.logCameraValidation(
      word: identifiedWord,
      accepted: true,
      validatorType: _cameraValidatorType,
      confidence: _currentValidationConfidence(),
    ));
  }

  Future<WordData> _saveImageAndCreateWordData(
    String word, {
    required Uint8List imageBytes,
    XFile? imageFile,
  }) async {
    String? imagePath;

    if (kIsWeb) {
      imagePath = dataImageUrlFromBytes(imageBytes);
    } else if (imageFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final newPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImageFile = await File(imageFile.path).copy(newPath);
      imagePath = savedImageFile.path;
      debugPrint('Saved new image to: ${savedImageFile.path}');
    }

    return WordData(
      word: word,
      imageUrl: imagePath,
      isCompleted: false,
    );
  }

  // ignore: unused_element
  Future<void> _openDailyMissionsFromHome() async {
    final result = await Navigator.push<Object?>(
      context,
      PageTransitions.slideFromRight(const DailyMissionsScreen()),
    );
    if (!mounted) return;
    if (result == 'camera') {
      await openScavengerHunt(context);
    }
  }

  Future<void> _openScavengerHunt() async {
    if (_geminiProxy == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(SparkStrings.aiUnavailable)),
        );
      }
      return;
    }
    await Navigator.push(
      context,
      PageTransitions.fadeScale(
        ScavengerHuntScreen(geminiProxy: _geminiProxy!),
      ),
    );
  }

  Future<void> _handlePronunciationFeedback(
    PronunciationFeedback aiFeedback,
    String recognizedWord,
  ) async {
    if (_words.isEmpty) return;

    final currentWordObject = _words[_currentIndex];
    _attemptsForCurrentWord++;

    final isCorrect = aiFeedback.isStrongAttempt;
    String feedback = aiFeedback.feedbackMessage;

    if (!mounted) return;

    if (isCorrect) {
      _streak++;
      const int pointsToAdd = 10;
      await context.read<CoinProvider>().addCoins(pointsToAdd);
      if (!mounted) return;

      context.read<AchievementService>().checkForAchievements(streak: _streak);

      await context
          .read<DailyMissionProvider>()
          .incrementByType(DailyMissionType.speakPractice);
      if (!mounted) return;

      final compliment = SparkStrings.randomCompliment();
      final coinLine = SparkStrings.quizCorrectCoins(compliment, pointsToAdd);
      feedback = '$feedback\n$coinLine';

      if (mounted) {
        setState(() {
          currentWordObject.isCompleted = true;
        });

        if (aiFeedback.stars == 3 &&
            !MediaQuery.disableAnimationsOf(context)) {
          _confettiController.play();
          unawaited(_soundService.playSound('confetti'));
          unawaited(
            _persistThreeStarAchievement(currentWordObject.word),
          );
          try {
            context.read<DailyMissionProvider>().incrementByType(
                  DailyMissionType.pronunciationPerfect,
                );
          } catch (_) {}
          try {
            unawaited(
              context.read<AchievementService>().recordPronunciationPerfect(
                    stars: aiFeedback.stars,
                  ),
            );
          } catch (_) {}
        }

        final levelJustFinished = _isLevelComplete;
        final CelebrationTier tier;
        if (levelJustFinished) {
          tier = CelebrationTier.big;
        } else if (_attemptsForCurrentWord == 1) {
          tier = CelebrationTier.micro;
        } else {
          tier = CelebrationTier.small;
        }

        await Celebration.fire(
          context,
          tier: tier,
          word: currentWordObject.word,
          compliment: tier == CelebrationTier.big ? compliment : null,
          coinsEarned: tier == CelebrationTier.big ? pointsToAdd : 0,
          starsEarned: tier == CelebrationTier.big ? _starsForLevel() : 0,
        );
        if (!mounted) return;

        // Save word completion
        final sessionProvider = context.read<UserSessionProvider>();
        final userId = sessionProvider.currentUserId;
        if (userId != null) {
          final isLocalUser = sessionProvider.isLocalUser;
          debugPrint('=== Saving Word Completion ===');
          debugPrint('Level ID: ${widget.levelId}');
          debugPrint('Word: ${currentWordObject.word}');
          debugPrint('User ID: $userId');
          debugPrint('Is local user: $isLocalUser');

          await _levelProgressService.markWordCompleted(
            userId,
            widget.levelId,
            currentWordObject.word,
            isLocalUser: isLocalUser,
          );

          // Verify it was saved
          final isSaved = await _levelProgressService.isWordCompleted(
            userId,
            widget.levelId,
            currentWordObject.word,
            isLocalUser: isLocalUser,
          );
          debugPrint('Word saved verification: $isSaved');
          debugPrint('=== Word Completion Saved ===');

          // Check if level is now complete
          await _checkLevelCompletion();
        } else {
          debugPrint('Cannot save word completion: No user ID');
        }
      }
    } else {
      _streak = 0;
      if (feedback.isEmpty) {
        feedback = SparkStrings.wrongAlmostHeard(recognizedWord);
      }

      // Play gentle error sound (not harsh)
      unawaited(_soundService.playSound('error'));

      // Update Spark emotion to be empathetic, not disappointed
      if (mounted) {
        setState(() {
          _sparkEmotion = SparkEmotion.empathetic;
        });

        // Reset Spark to idle after a moment
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _sparkEmotion = SparkEmotion.neutral;
            });
          }
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _feedbackText = feedback;
      _lastResultSuccess = isCorrect;
      _showFeedback = true;
    });
    if (isCorrect) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() {});
      });
    }

    if (!mounted) return;

    // Determine emotion based on result
    final emotion = isCorrect ? SparkEmotion.excited : SparkEmotion.empathetic;
    await _speak(feedback, languageCode: 'he-IL', emotion: emotion);

    // Auto-hide feedback after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
        });
      }
    });
  }

  void _nextWord() {
    if (_words.isNotEmpty) {
      _soundService.playPopSound();
      setState(() {
        _currentIndex = (_currentIndex + 1) % _words.length;
        _attemptsForCurrentWord = 0;
        _feedbackText = '';
        _showFeedback = false;
        _sparkEmotion = SparkEmotion.neutral;
      });
    }
  }

  void _previousWord() {
    if (_words.isNotEmpty) {
      _soundService.playPopSound();
      setState(() {
        _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
        _attemptsForCurrentWord = 0;
        _feedbackText = '';
        _showFeedback = false;
        _sparkEmotion = SparkEmotion.neutral;
      });
    }
  }

  /// Stars shown on level-complete celebration.
  /// 3 stars = all words mastered on first try, 2 = most, 1 = some.
  int _starsForLevel() {
    if (_words.isEmpty) return 3;
    final completed = _words.where((w) => w.isCompleted).length;
    final ratio = completed / _words.length;
    if (ratio >= 1.0) return 3;
    if (ratio >= 0.67) return 2;
    return 1;
  }

  void _openGameMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GameMenuSheet(
        onAddWord: _speechBusy ? null : _takePictureAndIdentify,
        onScavengerHunt: _speechBusy ? null : _openScavengerHunt,
        onShop: _speechBusy
            ? null
            : () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageTransitions.slideFromRight(const ShopScreen()),
                );
              },
        onImageQuiz: _speechBusy
            ? null
            : () {
                Navigator.pop(context);
                final heroWord =
                    _words.isNotEmpty ? _words[_currentIndex].word : null;
                Navigator.push(
                  context,
                  PageTransitions.fadeScale(
                    ImageQuizScreen(
                      levelId: widget.levelId,
                      wordsForLevel: widget.wordsForLevel,
                      heroWord: heroWord,
                    ),
                  ),
                );
              },
        onChatBuddy: _speechBusy
            ? null
            : () {
                Navigator.pop(context);
                final focusWords = _words
                    .take(6)
                    .map((word) => word.word)
                    .toList(growable: false);
                Navigator.push(
                  context,
                  PageTransitions.slideFromRight(
                    ChatBuddyScreen(focusWords: focusWords),
                  ),
                );
              },
        onPracticePack: _speechBusy
            ? null
            : () {
                Navigator.pop(context);
                final focusWords = _words
                    .take(6)
                    .map((word) => word.word)
                    .toList(growable: false);
                Navigator.push(
                  context,
                  PageTransitions.slideFromRight(
                    AiPracticePackScreen(focusWords: focusWords),
                  ),
                );
              },
        onLightning: _speechBusy
            ? null
            : (_words.length < 2
                ? () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          SparkStrings.homeNeedWordsLightning,
                        ),
                      ),
                    );
                  }
                : () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LightningPracticeScreen(
                          words: List<WordData>.unmodifiable(_words),
                          levelId: widget.levelId,
                          levelTitle: widget.title,
                        ),
                      ),
                    );
                  }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.title)),
        body: RepaintBoundary(
          child: Stack(
            children: [
              Image.asset(
                'assets/images/background.png',
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                cacheWidth: 1920,
                cacheHeight: 1080,
              ),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }
    final currentWordData = _words.isNotEmpty ? _words[_currentIndex] : null;
    final coinProvider = context.watch<CoinProvider>();
    // Redesigned by Gemini 3 Pro
    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          // Cleaner AppBar
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: Hero(
              tag: HeroTags.level(widget.levelId),
              child: Material(
                color: Colors.transparent,
                child: _LevelHeader(title: widget.title),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_rounded,
                    color: Colors.white, size: 32),
                onPressed: _openGameMenu,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade300,
                  Colors.purple.shade200,
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Living Spark in top corner
                  Positioned(
                    top: 10,
                    left: 10,
                    child: LivingSpark(
                      emotion: _sparkEmotion,
                      size: 60,
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      // 1. Top Stats & Progress
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stats Pill (Coins)
                            _CoinBadge(coins: coinProvider.coins),
                            // Segmented Progress
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0),
                                child: _SegmentedProgressBar(
                                  total: _words.length,
                                  current: _currentIndex,
                                  completedIndices: _words
                                      .asMap()
                                      .entries
                                      .where((e) => e.value.isCompleted)
                                      .map((e) => e.key)
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 2. Hero Word Card — primary focus
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: currentWordData != null
                              ? WordDisplayCard(
                                  layout: WordDisplayCardLayout.levelHero,
                                  wordData: currentWordData,
                                  heroImageTag: HeroTags.wordImage(
                                    widget.levelId,
                                    currentWordData.word,
                                  ),
                                  heroTitleTag: HeroTags.wordTitle(
                                    widget.levelId,
                                    currentWordData.word,
                                  ),
                                  onNext: _speechBusy ? null : _nextWord,
                                  onPrevious:
                                      _speechBusy ? null : _previousWord,
                                  onPlayAudio: _speechBusy
                                      ? null
                                      : () async {
                                          await _speak(
                                            currentWordData.word,
                                            languageCode: 'en-US',
                                            emotion: SparkEmotion.teaching,
                                          );
                                        },
                                  canShowNext:
                                      _currentIndex < _words.length - 1,
                                  canShowPrevious: _currentIndex > 0,
                                )
                              : const Center(
                                  child: Text(
                                    SparkStrings.homeNoWordsYet,
                                    style: TextStyle(
                                        fontSize: 22, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        ),
                      ),
                      // 3. Mic & feedback dock — clearly partitioned at bottom
                      _LevelControlDock(
                        showFeedback: _showFeedback,
                        feedbackText: _feedbackText,
                        isSuccess: _lastResultSuccess,
                        child: currentWordData != null &&
                                _speechFeedbackService != null
                            ? PronunciationMicButton(
                                targetWord: currentWordData.word,
                                speechService: _speechFeedbackService!,
                                enabled: !_isLoading,
                                onListeningChanged: (listening) {
                                  if (!mounted) return;
                                  setState(() => _isListening = listening);
                                },
                                onEvaluatingChanged: (evaluating) {
                                  if (!mounted) return;
                                  setState(() => _isEvaluating = evaluating);
                                },
                                onFeedback: _handlePronunciationFeedback,
                              )
                            : const SizedBox(height: 200),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 28,
              maxBlastForce: 22,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              gravity: 0.18,
              colors: _confettiColors,
            ),
          ),
        ),
      ],
    );
  }

  bool get _speechBusy => _isListening || _isEvaluating;

  bool get _isLevelComplete => !_words.any((word) => !word.isCompleted);

  /// Persists a perfect (3-star) pronunciation without affecting UI flow.
  Future<void> _persistThreeStarAchievement(String word) async {
    try {
      final sessionProvider = context.read<UserSessionProvider>();
      final userId = sessionProvider.currentUserId;
      if (userId == null) {
        debugPrint('Cannot persist 3-star score: no user ID');
        return;
      }

      await _levelProgressService.recordPronunciationScore(
        userId: userId,
        levelId: widget.levelId,
        word: word,
        stars: 3,
        isLocalUser: sessionProvider.isLocalUser,
      );

      if (!mounted) return;
      final index = _words.indexWhere((w) => w.word == word);
      if (index >= 0) {
        setState(() {
          _words[index].masteryLevel = 1.0;
          _words[index].lastReviewed = DateTime.now();
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to persist 3-star achievement for $word: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Load saved progress for words in this level
  Future<void> _loadLevelProgress() async {
    try {
      debugPrint('=== Loading Level Progress ===');
      debugPrint('Level ID: ${widget.levelId}');
      debugPrint('Total words: ${_words.length}');

      final sessionProvider = context.read<UserSessionProvider>();
      final userId = sessionProvider.currentUserId;
      debugPrint('User ID: $userId');
      if (userId == null) {
        debugPrint('No user ID found, skipping progress load');
        return;
      }

      final isLocalUser = sessionProvider.isLocalUser;
      debugPrint('Is local user: $isLocalUser');

      if (!isLocalUser) {
        await _levelProgressService.syncLevelProgressFromCloud(
          userId: userId,
          levelId: widget.levelId,
          isLocalUser: false,
        );
      }

      // Get all completed words at once
      final completedWords = await _levelProgressService.getCompletedWords(
        userId,
        widget.levelId,
        isLocalUser: isLocalUser,
      );

      debugPrint('Completed words from storage: $completedWords');

      int loadedCount = 0;
      for (final word in _words) {
        if (completedWords.contains(word.word)) {
          word.isCompleted = true;
          loadedCount++;
          debugPrint('Loaded completed word: ${word.word}');
        } else {
          word.isCompleted = false;
        }

        try {
          final mastery = await _wordMasteryService.getMastery(
            userId: userId,
            levelId: widget.levelId,
            word: word.word,
          );
          final merged = _wordMasteryService.applyToWord(word, mastery);
          word.masteryLevel = merged.masteryLevel;
          word.lastReviewed = merged.lastReviewed;
        } catch (error, stackTrace) {
          debugPrint(
            'Error loading mastery for ${word.word}: $error',
          );
          debugPrint('$stackTrace');
        }
      }

      debugPrint('Loaded $loadedCount completed words out of ${_words.length}');
      debugPrint('=== Level Progress Loaded ===');

      if (mounted) {
        setState(() {
          _attemptsForCurrentWord = 0;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading level progress: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Check if level is completed and show completion screen
  Future<void> _checkLevelCompletion() async {
    if (!_isLevelComplete) return;

    try {
      final sessionProvider = context.read<UserSessionProvider>();
      final userId = sessionProvider.currentUserId;
      if (userId == null) return;

      final isLocalUser = sessionProvider.isLocalUser;
      final isCompleted = await _levelProgressService.isLevelCompleted(
        userId,
        widget.levelId,
        _words.length,
        isLocalUser: isLocalUser,
      );

      if (isCompleted && mounted) {
        // Show completion screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LevelCompletionScreen(
              levelName: widget.title,
              levelId: widget.levelId,
              completedWords: _words.where((w) => w.isCompleted).length,
              totalWords: _words.length,
              isChapterEnd: widget.isChapterEnd,
              coinsEarned: widget.wordsForLevel.length * 5,
              onContinue: () {
                Navigator.of(context).pop(); // Pop completion screen
                Navigator.of(context).pop(); // Pop home page, return to map
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking level completion: $e');
    }
  }

  String get _cameraValidatorType => _cameraValidator.runtimeType.toString();

  double? _currentValidationConfidence() {
    final validator = _cameraValidator;
    if (validator is HttpFunctionAiImageValidator) {
      return validator.lastConfidence;
    }
    return null;
  }
}

// ignore: unused_element
class _MissionNudgeCard extends StatelessWidget {
  const _MissionNudgeCard({
    required this.mission,
    required this.isClaimable,
  }) : onTap = null;

  final DailyMission mission;
  final bool isClaimable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        isClaimable ? Colors.green.shade500 : Colors.indigo.shade400;
    final double progress = mission.completionRatio;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: isClaimable ? Colors.green.shade50 : Colors.indigo.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Icon(
                      isClaimable ? Icons.card_giftcard : Icons.flag,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SparkStrings.dailyMissionTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          mission.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: accent),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mission.description,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${mission.progress}/${mission.target}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (isClaimable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${mission.reward}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      mission.remaining > 0
                          ? SparkStrings.dailyMissionRemaining(
                              mission.remaining,
                            )
                          : SparkStrings.dailyMissionKeepGoing,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Widgets - Redesigned by Gemini 3 Pro ---

// 1. Coin Badge (Floating Style)
class _CoinBadge extends StatelessWidget {
  final int coins;

  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, color: Colors.yellow.shade700, size: 20),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// 2. Segmented Progress Bar
class _SegmentedProgressBar extends StatelessWidget {
  final int total;
  final int current;
  final List<int> completedIndices;

  const _SegmentedProgressBar({
    required this.total,
    required this.current,
    required this.completedIndices,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox();

    return SizedBox(
      height: 8,
      child: Row(
        children: List.generate(total, (index) {
          final bool isActive = index == current;
          final bool isDone = completedIndices.contains(index);

          Color color;
          if (isActive) {
            color = Colors.white;
          } else if (isDone) {
            color = const Color(0xFF50C878); // Success Green
          } else {
            color = Colors.white.withValues(alpha: 0.3);
          }

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// 3. Bottom dock — mic + feedback partition
class _LevelControlDock extends StatelessWidget {
  const _LevelControlDock({
    required this.showFeedback,
    required this.feedbackText,
    required this.isSuccess,
    required this.child,
  });

  final bool showFeedback;
  final String feedbackText;
  final bool isSuccess;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showFeedback
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FeedbackPanel(
                      key: ValueKey<String>(feedbackText),
                      text: feedbackText,
                      isSuccess: isSuccess,
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          child,
        ],
      ),
    );
  }
}

// 5. Feedback Panel
class _FeedbackPanel extends StatefulWidget {
  final String text;
  final bool isSuccess;

  const _FeedbackPanel({
    super.key,
    required this.text,
    required this.isSuccess,
  });

  @override
  State<_FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<_FeedbackPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_controller);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: widget.isSuccess
                ? Colors.green.shade600
                : Colors.orange.shade800,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (widget.isSuccess ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isSuccess ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.text,
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 6. Level Header
class _LevelHeader extends StatelessWidget {
  final String title;

  const _LevelHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

// 7. Menu Sheet (Clean way to handle secondary actions)
class _GameMenuEntry {
  const _GameMenuEntry({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
}

class _IconGradientBadge extends StatelessWidget {
  const _IconGradientBadge({
    required this.icon,
    required this.gradient,
  });

  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _GameMenuGridTile extends StatelessWidget {
  const _GameMenuGridTile({required this.entry});

  final _GameMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          entry.onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IconGradientBadge(
                  icon: entry.icon,
                  gradient: entry.gradient,
                ),
                const SizedBox(height: 8),
                Text(
                  entry.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.heebo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AuroraTokens.ink,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameMenuSheet extends StatelessWidget {
  final VoidCallback? onAddWord;
  final VoidCallback? onScavengerHunt;
  final VoidCallback? onShop;
  final VoidCallback? onImageQuiz;
  final VoidCallback? onChatBuddy;
  final VoidCallback? onPracticePack;
  final VoidCallback? onLightning;

  const _GameMenuSheet({
    this.onAddWord,
    this.onScavengerHunt,
    this.onShop,
    this.onImageQuiz,
    this.onChatBuddy,
    this.onPracticePack,
    this.onLightning,
  });

  List<_GameMenuEntry> _buildEntries() {
    final entries = <_GameMenuEntry>[];

    if (onAddWord != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.camera_alt_rounded,
          label: 'הוסף מילה חדשה',
          gradient: const [AuroraTokens.blueberry, AuroraTokens.sky],
          onTap: onAddWord!,
        ),
      );
    }
    if (onScavengerHunt != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.explore_rounded,
          label: SparkStrings.scavengerTitle,
          gradient: const [AuroraTokens.mint, AuroraTokens.sky],
          onTap: onScavengerHunt!,
        ),
      );
    }
    if (onShop != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.store_rounded,
          label: 'חנות',
          gradient: const [AuroraTokens.plum, AuroraTokens.blueberry],
          onTap: onShop!,
        ),
      );
    }
    if (onImageQuiz != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.image_search_rounded,
          label: 'חידון תמונות',
          gradient: const [AuroraTokens.coral, AuroraTokens.butter],
          onTap: onImageQuiz!,
        ),
      );
    }
    if (onChatBuddy != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.chat_rounded,
          label: 'חבר שיחה של ספרק',
          gradient: const [AuroraTokens.mint, Color(0xFF1FA888)],
          onTap: onChatBuddy!,
        ),
      );
    }
    if (onPracticePack != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.emoji_events_rounded,
          label: 'חבילת אימון AI',
          gradient: const [AuroraTokens.butter, AuroraTokens.coral],
          onTap: onPracticePack!,
        ),
      );
    }
    if (onLightning != null) {
      entries.add(
        _GameMenuEntry(
          icon: Icons.flash_on_rounded,
          label: 'ריצת ברק',
          gradient: const [AuroraTokens.butter, AuroraTokens.coral],
          onTap: onLightning!,
        ),
      );
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassCard(
          borderRadius: 32,
          blurSigma: 14,
          surfaceOpacity: 0.28,
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          borderColor: Colors.white.withValues(alpha: 0.55),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'תפריט משחק',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AuroraTokens.ink,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.08,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) =>
                    _GameMenuGridTile(entry: entries[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
