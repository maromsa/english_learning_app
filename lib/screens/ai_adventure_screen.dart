import 'package:english_learning_app/models/level_data.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/adventure_story_service.dart';
import 'package:english_learning_app/models/word_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';

class AiAdventureScreen extends StatefulWidget {
  const AiAdventureScreen({super.key, required this.levels, required this.totalStars});

  final List<LevelData> levels;
  final int totalStars;

  @override
  State<AiAdventureScreen> createState() => _AiAdventureScreenState();
}

class _AiAdventureScreenState extends State<AiAdventureScreen> {
  late final AdventureStoryService _service;
  late LevelData _selectedLevel;

  String _selectedMood = _moods.first;
  bool _isGenerating = false;
  AdventureStory? _story;
  String? _error;
  final TextEditingController _nameController = TextEditingController();

  static const List<String> _moods = <String>[
    'brave explorer',
    'curious scientist',
    'kind helper',
    'silly comedian',
  ];

  @override
  void initState() {
    super.initState();
    _service = AdventureStoryService();
    _selectedLevel = _initialLevel();
  }

  LevelData _initialLevel() {
    final unlocked = widget.levels.where((level) => level.isUnlocked).toList(growable: false);
    if (unlocked.isNotEmpty) {
      return unlocked.first;
    }
    if (widget.levels.isNotEmpty) {
      return widget.levels.first;
    }
    return LevelData(
      id: 'placeholder_world',
      name: 'Starter World',
      words: const <WordData>[],
      isUnlocked: true,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasGemini = AppConfig.hasGemini;
    final coins = context.watch<CoinProvider>().coins;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spark\'s Adventure Lab'),
        backgroundColor: Colors.deepPurple.shade400,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF482E96), Color(0xFF8A4FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        hasGemini
                            ? 'Spark the Gemini mentor is ready to spin a quest just for you.'
                            : 'Add a GEMINI_API_KEY via --dart-define to unlock Spark\'s quests.',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildLevelPicker(),
                      const SizedBox(height: 16),
                      _buildMoodPicker(),
                      const SizedBox(height: 16),
                      _buildStatsRow(coins: coins),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: hasGemini && !_isGenerating ? () => _generateAdventure(coins) : null,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(_isGenerating ? 'Summoning Spark...' : 'Create My Quest'),
                      ),
                      const SizedBox(height: 16),
                      if (_isGenerating)
                        const Center(child: CircularProgressIndicator()),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (_story != null) _StoryView(story: _story!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Player name (optional)',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildLevelPicker() {
    if (widget.levels.isEmpty) {
      return const Text('No levels available yet. Start your journey from the map!');
    }

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Choose a world',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LevelData>(
          value: _selectedLevel,
          items: widget.levels
              .map(
                (level) => DropdownMenuItem<LevelData>(
                  value: level,
                  child: Row(
                    children: [
                      Icon(
                        level.isUnlocked ? Icons.rocket_launch : Icons.lock_outline,
                        color: level.isUnlocked ? Colors.indigo : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(level.name)),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (LevelData? value) {
            if (value != null) {
              setState(() {
                _selectedLevel = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildMoodPicker() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Pick a vibe',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMood,
          items: _moods
              .map((mood) => DropdownMenuItem<String>(
                    value: mood,
                    child: Text(mood[0].toUpperCase() + mood.substring(1)),
                  ))
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedMood = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow({required int coins}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatChip(icon: Icons.monetization_on, label: 'Coins', value: coins.toString()),
            _StatChip(icon: Icons.star_rate, label: 'Total stars', value: '${widget.totalStars}'),
            _StatChip(icon: Icons.stars, label: 'Level stars', value: '${_selectedLevel.stars}'),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAdventure(int coins) async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final selected = _selectedLevel;
    final context = AdventureStoryContext(
      levelName: selected.name,
      levelDescription: selected.description ?? 'A surprise level full of learning treasures.',
      vocabularyWords: selected.words.map((word) => word.word).take(6).toList(growable: false),
      levelStars: selected.stars,
      totalStars: widget.totalStars,
      coins: coins,
      mood: _selectedMood,
      playerName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
    );

    try {
      final story = await _service.generateAdventure(context);
      if (!mounted) return;
      setState(() {
        _story = story;
      });
    } on AdventureStoryGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _story = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}

class _StoryView extends StatelessWidget {
  const _StoryView({required this.story});

  final AdventureStory story;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.title.isEmpty ? 'Spark\'s Quest' : story.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.deepPurple.shade700,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            story.scene,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (story.challenge.isNotEmpty)
            _StorySection(
              icon: Icons.flash_on,
              label: 'Challenge',
              text: story.challenge,
            ),
          if (story.encouragement.isNotEmpty)
            _StorySection(
              icon: Icons.favorite,
              label: 'Spark says',
              text: story.encouragement,
            ),
          if (story.vocabulary.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: story.vocabulary
                  .map((word) => Chip(
                        label: Text(word),
                        avatar: const Icon(Icons.menu_book, size: 16),
                      ))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _StorySection extends StatelessWidget {
  const _StorySection({required this.icon, required this.label, required this.text});

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple.shade400),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
