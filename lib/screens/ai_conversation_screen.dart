import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/services/conversation_coach_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiConversationScreen extends StatefulWidget {
  const AiConversationScreen({super.key, this.focusWords = const <String>[]});

  final List<String> focusWords;

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends State<AiConversationScreen> {
  late final ConversationCoachService _service;
  late final FlutterTts _tts;
  final SpeechToText _speechToText = SpeechToText();

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatEntry> _entries = <_ChatEntry>[];
  final List<ConversationTurn> _history = <ConversationTurn>[];

  bool _speechReady = false;
  bool _isListening = false;
  bool _isBusy = false;
  bool _sessionStarted = false;

  String? _errorMessage;

  String _selectedTopic = _topics.first.id;
  String _selectedSkill = _skills.first.id;
  String _selectedEnergy = _energies.first.id;

  @override
  void initState() {
    super.initState();
    _service = ConversationCoachService();
    _tts = FlutterTts();
    _initSpeech();
    _configureTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TelemetryService.maybeOf(context)?.startScreenSession('ai_conversation');
    });
  }

  Future<void> _initSpeech() async {
    final ready = await _speechToText.initialize();
    if (mounted) {
      setState(() {
        _speechReady = ready;
      });
    }
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('he-IL');
    await _tts.setSpeechRate(0.9);
  }

  @override
  void dispose() {
    TelemetryService.maybeOf(context)?.endScreenSession(
      'ai_conversation',
      extra: {
        'turns_total': _entries.length,
        'session_started': _sessionStarted,
      },
    );
    _messageController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speechToText.stop();
    _speechToText.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חבר השיחה של ספרק'),
        backgroundColor: Colors.deepPurple.shade400,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5E4AE3), Color(0xFF8E8DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildConfiguratorCard(),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ErrorBanner(
                    message: _errorMessage!,
                    onClose: () {
                      setState(() => _errorMessage = null);
                    },
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildConversationArea(),
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfiguratorCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'בחרו עם מי ספרק מתאמן היום',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'שם הלומד/ת (לא חובה)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    _topics,
                    _selectedTopic,
                    (value) => setState(() => _selectedTopic = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    _skills,
                    _selectedSkill,
                    (value) => setState(() => _selectedSkill = value),
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
                Expanded(child: _buildFocusWordsPreview()),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isBusy ? null : _startConversation,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _sessionStarted ? 'התחילו שיחה חדשה' : 'צאו לשיחה קסומה',
              ),
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
      value: selected,
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

  Widget _buildFocusWordsPreview() {
    final words = _resolveFocusWords();
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple.shade100),
        borderRadius: BorderRadius.circular(14),
        color: Colors.deepPurple.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'מילות מיקוד',
            style: TextStyle(fontWeight: FontWeight.w600),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: words
                .map(
                  (word) => Chip(
                    label: Text(word),
                    avatar: const Icon(Icons.bolt, size: 16),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationArea() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white.withOpacity(0.85),
            ),
            const SizedBox(height: 12),
            const Text(
              'התחילו שיחה עם ספרק כדי לראות את הקסם קורה!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _entries.length,
      padding: const EdgeInsets.only(bottom: 12),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        if (entry.speaker == ConversationSpeaker.spark) {
          return _SparkBubble(
            response: entry.responseMeta,
            message: entry.message,
            onSuggestionTap: (suggestion) {
              setState(() {
                _messageController.text = suggestion;
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: suggestion.length),
                );
              });
            },
          );
        }
        return _LearnerBubble(message: entry.message);
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isBusy,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'מה תרצו להגיד לספרק?',
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendLearnerMessage(),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.hearing_disabled : Icons.hearing,
                ),
                tooltip: _speechReady ? 'אמרו משפט בקול' : 'הפעלת דיבור',
                onPressed: !_speechReady || _isBusy ? null : _toggleListening,
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isBusy ? null : _sendLearnerMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startConversation() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _entries.clear();
      _history.clear();
      _sessionStarted = false;
      _errorMessage = null;
    });

    final setup = ConversationSetup(
      topic: _selectedTopic,
      skillFocus: _selectedSkill,
      energyLevel: _selectedEnergy,
      learnerName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      focusWords: _resolveFocusWords(),
    );

    try {
      final response = await _service.startConversation(setup);
      if (!mounted) return;

      _appendSparkResponse(response);
      _history.add(
        ConversationTurn(
          speaker: ConversationSpeaker.spark,
          message: response.message,
        ),
      );
      _sessionStarted = true;

      await _speakSpark(response.message);
      TelemetryService.maybeOf(context)?.logCustomEvent(
        'ai_conversation_started',
        {'topic': _selectedTopic, 'skill': _selectedSkill},
      );
    } on ConversationGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'משהו השתבש. נסו שוב בעוד רגע.';
      });
      debugPrint('Unexpected conversation start error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _sendLearnerMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isBusy) {
      return;
    }
    if (!_sessionStarted) {
      setState(() {
        _errorMessage = 'פתחו שיחה עם ספרק לפני שאתם עונים.';
      });
      return;
    }

    setState(() {
      _entries.add(
        _ChatEntry(speaker: ConversationSpeaker.learner, message: message),
      );
      _history.add(
        ConversationTurn(
          speaker: ConversationSpeaker.learner,
          message: message,
        ),
      );
      _isBusy = true;
      _errorMessage = null;
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final trimmedHistory = _history.length > 12
          ? _history.sublist(_history.length - 12)
          : List<ConversationTurn>.from(_history);
      final response = await _service.continueConversation(
        setup: ConversationSetup(
          topic: _selectedTopic,
          skillFocus: _selectedSkill,
          energyLevel: _selectedEnergy,
          learnerName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          focusWords: _resolveFocusWords(),
        ),
        history: trimmedHistory,
        learnerMessage: message,
      );
      if (!mounted) return;

      _appendSparkResponse(response);
      _history.add(
        ConversationTurn(
          speaker: ConversationSpeaker.spark,
          message: response.message,
        ),
      );

      await _speakSpark(response.message);
      await _rewardLearner();
      TelemetryService.maybeOf(context)?.logCustomEvent(
        'ai_conversation_turn',
        {'topic': _selectedTopic, 'skill': _selectedSkill},
      );
    } on ConversationGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ספרק נתקע בתשובה. נסו שוב.';
      });
      debugPrint('Unexpected conversation turn error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _appendSparkResponse(SparkCoachResponse response) {
    setState(() {
      _entries.add(
        _ChatEntry(
          speaker: ConversationSpeaker.spark,
          message: response.message,
          responseMeta: response,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _speakSpark(String message) async {
    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (error) {
      debugPrint('TTS error: $error');
    }
  }

  Future<void> _rewardLearner() async {
    final coinProvider = context.read<CoinProvider>();
    await coinProvider.addCoins(3);
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('🌟 כל הכבוד! קיבלתם 3 מטבעות על תרגול באנגלית.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    try {
      await _speechToText.listen(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 10),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _messageController.text = result.recognizedWords;
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
            if (result.finalResult) {
              _isListening = false;
            }
          });
        },
      );
      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }
    } catch (error) {
      debugPrint('Speech recognition error: $error');
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage = 'לא הצלחנו לשמוע אתכם. נסו שוב או הקלידו.';
        });
      }
    }
  }

  List<String> _resolveFocusWords() {
    if (widget.focusWords.isNotEmpty) {
      return widget.focusWords;
    }
    return _topicVocabulary[_selectedTopic] ?? const <String>[];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 64,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ChatEntry {
  _ChatEntry({required this.speaker, required this.message, this.responseMeta});

  final ConversationSpeaker speaker;
  final String message;
  final SparkCoachResponse? responseMeta;
}

class _SparkBubble extends StatelessWidget {
  const _SparkBubble({
    required this.message,
    this.response,
    this.onSuggestionTap,
  });

  final String message;
  final SparkCoachResponse? response;
  final ValueChanged<String>? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(22),
              topLeft: Radius.circular(8),
              bottomRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                if (response?.sparkTip != null &&
                    response!.sparkTip!.isNotEmpty) ...[
                  _InfoChip(
                    icon: Icons.lightbulb_outline,
                    label: 'טיפ של ספרק',
                    text: response!.sparkTip!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (response?.vocabularyHighlights.isNotEmpty == true) ...[
                  Text(
                    'מילים באנגלית מהשיחה:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.deepPurple.shade600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: response!.vocabularyHighlights
                        .map(
                          (word) => Chip(
                            avatar: const Icon(Icons.translate, size: 16),
                            label: Text(word),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                ],
                if (response?.miniChallenge != null &&
                    response!.miniChallenge!.isNotEmpty) ...[
                  _InfoChip(
                    icon: Icons.sports_gymnastics,
                    label: 'אתגר מהיר',
                    text: response!.miniChallenge!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (response?.followUp != null &&
                    response!.followUp!.isNotEmpty) ...[
                  _InfoChip(
                    icon: Icons.question_answer,
                    label: 'שאלת המשך',
                    text: response!.followUp!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (response?.celebration != null &&
                    response!.celebration!.isNotEmpty)
                  Text(
                    response!.celebration!,
                    style: const TextStyle(fontSize: 24),
                    textDirection: TextDirection.rtl,
                  ),
                if (response?.suggestedLearnerReplies.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'רעיונות לתשובה:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.deepPurple.shade600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: response!.suggestedLearnerReplies
                        .map(
                          (suggestion) => ActionChip(
                            avatar: const Icon(
                              Icons.record_voice_over,
                              size: 18,
                            ),
                            label: Text(suggestion),
                            onPressed: onSuggestionTap == null
                                ? null
                                : () => onSuggestionTap!(suggestion),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnerBubble extends StatelessWidget {
  const _LearnerBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.lightBlue.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
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

const List<_Option> _topics = <_Option>[
  _Option(id: 'space_mission', label: 'משימת חלל'),
  _Option(id: 'magic_school', label: 'בית ספר לקוסמים'),
  _Option(id: 'everyday_fun', label: 'יום כיף בבית'),
  _Option(id: 'superhero_rescue', label: 'מבצע גיבורי-על'),
];

const List<_Option> _skills = <_Option>[
  _Option(id: 'confidence', label: 'ביטחון בדיבור'),
  _Option(id: 'pronunciation', label: 'הגייה'),
  _Option(id: 'sentence_builder', label: 'בניית משפטים'),
  _Option(id: 'storytelling', label: 'סיפור יצירתי'),
];

const List<_Option> _energies = <_Option>[
  _Option(id: 'calm_magic', label: 'רגוע ומרגיע'),
  _Option(id: 'playful', label: 'משעשע ושובב'),
  _Option(id: 'epic', label: 'הרפתקה דרמטית'),
];

const Map<String, List<String>> _topicVocabulary = <String, List<String>>{
  'space_mission': ['rocket', 'astronaut', 'planet'],
  'magic_school': ['magic wand', 'spell', 'dragon'],
  'everyday_fun': ['pancake', 'drawing', 'friend'],
  'superhero_rescue': ['hero', 'save', 'power'],
};
