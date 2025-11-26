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
import 'package:english_learning_app/screens/image_quiz_game.dart';
import 'package:english_learning_app/screens/daily_missions_screen.dart';
import 'package:english_learning_app/screens/lightning_practice_screen.dart';
import 'package:english_learning_app/screens/shop_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/ai_image_validator.dart';
import 'package:english_learning_app/services/audio/bytes_audio_source.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/google_tts_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/services/web_image_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/services/local_user_service.dart';
import 'package:english_learning_app/screens/level_completion_screen.dart';
import 'package:english_learning_app/widgets/achievement_notification.dart';
import 'package:english_learning_app/utils/page_transitions.dart';
import 'package:english_learning_app/widgets/bouncy_button.dart';
import 'package:english_learning_app/widgets/living_spark.dart';
import 'package:english_learning_app/services/sound_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/services/kid_speech_service.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final FlutterTts flutterTts;
  GoogleTtsService? _googleTts;
  final KidSpeechService _kidSpeechService = KidSpeechService();
  final SparkVoiceService _sparkVoiceService = SparkVoiceService();
  final ImagePicker _picker = ImagePicker();
  late final WordRepository _wordRepository;
  final LevelProgressService _levelProgressService = LevelProgressService();
  final LocalUserService _localUserService = LocalUserService();
  WebImageService? _webImageService;
  final AiImageValidator _cameraValidator = const PassthroughAiImageValidator();
  HttpFunctionAiImageValidator? _httpImageValidator;
  GeminiProxyService? _geminiProxy;

  bool _isLoading = true;
  List<WordData> _words = [];
  int _currentIndex = 0;
  bool _isListening = false;
  String _feedbackText = 'לחצו על המיקרופון כדי לדבר';
  String _recognizedWords = '';
  bool _speechEnabled = false;
  double _soundLevel = 0.0; // For visual feedback
  int _streak = 0;
  bool _isEvaluating = false; // Prevent double evaluation
  OverlayEntry? _achievementOverlay;
  // AI features are always enabled since geminiProxyEndpoint always returns a valid endpoint
  Uri get proxyEndpoint => AppConfig.geminiProxyEndpoint;

  // New visual state for redesigned UI - Redesigned by Gemini 3 Pro
  late AnimationController _micPulseController;
  bool _showFeedback = false;
  bool _lastResultSuccess = false;
  
  // Spark emotion state
  SparkEmotion _sparkEmotion = SparkEmotion.neutral;
  
  // Sound service
  final SoundService _soundService = SoundService();
  
  // Random compliments for success
  static final List<String> _successCompliments = [
    'מעולה!',
    'וואו!',
    'אלוף!',
    'מדהים!',
    'כל הכבוד!',
    'נהדר!',
    'מצוין!',
    'פנטסטי!',
  ];
  
  String _getRandomCompliment() {
    return _successCompliments[math.Random().nextInt(_successCompliments.length)];
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _words = widget.wordsForLevel;
    _setupAchievementListener();
    _initializeServices().then((_) async {
      // Load progress after services are initialized
      await _loadLevelProgress();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final telemetry = TelemetryService.maybeOf(context);
      telemetry?.startScreenSession('home');
    });

    // Initialize mic pulse animation - Redesigned by Gemini 3 Pro
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _setupAchievementListener() {
    // Set up achievement notification callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final achievementService = Provider.of<AchievementService>(
        context,
        listen: false,
      );
      achievementService.setAchievementUnlockedCallback((achievement) {
        if (mounted) {
          _showAchievementNotification(achievement);
        }
      });
    });
  }

  void _showAchievementNotification(Achievement achievement) {
    final overlay = Overlay.of(context);

    _achievementOverlay?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: AchievementNotification(
            achievement: achievement,
            onDismiss: () {
              entry.remove();
              if (_achievementOverlay == entry) {
                _achievementOverlay = null;
              }
            },
          ),
        ),
      ),
    );
    _achievementOverlay = entry;
    overlay.insert(entry);
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
    _kidSpeechService.stop();
    _confettiController.dispose();
    _audioPlayer.dispose();
    _achievementOverlay?.remove();
    _httpImageValidator?.dispose();
    _webImageService?.dispose();
    _geminiProxy?.dispose();
    _googleTts?.dispose();
    _micPulseController.dispose(); // Redesigned by Gemini 3 Pro
    super.dispose();
  }

  Future<void> _initializeServices() async {
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
    _speechEnabled = await _kidSpeechService.initialize();

    if (!cloudinaryAvailable) {
      AppConfig.debugWarnIfMissing('Cloudinary word sync', false);
    }

    _wordRepository = WordRepository(webImageProvider: _webImageService);

    await _loadWords(remoteEnabled: cloudinaryAvailable);

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
        await _sparkVoiceService.speak(
          text: text,
          isEnglish: languageCode == 'en-US',
          emotion: emotion,
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
            _feedbackText = 'שגיאה בהשמעת הקול. אנא נסו שוב.';
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

  Future<void> _loadWords({required bool remoteEnabled}) async {
    debugPrint('--- Loading lesson words (remoteEnabled=$remoteEnabled) ---');
    try {
      final words = await _wordRepository.loadWords(
        remoteEnabled: remoteEnabled,
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
            content: Text(
              'שגיאה באתחול שירות ה-AI. אנא נסו שוב.',
            ),
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
      _feedbackText = 'מנתחים את התמונה שלכם...';
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
          _feedbackText = 'לא הצלחתי לראות ברור. נסו לצלם מחדש.';
        });
        await _speak('לא ראיתי ברור. בואו ננסה שוב.', languageCode: 'he-IL');
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
              _feedbackText =
                  'התמונה עדיין לא נראית כמו $identifiedWord. נסו למקם את הפריט במרכז ולצלם שוב.';
            });
          }
          telemetry?.logCameraValidation(
            word: identifiedWord,
            accepted: false,
            validatorType: _cameraValidatorType,
            confidence: _currentValidationConfidence(),
          );
          await _speak(
            'בואו ננסה שוב. שמרו את $identifiedWord במרכז התמונה וצלמו עוד פעם.',
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
          _feedbackText =
              'איזה יופי! אני רואה ${newWord.word}. בואו נלמד אותה יחד!';
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
        await _speak('מצוין! אני רואה ${newWord.word}.', languageCode: 'he-IL');
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
          _feedbackText = "מצטער, משהו השתבש. אנא נסו שוב.";
        });
        await _speak('אוי, משהו השתבש. נסו שוב.', languageCode: 'he-IL');
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
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(const DailyMissionsScreen()),
    );
  }

  Future<bool> _evaluateSpeechWithGemini(
    String correctWord,
    String recognizedWord,
  ) async {
    try {
      debugPrint('--- Asking Gemini for phonetic evaluation ---');
      debugPrint("Correct: '$correctWord', Recognized: '$recognizedWord'");

      final proxy = _geminiProxy;
      if (proxy == null) {
        throw StateError('Gemini proxy is not initialized.');
      }

      final prompt = "You are an English teacher for a 3-6 year old child. "
          "The child was asked to say the word '$correctWord' and they said '$recognizedWord'. "
          "Considering their age and common pronunciation mistakes (like confusing 'th' and 't' sounds), "
          "should this attempt be considered a good and acceptable try? "
          "Answer with only 'yes' or 'no'.";

      final response =
          await proxy.generateText(prompt).timeout(const Duration(seconds: 10));
      if (response == null || response.trim().isEmpty) {
        throw StateError('Gemini proxy returned an empty response.');
      }

      final answer = response.trim().toLowerCase();
      debugPrint("Gemini's answer: '$answer'");
      return answer == 'yes';
    } catch (e) {
      debugPrint('Error during Gemini evaluation: $e');
      return correctWord.toLowerCase() == recognizedWord.toLowerCase();
    }
  }

  Future<void> _evaluateSpeech() async {
    if (_words.isEmpty) return;

    // Prevent double evaluation
    if (_isEvaluating) {
      debugPrint('Evaluation already in progress, skipping duplicate call');
      return;
    }

    _isEvaluating = true;

    final currentWordObject = _words[_currentIndex];
    final recognizedWord = _recognizedWords.trim();

    if (recognizedWord.isEmpty) {
      _isEvaluating = false;
      if (!mounted) return;
      setState(() {
        _feedbackText = "לא שמעתי כלום. בוא ננסה שוב.";
      });
      return;
    }

    // First check if it's close enough using fuzzy matching
    bool isCorrect = _kidSpeechService.isCloseEnough(
      currentWordObject.word,
      recognizedWord,
    );
    
    // If fuzzy match fails, use Gemini for more sophisticated evaluation
    if (!isCorrect) {
      isCorrect = await _evaluateSpeechWithGemini(
        currentWordObject.word,
        recognizedWord,
      );
    }

    if (!mounted) return;

    String feedback;
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

      // Use random compliment for variety
      final compliment = _getRandomCompliment();
      feedback = "$compliment +10 מטבעות";
      
      // Play success sound
      _soundService.playSound('success');
      
      // Update Spark emotion
      if (mounted) {
        setState(() {
          _sparkEmotion = SparkEmotion.excited;
          currentWordObject.isCompleted = true;
        });
        _confettiController.play();
        
        // Reset Spark to happy after celebration
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _sparkEmotion = SparkEmotion.happy;
            });
          }
        });

        // Save word completion
        final userId = await _getCurrentUserId();
        if (userId != null) {
          final isLocalUser = await _isLocalUser();
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
      // Empathetic failure message - never make child feel bad
      feedback = "כמעט! זה נשמע כמו '$recognizedWord'. בוא ננסה שוב יחד!";
      
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

    if (!mounted) {
      _isEvaluating = false;
      return;
    }
    setState(() {
      _feedbackText = feedback;
      _lastResultSuccess = isCorrect;
      _showFeedback = true;
    });

    if (!mounted) {
      _isEvaluating = false;
      return;
    }
    
    // Determine emotion based on result
    final emotion = isCorrect ? SparkEmotion.excited : SparkEmotion.empathetic;
    await _speak(feedback, languageCode: "he-IL", emotion: emotion);
    _isEvaluating = false;

    // Auto-hide feedback after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
        });
      }
    });
  }

  void _startListening() async {
    if (!_speechEnabled) {
      setState(() {
        _feedbackText = "הרשאת מיקרופון לא זמינה. אנא בדוק את ההגדרות.";
      });
      return;
    }

    setState(() {
      _isListening = true;
      _feedbackText = 'מקשיב...';
      _recognizedWords = '';
      _isEvaluating =
          false; // Reset evaluation flag when starting new listening session
    });

    try {
      await _kidSpeechService.listen(
        onResult: (recognizedWords) async {
          if (mounted) {
            setState(() {
              _recognizedWords = recognizedWords;
            });

            // Auto-stop and evaluate when final result is received
            if (recognizedWords.trim().isNotEmpty) {
              // Stop listening immediately
              try {
                await _kidSpeechService.stop();
              } catch (e) {
                debugPrint('Error stopping speech recognition: $e');
              }

              if (mounted) {
                setState(() {
                  _isListening = false;
                  _feedbackText = 'סיימתי להקשיב. בודק...';
                });

                // Evaluate speech immediately after stopping
                // Small delay to ensure state is updated
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted) {
                    _evaluateSpeech();
                  }
                });
              }
            }
          }
        },
        onSoundLevel: (level) {
          // Update visual feedback with sound level
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
      );
    } catch (e) {
      debugPrint("Error starting speech recognition: $e");
      if (mounted) {
        setState(() {
          _isListening = false;
          _feedbackText = "לא הצלחתי להתחיל להקשיב. אנא נסה שוב.";
        });
      }
    }
  }

  void _stopListening() async {
    try {
      await _kidSpeechService.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      // Only evaluate if not already evaluating (to prevent double evaluation)
      // The onResult callback will handle evaluation
      if (!_isEvaluating && _recognizedWords.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isEvaluating) {
            _evaluateSpeech();
          }
        });
      } else if (_recognizedWords.isEmpty) {
        if (mounted) {
          setState(() {
            _feedbackText = "לא שמעתי כלום. בוא ננסה שוב.";
          });
        }
      }
    } catch (e) {
      debugPrint("Error stopping speech recognition: $e");
      if (mounted) {
        setState(() {
          _isListening = false;
          _feedbackText = "שגיאה. אנא נסה שוב.";
        });
      }
    }
  }

  void _handleSpeech() {
    if (!_speechEnabled) return;
    if (_kidSpeechService.isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _nextWord() {
    if (_words.isNotEmpty) {
      _soundService.playSound('pop');
      setState(() {
        _currentIndex = (_currentIndex + 1) % _words.length;
        _feedbackText = '';
        _showFeedback = false;
        _sparkEmotion = SparkEmotion.neutral;
      });
    }
  }

  void _previousWord() {
    if (_words.isNotEmpty) {
      _soundService.playSound('pop');
      setState(() {
        _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
        _feedbackText = '';
        _showFeedback = false;
        _sparkEmotion = SparkEmotion.neutral;
      });
    }
  }

  void _openGameMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _GameMenuSheet(
        onAddWord: _isListening ? null : _takePictureAndIdentify,
        onShop: _isListening
            ? null
            : () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageTransitions.slideFromRight(const ShopScreen()),
                );
              },
        onImageQuiz: _isListening
            ? null
            : () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageTransitions.fadeScale(ImageQuizGame()),
                );
              },
        onChatBuddy: _isListening
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
        onPracticePack: _isListening
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
        onLightning: _isListening
            ? null
            : (_words.length < 2
                ? () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'הוסיפו לפחות שתי מילים כדי להתחיל ריצת ברק!',
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
                                  onNext: _isListening ? null : _nextWord,
                                  onPrev: _isListening ? null : _previousWord,
                                  onPlayAudio: _isListening
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
                                    "אין עדיין מילים לתרגול. לחץ על המצלמה כדי להוסיף אחת חדשה!",
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
                      SizedBox(
                        height: 100,
                        child: Center(
                          child: _SmartMicButton(
                            isListening: _isListening,
                            isEvaluating: _isEvaluating,
                            onPressed: _handleSpeech,
                            animation: _micPulseController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                  // Confetti widget
                  ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple,
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

  bool get _isLevelComplete => !_words.any((word) => !word.isCompleted);

  /// Load saved progress for words in this level
  Future<void> _loadLevelProgress() async {
    try {
      debugPrint('=== Loading Level Progress ===');
      debugPrint('Level ID: ${widget.levelId}');
      debugPrint('Total words: ${_words.length}');

      final userId = await _getCurrentUserId();
      debugPrint('User ID: $userId');
      if (userId == null) {
        debugPrint('No user ID found, skipping progress load');
        return;
      }

      final isLocalUser = await _isLocalUser();
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
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading level progress: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Get current user ID (Firebase or local)
  Future<String?> _getCurrentUserId() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.firebaseUser != null) {
        return authProvider.firebaseUser!.uid;
      } else {
        final localUser = await _localUserService.getActiveUser();
        return localUser?.id;
      }
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  /// Check if current user is a local user
  Future<bool> _isLocalUser() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        return false;
      }
      final localUser = await _localUserService.getActiveUser();
      return localUser != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if level is completed and show completion screen
  Future<void> _checkLevelCompletion() async {
    if (!_isLevelComplete) return;

    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return;

      final isLocalUser = await _isLocalUser();
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
                          'משימה יומית',
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
                          ? 'עוד ${mission.remaining} כדי לנצח'
                          : 'המשיכו להצליח!',
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

// 4. Smart Microphone Button
class _SmartMicButton extends StatelessWidget {
  final bool isListening;
  final bool isEvaluating;
  final VoidCallback onPressed;
  final Animation<double> animation;

  const _SmartMicButton({
    required this.isListening,
    required this.isEvaluating,
    required this.onPressed,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.blue; // Default
    IconData icon = Icons.mic_rounded;
    String label = "דבר";

    if (isListening) {
      bgColor = Colors.redAccent;
      icon = Icons.graphic_eq;
      label = "מקשיב...";
    } else if (isEvaluating) {
      bgColor = Colors.purpleAccent;
      icon = Icons.auto_awesome;
      label = "בודק...";
    }

    final buttonContent = AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        double scale = isListening ? 1.0 + (animation.value * 0.1) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isEvaluating
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                ),
              )
            ],
          ),
        );
      },
    );

    // Wrap in BouncyButton for satisfying tactile feedback
    if (isListening || isEvaluating) {
      return buttonContent; // Disable bounce when active
    }

    return BouncyButton(
      onPressed: onPressed,
      child: buttonContent,
    );
  }
}

// 5. Feedback Panel
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
  final VoidCallback? onShop;
  final VoidCallback? onImageQuiz;
  final VoidCallback? onChatBuddy;
  final VoidCallback? onPracticePack;
  final VoidCallback? onLightning;

  const _GameMenuSheet({
    this.onAddWord,
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
