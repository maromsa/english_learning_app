import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const MyApp());
}

class WordData {
  final String word;
  final String imageUrl;
  final String audioUrl; // This will not be used for TTS, but kept for consistency if needed later

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

  final String _geminiApiKey = 'AIzaSyAill27e72g7DRjoH4hBxFASUUa8b9YqkY';

  late final GenerativeModel _model;
  late final FlutterTts flutterTts;

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
    _model = GenerativeModel(model: 'gemini-pro', apiKey: _geminiApiKey);

    flutterTts = FlutterTts();
    _configureTts();
  }

  void _configureTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  void _nextWord() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
    });
  }

  void _previousWord() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
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
                await flutterTts.speak(currentWordData.word); // Speak the word using TTS
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
              onPressed: () {
                print('Start listening for Gemini interaction for ${currentWordData.word}');
              },
              label: const Text('Speak', style: TextStyle(fontSize: 24)),
              icon: const Icon(Icons.mic, size: 30),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
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
