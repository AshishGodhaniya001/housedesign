import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final Animation<double> _logoScale = Tween<double>(begin: 0.8, end: 1)
      .animate(
        CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
      );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _introController,
    curve: const Interval(0.1, 0.95, curve: Curves.easeInOutCubic),
  );

  late final Animation<Offset> _titleSlide =
      Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
        CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
      );

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _navTimer = Timer(const Duration(milliseconds: 3200), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/planner');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark
        ? const Color(0xFFF2E6CF)
        : const Color(0xFF112034);
    final secondaryText = isDark
        ? const Color(0xFFDCC89C)
        : const Color(0xFF506684);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = _pulseController.value;
          final floatY = math.sin(t * 2 * math.pi) * 10;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF060E18),
                        Color(0xFF112033),
                        Color(0xFF1A2C45),
                      ]
                    : const [
                        Color(0xFFF8F3E8),
                        Color(0xFFEBD9B8),
                        Color(0xFFF4EBDD),
                      ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: -120 + (t * 50),
                    left: -80,
                    child: _GlowOrb(
                      size: 290,
                      color: isDark
                          ? const Color(0xFF2A4467).withValues(alpha: 0.34)
                          : const Color(0xFFE3C47B).withValues(alpha: 0.26),
                    ),
                  ),
                  Positioned(
                    bottom: -140 + (t * 60),
                    right: -100,
                    child: _GlowOrb(
                      size: 320,
                      color: isDark
                          ? const Color(0xFFD8B66B).withValues(alpha: 0.16)
                          : const Color(0xFF445E86).withValues(alpha: 0.12),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FadeTransition(
                            opacity: _logoFade,
                            child: Transform.translate(
                              offset: Offset(0, floatY),
                              child: ScaleTransition(
                                scale: _logoScale,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 176,
                                      height: 176,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(
                                                  0xFFD8B66B,
                                                ).withValues(alpha: 0.45)
                                              : const Color(
                                                  0xFF173050,
                                                ).withValues(alpha: 0.3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 146,
                                      height: 146,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(34),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 26,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/branding/royalnest_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          SlideTransition(
                            position: _titleSlide,
                            child: FadeTransition(
                              opacity: _logoFade,
                              child: Column(
                                children: [
                                  Text(
                                    'RoyalNest Planner',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Craft luxury floor plans with precision',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark
                                    ? const Color(0xFFD8B66B)
                                    : const Color(0xFF1A2E48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.14), Colors.transparent],
        ),
      ),
    );
  }
}
