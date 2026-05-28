import 'dart:async';
import 'dart:io';
import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/models/achievement.dart';
import 'package:english_learning_app/models/daily_mission.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/screens/ai_conversation_screen.dart';
import 'package:english_learning_app/screens/ai_practice_pack_screen.dart';
import 'package:english_learning_app/screens/image_quiz_screen.dart';
import 'package:english_learning_app/screens/daily_missions_screen.dart';
import 'package:english_learning_app/screens/lightning_practice_screen.dart';
import 'package:english_learning_app/screens/scavenger_hunt_screen.dart';
import 'package:english_learning_app/screens/shop_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:english_learning_app/services/audio/bytes_audio_source.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/google_tts_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/services/web_image_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/utils/device_connectivity.dart';
import 'package:english_learning_app/utils/offline_word_loader.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/screens/level_completion_screen.dart';
import 'package:english_learning_app/utils/page_transitions.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:english_learning_app/widgets/living_spark.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/pronunciation_feedback.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:english_learning_app/widgets/pronunciation_mic_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  });

  final String title;
  final String levelId;
  final List<WordData> wordsForLevel;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final FlutterTts flutterTts;
  GoogleTtsService? _googleTts;
  SpeechFeedbackService? _speechFeedbackService;
  final SparkVoiceService _sparkVoiceService = SparkVoiceService();
  final ImagePicker _picker = ImagePicker();
  late final WordRepository _wordRepository;
  late final OfflineWordLoader _offlineWordLoader;
  final LevelProgressService _levelProgressService = LevelProgressService();
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
  
  @override
  void initState() {
    super.initState();
    _words = widget.wordsForLevel;
    _initializeServices().then((_) async {
      // Load progress after services are initialized
      await _loadLevelProgress();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final telemetry = TelemetryService.maybeOf(context);
      telemetry?.startScreenSession('home');
    });

  }

  @override
  void dispose() {
    TelemetryService.maybeOf(context)?.endScreenSession(
      'home',
      extra: {
        'words_total': _words.length,
        'words_completed': _words.where((word) => word.isCompleted).length,
        'streak': _streak,
      },
    );
    flutterTts.stop();
    unawaited(_speechFeedbackService?.cancelListening());
    _audioPlayer.dispose();
    _httpImageValidator?.dispose();
    _webImageService?.dispose();
    _geminiProxy?.dispose();
    _googleTts?.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _speechFeedbackService = context.read<SpeechFeedbackService>();
    final bool cloudinaryAvailable = AppConfig.hasCloudinary;
    final bool pixabayAvailable = AppConfig.hasPixabay;

    // Always initialize Gemini proxy - it's always available
    _geminiProxy = GeminiProxyService(proxyEndpoint);

    if (pixabayAvailable) {
      _webImageService = WebImageService(
        apiKey: AppConfig.pixabayApiKey,
        imageValidator: _cameraValidator,
      );
    } else {
      AppConfig.debugWarnIfMissing('Pixabay image search', false);
    }

    flutterTts = FlutterTts();
    if (AppConfig.hasGoogleTts) {
      _googleTts = GoogleTtsService(apiKey: AppConfig.googleTtsApiKey);
    }
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

  Future<void> _speak(String text, {String languageCode = "he-IL", SparkEmotion emotion = SparkEmotion.neutral}) async {
    if (text.isEmpty) return;

    try {
      // Try SparkVoiceService first (uses Google TTS with SSML)
      if (AppConfig.hasGoogleTts) {
        final online = await DeviceConnectivity.current.isOnline();
        await _sparkVoiceService.speak(
          text: text,
          isEnglish: languageCode == 'en-US',
          emotion: emotion,
          networkAllowed: online,
        );
        return;
      }

      // Fallback to FlutterTts if Google TTS is not available
      debugPrint("Google TTS not available, using FlutterTts fallback");
      await _speakWithFlutterTts(text, languageCode: languageCode);
    } catch (e) {
      debugPrint("Error in _speak function: $e");
      // Fallback to FlutterTts on error
      try {
        await _speakWithFlutterTts(text, languageCode: languageCode);
      } catch (fallbackError) {
        debugPrint("FlutterTts fallback also failed: $fallbackError");
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
    await flutterTts.setLanguage(languageCode);
    if (languageCode == 'he-IL') {
      await flutterTts.setSpeechRate(0.4);
      await flutterTts.setPitch(1.1);
    } else {
      await flutterTts.setSpeechRate(0.9);
      await flutterTts.setPitch(1.0);
    }
    await flutterTts.speak(text);
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
    try {
      await flutterTts.setLanguage("en-US");
    } catch (error, stackTrace) {
      debugPrint('TTS setLanguage failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      // Set slower speech rate for children (0.4-0.45 is ideal for kids learning)
      await flutterTts.setSpeechRate(0.4);
    } catch (error, stackTrace) {
      debugPrint('TTS setSpeechRate failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      // Set pitch for friendly, child-appropriate voice (slightly higher for warmth)
      await flutterTts.setPitch(1.1);
    } catch (error, stackTrace) {
      debugPrint('TTS setPitch failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      // Set volume to comfortable level
      await flutterTts.setVolume(0.9);
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

    setState(() {
      _feedbackText = SparkStrings.imageAnalyzing;
    });

    try {
      final imageBytes = await imageFile.readAsBytes();
      const prompt =
          "Identify the main, single object in this image. Respond with only the object's name in English, in singular form. For example: 'Apple', 'Car', 'Dog'. If you cannot identify a single clear object, respond with the word 'unclear'.";

      final proxyResult = await _geminiProxy!.identifyMainObject(
        imageBytes,
        prompt: prompt,
        mimeType: 'image/jpeg',
      );
      final identifiedWord = proxyResult ?? 'unclear';

      debugPrint('Gemini identified: $identifiedWord');

      if (identifiedWord.toLowerCase() == 'unclear' ||
          identifiedWord.contains(' ')) {
        telemetry?.logCameraValidation(
          word: identifiedWord,
          accepted: false,
          validatorType: _cameraValidatorType,
          confidence: null,
        );
        setState(() {
          _feedbackText = SparkStrings.cameraUnclearUi;
        });
        await _speak(SparkStrings.cameraUnclearSpeak, languageCode: 'he-IL');
      } else {
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
          telemetry?.logCameraValidation(
            word: identifiedWord,
            accepted: false,
            validatorType: _cameraValidatorType,
            confidence: _currentValidationConfidence(),
          );
          await _speak(
            SparkStrings.cameraCenterWord(identifiedWord),
            languageCode: 'he-IL',
          );
          return;
        }

        final newWord = await _saveImageAndCreateWordData(
          imageFile,
          identifiedWord,
        );
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
        await flutterTts.setLanguage('en-US');
        await flutterTts.speak(newWord.word);
        telemetry?.logCameraValidation(
          word: identifiedWord,
          accepted: true,
          validatorType: _cameraValidatorType,
          confidence: _currentValidationConfidence(),
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

  Future<WordData> _saveImageAndCreateWordData(
    XFile imageFile,
    String word,
  ) async {
    String? imagePath;

    if (kIsWeb) {
      imagePath = imageFile.path;

      if (imagePath.isEmpty) {
        try {
          final bytes = await imageFile.readAsBytes();
          if (bytes.isNotEmpty) {
            imagePath = Uri.dataFromBytes(
              bytes,
              mimeType: 'image/jpeg',
            ).toString();
          }
        } catch (error) {
          debugPrint('Failed to read picked web image bytes: $error');
          imagePath = null;
        }
      }
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final newPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImageFile = await File(imageFile.path).copy(newPath);
      imagePath = savedImageFile.path;
      debugPrint("Saved new image to: ${savedImageFile.path}");
    }

    return WordData(
      word: word,
      imageUrl: imagePath,
      isCompleted: false,
    );
  }

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
        final sessionProvider =
            context.read<UserSessionProvider>();
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
      _soundService.playSound('error');
      
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
    await _speak(feedback, languageCode: "he-IL", emotion: emotion);

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

  /// Stars shown on level-complete celebration (refine with mastery in P-09).
  int _starsForLevel() => 3;

  void _openGameMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                Navigator.push(
                  context,
                  PageTransitions.fadeScale(
                    ImageQuizScreen(
                      levelId: widget.levelId,
                      wordsForLevel: widget.wordsForLevel,
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
                    AiConversationScreen(focusWords: focusWords),
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
            title: _LevelHeader(title: widget.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 32),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                      const Spacer(flex: 1),
                      // 2. Hero Word Card Area
                      Expanded(
                        flex: 10,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: currentWordData != null
                              ? _HeroWordDisplay(
                                  wordData: currentWordData,
                                  onNext: _speechBusy ? null : _nextWord,
                                  onPrev: _speechBusy ? null : _previousWord,
                                  onPlayAudio: _speechBusy
                                      ? null
                                      : () async {
                                          _soundService.playSound('pop');
                                          await flutterTts.setLanguage("en-US");
                                          await flutterTts.setSpeechRate(0.4);
                                          await flutterTts.setPitch(1.1);
                                          await flutterTts.speak(currentWordData.word);
                                        },
                                  canGoNext: _currentIndex < _words.length - 1,
                                  canGoPrev: _currentIndex > 0,
                                )
                              : const Center(
                                  child: Text(
                                    SparkStrings.homeNoWordsYet,
                                    style: TextStyle(fontSize: 22, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        ),
                      ),
                      const Spacer(flex: 1),
                      // 3. Feedback Area (Dynamic Height)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: _showFeedback
                            ? _FeedbackPanel(
                                text: _feedbackText,
                                isSuccess: _lastResultSuccess,
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 20),
                      // 4. Controls Area
                      if (currentWordData != null &&
                          _speechFeedbackService != null)
                        PronunciationMicButton(
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
                      else
                        const SizedBox(height: 220),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _speechBusy => _isListening || _isEvaluating;

  bool get _isLevelComplete => !_words.any((word) => !word.isCompleted);

  /// Load saved progress for words in this level
  Future<void> _loadLevelProgress() async {
    try {
      debugPrint('=== Loading Level Progress ===');
      debugPrint('Level ID: ${widget.levelId}');
      debugPrint('Total words: ${_words.length}');

      final sessionProvider =
          context.read<UserSessionProvider>();
      final userId = sessionProvider.currentUserId;
      debugPrint('User ID: $userId');
      if (userId == null) {
        debugPrint('No user ID found, skipping progress load');
        return;
      }

      final isLocalUser = sessionProvider.isLocalUser;
      debugPrint('Is local user: $isLocalUser');

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
      final sessionProvider =
          context.read<UserSessionProvider>();
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
              completedWords: _words.where((w) => w.isCompleted).length,
              totalWords: _words.length,
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

class _MissionNudgeCard extends StatelessWidget {
  const _MissionNudgeCard({
    required this.mission,
    required this.isClaimable,
    this.onTap,
  });

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
            "$coins",
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
          bool isActive = index == current;
          bool isDone = completedIndices.contains(index);

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

// 3. Hero Word Display
class _HeroWordDisplay extends StatelessWidget {
  final WordData wordData;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback? onPlayAudio;
  final bool canGoNext;
  final bool canGoPrev;

  const _HeroWordDisplay({
    required this.wordData,
    required this.onNext,
    required this.onPrev,
    required this.onPlayAudio,
    required this.canGoNext,
    required this.canGoPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main Card
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Card(
            key: ValueKey<String>(wordData.word),
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: wordData.isCompleted
                    ? Border.all(color: Colors.green.shade300, width: 3)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image Area
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Use WordDisplayCard's image building logic
                            _buildImage(context),
                            if (wordData.isCompleted)
                              Container(
                                color: Colors.green.withValues(alpha: 0.2),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 64,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Word & TTS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        wordData.word,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: onPlayAudio,
                        icon: const Icon(Icons.volume_up_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.indigo.shade50,
                          foregroundColor: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        // Navigation Arrows (Floating on sides)
        if (canGoPrev)
          Positioned(
            left: 0,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: onPrev,
              ),
            ),
          ),
        if (canGoNext)
          Positioned(
            right: 0,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.black87),
                onPressed: onNext,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    final imageUrl = wordData.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.image, size: 64, color: Colors.grey),
      );
    }

    final bool isAssetImage = imageUrl.startsWith('assets/');
    final bool isLocalFile = !kIsWeb &&
        !imageUrl.startsWith('http') &&
        !imageUrl.startsWith('blob:') &&
        !imageUrl.startsWith('data:') &&
        !isAssetImage;

    if (isAssetImage) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 64, color: Colors.grey),
      );
    } else if (isLocalFile) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 64, color: Colors.grey),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.image, size: 64, color: Colors.grey),
      );
    }
  }
}

// 4. Feedback Panel
class _FeedbackPanel extends StatelessWidget {
  final String text;
  final bool isSuccess;

  const _FeedbackPanel({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade600 : Colors.orange.shade800,
        borderRadius: BorderRadius.circular(16),
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
          Icon(
            isSuccess ? Icons.check_circle : Icons.info_outline,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "תפריט משחק",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (onAddWord != null)
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("הוסף מילה חדשה"),
              onTap: () {
                Navigator.pop(context);
                onAddWord?.call();
              },
            ),
          if (onScavengerHunt != null)
            ListTile(
              leading: const Icon(Icons.explore_rounded, color: Colors.teal),
              title: const Text(SparkStrings.scavengerTitle),
              onTap: () {
                Navigator.pop(context);
                onScavengerHunt?.call();
              },
            ),
          if (onShop != null)
            ListTile(
              leading: const Icon(Icons.store, color: Colors.purple),
              title: const Text("חנות"),
              onTap: () {
                Navigator.pop(context);
                onShop?.call();
              },
            ),
          if (onImageQuiz != null)
            ListTile(
              leading: const Icon(Icons.image_search, color: Colors.orange),
              title: const Text("חידון תמונות"),
              onTap: () {
                Navigator.pop(context);
                onImageQuiz?.call();
              },
            ),
          if (onChatBuddy != null)
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text("חבר שיחה של ספרק"),
              onTap: () {
                Navigator.pop(context);
                onChatBuddy?.call();
              },
            ),
          if (onPracticePack != null)
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: const Text("חבילת אימון AI"),
              onTap: () {
                Navigator.pop(context);
                onPracticePack?.call();
              },
            ),
          if (onLightning != null)
            ListTile(
              leading: const Icon(Icons.flash_on, color: Colors.orange),
              title: const Text("ריצת ברק"),
              onTap: () {
                Navigator.pop(context);
                onLightning?.call();
              },
            ),
        ],
      ),
    );
  }
}
