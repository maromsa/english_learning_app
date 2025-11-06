import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_mission.dart';
import '../models/word_data.dart';
import '../providers/coin_provider.dart';
import '../providers/daily_mission_provider.dart';
import '../services/telemetry_service.dart';

class LightningPracticeScreen extends StatefulWidget {
  const LightningPracticeScreen({
    super.key,
    required this.words,
    this.levelTitle,
  });

  final List<WordData> words;
  final String? levelTitle;

  @override
  State<LightningPracticeScreen> createState() => _LightningPracticeScreenState();
}

class _LightningPracticeScreenState extends State<LightningPracticeScreen> {
  static const int _sessionSeconds = 60;
  static const int _recentHistorySize = 4;

  final Random _random = Random();
  final Queue<String> _recentWords = Queue<String>();

  late final List<WordData> _wordPool;
  late TelemetryService? _telemetry;

  Timer? _timer;
  int _remainingSeconds = _sessionSeconds;
  bool _sessionActive = false;
  bool _sessionEnded = false;

  WordData? _currentWord;
  List<String> _currentOptions = <String>[];
  String? _selectedAnswer;
  bool? _lastAnswerCorrect;
  bool _awaitingNext = false;
  String? _feedback;

  int _score = 0;
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  int _questionCount = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;

  static const List<Map<String, String>> _fallbackWordEntries = [
    {'word': 'Rainbow', 'hint': 'כל הצבעים שמופיעים אחרי הגשם'},
    {'word': 'Pirate', 'hint': 'שודד ים עם כובע וטלאי עין'},
    {'word': 'Robot', 'hint': 'מכונה חכמה שמדברת ומזיזה ידיים'},
    {'word': 'Castle', 'hint': 'בית גדול של מלך ומלכה'},
    {'word': 'Rocket', 'hint': 'טיל שטס אל החלל'},
    {'word': 'Puppy', 'hint': 'כלבלב קטן וחמוד'},
    {'word': 'Galaxy', 'hint': 'אוסף ענק של כוכבים וחלליות'},
    {'word': 'Treasure', 'hint': 'תיבת מטבעות ואבני חן נוצצות'},
  ];

  @override
  void initState() {
    super.initState();
    _wordPool = _buildWordPool();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _telemetry = TelemetryService.maybeOf(context);
      _telemetry?.startScreenSession('lightning');
      _startSession();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _telemetry?.endScreenSession('lightning', extra: {
      'score': _score,
      'correct': _correctAnswers,
      'incorrect': _incorrectAnswers,
      'best_streak': _bestStreak,
      'questions': _questionCount,
    });
    super.dispose();
  }

  List<WordData> _buildWordPool() {
    final List<WordData> cleaned = widget.words
        .where((word) => word.word.trim().isNotEmpty)
        .map((word) => WordData(
              word: word.word.trim(),
              searchHint: word.searchHint,
              imageUrl: word.imageUrl,
            ))
        .toList(growable: true);

    if (cleaned.length >= 4) {
      return cleaned;
    }

    for (final entry in _fallbackWordEntries) {
      final word = entry['word']!;
      final hint = entry['hint'];
      if (cleaned.any((existing) => existing.word.toLowerCase() == word.toLowerCase())) {
        continue;
      }
      cleaned.add(WordData(word: word, searchHint: hint));
      if (cleaned.length >= 8) {
        break;
      }
    }

    return cleaned;
  }

  void _startSession() {
    if (_wordPool.length < 2) {
      setState(() {
        _sessionActive = false;
        _sessionEnded = true;
        _feedback = 'אין מספיק מילים כדי להתחיל ריצת ברק. הוסיפו עוד מילים בשלב!';
      });
      return;
    }

    _timer?.cancel();
    setState(() {
      _sessionActive = true;
      _sessionEnded = false;
      _awaitingNext = false;
      _selectedAnswer = null;
      _lastAnswerCorrect = null;
      _feedback = null;
      _remainingSeconds = _sessionSeconds;
      _score = 0;
      _correctAnswers = 0;
      _incorrectAnswers = 0;
      _questionCount = 0;
      _currentStreak = 0;
      _bestStreak = 0;
      _recentWords.clear();
    });
    _prepareNextQuestion();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _endSession(triggeredByTimer: true);
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _prepareNextQuestion() {
    if (_wordPool.isEmpty) {
      return;
    }

    final List<WordData> candidates = _wordPool
        .where((word) => !_recentWords.contains(word.word))
        .toList(growable: false);
    final List<WordData> source = candidates.isNotEmpty ? candidates : _wordPool;
    final WordData nextWord = source[_random.nextInt(source.length)];

    _recentWords.addLast(nextWord.word);
    if (_recentWords.length > _recentHistorySize) {
      _recentWords.removeFirst();
    }

    setState(() {
      _currentWord = nextWord;
      _currentOptions = _buildOptions(nextWord.word);
      _selectedAnswer = null;
      _awaitingNext = false;
      _lastAnswerCorrect = null;
      _feedback = null;
    });
  }

  List<String> _buildOptions(String correctWord) {
    final Set<String> options = <String>{correctWord};
    final List<String> pool = _wordPool
        .map((word) => word.word)
        .where((word) => !word.equalsIgnoreCase(correctWord))
        .toList(growable: true);

    while (options.length < 4 && pool.isNotEmpty) {
      final candidate = pool.removeAt(_random.nextInt(pool.length));
      options.add(candidate);
    }

    while (options.length < 4) {
      final fallback = _fallbackWordEntries[_random.nextInt(_fallbackWordEntries.length)]['word']!;
      if (!options.contains(fallback)) {
        options.add(fallback);
      }
    }

    final List<String> shuffled = options.toList(growable: false);
    shuffled.shuffle(_random);
    return shuffled;
  }

  Future<void> _handleAnswer(String option) async {
    if (!_sessionActive || _sessionEnded || _awaitingNext || _currentWord == null) {
      return;
    }

    setState(() {
      _awaitingNext = true;
      _selectedAnswer = option;
      _questionCount++;
    });

    final bool isCorrect = option == _currentWord!.word;
    int reward = 0;
    String feedback;

    if (isCorrect) {
      _currentStreak += 1;
      _bestStreak = max(_bestStreak, _currentStreak);
      reward = 5 + ((_currentStreak - 1) * 2);
      _score += reward;
      _correctAnswers += 1;
      feedback = 'מעולה! הרווחתם $reward מטבעות ⚡️';
      await context.read<CoinProvider>().addCoins(reward);
    } else {
      _currentStreak = 0;
      _incorrectAnswers += 1;
      reward = 0;
      feedback = 'כמעט! התשובה הנכונה: "${_currentWord!.word}".';
    }

    final int elapsed = _sessionSeconds - _remainingSeconds;
    _telemetry?.logLightningAnswer(
      word: _currentWord!.word,
      correct: isCorrect,
      streak: _currentStreak,
      elapsedSeconds: elapsed < 0 ? 0 : elapsed,
      remainingSeconds: _remainingSeconds,
      reward: reward,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _feedback = feedback;
      _lastAnswerCorrect = isCorrect;
    });

    if (_remainingSeconds <= 0) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _endSession();
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _sessionEnded) {
        return;
      }
      setState(() {
        _awaitingNext = false;
        _selectedAnswer = null;
        _lastAnswerCorrect = null;
        _feedback = null;
      });
      _prepareNextQuestion();
    });
  }

  void _endSession({bool triggeredByTimer = false}) {
    if (_sessionEnded) {
      return;
    }

    _timer?.cancel();
    setState(() {
      _sessionActive = false;
      _sessionEnded = true;
    });

    context.read<DailyMissionProvider>().incrementByType(
          DailyMissionType.lightningRound,
        );

    _telemetry?.logLightningSession(
      score: _score,
      correct: _correctAnswers,
      incorrect: _incorrectAnswers,
      bestStreak: _bestStreak,
      totalQuestions: _questionCount,
    );

    if (triggeredByTimer && mounted) {
      setState(() {
        _feedback = _feedback ?? 'הזמן נגמר! בואו נסקור את ההצלחה שלכם.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool insufficientWords = _wordPool.length < 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.levelTitle == null ? 'ריצת ברק' : 'ריצת ברק - ${widget.levelTitle}'),
        backgroundColor: Colors.deepOrange.shade400,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: insufficientWords
              ? _buildEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusRow(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _sessionEnded
                            ? _buildSummaryCard()
                            : _buildQuestionCard(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBottomControls(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    final double accuracy = _questionCount == 0 ? 0 : (_correctAnswers / _questionCount) * 100;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatusChip(
              icon: Icons.timer_outlined,
              label: 'זמן',
              value: '${_remainingSeconds}s',
              color: Colors.deepOrange.shade500,
            ),
            _StatusChip(
              icon: Icons.flash_on,
              label: 'ניקוד',
              value: '$_score',
              color: Colors.amber.shade800,
            ),
            _StatusChip(
              icon: Icons.whatshot,
              label: 'רצף',
              value: '$_currentStreak',
              color: Colors.redAccent.shade200,
            ),
            _StatusChip(
              icon: Icons.insights,
              label: 'דיוק',
              value: '${accuracy.round()}%',
              color: Colors.blue.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final word = _currentWord;
    if (word == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget? visual = _buildVisual(word);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'רמז קסם:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _clueForWord(word),
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            if (visual != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(height: 160, child: visual),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _currentOptions
                      .map((option) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LightningOptionButton(
                              option: option,
                              isSelected: _selectedAnswer == option,
                              isCorrectAnswer: word.word == option,
                              awaitingNext: _awaitingNext,
                              onTap: () => _handleAnswer(option),
                            ),
                          ))
                      .toList(growable: false),
                ),
              ),
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: 1,
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _lastAnswerCorrect == true
                          ? Colors.green.shade700
                          : Colors.redAccent.shade200,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'סיכום ריצת הברק',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade600,
                  ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _SummaryStat(label: 'ניקוד', value: '$_score', icon: Icons.flash_on, color: Colors.deepOrange),
                _SummaryStat(label: 'תשובות נכונות', value: '$_correctAnswers', icon: Icons.check_circle, color: Colors.green),
                _SummaryStat(label: 'טעויות', value: '$_incorrectAnswers', icon: Icons.close_rounded, color: Colors.redAccent),
                _SummaryStat(label: 'רצף שיא', value: '$_bestStreak', icon: Icons.whatshot, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.refresh),
              label: const Text('שחקו שוב'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('חזרה למסע'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_sessionEnded) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: _sessionActive ? () => _endSession() : null,
          icon: const Icon(Icons.flag_circle_outlined),
          label: const Text('סיימו מוקדם'),
        ),
        TextButton.icon(
          onPressed: _awaitingNext || _sessionEnded ? null : () => _prepareNextQuestion(),
          icon: const Icon(Icons.shuffle),
          label: const Text('דלגו לרמז חדש'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 64, color: Colors.deepOrange.shade300),
              const SizedBox(height: 16),
              const Text(
                'זקוקים לעוד מילים כדי להתחיל את ריצת הברק!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'הוסיפו מילים חדשות בשלב או צלמו חפצים חדשים במצלמה.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildVisual(WordData word) {
    final String? path = word.imageUrl;
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.contain);
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return null;
  }

  String _clueForWord(WordData word) {
    final hint = word.searchHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      return hint.endsWith('.') ? hint : '$hint.';
    }
    final cleaned = word.word.trim();
    if (cleaned.length <= 2) {
      return 'איזו מילה אתם מזהים? היא קצרה ומהירה!';
    }
    final first = cleaned.characters.first.toUpperCase();
    final last = cleaned.characters.last.toUpperCase();
    return 'המילה מתחילה באות $first ונגמרת באות $last.';
  }
}

class _LightningOptionButton extends StatelessWidget {
  const _LightningOptionButton({
    required this.option,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.awaitingNext,
    required this.onTap,
  });

  final String option;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool awaitingNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color background = Colors.white;
    Color borderColor = Colors.deepOrange.shade100;
    Color textColor = Colors.deepOrange.shade800;

    if (awaitingNext) {
      if (isCorrectAnswer) {
        background = Colors.green.shade100;
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade800;
      } else if (isSelected) {
        background = Colors.red.shade100;
        borderColor = Colors.redAccent;
        textColor = Colors.red.shade700;
      } else {
        background = Colors.white;
      }
    } else if (isSelected) {
      background = Colors.deepOrange.shade100;
      borderColor = Colors.deepOrange.shade400;
    }

    return ElevatedButton(
      onPressed: awaitingNext ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background,
        foregroundColor: textColor,
        elevation: awaitingNext ? 0 : 3,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 2),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          option,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

extension StringCaseCompare on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
