import 'package:english_learning_app/l10n/spark_strings.dart';
import 'package:english_learning_app/models/scene_teaching_moment.dart';
import 'package:english_learning_app/models/scavenger_hunt_challenge.dart';
import 'package:english_learning_app/services/scene_teaching_moment_service.dart';
import 'package:english_learning_app/services/gemini_proxy_service.dart';
import 'package:english_learning_app/services/spark_voice_service.dart';
import 'package:english_learning_app/utils/english_word_emoji.dart';
import 'package:english_learning_app/widgets/living_spark.dart';
import 'package:english_learning_app/widgets/ui/_barrel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-height sheet: Spark teaches from the same photo the child just captured.
class ScavengerTeachingMomentSheet extends StatefulWidget {
  const ScavengerTeachingMomentSheet({
    super.key,
    required this.geminiProxy,
    required this.imageBytes,
    required this.challenge,
    required this.isLastRound,
    required this.onContinue,
  });

  final GeminiProxyService geminiProxy;
  final Uint8List imageBytes;
  final ScavengerHuntChallenge challenge;
  final bool isLastRound;
  final VoidCallback onContinue;

  @override
  State<ScavengerTeachingMomentSheet> createState() =>
      _ScavengerTeachingMomentSheetState();
}

class _ScavengerTeachingMomentSheetState
    extends State<ScavengerTeachingMomentSheet> {
  late final SceneTeachingMomentService _service;
  final SparkVoiceService _sparkVoice = SparkVoiceService();

  SceneTeachingMoment? _moment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = SceneTeachingMomentService(widget.geminiProxy);
    _loadMoment();
  }

  Future<void> _loadMoment() async {
    final moment = await _service.fetchForSuccessPhoto(
      widget.imageBytes,
      widget.challenge,
    );

    if (!mounted) return;

    setState(() {
      _moment = moment;
      _isLoading = false;
    });

    if (!moment.isFallback && moment.description.isNotEmpty) {
      await _sparkVoice.speak(
        text: moment.description,
        emotion: SparkEmotion.teaching,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B4965), Color(0xFF0D1B2A)],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingBody()
                      : _buildContentBody(scrollController),
                ),
                _buildContinueBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivingSpark(emotion: SparkEmotion.teaching, size: 100),
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: Color(0xFFFFD93D)),
          const SizedBox(height: 16),
          Text(
            SparkStrings.scavengerTeachingLoading,
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildContentBody(ScrollController scrollController) {
    final moment = _moment!;
    final teachingPoints = moment.hebrewTeachingPoints;
    final objects = moment.targetObjects;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LivingSpark(emotion: SparkEmotion.excited, size: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SparkStrings.scavengerTeachingTitle,
                    style: GoogleFonts.rubik(
                      color: const Color(0xFFFFD93D),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (moment.description.isNotEmpty)
                    Text(
                      moment.description,
                      style: GoogleFonts.rubik(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.05, end: 0),
        if (teachingPoints.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            SparkStrings.scavengerTeachingTipsLabel,
            style: GoogleFonts.rubik(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...teachingPoints.map(_buildTeachingPointTile),
        ],
        if (objects.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            SparkStrings.scavengerTeachingObjectsLabel,
            style: GoogleFonts.rubik(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: objects
                .map((word) => _buildObjectChip(word))
                .toList(growable: false),
          ),
        ],
        if (moment.isFallback) ...[
          const SizedBox(height: 16),
          Text(
            SparkStrings.scavengerTeachingSkipHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTeachingPointTile(String point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                point,
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
  }

  Widget _buildObjectChip(String englishWord) {
    final emoji = emojiForEnglishWord(englishWord);
    final display = englishWord.trim().isEmpty
        ? englishWord
        : englishWord[0].toUpperCase() + englishWord.substring(1).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5FA8D3).withValues(alpha: 0.35),
            const Color(0xFF1B4965).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD93D).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            display,
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 320.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildContinueBar() {
    final label = widget.isLastRound
        ? SparkStrings.scavengerTeachingFinish
        : SparkStrings.scavengerTeachingContinue;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: KidButton.primary(
          label: _isLoading ? SparkStrings.scavengerTeachingSkipWhileLoading : label,
          onPressed: widget.onContinue,
          fullWidth: true,
        ),
      ),
    );
  }
}
