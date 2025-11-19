import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_item.dart';
import '../models/daily_mission.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';
import '../services/telemetry_service.dart';
import '../widgets/answer_button.dart';

// Quiz question list (can be moved to a separate file or API)
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
  QuizItem(
    imageAsset: 'assets/images/words/hero_shield.png',
    correctAnswer: 'Hero Shield',
    wrongAnswers: ['Treasure Map', 'Dragon Armor', 'Energy Gauntlet'],
  ),
  QuizItem(
    imageAsset: 'assets/images/words/hot_air_balloon.png',
    correctAnswer: 'Hot Air Balloon',
    wrongAnswers: ['Helicopter', 'Submarine', 'Train'],
  ),
  QuizItem(
    imageAsset: 'assets/images/words/apple.png',
    correctAnswer: 'Apple',
    wrongAnswers: ['Banana', 'Orange', 'Strawberry'],
  ),
  QuizItem(
    imageAsset: 'assets/images/words/pineapple.png',
    correctAnswer: 'Pineapple',
    wrongAnswers: ['Banana', 'Grapes', 'Apple'],
  ),
  QuizItem(
    imageAsset: 'assets/images/words/lion.png',
    correctAnswer: 'Lion',
    wrongAnswers: ['Monkey', 'Elephant', 'Dog'],
  ),
  QuizItem(
    imageAsset: 'assets/images/words/penguin.png',
    correctAnswer: 'Penguin',
    wrongAnswers: ['Lion', 'Cat', 'Dog'],
  ),
  QuizItem(
    imageAsset: 'assets/images/words/astronaut.png',
    correctAnswer: 'Astronaut',
    wrongAnswers: ['Rocket', 'Satellite', 'Space Station'],
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
    final telemetry = TelemetryService.maybeOf(context);

    int reward = 0;
    int newScore = _score;
    int newStreak = _streak;
    String feedback;

    if (isCorrect) {
      newStreak = _streak + 1;
      reward = _baseReward + (newStreak - 1) * _streakBonusStep;
      newScore += reward;
      feedback = 'Great job! You earned +$reward coins';
      await context.read<CoinProvider>().addCoins(reward);
    } else {
      newStreak = 0;
      feedback = 'Oops! The correct answer is ${quizItem.correctAnswer}.';
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

    try {
      if (mounted) {
        context.read<DailyMissionProvider>().incrementByType(
          DailyMissionType.quizPlay,
        );
      }
    } on ProviderNotFoundException {
      // Tests or standalone screens might not provide DailyMissionProvider; ignore silently.
    }
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % quizItems.length;
      _prepareNextQuestion();
    });
  }

  void _prepareNextQuestion() {
    _currentOptions = quizItems[_currentIndex].getShuffledAnswers(
      random: _random,
    );
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
    final wrongAnswers = _currentOptions
        .where((answer) => answer != quizItem.correctAnswer)
        .toList();
    if (wrongAnswers.isEmpty) {
      return;
    }

    final answerToRemove = wrongAnswers[_random.nextInt(wrongAnswers.length)];
    final telemetry = TelemetryService.maybeOf(context);
    final remainingOptions = _currentOptions.length - 1;

    setState(() {
      _currentOptions = List<String>.from(_currentOptions)
        ..remove(answerToRemove);
      _hintUsed = true;
      _feedbackMessage = 'I removed one incorrect option 😉';
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
            _StatBadge(label: 'Score', value: _score, icon: Icons.emoji_events),
            _StatBadge(
              label: 'Streak',
              value: _streak,
              icon: Icons.local_fire_department,
            ),
            _StatBadge(
              label: 'Best Streak',
              value: _bestStreak,
              icon: Icons.military_tech,
            ),
            _StatBadge(
              label: 'Coins',
              value: totalCoins,
              icon: Icons.attach_money,
            ),
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
        title: const Text('Image Quiz Game'),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
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
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed:
                      (!_answered && !_hintUsed && _currentOptions.length > 2)
                      ? _useHint
                      : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_hintUsed ? 'Hint used' : 'Get a hint'),
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
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          _feedbackMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answered
                        ? Colors.green.shade700
                        : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  onPressed: _answered ? _nextQuestion : null,
                  child: Text(
                    _answered
                        ? 'Next question'
                        : 'Choose an answer to continue',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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

  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

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
