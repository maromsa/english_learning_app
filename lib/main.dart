import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:speech_to_text/speech_to_text.dart'; // Temporarily disabled
import 'package:english_learning_app/config.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class WordData {
  final String word;
  final String imageUrl;

  const WordData({required this.word, required this.imageUrl});

  factory WordData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WordData(
      word: data['word'] ?? 'Error',
      imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/250/FF0000/FFFFFF?text=Error',
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
  late final GenerativeModel _model;
  late final FlutterTts flutterTts;
  // late final SpeechToText _speechToText; // Temporarily disabled

  bool _isLoading = true;
  String? _userId;
  List<WordData> _words = [];
  int _currentIndex = 0;

  // bool _speechEnabled = false; // Temporarily disabled
  // String _lastWords = ''; // Temporarily disabled
  // String _geminiResponse = ''; // Temporarily disabled

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _model = GenerativeModel(model: 'gemini-pro', apiKey: geminiApiKey);
    flutterTts = FlutterTts();
    await _configureTts();
    // _speechToText = SpeechToText(); // Temporarily disabled
    // _speechEnabled = await _speechToText.initialize(); // Temporarily disabled

    await _initializeFirebaseUser();

    if (mounted) setState(() {});
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
        print('Firebase User ID: $_userId');
        _setupFirestoreListener();
      }
    } catch (e) {
      print("Firebase Auth Error: $e");
      if (mounted) setState(() => _isLoading = false);
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
            if (_currentIndex >= _words.length) _currentIndex = 0;
          });
        }
      }
    });
  }

  Future<void> _addInitialWordsToFirestore() async {
    if (_userId == null) return;
    print('Database is empty. Adding initial words...');
    final collection = FirebaseFirestore.instance.collection('users').doc(_userId).collection('words');
    final batch = FirebaseFirestore.instance.batch();
    batch.set(collection.doc(), {'word': 'Apple', 'imageUrl': 'https://i.imgur.com/gAYAEa5.png'});
    batch.set(collection.doc(), {'word': 'Banana', 'imageUrl': 'https://i.imgur.com/r3yC4QG.png'});
    batch.set(collection.doc(), {'word': 'Car', 'imageUrl': 'https://i.imgur.com/mJ9f5gS.png'});
    await batch.commit();
  }

  void _nextWord() {
    if (_words.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _words.length;
      });
    }
  }

  void _previousWord() {
    if (_words.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
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
              if (currentWordData != null) ...[
                Container(
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
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: Image.network(
                      currentWordData.imageUrl,
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error_outline, size: 150, color: Colors.grey);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  currentWordData.word,
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ] else
                const Text("No words found!", style: TextStyle(fontSize: 22)),

              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: (currentWordData == null) ? null : () => flutterTts.speak(currentWordData.word),
                icon: const Icon(Icons.volume_up, size: 30),
                label: const Text('Listen', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: Colors.green.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 20),
              // --- SPEAK BUTTON DISABLED FOR DIAGNOSTICS ---
              FloatingActionButton.extended(
                onPressed: null, // Disabled
                label: const Text('Speak', style: TextStyle(fontSize: 24)),
                icon: const Icon(Icons.mic_off, size: 30),
                backgroundColor: Colors.grey,
              ),
              const SizedBox(height: 120), // Placeholder for feedback area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _previousWord,
                    child: const Icon(Icons.arrow_back),
                  ),
                  ElevatedButton(
                    onPressed: _nextWord,
                    child: const Icon(Icons.arrow_forward),
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