import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  // IMPORTANT: Replace with your actual Google AI API key
  final String _geminiApiKey = 'AIzaSyAill27e72g7DRjoH4hBxFASUUa8b9YqkY';

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
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiApiKey);

    flutterTts = FlutterTts();
    _configureTts();
    _initSpeech(); // Initialize speech-to-text
  }

  // Configures Text-to-Speech (TTS) settings
  Future<void> _configureTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  // Initializes speech recognition
  Future<void> _initSpeech() async {
    _speechToText = SpeechToText();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  // Starts the speech recognition
  Future<void> _startListening() async {
    _geminiResponse = 'Listening...';
    setState(() {});
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 5),
      localeId: 'en_US',
      // שינויים כאן:
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: false,
      ),
    );
  }

  // Stops the speech recognition
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

  // Gets feedback from Gemini based on user's speech
  Future<void> _getGeminiFeedback(String userSpeech, String expectedWord) async {
    setState(() {
      _geminiResponse = 'Thinking...';
    });

    try {
      final prompt = "You are an English tutor for kids (age 3-6). The child said \"$userSpeech\". The correct word is \"$expectedWord\". Give friendly, simple, and encouraging feedback. Keep the response very short (1-2 sentences). Focus on pronunciation and accuracy, but be positive. If the word is correct, praise them. If it's incorrect, gently encourage them to try again, perhaps suggesting how to improve.";
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

  // Moves to the next word in the list
  void _nextWord() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _lastWords = ''; // Clear recognized words when changing word
      _geminiResponse = ''; // Clear Gemini response
    });
  }

  // Moves to the previous word in the list
  void _previousWord() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      _lastWords = ''; // Clear recognized words when changing word
      _geminiResponse = ''; // Clear Gemini response
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
