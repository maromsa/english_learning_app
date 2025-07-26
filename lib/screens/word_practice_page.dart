import 'dart:async';
import 'dart:io';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';

import '../models/word_data.dart';
import '../widgets/action_button.dart';
import '../widgets/score_display.dart';
import '../widgets/word_display_card.dart';
import '../widgets/words_progress_bar.dart';

class WordPracticePage extends StatefulWidget {
  final List<WordData> wordsForLevel;
  final FlutterTts flutterTts;
  final Cloudinary cloudinary;
  final GenerativeModel geminiModel;
  final ImagePicker imagePicker;
  final String title;

  const WordPracticePage({
    Key? key,
    required this.wordsForLevel,
    required this.flutterTts,
    required this.cloudinary,
    required this.geminiModel,
    required this.imagePicker,
    required this.title,
  }) : super(key: key);

  @override
  State<WordPracticePage> createState() => _WordPracticePageState();
}

class _WordPracticePageState extends State<WordPracticePage> {
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;

  int _score = 0;
  int _streak = 0;
  int _currentIndex = 0;

  bool _isListening = false;
  bool _speechEnabled = false;

  String _recognizedWords = '';
  String _feedbackText = 'לחץ על המיקרופון כדי לדבר';

  List<WordData> get _words => widget.wordsForLevel;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    widget.flutterTts.stop();
    _speechToText.stop();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _speak(String text, {String languageCode = "he-IL"}) async {
    if (text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=${googleTtsApiKey}'),
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

        await _audioPlayer.setAudioSource(BytesAudioSource(audioBytes));
        _audioPlayer.play();
      } else {
        print("Google TTS Error: ${response.body}");
      }
    } catch (e) {
      print("Error in _speak function: $e");
    }
  }

  Future<void> _takePictureAndIdentify() async {
    final XFile? imageFile = await widget.imagePicker.pickImage(source: ImageSource.camera);
    if (imageFile == null) return;

    setState(() {
      _feedbackText = "Analyzing your picture...";
    });

    try {
      final imageBytes = await imageFile.readAsBytes();
      const prompt =
          "Identify the main, single object in this image. Respond with only the object's name in English, in singular form. For example: 'Apple', 'Car', 'Dog'. If you cannot identify a single clear object, respond with the word 'unclear'.";

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await widget.geminiModel.generateContent(content);
      final identifiedWord = response.text?.trim() ?? "unclear";

      if (identifiedWord.toLowerCase() == 'unclear' || identifiedWord.contains(' ')) {
        setState(() {
          _feedbackText = "I couldn't see that clearly. Please try taking another picture.";
        });
        await widget.flutterTts.speak("I couldn't see that clearly. Please try again.");
        return;
      }

      final newWord = await _saveImageAndCreateWordData(imageFile, identifiedWord);
      setState(() {
        _words.add(newWord);
        _currentIndex = _words.length - 1;
        _feedbackText = "Great! I see a ${newWord.word}. Let's learn it!";
      });
      await widget.flutterTts.speak("Great! I see a ${newWord.word}.");
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

    return WordData(
      word: word,
      imageUrl: savedImageFile.path,
      isCompleted: false,
    );
  }

  void _evaluateSpeech() {
    if (_words.isEmpty) return;
    final currentWord = _words[_currentIndex];
    final similarity = _recognizedWords.toLowerCase().similarityTo(currentWord.word.toLowerCase());
    const threshold = 0.7;

    String feedback;

    if (similarity >= threshold) {
      _streak++;
      final pointsToAdd = 10 + (10 * (_streak ~/ 5));
      _score += pointsToAdd;

      feedback = "כל הכבוד! +$pointsToAdd נקודות";
      currentWord.isCompleted = true;
      _confettiController.play();
    } else {
      _streak = 0;
      feedback = "זה נשמע כמו '$_recognizedWords'. בוא ננסה שוב.";
    }

    setState(() => _feedbackText = feedback);
    _speak(feedback, languageCode: "he-IL");
  }

  void _startListening() {
    if (!_speechEnabled) return;

    setState(() {
      _isListening = true;
      _feedbackText = 'מקשיב...';
      _recognizedWords = '';
    });

    _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _recognizedWords = result.recognizedWords;
          });
        }
      },
      localeId: "en_US",
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
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
    if (_words.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _feedbackText = '';
    });
  }

  void _previousWord() {
    if (_words.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      _feedbackText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWordData = _words.isNotEmpty ? _words[_currentIndex] : null;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.lightBlue.shade300,
            title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    WordDisplayCard(wordData: currentWordData, cloudinary: widget.cloudinary)
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActionButton(
                        text: 'הקשב',
                        icon: Icons.volume_up,
                        color: Colors.lightBlue.shade400,
                        onPressed: (currentWordData == null)
                            ? null
                            : () async {
                          await widget.flutterTts.setLanguage("en-US");
                          widget.flutterTts.speak(currentWordData.word);
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
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 100,
                    child: Text(
                      _feedbackText.isEmpty ? "לחץ על המקרופון בשביל לדבר" : _feedbackText,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      IconButton(
                        onPressed: _previousWord,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        iconSize: 40,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.lightBlue.withOpacity(0.8),
                          padding: const EdgeInsets.all(15),
                        ),
                      ),
                      IconButton(
                        onPressed: _nextWord,
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                        iconSize: 40,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.lightBlue.withOpacity(0.8),
                          padding: const EdgeInsets.all(15),
                        ),
                      ),
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
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
          ],
        ),
      ],
    );
  }
}

// עזר להפעלת אודיו מבייטים
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
