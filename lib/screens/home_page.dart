import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:english_learning_app/config.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/screens/image_quiz_game.dart';
import 'package:english_learning_app/screens/shop_screen.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/widgets/action_button.dart';
import 'package:english_learning_app/widgets/achievement_notification.dart';
import 'package:english_learning_app/widgets/score_display.dart';
import 'package:english_learning_app/widgets/word_display_card.dart';
import 'package:english_learning_app/widgets/words_progress_bar.dart';
import 'package:english_learning_app/models/achievement.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.wordsForLevel});
  final String title;
  final List<WordData> wordsForLevel;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final GenerativeModel _model;
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final FlutterTts flutterTts;
  final SpeechToText _speechToText = SpeechToText();
  late final Cloudinary cloudinary;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  List<WordData> _words = [];
  int _currentIndex = 0;
  bool _isListening = false;
  String _feedbackText = 'לחץ על המיקרופון כדי לדבר';
  String _recognizedWords = '';
  bool _speechEnabled = false;
  int _streak = 0;
  OverlayEntry? _achievementOverlay;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _words = widget.wordsForLevel;
    _setupAchievementListener();
    _initializeServices();
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
    _achievementOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: AchievementNotification(
            achievement: achievement,
            onDismiss: () {
              _achievementOverlay?.remove();
              _achievementOverlay = null;
            },
          ),
        ),
      ),
    );
    overlay.insert(_achievementOverlay!);
  }

  @override
  void dispose() {
    flutterTts.stop();
    _speechToText.stop();
    _confettiController.dispose();
    _audioPlayer.dispose();
    _achievementOverlay?.remove();
    super.dispose();
  }


  Future<void> _initializeServices() async {
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
    flutterTts = FlutterTts();
    await _configureTts();
    _speechEnabled = await _speechToText.initialize();
    cloudinary = Cloudinary.fromStringUrl(cloudinaryUrl);

    await _loadWordsFromCloudinary();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _speak(String text, {String languageCode = "he-IL"}) async {
    if (text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleTtsApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': languageCode, 'name': languageCode == 'en-US' ? 'en-US-Wavenet-D' : 'he-IL-Wavenet-A'},
          'audioConfig': {'audioEncoding': 'MP3'}
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final audioBytes = base64Decode(body['audioContent']);

        // Use just_audio to play the audio from memory
        await _audioPlayer.setAudioSource(BytesAudioSource(audioBytes));
        _audioPlayer.play();
      } else {
        debugPrint("Google TTS Error: ${response.body}");
        if (mounted) {
          setState(() {
            _feedbackText = "שגיאה בהשמעת הקול. אנא נסה שוב.";
          });
        }
      }
    } catch (e) {
      debugPrint("Error in _speak function: $e");
      if (mounted) {
        setState(() {
          _feedbackText = "שגיאה בהשמעת הקול. אנא נסה שוב.";
        });
      }
    }
  }

  Future<void> _loadWordsFromCloudinary() async {
    debugPrint("--- Starting to load words from Cloudinary... ---");

    final auth = 'Basic ${base64Encode(utf8.encode('$cloudinaryApiKey:$cloudinaryApiSecret'))}';

    final requestBody = jsonEncode({
      'expression': 'tags=english_kids_app',
      'with_field': 'tags',
      'max_results': 50,
    });
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/resources/search');
      final response = await http.post(
        url,
        headers: {'Authorization': auth, 'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 10));

      debugPrint("Cloudinary API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resources = data['resources'] as List<dynamic>? ?? [];
        debugPrint("Successfully parsed response. Found ${resources.length} resources.");

        final loadedWords = <WordData>[];
        for (final resource in resources) {
          final tags = List<String>.from(resource['tags'] ?? []);
          final secureUrl = resource['secure_url'];
          final wordTag = tags.firstWhere((tag) => tag != 'english_kids_app', orElse: () => '');

          if (wordTag.isNotEmpty && secureUrl != null) {
            loadedWords.add(WordData(
              word: wordTag[0].toUpperCase() + wordTag.substring(1),
              imageUrl: secureUrl,
            ));
          }
        }
        if (mounted) {
          setState(() {
            _words = loadedWords.isEmpty ? widget.wordsForLevel : loadedWords;
          });
        }
      } else {
        debugPrint("Error response from Cloudinary: ${response.body}");
        // Fallback to default words if Cloudinary fails
        if (mounted) {
          setState(() {
            _words = widget.wordsForLevel;
          });
        }
      }
    } catch (e) {
      debugPrint("An exception occurred loading words: $e");
      // Fallback to default words on error
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
    // 1. Open the camera and let the user take a picture
    final XFile? imageFile = await _picker.pickImage(source: ImageSource.camera);

    if (imageFile == null) {
      // User canceled the camera
      return;
    }

    setState(() {
      _feedbackText = "Analyzing your picture...";
    });

    try {
      // 2. Prepare the image and prompt for Gemini
      final imageBytes = await imageFile.readAsBytes();
      const prompt = "Identify the main, single object in this image. Respond with only the object's name in English, in singular form. For example: 'Apple', 'Car', 'Dog'. If you cannot identify a single clear object, respond with the word 'unclear'.";

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      // 3. Send to Gemini and get the response
      final response = await _model.generateContent(content);
      final identifiedWord = response.text?.trim() ?? "unclear";

      debugPrint("Gemini identified: $identifiedWord");

      // 4. Handle the response
      if (identifiedWord.toLowerCase() == 'unclear' || identifiedWord.contains(' ')) {
        setState(() {
          _feedbackText = "I couldn't see that clearly. Please try taking another picture.";
        });
        flutterTts.speak("I couldn't see that clearly. Please try again.");
      } else {
        // 5. Save the image and add the new word to our list
        final newWord = await _saveImageAndCreateWordData(imageFile, identifiedWord);
        setState(() {
          _words.add(newWord);
          _currentIndex = _words.length - 1; // Go to the new word
          _feedbackText = "Great! I see a ${newWord.word}. Let's learn it!";
        });
        flutterTts.speak("Great! I see a ${newWord.word}.");
      }
    } catch (e) {
      debugPrint("Error identifying image: $e");
      if (mounted) {
        setState(() {
          _feedbackText = "מצטער, משהו השתבש. אנא נסה שוב.";
        });
        await _speak("Sorry, something went wrong. Please try again.", languageCode: "en-US");
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

  // lib/screens/home_page.dart

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

      final response = await _model.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 10));
      final answer = response.text?.trim().toLowerCase() ?? 'no';

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
    final bool isCorrect = await _evaluateSpeechWithGemini(currentWordObject.word, recognizedWord);

    if (isCorrect) {
      _streak++;
      int pointsToAdd = 10;
      await Provider.of<CoinProvider>(context, listen: false).addCoins(pointsToAdd);

      Provider.of<AchievementService>(context, listen: false)
          .checkForAchievements(streak: _streak);

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
                icon: const Icon(Icons.image_search),
                tooltip: 'משחק תמונות',
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
                onPressed: _takePictureAndIdentify,
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
            onPressed: _takePictureAndIdentify,
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
                  if (currentWordData != null)
                    WordDisplayCard(
                        wordData: currentWordData, cloudinary: cloudinary)
                  else
                    const SizedBox(height: 346,
                        child: Center(child: Text(
                            "אין עדיין מילים לתרגול. לחץ על המצלמה כדי להוסיף אחת חדשה!",
                            style: TextStyle(fontSize: 22)))),
                  const SizedBox(height: 40),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 100,
                    child: Text(
                      _feedbackText.isEmpty
                          ? "לחץ על המקרופון בשביל לדבר"
                          : _feedbackText,
                      style: const TextStyle(fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple),
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