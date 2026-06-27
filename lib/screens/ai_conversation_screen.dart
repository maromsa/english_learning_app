import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/local_user.dart';
import 'package:english_learning_app/models/daily_mission.dart';
import 'package:english_learning_app/providers/coin_provider.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/spark_overlay_controller.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/background_music_service.dart';
import 'package:english_learning_app/services/conversation_coach_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/services/local_user_service.dart';
import 'package:english_learning_app/services/telemetry_service.dart';
import 'package:english_learning_app/utils/device_connectivity.dart';
import 'package:english_learning_app/utils/route_observer.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
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

class _AiConversationScreenState extends State<AiConversationScreen>
    with RouteAware {
  late final ConversationCoachService _service;
  late final FlutterTts _tts;
  final SpeechToText _speechToText = SpeechToText();
  final LocalUserService _localUserService = LocalUserService();

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatEntry> _entries = <_ChatEntry>[];
  final List<ConversationTurn> _history = <ConversationTurn>[];

  bool _speechReady = false;
  bool _isListening = false;
  bool _isBusy = false;
  bool _sessionStarted = false;
  double _soundLevel = 0.0;

  String? _errorMessage;
  TelemetryService? _telemetry;

  String _selectedTopic = _topics.first.id;
  String _selectedSkill = _skills.first.id;
  String _selectedEnergy = _energies.first.id;

  @override
  void initState() {
    super.initState();
    // Stop map music immediately when entering AI conversation screen
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

    _service = ConversationCoachService();
    _tts = FlutterTts();
    _initSpeech();
    _configureTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _telemetry = TelemetryService.maybeOf(context);
      _telemetry?.startScreenSession('ai_conversation');
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes and stop music when entering this screen
    RouteObserverService.routeObserver.subscribe(this, ModalRoute.of(context)!);
    // Stop map music when entering AI conversation screen
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
    // Stop map music when entering AI conversation screen
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

  Future<void> _configureTts() async {
    await _tts.setLanguage('he-IL');
    await _tts.setSpeechRate(
        0.5,); // Slower rate for children - clear and understandable
    await _tts.setPitch(1.0); // Natural pitch
  }

  @override
  void dispose() {
    RouteObserverService.routeObserver.unsubscribe(this);
    _telemetry?.endScreenSession(
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
    SparkVoiceService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Redesigned by Gemini 3 Pro
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light clean background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SparkAvatar(size: 32),
            const SizedBox(width: 8),
            Text(
              'ספרק AI',
              style: TextStyle(
                color: Colors.deepPurple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          // 1. Configurator (Collapsible)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.white,
              child: !_sessionStarted
                  ? _buildFullConfigurator()
                  : const SizedBox.shrink(),
            ),
          ),
          // 2. Error Banner
          if (_errorMessage != null)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.red.shade900,
                    onPressed: () {
                      setState(() => _errorMessage = null);
                    },
                  ),
                ],
              ),
            ),
          // 3. Conversation Area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8F9FF), Color(0xFFECECFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: _entries.isEmpty && !_sessionStarted
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20,),
                      itemCount: _entries.length + (_isBusy ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Loading Indicator at the end
                        if (index == _entries.length) {
                          return const _TypingIndicator();
                        }

                        final entry = _entries[index];
                        final bool isSpark =
                            entry.speaker == ConversationSpeaker.spark;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: isSpark
                              ? _SparkMessageBubble(
                                  entry: entry,
                                  onSuggestionSelected: (text) {
                                    setState(() {
                                      _messageController.text = text;
                                      _messageController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(offset: text.length),
                                      );
                                    });
                                  },
                                )
                              : _LearnerMessageBubble(message: entry.message),
                        );
                      },
                    ),
            ),
          ),
          // 4. Input Bar
          if (_sessionStarted) _buildEnhancedInputBar(),
        ],
      ),
    );
  }

  Widget _buildFullConfigurator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'בואו נתכונן לשיחה!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ConfigChip(
                  icon: Icons.topic,
                  label:
                      'נושא: ${_topics.firstWhere((t) => t.id == _selectedTopic).label}',
                  color: Colors.orange.shade100,
                  textColor: Colors.orange.shade900,
                  onTap: () {
                    _showTopicSelector();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConfigChip(
                  icon: Icons.bar_chart,
                  label:
                      'מיומנות: ${_skills.firstWhere((s) => s.id == _selectedSkill).label}',
                  color: Colors.green.shade100,
                  textColor: Colors.green.shade900,
                  onTap: () {
                    _showSkillSelector();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ConfigChip(
                  icon: Icons.energy_savings_leaf,
                  label:
                      'אנרגיה: ${_energies.firstWhere((e) => e.id == _selectedEnergy).label}',
                  color: Colors.purple.shade100,
                  textColor: Colors.purple.shade900,
                  onTap: () {
                    _showEnergySelector();
                  },
                ),
              ),
            ],
          ),
          if (widget.focusWords.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildFocusWordsPreview(),
          ],
          const SizedBox(height: 16),
          KidButton.primary(
            label: _sessionStarted ? 'התחילו שיחה חדשה' : 'צאו לשיחה קסומה',
            onPressed: _isBusy ? null : _startConversation,
            leadingIcon: Icons.chat_bubble_outline,
            isLoading: _isBusy,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  void _showTopicSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('בחר נושא'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _topics.map((topic) {
            return ListTile(
              title: Text(topic.label),
              selected: topic.id == _selectedTopic,
              onTap: () {
                setState(() => _selectedTopic = topic.id);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSkillSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('בחר מיומנות'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _skills.map((skill) {
            return ListTile(
              title: Text(skill.label),
              selected: skill.id == _selectedSkill,
              onTap: () {
                setState(() => _selectedSkill = skill.id);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEnergySelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('בחר רמת אנרגיה'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _energies.map((energy) {
            return ListTile(
              title: Text(energy.label),
              selected: energy.id == _selectedEnergy,
              onTap: () {
                setState(() => _selectedEnergy = energy.id);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SparkAvatar(size: 100),
          const SizedBox(height: 24),
          Text(
            'שלום! אני ספרק',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'בחר נושא והתחל לתרגל אנגלית בכיף',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          SparkOrb(
            state: _isListening
                ? OrbState.listening
                : _isBusy
                    ? OrbState.thinking
                    : OrbState.idle,
            soundLevel: _soundLevel,
            onTap: !_speechReady || _isBusy ? null : _toggleListening,
            size: 88,
          ),
          const SizedBox(width: 12),
          // Text Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'כתוב הודעה לספרק...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendLearnerMessage(),
                enabled: !_isBusy,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send Button
          IconButton.filled(
            onPressed: (_isBusy) ? null : _sendLearnerMessage,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2), // Primary Blue
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startConversation() async {
    if (_isBusy) return;

    // Clear previous conversation data
    _entries.clear();
    _history.clear();

    // Reset scroll position
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    setState(() {
      _isBusy = true;
      _sessionStarted = false;
      _errorMessage = null;
    });

    final sparkController = Provider.of<SparkOverlayController>(context, listen: false);
    sparkController.markThinking();

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
      // Get current user context
      final userSession =
          Provider.of<UserSessionProvider>(context, listen: false);
      final appUser = userSession.currentUser;
      LocalUser? localUser;

      // If local user, fetch full details (for age)
      if (appUser != null && !appUser.isGoogle) {
        localUser = await _localUserService.getUserById(appUser.id);
      }

      final response = await _service.startConversation(
        setup,
        user: appUser,
        localUser: localUser,
      );
      if (!mounted) return;

      _appendSparkResponse(response);
      _history.add(
        ConversationTurn(
          speaker: ConversationSpeaker.spark,
          message: response.message,
        ),
      );
      _sessionStarted = true;

      sparkController.markIdle();
      // Hide loading state before speaking
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }

      await _speakSpark(response.message);
      if (mounted) {
        unawaited(TelemetryService.maybeOf(context)?.logCustomEvent(
          'ai_conversation_started',
          {'topic': _selectedTopic, 'skill': _selectedSkill},
        ));
      }
    } on ConversationGenerationException catch (error) {
      sparkController.markIdle();
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isBusy = false;
      });
    } catch (error) {
      sparkController.markIdle();
      if (!mounted) return;
      setState(() {
        _errorMessage = SparkStrings.aiChatRetry;
        _isBusy = false;
      });
      debugPrint('Unexpected conversation start error: $error');
    }
  }

  Future<void> _sendLearnerMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isBusy) {
      return;
    }
    if (!_sessionStarted) {
      setState(() {
        _errorMessage = SparkStrings.aiChatStartFirst;
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

    final sparkController = Provider.of<SparkOverlayController>(context, listen: false);
    sparkController.markThinking();

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
        user: appUser,
        localUser: localUser,
      );
      if (!mounted) return;

      _appendSparkResponse(response);
      _history.add(
        ConversationTurn(
          speaker: ConversationSpeaker.spark,
          message: response.message,
        ),
      );

      sparkController.markIdle();
      // Update state to hide typing indicator before speaking
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }

      await _speakSpark(response.message);
      await _rewardLearner();
      if (mounted) {
        unawaited(TelemetryService.maybeOf(context)?.logCustomEvent(
          'ai_conversation_turn',
          {'topic': _selectedTopic, 'skill': _selectedSkill},
        ));
      }
    } on ConversationGenerationException catch (error) {
      sparkController.markIdle();
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isBusy = false;
      });
    } catch (error) {
      sparkController.markIdle();
      if (!mounted) return;
      setState(() {
        _errorMessage = SparkStrings.aiChatStuck;
        _isBusy = false;
      });
      debugPrint('Unexpected conversation turn error: $error');
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
    if (message.isEmpty) return;

    try {
      await _tts.stop();
      await SparkVoiceService().stop();

      if (AppConfig.hasGoogleTts) {
        final online = await DeviceConnectivity.current.isOnline();
        final spoke = await SparkVoiceService().speak(
          text: message,
          isEnglish: false,
          emotion: SparkEmotion.happy,
          networkAllowed: online,
        );
        if (spoke) {
          return;
        }
      }

      // Fallback to built-in TTS - slower and clearer for children
      await _tts.setLanguage('he-IL');
      await _tts.setSpeechRate(0.5); // Much slower for clarity
      await _tts.setPitch(1.0); // Natural pitch
      await _tts.speak(message);
    } catch (error) {
      debugPrint('TTS error: $error');
      // Final fallback
      try {
        await _tts.setLanguage('he-IL');
        await _tts.speak(message);
      } catch (e) {
        debugPrint('Final TTS fallback error: $e');
      }
    }
  }

  Future<void> _rewardLearner() async {
    final coinProvider = context.read<CoinProvider>();
    await coinProvider.addCoins(3);
    if (!mounted) {
      return;
    }
    try {
      context
          .read<DailyMissionProvider>()
          .incrementByType(DailyMissionType.speakPractice);
    } catch (_) {}
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🌟 כל הכבוד! קיבלתם 3 מטבעות על תרגול באנגלית.'),
        duration: Duration(seconds: 2),
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
          _soundLevel = 0.0;
        });
      }
      return;
    }

    try {
      await _speechToText.listen(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 10),
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _messageController.text = result.recognizedWords;
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
            if (result.finalResult) {
              _isListening = false;
              _soundLevel = 0.0;
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
          _soundLevel = 0.0;
          _errorMessage = SparkStrings.aiChatCantHear;
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

// --- Helper Widgets - Redesigned by Gemini 3 Pro ---

// 1. Spark Avatar
class _SparkAvatar extends StatelessWidget {
  final double size;

  const _SparkAvatar({this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7B68EE), Color(0xFF5E4AE3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B68EE).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

// 2. Config Chip
class _ConfigChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ConfigChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Learner Bubble (Right Aligned)
class _LearnerMessageBubble extends StatelessWidget {
  final String message;

  const _LearnerMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight, // User on right
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin:
                  const EdgeInsets.only(left: 40), // Prevent stretching too far
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF4A90E2), // Blue
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(4), // Tail
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

// 4. Spark Bubble (Left Aligned) with Response Cards
class _SparkMessageBubble extends StatelessWidget {
  final _ChatEntry entry;
  final Function(String) onSuggestionSelected;

  const _SparkMessageBubble({
    required this.entry,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final response = entry.responseMeta;

    return Align(
      alignment: Alignment.centerLeft, // Spark on left
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SparkAvatar(size: 36),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Message
                Container(
                  margin: const EdgeInsets.only(right: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4), // Tail
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (response?.celebration != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            response!.celebration!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      Text(
                        entry.message,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87,),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                // Structured Response Cards
                if (response != null) ...[
                  // 1. Tip Card
                  if (response.sparkTip != null)
                    _ResponseCard(
                      color: Colors.amber.shade50,
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber.shade800,
                      title: 'טיפ מספרק',
                      content: response.sparkTip!,
                    ),
                  // 2. Vocabulary Card
                  if (response.vocabularyHighlights.isNotEmpty)
                    _VocabularyCard(words: response.vocabularyHighlights),
                  // 3. Challenge Card
                  if (response.miniChallenge != null)
                    _ResponseCard(
                      color: Colors.green.shade50,
                      icon: Icons.flag_outlined,
                      iconColor: Colors.green.shade700,
                      title: 'אתגר קטן',
                      content: response.miniChallenge!,
                    ),
                  // 4. Follow-up Card
                  if (response.followUp != null)
                    _ResponseCard(
                      color: Colors.purple.shade50,
                      icon: Icons.question_answer,
                      iconColor: Colors.purple.shade700,
                      title: 'שאלת המשך',
                      content: response.followUp!,
                    ),
                  // 5. Suggestions (Quick Replies)
                  if (response.suggestedLearnerReplies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: response.suggestedLearnerReplies.map((reply) {
                          return ActionChip(
                            label: Text(reply),
                            onPressed: () => onSuggestionSelected(reply),
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.deepPurple.shade50,
                            side: BorderSide(color: Colors.deepPurple.shade100),
                            labelStyle:
                                TextStyle(color: Colors.deepPurple.shade700),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 5. Reusable Response Card
class _ResponseCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _ResponseCard({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 12,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
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

// 6. Vocabulary Card
class _VocabularyCard extends StatelessWidget {
  final List<String> words;

  const _VocabularyCard({required this.words});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book_outlined, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 6),
              Text(
                'מילים חדשות',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: words.map((w) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  w,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// 7. Typing Indicator
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const _SparkAvatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return FadeTransition(
                  opacity: Tween(begin: 0.4, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Interval(
                        index * 0.2,
                        0.6 + index * 0.2,
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
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
