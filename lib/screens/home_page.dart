// lib/screens/home_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:english_learning_app/config.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/widgets/word_display_card.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/score_display.dart';
import '../widgets/words_progress_bar.dart';
import '../widgets/action_button.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.wordsForLevel});
  final String title;
  final List<WordData> wordsForLevel;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final FlutterTts flutterTts;
  final SpeechToText _speechToText = SpeechToText();
  late final Cloudinary cloudinary;
  late final GenerativeModel _model;
  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  int _score = 0;
  int _streak = 0;
  bool _isLoading = true;
  List<WordData> _words = [];
  int _currentIndex = 0;
  bool _isListening = false;
  String _feedbackText = 'לחץ על המיקרופון כדי לדבר';
  String _recognizedWords = '';
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _words = widget.wordsForLevel;
    _initializeServices();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _speechToText.stop();
    _confettiController.dispose();
    _audioPlayer.dispose();
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
        print("Google TTS Error: ${response.body}");
      }
    } catch (e) {
      print("Error in _speak function: $e");
    }
  }

  Future<void> _loadWordsFromCloudinary() async {
    final auth = 'Basic ${base64Encode(utf8.encode('$cloudinaryApiKey:$cloudinaryApiSecret'))}';
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/resources/search');
      final response = await http.post(
        url,
        headers: {'Authorization': auth, 'Content-Type': 'application/json'},
        body: jsonEncode({'expression': 'tags=english_kids_app', 'with_field': 'tags', 'max_results': 50}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resources = data['resources'] as List<dynamic>? ?? [];
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
        if (mounted) setState(() => _words = loadedWords);
      } else {
        print("Error response from Cloudinary: ${response.body}");
      }
    } catch (e) {
      print("An exception occurred: $e");
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

      print("Gemini identified: $identifiedWord");

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
      print("Error identifying image: $e");
      setState(() {
        _feedbackText = "Sorry, something went wrong.";
      });
    }
  }

  Future<WordData> _saveImageAndCreateWordData(XFile imageFile, String word) async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImageFile = await File(imageFile.path).copy(newPath);

    print("Saved new image to: ${savedImageFile.path}");

    return WordData(
      word: word,
      imageUrl: savedImageFile.path, // The URL is now a local file path
      isCompleted: false,
    );
  }

  void _evaluateSpeech() async {
    if (_words.isEmpty) return;
    final currentWord = _words[_currentIndex];
    String feedback;

    if (_recognizedWords.trim().toLowerCase() == currentWord.word.toLowerCase()) {
      _streak++;
      int pointsToAdd = 10 + (10 * (_streak / 5).floor());
      _score += pointsToAdd;

      feedback = "כל הכבוד! +$pointsToAdd נקודות";
      setState(() => currentWord.isCompleted = true);
      _confettiController.play();
    } else {
      _streak = 0;
      feedback = "זה נשמע כמו '$_recognizedWords'. בוא ננסה שוב.";
    }
    setState(() => _feedbackText = feedback);
    _speak(feedback, languageCode: "he-IL");
  }

  void _startListening() {
    setState(() { _isListening = true; _feedbackText = 'מקשיב...'; _recognizedWords = ''; });
    _speechToText.listen(onResult: (result) {
      if (result.finalResult) {
        setState(() { _recognizedWords = result.recognizedWords; });
      }
    }, localeId: "en_US");
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() => _isListening = false);
    Future.delayed(const Duration(milliseconds: 200), _evaluateSpeech);
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
      return Scaffold(appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: CircularProgressIndicator()));
    }
    final currentWordData = _words.isNotEmpty ? _words[_currentIndex] : null;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.lightBlue.shade300,
            title: Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
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
                  ScoreDisplay(score: _score, streak: _streak),
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
                            "לא נמצאו מילים. ודא שהרצת את הסקריפט.",
                            style: TextStyle(fontSize: 22)))),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // כפתור "הקשב" החדש
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
                      // כפתור "דבר" החדש
                      ActionButton(
                        text: 'דבר',
                        icon: _isListening ? Icons.stop : Icons.mic,
                        color: _isListening ? Colors.grey.shade600 : Colors
                            .redAccent,
                        onPressed: _handleSpeech,
                      ),
                    ],
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
                      ElevatedButton(onPressed: _previousWord,
                          child: const Icon(Icons.arrow_back)),
                      ElevatedButton(onPressed: _nextWord,
                          child: const Icon(Icons.arrow_forward)),
                    ],
                  ),
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