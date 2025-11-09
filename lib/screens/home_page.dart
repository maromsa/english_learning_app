import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/services/web_image_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/widgets/action_button.dart';
import 'package:english_learning_app/widgets/achievement_notification.dart';
import 'package:english_learning_app/widgets/score_display.dart';
import 'package:english_learning_app/widgets/word_display_card.dart';
import 'package:english_learning_app/widgets/words_progress_bar.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final FlutterTts flutterTts;
  final SpeechToText _speechToText = SpeechToText();
  final ImagePicker _picker = ImagePicker();
  late final WordRepository _wordRepository;
  WebImageService? _webImageService;
  AiImageValidator _cameraValidator = const PassthroughAiImageValidator();
  HttpFunctionAiImageValidator? _httpImageValidator;
  GeminiProxyService? _geminiProxy;

  bool _isLoading = true;
  List<WordData> _words = [];
  int _currentIndex = 0;
  bool _isListening = false;
    String _feedbackText = 'לחצו על המיקרופון כדי לדבר';
  String _recognizedWords = '';
  bool _speechEnabled = false;
  int _streak = 0;
  OverlayEntry? _achievementOverlay;
  bool _aiFeaturesEnabled = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _words = widget.wordsForLevel;
    _setupAchievementListener();
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final telemetry = TelemetryService.maybeOf(context);
      telemetry?.startScreenSession('home');
    });
  }

  void _setupAchievementListener() {
    // Set up achievement notification callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final achievementService = Provider.of<AchievementService>(context, listen: false);
      achievementService.setAchievementUnlockedCallback((achievement) {
        if (mounted) {
          _showAchievementNotification(achievement);
        }
      });
    });
  }

  void _showAchievementNotification(Achievement achievement) {
    final overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }

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
    _speechToText.stop();
    _confettiController.dispose();
    _audioPlayer.dispose();
    _achievementOverlay?.remove();
    _httpImageValidator?.dispose();
    _webImageService?.dispose();
    _geminiProxy?.dispose();
    super.dispose();
  }


  Future<void> _initializeServices() async {
    final bool geminiProxyAvailable = AppConfig.hasGeminiProxy;
    final bool cloudinaryAvailable = AppConfig.hasCloudinary;
    final bool pixabayAvailable = AppConfig.hasPixabay;
    final Uri? proxyEndpoint = AppConfig.geminiProxyEndpoint;
    final Uri? validationEndpoint = AppConfig.aiImageValidationEndpoint ?? proxyEndpoint;

    if (validationEndpoint != null) {
      _httpImageValidator = HttpFunctionAiImageValidator(validationEndpoint);
      _cameraValidator = _httpImageValidator!;
    } else if (AppConfig.hasAiImageValidation) {
      AppConfig.debugWarnIfMissing('AI image validation endpoint', false);
    }

    if (geminiProxyAvailable && proxyEndpoint != null) {
      _geminiProxy = GeminiProxyService(proxyEndpoint);
    } else {
      AppConfig.debugWarnIfMissing('Gemini AI features', false);
    }

    if (pixabayAvailable) {
      _webImageService = WebImageService(
        apiKey: AppConfig.pixabayApiKey,
        imageValidator: _cameraValidator,
      );
    } else {
      AppConfig.debugWarnIfMissing('Pixabay image search', false);
    }

    flutterTts = FlutterTts();
    await _configureTts();
    _speechEnabled = await _speechToText.initialize();

    if (!cloudinaryAvailable) {
      AppConfig.debugWarnIfMissing('Cloudinary word sync', false);
    }

    _wordRepository = WordRepository(webImageProvider: _webImageService);

    await _loadWords(remoteEnabled: cloudinaryAvailable);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _aiFeaturesEnabled = geminiProxyAvailable && proxyEndpoint != null;
      });
    }
  }

  Future<void> _speak(String text, {String languageCode = "he-IL"}) async {
    if (text.isEmpty) return;

    try {
      if (!AppConfig.hasGoogleTts) {
        await flutterTts.setLanguage(languageCode);
        await flutterTts.speak(text);
        return;
      }

      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=${AppConfig.googleTtsApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': languageCode,
            'name': languageCode == 'en-US' ? 'en-US-Wavenet-D' : 'he-IL-Wavenet-A'
          },
          'audioConfig': {'audioEncoding': 'MP3'}
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final audioBytes = base64Decode(body['audioContent']);

        await _audioPlayer.setAudioSource(BytesAudioSource(audioBytes));
        _audioPlayer.play();
      } else {
        debugPrint("Google TTS Error: ${response.body}");
        if (mounted) {
          setState(() {
            _feedbackText = 'שגיאה בהשמעת הקול. אנא נסו שוב.';
          });
        }
      }
    } catch (e) {
      debugPrint("Error in _speak function: $e");
        if (mounted) {
          setState(() {
            _feedbackText = 'שגיאה בהשמעת הקול. אנא נסו שוב.';
          });
        }
    }
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
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5);
    }

  Future<void> _takePictureAndIdentify() async {
    if (!_aiFeaturesEnabled || _geminiProxy == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('תכונת ה-AI כבויה. הגדירו GEMINI_PROXY_URL של פונקציית הענן כדי להפעיל צילום חכם.'),
          ),
        );
      }
      return;
    }

    final telemetry = TelemetryService.maybeOf(context);

    final XFile? imageFile = await _picker.pickImage(source: ImageSource.camera);
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

      if (identifiedWord.toLowerCase() == 'unclear' || identifiedWord.contains(' ')) {
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
        debugPrint('Camera validation for "$identifiedWord": $validationPassed');

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

        final newWord = await _saveImageAndCreateWordData(imageFile, identifiedWord);
        setState(() {
          _words.add(newWord);
          _currentIndex = _words.length - 1;
          _feedbackText = 'איזה יופי! אני רואה ${newWord.word}. בואו נלמד אותה יחד!';
        });
        await _wordRepository.cacheWords(
          _words,
          cacheNamespace: widget.levelId,
        );
        Provider.of<AchievementService>(context, listen: false)
            .checkForAchievements(streak: _streak, wordAdded: true);
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
    }
  }

  Future<WordData> _saveImageAndCreateWordData(XFile imageFile, String word) async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImageFile = await File(imageFile.path).copy(newPath);

      debugPrint("Saved new image to: ${savedImageFile.path}");

    return WordData(
      word: word,
      imageUrl: savedImageFile.path, // The URL is now a local file path
      isCompleted: false,
    );
  }

  Future<void> _openDailyMissionsFromHome() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyMissionsScreen()),
    );
  }

  Future<bool> _evaluateSpeechWithGemini(String correctWord, String recognizedWord) async {
    try {
      debugPrint("--- Asking Gemini for phonetic evaluation ---");
      debugPrint("Correct: '$correctWord', Recognized: '$recognizedWord'");

      final prompt =
          "You are an English teacher for a 3-6 year old child. "
          "The child was asked to say the word '$correctWord' and they said '$recognizedWord'. "
          "Considering their age and common pronunciation mistakes (like confusing 'th' and 't' sounds), "
          "should this attempt be considered a good and acceptable try? "
          "Answer with only 'yes' or 'no'.";

      final proxy = _geminiProxy;
      if (proxy == null) {
        throw StateError('Gemini proxy is not initialized');
      }

      final response = await proxy.generateText(prompt).timeout(const Duration(seconds: 10));
      final answer = response?.trim().toLowerCase() ?? 'no';

      debugPrint("Gemini's answer: '$answer'");
      return answer == 'yes';
    } catch (e) {
      debugPrint("Error during Gemini evaluation: $e");
      // In case of an error, we fall back to a simple, strict check
      return correctWord.toLowerCase() == recognizedWord.toLowerCase();
    }
  }

  void _evaluateSpeech() async {
    if (_words.isEmpty) return;

    final currentWordObject = _words[_currentIndex];
    final recognizedWord = _recognizedWords.trim();
    String feedback;

    // --- קריאה ל-Gemini כדי לבדוק את התשובה ---
    final bool isCorrect =
        await _evaluateSpeechWithGemini(currentWordObject.word, recognizedWord);

    if (isCorrect) {
      _streak++;
      const int pointsToAdd = 10;
      await Provider.of<CoinProvider>(context, listen: false).addCoins(pointsToAdd);

      Provider.of<AchievementService>(context, listen: false)
          .checkForAchievements(streak: _streak);

      context.read<DailyMissionProvider>().incrementByType(
            DailyMissionType.speakPractice,
          );

      feedback = "כל הכבוד! +10 מטבעות";
      setState(() => currentWordObject.isCompleted = true);
      _confettiController.play();
    } else {
      _streak = 0;
      feedback = "זה נשמע כמו '$recognizedWord'. בוא ננסה שוב.";
    }

    setState(() => _feedbackText = feedback);
    await _speak(feedback, languageCode: "he-IL");
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
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _recognizedWords = result.recognizedWords;
              if (result.finalResult) {
                _feedbackText = 'סיימתי להקשיב. בודק...';
                // Auto-evaluate when final result is received
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _speechToText.isNotListening) {
                    setState(() {
                      _isListening = false;
                    });
                    _evaluateSpeech();
                  }
                });
              }
            });
          }
        },
        localeId: "en_US",
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
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
      await _speechToText.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      // Evaluate speech after a short delay to ensure recognition is complete
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          if (_recognizedWords.isNotEmpty) {
            _evaluateSpeech();
          } else {
            setState(() {
              _feedbackText = "לא שמעתי כלום. בוא ננסה שוב.";
            });
          }
        }
      });
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
    if (_speechToText.isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _nextWord() {
    if (_words.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _words.length;
        _feedbackText = '';
      });
    }
  }

  void _previousWord() {
    if (_words.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
        _feedbackText = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(title: Text(widget.title)),
          body: Stack(
              children: [
                Image.asset(
                  'assets/images/background.png',
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity,
                ),
                Center(
                  child: SingleChildScrollView(child: const CircularProgressIndicator()),
                ),
              ],
          ),
      );
    }
    final currentWordData = _words.isNotEmpty ? _words[_currentIndex] : null;
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.lightBlue.shade300,
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat),
                  tooltip: 'חבר שיחה של ספרק',
                  onPressed: () {
                    final focusWords = _words.take(6).map((word) => word.word).toList(growable: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiConversationScreen(focusWords: focusWords),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_events),
                  tooltip: 'חבילת אימון AI',
                  onPressed: () {
                    final focusWords = _words.take(6).map((word) => word.word).toList(growable: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiPracticePackScreen(focusWords: focusWords),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.image_search),
                  tooltip: 'Image Quiz Game',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ImageQuizGame()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'הוסף מילה',
                  onPressed: _aiFeaturesEnabled ? _takePictureAndIdentify : null,
                ),
                IconButton(
                  icon: const Icon(Icons.store),
                  tooltip: 'חנות',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShopScreen()),
                    );
                  },
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _aiFeaturesEnabled ? _takePictureAndIdentify : null,
              label: const Text('הוסף מילה'),
              icon: const Icon(Icons.camera_alt),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                  ScoreDisplay(coins: Provider.of<CoinProvider>(context).coins),
                  WordsProgressBar(
                    totalWords: _words.length,
                    completedWords: _words.where((w) => w.isCompleted).length,
                  ),
                  Consumer<DailyMissionProvider>(
                    builder: (context, missionsProvider, _) {
                      if (!missionsProvider.isInitialized || missionsProvider.missions.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      DailyMission? claimable;
                      DailyMission? next;
                      for (final mission in missionsProvider.missions) {
                        if (mission.isClaimable) {
                          claimable = mission;
                          break;
                        }
                        if (!mission.isCompleted && next == null) {
                          next = mission;
                        }
                      }

                      final DailyMission highlight = claimable ?? next ?? missionsProvider.missions.first;
                      return Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _MissionNudgeCard(
                          mission: highlight,
                          isClaimable: highlight.isClaimable,
                          onTap: _openDailyMissionsFromHome,
                        ),
                      );
                    },
                  ),
                  if (currentWordData != null)
                    WordDisplayCard(
                      wordData: currentWordData,
                      onPrevious: _previousWord,
                      onNext: _nextWord,
                    )
                  else
                    const SizedBox(
                      height: 346,
                      child: Center(
                        child: Text(
                          "אין עדיין מילים לתרגול. לחץ על המצלמה כדי להוסיף אחת חדשה!",
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (!_aiFeaturesEnabled)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: const Text(
                          'תכונות ה-AI כבויות כרגע. השתמשו באפליקציה גם ללא צילום חכם או הוסיפו מפתחות API כדי להפעיל אותן.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ActionButton(
                            text: 'הקשב',
                            icon: Icons.volume_up,
                            color: Colors.lightBlue.shade400,
                            onPressed: (currentWordData == null)
                                ? null
                                : () async {
                                    await flutterTts.setLanguage("en-US");
                                    flutterTts.speak(currentWordData.word);
                                  },
                          ),
                          const SizedBox(width: 20),
                          ActionButton(
                            text: 'דבר',
                            icon: _isListening ? Icons.stop : Icons.mic,
                            color: _isListening ? Colors.grey.shade600 : Colors.redAccent,
                            onPressed: _handleSpeech,
                          ),
                          const SizedBox(width: 20),
                          ActionButton(
                            text: 'ריצת ברק',
                            icon: Icons.flash_on,
                            color: Colors.orangeAccent,
                            onPressed: _words.length < 2
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('הוסיפו לפחות שתי מילים כדי להתחיל ריצת ברק!'),
                                      ),
                                    );
                                  }
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LightningPracticeScreen(
                                          words: List<WordData>.unmodifiable(_words),
                                          levelTitle: widget.title,
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                    SizedBox(
                      height: 100,
                      child: Text(
                        _feedbackText.isEmpty
                            ? 'לחצו על המיקרופון כדי לדבר'
                            : _feedbackText,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      // כפתור "אחורה" - תמיד מוצג
                      IconButton(
                        onPressed: _previousWord,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        iconSize: 40,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.lightBlue.withOpacity(0.8),
                            padding: const EdgeInsets.all(15)
                        ),
                      ),

                      // כאן מגיע התנאי הלוגי
                      if (_isLevelComplete)
                      // אם השלב הושלם, הצג את כפתור "סיימתי"
                        ElevatedButton(
                          onPressed: () {
                            // החזר את הניקוד והרצף למסך הקודם
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                          ),
                          child: const Text('סיימתי!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        )
                      else
                      // אם השלב עוד לא הושלם, הצג את כפתור "הבא"
                        IconButton(
                          onPressed: _nextWord,
                          icon: const Icon(Icons.arrow_forward_ios_rounded),
                          iconSize: 40,
                          color: Colors.white,
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.lightBlue.withOpacity(0.8),
                              padding: const EdgeInsets.all(15)
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple
          ],
        ),
      ],
    );
  }

  bool get _isLevelComplete => !_words.any((word) => !word.isCompleted);

  String get _cameraValidatorType => _cameraValidator.runtimeType.toString();

  double? _currentValidationConfidence() {
    final validator = _cameraValidator;
    if (validator is HttpFunctionAiImageValidator) {
      return validator.lastConfidence;
    }
    return null;
  }

}



// Add this helper class at the end of the file
class BytesAudioSource extends StreamAudioSource {
  final List<int> _bytes;

  BytesAudioSource(this._bytes) : super(tag: 'BytesAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: (end ?? _bytes.length) - (start ?? 0),
      offset: start ?? 0,
      stream: Stream.value(_bytes.sublist(start ?? 0, end)),
      contentType: 'audio/mpeg',
    );
  }
}

class _MissionNudgeCard extends StatelessWidget {
  const _MissionNudgeCard({
    required this.mission,
    required this.isClaimable,
    required this.onTap,
  });

  final DailyMission mission;
  final bool isClaimable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = isClaimable ? Colors.green.shade500 : Colors.indigo.shade400;
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
                    backgroundColor: accent.withOpacity(0.15),
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('+${mission.reward}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    Text(
                      mission.remaining > 0
                          ? 'עוד ${mission.remaining} כדי לנצח'
                          : 'המשיכו להצליח!',
                      style: TextStyle(color: accent, fontWeight: FontWeight.w600),
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