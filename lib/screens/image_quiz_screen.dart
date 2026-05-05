import 'dart:math' as math;

import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/achievement_service.dart';
import 'package:english_learning_app/services/level_progress_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/services/word_mastery_service.dart';
import 'package:english_learning_app/services/word_repository.dart';
import 'package:english_learning_app/widgets/ui/glass_card.dart';
import 'package:english_learning_app/widgets/ui/spark_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

/// Image Quiz mini-game integrated with the Living World: uses WordRepository +
/// WordMasteryService for spaced repetition, LevelProgressService for
/// completion/mastery/bridge, CoinProvider and SparkOverlayController for UX.
class ImageQuizScreen extends StatefulWidget {
  const ImageQuizScreen({
    super.key,
    required this.levelId,
    required this.wordsForLevel,
    this.wordRepository,
    this.wordMasteryService,
    this.levelProgressService,
  });

  final String levelId;
  final List<WordData> wordsForLevel;
  final WordRepository? wordRepository;
  final WordMasteryService? wordMasteryService;
  final LevelProgressService? levelProgressService;

  @override
  State<ImageQuizScreen> createState() => _ImageQuizScreenState();
}

class _ImageQuizScreenState extends State<ImageQuizScreen> {
  static const int _minWordsForQuiz = 4;
  static const int _baseReward = 10;
  static const int _rewardPerStreak = 2;

  late final WordRepository _wordRepository;
  late final WordMasteryService _wordMasteryService;
  late final LevelProgressService _levelProgressService;
  late final SparkVoiceService _sparkVoiceService;
  late final FlutterTts _flutterTts;

  List<WordData> _wordsWithMastery = [];
  bool _isLoading = true;
  String? _loadError;
  int _currentIndex = 0;
  bool _answered = false;
  WordData? _selectedOption;
  int _streak = 0;
  String? _feedbackMessage;
  late List<WordData> _currentOptions;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _wordRepository = widget.wordRepository ?? WordRepository();
    _wordMasteryService = widget.wordMasteryService ?? WordMasteryService();
    _levelProgressService =
        widget.levelProgressService ?? LevelProgressService();
    _sparkVoiceService = SparkVoiceService();
    _flutterTts = FlutterTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySparkHappy();
      _loadWords();
      _configureTts();
    });
  }

  void _notifySparkHappy() {
    final controller = context.read<SparkOverlayController>();
    controller.setEmotion(SparkEmotion.happy);
  }

  Future<void> _configureTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.setPitch(1.1);
    } catch (_) {}
  }

  Future<void> _loadWords() async {
    final session = context.read<UserSessionProvider>();
    final userId = session.currentUser?.id ?? 'local_guest';

    try {
      final words = await _wordRepository.loadWords(
        remoteEnabled: true,
        fallbackWords: widget.wordsForLevel,
        cloudName: AppConfig.cloudinaryCloudName,
        tagName: 'english_kids_app',
        maxResults: 50,
        cacheNamespace: widget.levelId,
      );

      final List<WordData> withMastery = [];
      for (final w in words) {
        final entry = await _wordMasteryService.getMastery(
          userId: userId,
          levelId: widget.levelId,
          word: w.word,
        );
        withMastery.add(_wordMasteryService.applyToWord(w, entry));
      }
      withMastery.sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));

      if (mounted) {
        setState(() {
          _wordsWithMastery = withMastery;
          _isLoading = false;
          _loadError = null;
        });
        if (_wordsWithMastery.length >= _minWordsForQuiz) {
          _prepareQuestion();
        }
      }
    } catch (e, st) {
      debugPrint('ImageQuizScreen loadWords error: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'לא ניתן לטעון מילים. נסו שוב.';
        });
      }
    }
  }

  void _prepareQuestion() {
    if (_wordsWithMastery.length < _minWordsForQuiz) return;
    final target = _wordsWithMastery[_currentIndex];
    final others = _wordsWithMastery
        .where((w) => w.word != target.word)
        .toList()
      ..shuffle(_random);
    final wrong = others.take(3).toList();
    final options = [target, ...wrong]..shuffle(_random);
    setState(() {
      _currentOptions = options;
      _answered = false;
      _selectedOption = null;
      _feedbackMessage = null;
    });
    _playWord(target.word);
  }

  Future<void> _playWord(String word) async {
    if (word.isEmpty) return;
    try {
      if (AppConfig.hasGoogleTts) {
        await _sparkVoiceService.speak(
          text: word,
          isEnglish: true,
          emotion: SparkEmotion.happy,
        );
      } else {
        await _flutterTts.setLanguage('en-US');
        await _flutterTts.setSpeechRate(0.4);
        await _flutterTts.setPitch(1.1);
        await _flutterTts.speak(word);
      }
    } catch (_) {}
  }

  String? _imageUrlForWord(WordData word) {
    if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
      return word.imageUrl;
    }
    if (word.publicId != null && word.publicId!.isNotEmpty) {
      final cloudName = AppConfig.cloudinaryCloudName;
      if (cloudName.isNotEmpty) {
        return 'https://res.cloudinary.com/$cloudName/image/upload/${word.publicId}';
      }
    }
    return null;
  }

  bool _isAssetUrl(String? url) {
    return url != null && url.startsWith('assets/');
  }

  Future<void> _onOptionSelected(WordData option) async {
    if (_answered) return;
    final target = _wordsWithMastery[_currentIndex];
    final isCorrect = option.word == target.word;
    final session = context.read<UserSessionProvider>();
    final userId = session.currentUser?.id ?? 'local_guest';
    final isLocalUser =
        session.currentUser == null || !session.currentUser!.isGoogle;

    setState(() {
      _answered = true;
      _selectedOption = option;
    });

    if (isCorrect) {
      final reward = _baseReward + _streak * _rewardPerStreak;
      final coinProvider = context.read<CoinProvider>();
      final sparkController = context.read<SparkOverlayController>();
      await coinProvider.addCoins(reward);
      await _levelProgressService.markWordCompleted(
        userId,
        widget.levelId,
        target.word,
        isLocalUser: isLocalUser,
      );
      if (mounted) {
        sparkController.markCelebrating();
        setState(() {
          _streak += 1;
          _feedbackMessage = 'כל הכבוד! הרווחת $reward מטבעות';
        });
        context.read<AchievementService>().checkForAchievements(streak: _streak);
      }
    } else {
      if (mounted) {
        setState(() {
          _streak = 0;
          _feedbackMessage = 'לא הפעם. המילה הנכונה: ${target.word}';
        });
      }
    }
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _wordsWithMastery.length;
    });
    _prepareQuestion();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('בוחן תמונות')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || _wordsWithMastery.length < _minWordsForQuiz) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('בוחן תמונות')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _loadError ?? 'נדרשות לפחות $_minWordsForQuiz מילים ברמה כדי לשחק.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final target = _wordsWithMastery[_currentIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('בוחן תמונות'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: Text(
                'סטריק: $_streak',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      target.word,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    IconButton.filled(
                      onPressed: () => _playWord(target.word),
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'השמע מילה',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: _currentOptions.map((option) {
                  return _OptionTile(
                    key: Key('option_${option.word}'),
                    word: option,
                    imageUrl: _imageUrlForWord(option),
                    isAsset: _isAssetUrl(_imageUrlForWord(option)),
                    isSelected: _selectedOption?.word == option.word,
                    isCorrect: option.word == target.word,
                    answered: _answered,
                    onTap: () => _onOptionSelected(option),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_feedbackMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _feedbackMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _selectedOption?.word == target.word
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                  ),
                ),
              SparkButton(
                label: _answered ? 'שאלה הבאה' : 'בחר תמונה',
                onPressed: _answered ? _nextQuestion : () {},
                backgroundColor: _answered
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                icon: Icons.arrow_forward,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.word,
    required this.imageUrl,
    required this.isAsset,
    required this.isSelected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final WordData word;
  final String? imageUrl;
  final bool isAsset;
  final bool isSelected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (imageUrl == null || imageUrl!.isEmpty) {
      imageWidget = const Center(
        child: Icon(Icons.image_not_supported, size: 48),
      );
    } else if (isAsset) {
      imageWidget = Image.asset(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
      );
    }

    Color? borderColor;
    if (answered) {
      borderColor = isCorrect ? Colors.green : (isSelected ? Colors.orange : null);
    } else if (isSelected) {
      borderColor = Colors.blue;
    }

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: answered ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: imageWidget,
                ),
              ),
              if (answered && (isCorrect || isSelected))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    word.word,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
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
