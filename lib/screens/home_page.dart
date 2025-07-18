// lib/screens/home_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/word_data.dart';
import '../widgets/word_display_card.dart';

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

  @override
  void dispose() {
    flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    flutterTts = FlutterTts();
    await _configureTts();

    // Pass the status listener during initialization
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        // When listening is done, update the state
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => print('Speech error: $error'),
    );
    await _loadWordsFromCloudinary();
    if (mounted) {
      setState(() => _isLoading = false);
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

  void _evaluateSpeech() {
    if (_words.isEmpty) return;
    final currentWord = _words[_currentIndex];
    String feedback;
    if (_recognizedWords.trim().toLowerCase() == currentWord.word.toLowerCase()) {
      feedback = "Great job!";
      setState(() => currentWord.isCompleted = true);
    } else {
      feedback = "That sounded like '$_recognizedWords'. Let's try again.";
    }
    setState(() => _feedbackText = feedback);
    flutterTts.speak(feedback);
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _feedbackText = 'Listening...';
      _recognizedWords = '';
    });
    // Use listenFor to set a timeout
    _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _recognizedWords = result.recognizedWords;
          });
          // Evaluate the speech as soon as we have a final result
          _evaluateSpeech();
        }
      },
      localeId: "en_US",
      listenFor: const Duration(seconds: 5), // Listen for up to 5 seconds
      pauseFor: const Duration(seconds: 3),  // Stop if there's a 3-second pause
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    // We set isListening to false immediately for a responsive UI
    setState(() {
      _isListening = false;
    });
    // After stopping, we manually call the evaluation function
    _evaluateSpeech();
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
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
    }
    final currentWordData = _words.isNotEmpty ? _words[_currentIndex] : null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade300,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 346, child: Center(child: Text("No words found. Did you run the Python script?", style: TextStyle(fontSize: 22), textAlign: TextAlign.center))),

              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: (currentWordData == null) ? null : () => flutterTts.speak(currentWordData.word),
                    icon: const Icon(Icons.volume_up, size: 28),
                    label: const Text('Listen', style: TextStyle(fontSize: 22)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    onPressed: _handleSpeech,
                    child: Icon(_isListening ? Icons.stop : Icons.mic, size: 35),
                    backgroundColor: _isListening ? Colors.grey : Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 100,
                child: Text(
                  _feedbackText.isEmpty ? "Press the microphone to speak" : _feedbackText,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ElevatedButton(onPressed: _previousWord, child: const Icon(Icons.arrow_back)),
                  ElevatedButton(onPressed: _nextWord, child: const Icon(Icons.arrow_forward)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}