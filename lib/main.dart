import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class WordData {
  final String word;
  final String imageUrl;
  bool isCompleted;

  WordData({
    required this.word,
    required this.imageUrl,
    this.isCompleted = false,
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
      debugShowCheckedModeBanner: false,
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
  late final FlutterTts flutterTts;
  final SpeechToText _speechToText = SpeechToText();

  bool _isLoading = true;
  List<WordData> _words = [];
  int _currentIndex = 0;
  bool _isListening = false;
  String _feedbackText = '';
  String _recognizedWords = '';
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    flutterTts = FlutterTts();
    await _configureTts();
    _speechEnabled = await _speechToText.initialize();

    await _loadWordsFromCloudinary(); // Load data from Cloudinary

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWordsFromCloudinary() async {
    print("--- 📱 Flutter App: Starting to load words from Cloudinary... ---");
    final auth = 'Basic ${base64Encode(utf8.encode('$cloudinaryApiKey:$cloudinaryApiSecret'))}';
    final requestBody = jsonEncode({
      'expression': 'tags=english_kids_app',
      'with_field': 'tags',
      'max_results': 50,
    });

    print("--- 📱 Flutter App: Sending this request body: $requestBody");

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/resources/search');
      final response = await http.post(url, headers: {'Authorization': auth, 'Content-Type': 'application/json',}, body: requestBody);

      print("--- 📱 Flutter App: Got response with status code: ${response.statusCode} ---");
      // הדפסה של 500 התווים הראשונים של התשובה כדי שלא נקבל פלט ארוך מדי
      print("--- 📱 Flutter App: Response Body (first 500 chars): ${response.body.substring(0, 500)}...");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resources = data['resources'] as List<dynamic>? ?? [];

        print("--- 📱 Flutter App: Successfully parsed response. Found ${resources.length} resources. ---");

        if (resources.isEmpty) {
          print("--> ❗️ WARNING: Cloudinary found 0 images with the tag 'english_kids_app'. This is the root of the problem.");
        }

        final loadedWords = <WordData>[];
        for (final resource in resources) {
          final tags = List<String>.from(resource['tags'] ?? []);
          final secureUrl = resource['secure_url'];
          final wordTag = tags.firstWhere((tag) => tag != 'english_kids_app', orElse: () => '');

          print("  - Processing resource. Tags: $tags, Found word: '$wordTag', URL: $secureUrl");

          if (wordTag.isNotEmpty && secureUrl != null) {
            loadedWords.add(WordData(word: wordTag[0].toUpperCase() + wordTag.substring(1), imageUrl: secureUrl));
          }
        }

        if (mounted) setState(() => _words = loadedWords);
      } else {
        print("--> ❌ ERROR: Cloudinary request failed.");
      }
    } catch (e) {
      print("--> ❌ An exception occurred: $e");
    }
  }


  Future<void> _configureTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  void _evaluateSpeech() {
    if (_words.isEmpty) return;
    final currentWord = _words[_currentIndex];
    String feedback;

    if (_recognizedWords.trim().toLowerCase() == currentWord.word.toLowerCase()) {
      feedback = "Great job!";
      setState(() {
        currentWord.isCompleted = true;
      });
    } else {
      feedback = "Good try! Let's try again.";
    }

    setState(() => _feedbackText = feedback);
    flutterTts.speak(feedback);
  }

  void _startListening() {
    setState(() { _isListening = true; _feedbackText = 'Listening...'; _recognizedWords = ''; });
    _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            setState(() { _recognizedWords = result.recognizedWords; });
          }
        },
        localeId: "en_US");
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
      return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: CircularProgressIndicator()));
    }
    final currentWordData = _words.isNotEmpty ? _words[_currentIndex] : null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade300,
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (currentWordData != null)
                WordDisplayCard(wordData: currentWordData)
              else
                const SizedBox(
                    height: 346,
                    child: Center(
                        child: Text("No words found, check your connection.",
                            style: TextStyle(fontSize: 22)))),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: (currentWordData == null)
                        ? null
                        : () => flutterTts.speak(currentWordData.word),
                    icon: const Icon(Icons.volume_up, size: 28),
                    label: const Text('Listen', style: TextStyle(fontSize: 22)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    onPressed: _handleSpeech,
                    backgroundColor:
                    _isListening ? Colors.grey : Colors.redAccent,
                    child: Icon(_isListening ? Icons.stop : Icons.mic, size: 35),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 100,
                child: Text(
                  _feedbackText.isEmpty
                      ? "Press the microphone to speak"
                      : _feedbackText,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ElevatedButton(
                      onPressed: _previousWord,
                      child: const Icon(Icons.arrow_back)),
                  ElevatedButton(
                      onPressed: _nextWord,
                      child: const Icon(Icons.arrow_forward)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WordDisplayCard extends StatelessWidget {
  final WordData wordData;
  const WordDisplayCard({super.key, required this.wordData});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: wordData.isCompleted
                  ? Border.all(color: Colors.green.shade400, width: 4)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    wordData.imageUrl,
                    key: ValueKey(wordData.imageUrl),
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                    loadingBuilder: (BuildContext context, Widget child,
                        ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error_outline,
                          size: 150, color: Colors.grey);
                    },
                  ),
                  if (wordData.isCompleted)
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.check_circle,
                          color: Colors.green.shade400, size: 120),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(wordData.word,
            style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent)),
      ],
    );
  }
}