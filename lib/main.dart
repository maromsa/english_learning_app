import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

// Firebase Imports
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:english_learning_app/firebase_options.dart';

// On-Device Speech-to-Text package
import 'package:speech_to_text/speech_to_text.dart';

// We are not using google_generative_ai or flutter_sound anymore for this logic
// You can remove them from pubspec.yaml later if you wish

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class WordData {
  final String word;
  final String imageUrl;
  final String id;
  final bool isCompleted;

  const WordData({
    required this.word,
    required this.imageUrl,
    required this.id,
    this.isCompleted = false,
  });

  factory WordData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WordData(
      id: doc.id,
      word: data['word'] ?? 'Error',
      imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/250/FF0000/FFFFFF?text=Error',
      isCompleted: data['isCompleted'] ?? false,
    );
  }
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
  // Services
  late final FlutterTts flutterTts;
  final SpeechToText _speechToText = SpeechToText();

  // State Variables
  bool _isLoading = true;
  String? _userId;
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
    // Initialize speech-to-text service
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) => print('STT Status: $status'),
      onError: (error) => print('STT Error: $error'),
    );
    await _initializeFirebaseUser();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _configureTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initializeFirebaseUser() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        _userId = userCredential.user?.uid;
        _setupFirestoreListener();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: $e')),
        );
      }
    }
  }

  void _setupFirestoreListener() {
    if (_userId == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('words')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.docs.isEmpty && _isLoading) {
          _addInitialWordsToFirestore();
        } else {
          setState(() {
            _words = snapshot.docs.map((doc) => WordData.fromFirestore(doc)).toList();
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _addInitialWordsToFirestore() async {
    if (_userId == null) return;
    final collection = FirebaseFirestore.instance.collection('users').doc(_userId).collection('words');
    final batch = FirebaseFirestore.instance.batch();
    batch.set(collection.doc(), {'word': 'Apple', 'imageUrl': 'https://i.imgur.com/gAYAEa5.png', 'isCompleted': false});
    batch.set(collection.doc(), {'word': 'Banana', 'imageUrl': 'https://i.imgur.com/r3yC4QG.png', 'isCompleted': false});
    batch.set(collection.doc(), {'word': 'Car', 'imageUrl': 'https://i.imgur.com/mJ9f5gS.png', 'isCompleted': false});
    await batch.commit();
  }

  // This function now handles the speech-to-text flow
  Future<void> _handleSpeech() async {
    if (!_speechEnabled) {
      print("Speech recognition not initialized.");
      return;
    }

    if (_speechToText.isListening) {
      _stopListening(); // <-- ללא await
    } else {
      _startListening(); // <-- ללא await
    }
  }

  // Starts listening for speech
  void _startListening() async {
    setState(() {
      _isListening = true;
      _feedbackText = 'Listening...';
      _recognizedWords = ''; // Clear previous results
    });
    await _speechToText.listen(
      onResult: (result) {
        if(result.finalResult) { // We only care about the final result
          setState(() {
            _recognizedWords = result.recognizedWords;
          });
        }
      },
      localeId: "en_US",
    );
  }

  // Stops listening and evaluates the result
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    // A small delay to ensure the final recognized words are processed
    Future.delayed(const Duration(milliseconds: 200), _evaluateSpeech);
  }

  // Compares the recognized words with the correct word
  void _evaluateSpeech() {
    if (_words.isEmpty || _recognizedWords.isEmpty) {
      setState(() {
        _feedbackText = "Good try! Let's try again.";
      });
      flutterTts.speak("Good try! Let's try again.");
      return;
    };

    final currentWord = _words[_currentIndex].word;
    String feedback;

    if (_recognizedWords.trim().toLowerCase() == currentWord.toLowerCase()) {
      feedback = "Great job!";
      _markWordAsCompleted(_words[_currentIndex].id);
    } else {
      feedback = "That sounded like '$_recognizedWords'. Let's try again.";
    }

    setState(() {
      _feedbackText = feedback;
    });
    flutterTts.speak(feedback);
  }

  Future<void> _markWordAsCompleted(String wordId) async {
    if (_userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('words')
        .doc(wordId)
        .update({'isCompleted': true});
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
                SizedBox(height: 346, child: Center(child: Text("No words found!", style: TextStyle(fontSize: 22)))),

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
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error_outline, size: 150, color: Colors.grey);
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
                      child: Icon(Icons.check_circle, color: Colors.green.shade400, size: 120),
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