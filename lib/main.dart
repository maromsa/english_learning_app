import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:english_learning_app/config.dart'; // Ensure this path is correct for your config.dart

void main() {
  runApp(const MyApp());
}

class WordData {
  final String word;
  final String imageUrl;
  final String audioUrl;

  const WordData({
    required this.word,
    required this.imageUrl,
    required this.audioUrl,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Learning App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue.shade100),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'English Learning for Kids'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Using API key from config.dart
  late final GenerativeModel _model;
  late final FlutterTts flutterTts;
  late final SpeechToText _speechToText;
  bool _speechEnabled = false;
  String _lastWords = '';
  String _geminiResponse = '';

  final List<WordData> _words = const [
    WordData(word: 'Apple', imageUrl: 'https://picsum.photos/250?image=9', audioUrl: 'apple_audio_url.mp3'),
    WordData(word: 'Banana', imageUrl: 'https://picsum.photos/250?image=29', audioUrl: 'banana_audio_url.mp3'),
    WordData(word: 'Car', imageUrl: 'https://picsum.photos/250?image=59', audioUrl: 'car_audio_url.mp3'),
    WordData(word: 'Dog', imageUrl: 'https://picsum.photos/250?image=79', audioUrl: 'dog_audio_url.mp3'),
    WordData(word: 'Cat', imageUrl: 'https://picsum.photos/250?image=89', audioUrl: 'cat_audio_url.mp3'),
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: geminiApiKey); // Using geminiApiKey from config.dart

    flutterTts = FlutterTts();
    _configureTts();
    _initSpeech();
  }

  Future<void> _configureTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _initSpeech() async {
    _speechToText = SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    print('Speech enabled: $_speechEnabled');
    setState(() {});
  }

  Future<void> _startListening() async {
    setState(() {
      _geminiResponse = 'Listening...';
      _lastWords = '';
    });
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: false,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  Future<void> _onSpeechResult(result) async {
    setState(() {
      _lastWords = result.recognizedWords;
    });
    await _getGeminiFeedback(_lastWords, _words[_currentIndex].word);
  }

  Future<void> _getGeminiFeedback(String userSpeech, String expectedWord) async {
    setState(() {
      _geminiResponse = 'Thinking...';
    });

    try {
      // REFINED PROMPT: More specific and focused on pronunciation feedback
      final prompt = """You are a very friendly and encouraging English teacher for young kids (age 3-6) who are native Hebrew speakers learning English.
      The child just tried to say the English word "$expectedWord".
      They actually said "$userSpeech".
      Your task is to give a very short (1-2 sentences maximum), simple, and positive English feedback.
      Focus ONLY on whether their pronunciation was correct or if they need to try again.
      - If "$userSpeech" is very close or exactly "$expectedWord" (ignore minor variations or accents, focus on the core word), give enthusiastic praise (e.g., "Fantastic!", "Great job!", "Perfect!").
      - If "$userSpeech" is completely different or clearly wrong, gently encourage them to try again (e.g., "Almost!", "Let's try again!", "You can do it!").
      - DO NOT provide examples, explanations, or spelling tips. Just simple, direct feedback on their attempt.""";

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      setState(() {
        _geminiResponse = response.text ?? 'I did not understand.';
      });
      await flutterTts.speak(_geminiResponse);
    } catch (e) {
      setState(() {
        _geminiResponse = 'Error: ${e.toString()}';
      });
      print('Gemini API Error: $e');
    }
  }

  void _nextWord() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _lastWords = '';
      _geminiResponse = '';
    });
  }

  void _previousWord() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      _lastWords = '';
      _geminiResponse = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWordData = _words[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade300,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.network(
              currentWordData.imageUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 30),
            Text(
              currentWordData.word,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                print('Play sound for ${currentWordData.word}');
                await flutterTts.speak(currentWordData.word);
              },
              icon: const Icon(Icons.volume_up, size: 30),
              label: const Text('Listen', style: TextStyle(fontSize: 24)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: Colors.green.shade400,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 50),
            FloatingActionButton.extended(
              onPressed: _speechToText.isListening
                  ? _stopListening
                  : _speechEnabled
                  ? _startListening
                  : null,
              label: Text(
                _speechToText.isListening
                    ? 'Stop Listening'
                    : 'Speak',
                style: const TextStyle(fontSize: 24),
              ),
              icon: Icon(
                _speechToText.isListening ? Icons.mic_off : Icons.mic,
                size: 30,
              ),
              backgroundColor: _speechToText.isListening ? Colors.grey : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              _speechToText.isListening ? 'Say the word...' : _lastWords.isEmpty ? '' : 'You said: $_lastWords',
              style: const TextStyle(fontSize: 20, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            if (_geminiResponse.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  _geminiResponse,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _previousWord,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.orange.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.arrow_back, size: 24),
                ),
                ElevatedButton(
                  onPressed: _nextWord,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.arrow_forward, size: 24),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
