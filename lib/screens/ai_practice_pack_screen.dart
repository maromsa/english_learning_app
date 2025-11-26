import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/practice_pack_service.dart';
import 'package:english_learning_app/services/local_user_service.dart';
import 'package:english_learning_app/models/local_user.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/services/background_music_service.dart';
import 'package:english_learning_app/utils/route_observer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AiPracticePackScreen extends StatefulWidget {
  const AiPracticePackScreen({super.key, this.focusWords = const <String>[]});

  final List<String> focusWords;

  @override
  State<AiPracticePackScreen> createState() => _AiPracticePackScreenState();
}

class _AiPracticePackScreenState extends State<AiPracticePackScreen>
    with RouteAware {
  late final PracticePackService _service;
  final LocalUserService _localUserService = LocalUserService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _extraWordsController = TextEditingController();

  PracticePack? _pack;
  List<bool> _completed = const [];
  bool _isGenerating = false;
  String? _errorMessage;

  String _selectedSkill = _skills.first.id;
  String _selectedTime = _durations.first.id;
  String _selectedEnergy = _energies.first.id;
  String _selectedMode = _modes.first.id;

  @override
  void initState() {
    super.initState();
    // Stop map music immediately when entering AI practice pack screen
    // Use fadeOut first for smooth transition, then stop
    BackgroundMusicService()
        .fadeOut(duration: const Duration(milliseconds: 300))
        .then((_) {
      BackgroundMusicService().stop().catchError((error) {
        debugPrint('Failed to stop map music in initState: $error');
      });
    }).catchError((error) {
      // If fadeOut fails, try stop directly
      BackgroundMusicService().stop().catchError((e) {
        debugPrint('Failed to stop map music in initState: $e');
      });
    });

    _service = PracticePackService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TelemetryService.maybeOf(context)?.startScreenSession('ai_practice_pack');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes and stop music when entering this screen
    RouteObserverService.routeObserver.subscribe(this, ModalRoute.of(context)!);
    // Stop map music when entering AI practice pack screen
    // Use fadeOut first for smooth transition, then stop
    BackgroundMusicService()
        .fadeOut(duration: const Duration(milliseconds: 200))
        .then((_) {
      BackgroundMusicService().stop().catchError((error) {
        debugPrint('Failed to stop map music in didChangeDependencies: $error');
      });
    }).catchError((error) {
      // If fadeOut fails, try stop directly
      BackgroundMusicService().stop().catchError((e) {
        debugPrint('Failed to stop map music in didChangeDependencies: $e');
      });
    });
  }

  @override
  void didPush() {
    // Called when this route is pushed onto the navigator
    // Stop map music when entering AI practice pack screen
    // Use fadeOut first for smooth transition, then stop
    BackgroundMusicService()
        .fadeOut(duration: const Duration(milliseconds: 200))
        .then((_) {
      BackgroundMusicService().stop().catchError((error) {
        debugPrint('Failed to stop map music in didPush: $error');
      });
    }).catchError((error) {
      // If fadeOut fails, try stop directly
      BackgroundMusicService().stop().catchError((e) {
        debugPrint('Failed to stop map music in didPush: $e');
      });
    });
  }

  @override
  void dispose() {
    RouteObserverService.routeObserver.unsubscribe(this);
    TelemetryService.maybeOf(context)?.endScreenSession(
      'ai_practice_pack',
      extra: {
        'generated': _pack != null,
        'activities_count': _pack?.activities.length ?? 0,
      },
    );
    _nameController.dispose();
    _extraWordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חבילת אימון AI של ספרק'),
        backgroundColor: Colors.teal.shade400,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2EC4B6), Color(0xFFCBF3F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildOptionsCard(),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ErrorBanner(
                    message: _errorMessage!,
                    onClose: () => setState(() => _errorMessage = null),
                  ),
                ),
              Expanded(child: _buildPackView()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'בואו נתפור אימון מיוחד',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'שם הלומד/ת (לא חובה)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    _skills,
                    _selectedSkill,
                    (value) => setState(() => _selectedSkill = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    _durations,
                    _selectedTime,
                    (value) => setState(() => _selectedTime = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    _energies,
                    _selectedEnergy,
                    (value) => setState(() => _selectedEnergy = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    _modes,
                    _selectedMode,
                    (value) => setState(() => _selectedMode = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _extraWordsController,
              decoration: const InputDecoration(
                labelText: 'הוסיפו מילים באנגלית (מופרדות בפסיק)',
                hintText: 'כדוגמה: ocean, dance, friend',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            const SizedBox(height: 12),
            _FocusWordsPreview(words: _resolvedFocusWords()),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generatePack,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_pack == null ? 'בנו חבילת אימון' : 'צרו חבילה חדשה'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<_Option> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.id,
              child: Text(option.label, textDirection: TextDirection.rtl),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }

  Widget _buildPackView() {
    if (_isGenerating) {
      return const Center(child: CircularProgressIndicator());
    }
    final pack = _pack;
    if (pack == null) {
      return Center(
        child: Opacity(
          opacity: 0.9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 72,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 12),
              const Text(
                'ספרק מחכה שתבנו את חבילת האימון הראשונה!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: pack.activities.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeaderCard(pack);
        }

        final activity = pack.activities[index - 1];
        final isDone = _isActivityCompleted(index - 1);
        return _ActivityCard(
          activity: activity,
          isCompleted: isDone,
          onComplete: () => _completeActivity(index - 1),
        );
      },
    );
  }

  Widget _buildHeaderCard(PracticePack pack) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pack.pepTalk,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _resolvedFocusWords()
                  .map(
                    (word) => Chip(
                      backgroundColor: Colors.teal.shade50,
                      avatar: const Icon(Icons.translate, size: 18),
                      label: Text(word),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                pack.celebration,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePack() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final request = PracticePackRequest(
      skillFocus: _selectedSkill,
      timeAvailable: _selectedTime,
      energyLevel: _selectedEnergy,
      playMode: _selectedMode,
      learnerName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      focusWords: _resolvedFocusWords(),
    );

    try {
      // Get current user context
      final userSession =
          Provider.of<UserSessionProvider>(context, listen: false);
      final appUser = userSession.currentUser;
      LocalUser? localUser;

      // If local user, fetch full details (for age)
      if (appUser != null && !appUser.isGoogle) {
        localUser = await _localUserService.getUserById(appUser.id);
      }

      final pack = await _service.generatePack(
        request,
        user: appUser,
        localUser: localUser,
      );
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _completed = List<bool>.filled(pack.activities.length, false);
      });
      TelemetryService.maybeOf(context)?.logCustomEvent(
        'ai_practice_pack_generated',
        {
          'skill': _selectedSkill,
          'time': _selectedTime,
          'energy': _selectedEnergy,
        },
      );
    } on PracticePackGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ספרק לא הצליח לבנות חבילה חדשה. נסו שוב.';
      });
      debugPrint('Unexpected practice pack error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _completeActivity(int index) async {
    if (_isActivityCompleted(index)) {
      return;
    }
    setState(() {
      _completed = List<bool>.from(_completed)..[index] = true;
    });

    final coinProvider = context.read<CoinProvider>();
    await coinProvider.addCoins(6);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('✨ מעולה! הרווחתם 6 מטבעות על השלמת פעילות.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    TelemetryService.maybeOf(context)?.logCustomEvent(
      'ai_practice_activity_completed',
      {'skill': _selectedSkill, 'activity_index': index},
    );
  }

  List<String> _resolvedFocusWords() {
    final extraWords = _extraWordsController.text
        .split(',')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    final combined = <String>{
      ...widget.focusWords
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty),
      ...extraWords,
    }.toList(growable: false);

    return combined.take(6).toList(growable: false);
  }

  bool _isActivityCompleted(int index) {
    if (index < 0 || index >= _completed.length) {
      return false;
    }
    return _completed[index];
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.isCompleted,
    required this.onComplete,
  });

  final PracticeActivity activity;
  final bool isCompleted;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.sports_esports,
                  color: isCompleted ? Colors.teal : Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activity.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              activity.goal,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (var i = 0; i < activity.steps.length; i++)
                  _StepTile(index: i + 1, text: activity.steps[i]),
              ],
            ),
            const SizedBox(height: 12),
            if (activity.englishFocus.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activity.englishFocus
                    .map(
                      (word) => Chip(
                        avatar: const Icon(Icons.menu_book, size: 18),
                        label: Text(word),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (activity.boost.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bolt, color: Colors.teal.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activity.boost,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: isCompleted ? null : onComplete,
                child: Text(isCompleted ? 'סיימתם! 🌟' : 'סיימנו את הפעילות'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade200,
        foregroundColor: Colors.deepOrange,
        child: Text(index.toString()),
      ),
      title: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class _FocusWordsPreview extends StatelessWidget {
  const _FocusWordsPreview({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: const Text(
          'מומלץ לבחור 1-6 מילים באנגלית כדי שספרק יתמקד בהן.',
          textDirection: TextDirection.rtl,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'מילות מיקוד:',
            style: TextStyle(fontWeight: FontWeight.w600),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words
                .map(
                  (word) => Chip(
                    label: Text(word),
                    avatar: const Icon(Icons.star, size: 18),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Option {
  const _Option({required this.id, required this.label});

  final String id;
  final String label;
}

const List<_Option> _skills = <_Option>[
  _Option(id: 'speaking', label: 'דיבור חופשי'),
  _Option(id: 'listening', label: 'האזנה והבנה'),
  _Option(id: 'storytelling', label: 'סיפור יצירתי'),
  _Option(id: 'movement', label: 'לימוד בתנועה'),
];

const List<_Option> _durations = <_Option>[
  _Option(id: '5_minutes', label: '5 דקות'),
  _Option(id: '10_minutes', label: '10 דקות'),
  _Option(id: '15_minutes', label: '15 דקות'),
];

const List<_Option> _energies = <_Option>[
  _Option(id: 'calm', label: 'רגוע'),
  _Option(id: 'balanced', label: 'מלא אנרגיה מאוזנת'),
  _Option(id: 'hyper', label: 'טירוף אנרגיה חיובי'),
];

const List<_Option> _modes = <_Option>[
  _Option(id: 'solo', label: 'מתאמן יחיד'),
  _Option(id: 'family', label: 'עם המשפחה'),
  _Option(id: 'friends', label: 'עם חבר/ה'),
];
