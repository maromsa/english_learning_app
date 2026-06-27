import 'dart:async';

import 'package:english_learning_app/app_config.dart';
import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/local_user.dart';
import 'package:english_learning_app/models/daily_mission.dart';
import 'package:english_learning_app/providers/daily_mission_provider.dart';
import 'package:english_learning_app/providers/user_session_provider.dart';
import 'package:english_learning_app/services/background_music_service.dart';
import 'package:english_learning_app/services/chat_buddy_service.dart';
import 'package:english_learning_app/services/local_user_service.dart';
import 'package:english_learning_app/services/speech_feedback_service.dart';
import 'package:english_learning_app/utils/aurora_tokens.dart';
import 'package:english_learning_app/utils/route_observer.dart';
import 'package:english_learning_app/widgets/bouncy_button.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Spark Chat Buddy — live voice conversation with vocabulary scaffolding.
class ChatBuddyScreen extends StatefulWidget {
  const ChatBuddyScreen({super.key, this.focusWords = const <String>[]});

  final List<String> focusWords;

  @override
  State<ChatBuddyScreen> createState() => _ChatBuddyScreenState();
}

class _ChatBuddyScreenState extends State<ChatBuddyScreen> with RouteAware {
  late final ChatBuddyService _service;
  final LocalUserService _localUserService = LocalUserService();
  final ScrollController _scrollController = ScrollController();

  final List<_BubbleEntry> _entries = <_BubbleEntry>[];
  List<String> _scaffoldingWords = const [];

  bool _sessionStarted = false;
  bool _isThinking = false;
  bool _isListening = false;
  double _soundLevel = 0;
  String _liveTranscript = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = ChatBuddyService();
    BackgroundMusicService()
        .fadeOut(duration: const Duration(milliseconds: 300))
        .then((_) => BackgroundMusicService().stop())
        .catchError((_) => BackgroundMusicService().stop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    RouteObserverService.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    RouteObserverService.routeObserver.unsubscribe(this);
    unawaited(_service.cancelListening());
    _scrollController.dispose();
    super.dispose();
  }

  ChatBuddyContext _buildContext(LocalUser? localUser, AppSessionUser? user) {
    return ChatBuddyContext(
      focusWords: widget.focusWords,
      topic: 'everyday_fun',
      learnerName: user?.name ?? localUser?.name,
      age: localUser?.age,
    );
  }

  List<ChatBuddyMessage> _historyFromEntries() {
    return _entries
        .where((e) => !e.isLive && e.text.trim().isNotEmpty)
        .map(
          (e) => ChatBuddyMessage(
            speaker:
                e.isSpark ? ChatBuddySpeaker.spark : ChatBuddySpeaker.learner,
            text: e.text,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _startSession() async {
    if (_isThinking || !AppConfig.hasGeminiProxy) return;

    setState(() {
      _isThinking = true;
      _errorMessage = null;
      _entries.clear();
      _scaffoldingWords = const [];
    });

    try {
      final userSession = context.read<UserSessionProvider>();
      final appUser = userSession.currentUser;
      LocalUser? localUser;
      if (appUser != null && !appUser.isGoogle) {
        localUser = await _localUserService.getUserById(appUser.id);
      }
      final turn = await _service.startSession(
        _buildContext(localUser, appUser),
        user: appUser,
        localUser: localUser,
      );

      if (!mounted) return;
      setState(() {
        _sessionStarted = true;
        _isThinking = false;
        _entries.add(_BubbleEntry.spark(turn.message, tip: turn.sparkTip));
        _scaffoldingWords = turn.scaffoldingWords;
      });
      _scrollToEnd();
    } on ChatBuddyUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _errorMessage = e.message;
      });
    } on ChatBuddyGenerationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _errorMessage = e.message;
      });
    } catch (error) {
      debugPrint('ChatBuddy start error: $error');
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _errorMessage = 'לא הצלחנו להתחיל שיחה. נסו שוב.';
      });
    }
  }

  Future<void> _sendLearnerMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isThinking) return;

    setState(() {
      _entries.removeWhere((e) => e.isLive);
      _entries.add(_BubbleEntry.learner(trimmed));
      _liveTranscript = '';
      _isThinking = true;
      _errorMessage = null;
    });
    _scrollToEnd();

    try {
      final userSession = context.read<UserSessionProvider>();
      final appUser = userSession.currentUser;
      LocalUser? localUser;
      if (appUser != null && !appUser.isGoogle) {
        localUser = await _localUserService.getUserById(appUser.id);
      }
      final turn = await _service.continueChat(
        context: _buildContext(localUser, appUser),
        history: _historyFromEntries(),
        learnerMessage: trimmed,
        user: appUser,
        localUser: localUser,
      );

      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _entries.add(_BubbleEntry.spark(turn.message, tip: turn.sparkTip));
        _scaffoldingWords = turn.scaffoldingWords;
      });
      _scrollToEnd();
      try {
        context
            .read<DailyMissionProvider>()
            .incrementByType(DailyMissionType.speakPractice);
      } catch (_) {}
    } on ChatBuddyGenerationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _errorMessage = e.message;
      });
    } catch (error) {
      debugPrint('ChatBuddy continue error: $error');
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _errorMessage = 'ספרק לא הצליח לענות. נסו שוב.';
      });
    }
  }

  Future<void> _onMicPressed() async {
    if (_isThinking) return;

    if (_isListening) {
      await _finishListening();
      return;
    }

    if (!_sessionStarted) {
      await _startSession();
      if (!mounted || !_sessionStarted) return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _entries.removeWhere((e) => e.isLive);
      _entries.add(_BubbleEntry.learnerLive(''));
    });

    try {
      await _service.startListening(
        onTranscript: (text) {
          if (!mounted) return;
          setState(() {
            _liveTranscript = text;
            _updateLiveBubble(text);
          });
        },
        onFinalTranscript: (_) {
          if (!mounted || !_isListening) return;
          unawaited(_finishListening());
        },
        onSoundLevel: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
      );
    } on ChatBuddyMicrophoneException catch (error) {
      if (!mounted) return;
      _stopListeningUi(_micPermissionMessage(error.status));
      _maybeShowPermissionSnack(error.status);
    } on ChatBuddySpeechUnavailableException {
      if (!mounted) return;
      _stopListeningUi(SparkStrings.micStartFailed);
    } catch (error) {
      debugPrint('ChatBuddy listen error: $error');
      if (!mounted) return;
      _stopListeningUi(SparkStrings.micStartFailed);
    }
  }

  void _updateLiveBubble(String text) {
    final index = _entries.lastIndexWhere((e) => e.isLive);
    if (index == -1) return;
    _entries[index] = _BubbleEntry.learnerLive(
      text.isEmpty ? SparkStrings.micListening : text,
    );
  }

  Future<void> _finishListening() async {
    if (!_isListening) return;

    setState(() {
      _isListening = false;
      _soundLevel = 0;
    });

    try {
      await _service.stopListening();
    } catch (error) {
      debugPrint('ChatBuddy stop error: $error');
    }

    final heard = _liveTranscript.trim();
    if (heard.isEmpty) {
      if (!mounted) return;
      setState(() {
        _entries.removeWhere((e) => e.isLive);
        _errorMessage = SparkStrings.micHeardNothing;
      });
      return;
    }

    await _sendLearnerMessage(heard);
  }

  void _stopListeningUi(String hint) {
    setState(() {
      _isListening = false;
      _soundLevel = 0;
      _entries.removeWhere((e) => e.isLive);
      _errorMessage = hint;
    });
  }

  String _micPermissionMessage(MicrophoneAccessStatus status) {
    switch (status) {
      case MicrophoneAccessStatus.permanentlyDenied:
      case MicrophoneAccessStatus.restricted:
        return SparkStrings.micPermissionSettings;
      case MicrophoneAccessStatus.denied:
      case MicrophoneAccessStatus.unavailable:
      case MicrophoneAccessStatus.granted:
        return SparkStrings.micPermissionAsk;
    }
  }

  void _maybeShowPermissionSnack(MicrophoneAccessStatus status) {
    if (status != MicrophoneAccessStatus.permanentlyDenied &&
        status != MicrophoneAccessStatus.restricted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text(SparkStrings.micPermissionSettings),
        action: SnackBarAction(
          label: SparkStrings.micOpenSettings,
          onPressed: () => _service.openSystemSettings(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  OrbState get _orbState {
    if (_isListening) return OrbState.listening;
    if (_isThinking) return OrbState.thinking;
    return OrbState.idle;
  }

  String get _micLabel {
    if (_isListening) return SparkStrings.micListening;
    if (_isThinking) return SparkStrings.micChecking;
    if (!_sessionStarted) return 'התחילו שיחה';
    return SparkStrings.micSpeakBtn;
  }

  @override
  Widget build(BuildContext context) {
    final geminiReady = AppConfig.hasGeminiProxy;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'חבר שיחה של ספרק',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AuroraTokens.plum, AuroraTokens.blueberry],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F0FF), Color(0xFFE8F4FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!geminiReady)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'הגדירו GEMINI_PROXY_URL כדי לשוחח עם ספרק.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _entries.isEmpty && !_isThinking
                    ? _EmptyChatState(
                        onStart: geminiReady ? _startSession : null)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _entries.length + (_isThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _entries.length) {
                            return const _ThinkingBubble();
                          }
                          final entry = _entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: entry.isSpark
                                ? _SparkBubble(
                                    message: entry.text,
                                    tip: entry.tip,
                                  )
                                : _LearnerBubble(
                                    message: entry.text,
                                    isLive: entry.isLive,
                                  ),
                          );
                        },
                      ),
              ),
              if (_scaffoldingWords.isNotEmpty && _sessionStarted)
                _ScaffoldingBar(words: _scaffoldingWords),
              _MicPanel(
                orbState: _orbState,
                soundLevel: _soundLevel,
                label: _micLabel,
                enabled: geminiReady && !_isThinking,
                isListening: _isListening,
                onPressed: () => unawaited(_onMicPressed()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleEntry {
  _BubbleEntry({
    required this.isSpark,
    required this.text,
    this.tip,
    this.isLive = false,
  });

  factory _BubbleEntry.spark(String text, {String? tip}) =>
      _BubbleEntry(isSpark: true, text: text, tip: tip);

  factory _BubbleEntry.learner(String text) =>
      _BubbleEntry(isSpark: false, text: text);

  factory _BubbleEntry.learnerLive(String text) =>
      _BubbleEntry(isSpark: false, text: text, isLive: true);

  final bool isSpark;
  final String text;
  final String? tip;
  final bool isLive;
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SparkOrb(state: OrbState.idle, size: 100),
            const SizedBox(height: 20),
            const Text(
              'דברו עם ספרק באנגלית!\nלחצו על הכדור כדי להתחיל.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AuroraTokens.ink,
                height: 1.4,
              ),
            ),
            if (onStart != null) ...[
              const SizedBox(height: 20),
              KidButton.primary(
                label: 'התחילו שיחה',
                onPressed: onStart,
                leadingIcon: Icons.chat_bubble_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SparkBubble extends StatelessWidget {
  const _SparkBubble({required this.message, this.tip});

  final String message;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AuroraTokens.plum, AuroraTokens.coral],
              ),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      color: AuroraTokens.ink,
                    ),
                  ),
                ),
                if (tip != null && tip!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    tip!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AuroraTokens.plum.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideX(begin: -0.05, end: 0);
  }
}

class _LearnerBubble extends StatelessWidget {
  const _LearnerBubble({required this.message, this.isLive = false});

  final String message;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLive
                ? [AuroraTokens.sky, AuroraTokens.coral.withValues(alpha: 0.85)]
                : [AuroraTokens.blueberry, AuroraTokens.plum],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border:
              isLive ? Border.all(color: AuroraTokens.coral, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: AuroraTokens.plum.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fade(duration: 600.ms)
                  .then()
                  .fade(begin: 1, end: 0.35, duration: 600.ms),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: SparkOrb(state: OrbState.thinking, size: 36),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            AuroraTokens.plum.withValues(alpha: 0.5 + i * 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .fade(
                        delay: (i * 150).ms,
                        duration: 500.ms,
                      )
                      .then()
                      .fade(begin: 1, end: 0.3, duration: 500.ms);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaffoldingBar extends StatelessWidget {
  const _ScaffoldingBar({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraTokens.butter.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AuroraTokens.butter.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AuroraTokens.butter, size: 20),
              SizedBox(width: 6),
              Text(
                'מילים לנסות בהמשך',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AuroraTokens.ink,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: words.map((word) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AuroraTokens.butter.withValues(alpha: 0.35),
                      AuroraTokens.coral.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AuroraTokens.coral.withValues(alpha: 0.5)),
                ),
                child: Text(
                  word,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AuroraTokens.ink,
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.1, end: 0);
  }
}

class _MicPanel extends StatelessWidget {
  const _MicPanel({
    required this.orbState,
    required this.soundLevel,
    required this.label,
    required this.enabled,
    required this.isListening,
    required this.onPressed,
  });

  final OrbState orbState;
  final double soundLevel;
  final String label;
  final bool enabled;
  final bool isListening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabled)
            BouncyButton(
              onPressed: onPressed,
              child: Column(
                children: [
                  SparkOrb(
                    state: orbState,
                    soundLevel: soundLevel,
                    size: 120,
                    onTap: isListening ? onPressed : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AuroraTokens.ink,
                    ),
                  ),
                ],
              ),
            )
          else
            const SparkOrb(
              state: OrbState.idle,
              size: 120,
            ),
        ],
      ),
    );
  }
}
