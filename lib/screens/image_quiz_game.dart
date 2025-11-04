import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_item.dart';
import '../providers/coin_provider.dart';
import '../services/telemetry_service.dart';
import '../widgets/answer_button.dart';

// רשימת שאלות (אפשר להוציא לקובץ נפרד, או API)
final List<QuizItem> quizItems = [
  QuizItem(
    imageAsset: 'assets/images/magic_hat.jpg',
    correctAnswer: 'Magic Hat',
    wrongAnswers: ['Super Shoes', 'Power Sword', 'Treasure Map'],
  ),
  QuizItem(
    imageAsset: 'assets/images/super_shoes.jpg',
    correctAnswer: 'Super Shoes',
    wrongAnswers: ['Magic Hat', 'Power Sword', 'Golden Trophy'],
  ),
  QuizItem(
    imageAsset: 'assets/images/power_sword.jpg',
    correctAnswer: 'Power Sword',
    wrongAnswers: ['Magic Hat', 'Super Shoes', 'Magic Wand'],
  ),
];

class ImageQuizGame extends StatefulWidget {
  const ImageQuizGame({super.key});

  @override
  State<ImageQuizGame> createState() => _ImageQuizGameState();
}

class _ImageQuizGameState extends State<ImageQuizGame> {
  static const int _baseReward = 10;
  static const int _streakBonusStep = 2;

  final math.Random _random = math.Random();

  int _currentIndex = 0;
  bool _answered = false;
  String? _selectedAnswer;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _hintUsed = false;
  String? _feedbackMessage;
  late List<String> _currentOptions;

  @override
  void initState() {
    super.initState();
    _prepareNextQuestion();
  }

  Future<void> _answerQuestion(String answer) async {
    if (_answered) {
      return;
    }

    final quizItem = quizItems[_currentIndex];
    final isCorrect = answer == quizItem.correctAnswer;
    final telemetry = Provider.maybeOf<TelemetryService>(context, listen: false);

    int reward = 0;
    int newScore = _score;
    int newStreak = _streak;
    String feedback;

    if (isCorrect) {
      newStreak = _streak + 1;
      reward = _baseReward + (newStreak - 1) * _streakBonusStep;
      newScore += reward;
      feedback = 'כל הכבוד! זכית ב+$reward מטבעות';
      await context.read<CoinProvider>().addCoins(reward);
    } else {
      newStreak = 0;
      feedback = 'אופס! התשובה הנכונה היא ${quizItem.correctAnswer}.';
    }

    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      _streak = newStreak;
      _bestStreak = math.max(_bestStreak, newStreak);
      _score = newScore;
      _feedbackMessage = feedback;
    });

    telemetry?.logQuizAnswered(
      word: quizItem.correctAnswer,
      correct: isCorrect,
      reward: reward,
      streak: newStreak,
      questionIndex: _currentIndex,
      hintUsed: _hintUsed,
    );
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % quizItems.length;
      _prepareNextQuestion();
    });
  }

  void _prepareNextQuestion() {
    _currentOptions = quizItems[_currentIndex].getShuffledAnswers(random: _random);
    _answered = false;
    _selectedAnswer = null;
    _hintUsed = false;
    _feedbackMessage = null;
  }

  void _useHint() {
    if (_answered || _hintUsed) {
      return;
    }

    final quizItem = quizItems[_currentIndex];
    final wrongAnswers = _currentOptions.where((answer) => answer != quizItem.correctAnswer).toList();
    if (wrongAnswers.isEmpty) {
      return;
    }

    final answerToRemove = wrongAnswers[_random.nextInt(wrongAnswers.length)];
    final telemetry = Provider.maybeOf<TelemetryService>(context, listen: false);
    final remainingOptions = _currentOptions.length - 1;

    setState(() {
      _currentOptions = List<String>.from(_currentOptions)..remove(answerToRemove);
      _hintUsed = true;
      _feedbackMessage = 'הסרתי תשובה אחת שלא מתאימה 😉';
    });

    telemetry?.logHintUsed(
      word: quizItem.correctAnswer,
      optionsRemaining: remainingOptions,
    );
  }

  Widget _buildScoreHeader(BuildContext context) {
    final totalCoins = context.watch<CoinProvider>().coins;

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            _StatBadge(label: 'ניקוד', value: _score, icon: Icons.emoji_events),
            _StatBadge(label: 'רצף', value: _streak, icon: Icons.local_fire_department),
            _StatBadge(label: 'שיא רצף', value: _bestStreak, icon: Icons.military_tech),
            _StatBadge(label: 'מטבעות', value: totalCoins, icon: Icons.attach_money),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizItem = quizItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('משחק תמונות'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScoreHeader(context),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                clipBehavior: Clip.hardEdge,
                child: Image.asset(
                  quizItem.imageAsset,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: (!_answered && !_hintUsed && _currentOptions.length > 2) ? _useHint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_hintUsed ? 'רמז בשימוש' : 'קבל רמז'),
                ),
              ),
              const SizedBox(height: 16),
              ..._currentOptions.map(
                (answer) => AnswerButton(
                  key: ValueKey(answer),
                  answer: answer,
                  isSelected: _selectedAnswer == answer,
                  isCorrect: answer == quizItem.correctAnswer,
                  answered: _answered,
                  onTap: () {
                    _answerQuestion(answer);
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _feedbackMessage == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(_feedbackMessage),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                        ),
                        child: Text(
                          _feedbackMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.purple),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answered ? Colors.green.shade700 : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                  onPressed: _answered ? _nextQuestion : null,
                  child: Text(
                    _answered ? 'שאלה הבאה' : 'בחר תשובה כדי להמשיך',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatBadge({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green.shade700),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
