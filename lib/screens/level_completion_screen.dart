import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

/// Screen shown when a level is completed
class LevelCompletionScreen extends StatefulWidget {
  const LevelCompletionScreen({
    super.key,
    required this.levelName,
    required this.completedWords,
    required this.totalWords,
    required this.onContinue,
    // Optional parameters for future data expansion
    this.coinsEarned = 50, // Default mock value
    this.starsEarned = 3, // Default mock value
  });

  final String levelName;
  final int completedWords;
  final int totalWords;
  final VoidCallback onContinue;
  final int coinsEarned;
  final int starsEarned;

  @override
  State<LevelCompletionScreen> createState() => _LevelCompletionScreenState();
}

class _LevelCompletionScreenState extends State<LevelCompletionScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _entranceController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Confetti Controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

    // 2. Entrance Animations
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
    ));

    // 3. Pulse Animation for Button/Trophy
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Background
          const _AnimatedGradientBackground(),

          // 2. Floating Background Particles
          const _FloatingParticles(),

          // 3. Confetti Layer (Behind content)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 30, // Increased
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),

          // 4. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Hero Trophy Area ---
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: _HeroTrophy(pulseController: _pulseController),
                    ),

                    const SizedBox(height: 30),

                    // --- Celebration Text ---
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'כל הכבוד!',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'סיימת את ${widget.levelName}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- Achievement Card ---
                    SlideTransition(
                      position: _slideAnimation,
                      child: _AchievementCard(
                        completedWords: widget.completedWords,
                        totalWords: widget.totalWords,
                        coinsEarned: widget.coinsEarned,
                        starsEarned: widget.starsEarned,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- Action Buttons ---
                    ScaleTransition(
                      scale: _fadeAnimation,
                      child: _ActionButtons(
                        onContinue: widget.onContinue,
                        pulseController: _pulseController,
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// HELPER WIDGETS
// ----------------------------------------------------------------

// 1. Animated Gradient Background
class _AnimatedGradientBackground extends StatefulWidget {
  const _AnimatedGradientBackground();

  @override
  State<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<_AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Colors.purple.shade400, Colors.blue.shade500,
                    _controller.value)!,
                Color.lerp(Colors.blue.shade400, Colors.teal.shade300,
                    _controller.value)!,
                Color.lerp(Colors.green.shade400, Colors.purple.shade300,
                    _controller.value)!,
              ],
            ),
          ),
        );
      },
    );
  }
}

// 2. Hero Trophy with Glow
class _HeroTrophy extends StatelessWidget {
  final AnimationController pulseController;

  const _HeroTrophy({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating Glow (Behind)
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  radius: 0.6 + (pulseController.value * 0.1),
                ),
              ),
            );
          },
        ),
        // Main Icon Container
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.amber.shade300, width: 6),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 100,
                color: Colors.amber,
              ),
              // Sparkles
              Positioned(
                top: 30,
                right: 40,
                child: _PulsingStar(delay: 0),
              ),
              Positioned(
                bottom: 40,
                left: 30,
                child: _PulsingStar(delay: 500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 3. Achievement Stats Card
class _AchievementCard extends StatelessWidget {
  final int completedWords;
  final int totalWords;
  final int coinsEarned;
  final int starsEarned;

  const _AchievementCard({
    required this.completedWords,
    required this.totalWords,
    required this.coinsEarned,
    required this.starsEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stars Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  scale: index < starsEarned ? 1.2 : 1.0,
                  duration: Duration(milliseconds: 400 + (index * 200)),
                  curve: Curves.elasticOut,
                  child: Icon(
                    index < starsEarned
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: index < starsEarned
                        ? Colors.amber
                        : Colors.grey.shade300,
                    size: 40,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatPill(
                icon: Icons.check_circle,
                color: Colors.green,
                value: "$completedWords/$totalWords",
                label: "מילים",
              ),
              Container(
                  width: 1, height: 40, color: Colors.grey.shade300),
              _StatPill(
                icon: Icons.monetization_on,
                color: Colors.yellow.shade700,
                value: "+$coinsEarned",
                label: "מטבעות",
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "התקדמות בשלב",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: completedWords / math.max(totalWords, 1),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 4. Stat Pill Helper
class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            fontFamily: 'Nunito',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// 5. Pulsing Star Helper
class _PulsingStar extends StatefulWidget {
  final int delay;
  const _PulsingStar({required this.delay});

  @override
  State<_PulsingStar> createState() => _PulsingStarState();
}

class _PulsingStarState extends State<_PulsingStar>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..repeat(reverse: true);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Icon(Icons.auto_awesome,
          color: Colors.yellowAccent, size: 24);
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_controller!.value * 0.4),
          child: Opacity(
            opacity: 0.6 + (_controller!.value * 0.4),
            child: const Icon(Icons.auto_awesome,
                color: Colors.yellowAccent, size: 24),
          ),
        );
      },
    );
  }
}

// 6. Action Buttons
class _ActionButtons extends StatelessWidget {
  final VoidCallback onContinue;
  final AnimationController pulseController;

  const _ActionButtons({
    required this.onContinue,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (pulseController.value * 0.05),
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_back, size: 28), // RTL arrow
                label: const Text(
                  'המשך למפה',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            // For now, just continue (replay can be implemented later)
            onContinue();
          },
          icon: const Icon(Icons.replay, color: Colors.white70),
          label: const Text(
            'שחק שוב',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

// 7. Floating Particles Background
class _FloatingParticles extends StatelessWidget {
  const _FloatingParticles();

  @override
  Widget build(BuildContext context) {
    // Simple static positioning for demo, ideally animated
    return Stack(
      children: [
        Positioned(
            top: 50,
            left: 30,
            child: Icon(Icons.star, color: Colors.white.withValues(alpha: 0.24), size: 20)),
        Positioned(
            top: 150,
            right: 50,
            child: Icon(Icons.circle, color: Colors.white.withValues(alpha: 0.12), size: 15)),
        Positioned(
            bottom: 200,
            left: 80,
            child: Icon(Icons.star, color: Colors.white.withValues(alpha: 0.24), size: 25)),
        Positioned(
            bottom: 100,
            right: 40,
            child: Icon(Icons.favorite, color: Colors.white.withValues(alpha: 0.12), size: 20)),
      ],
    );
  }
}
