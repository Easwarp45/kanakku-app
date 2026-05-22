import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/local_cache_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Splash Screen Entry Point
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late AnimationController _bgFadeCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _chartCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _exitCtrl;

  // ── Animations ─────────────────────────────────────────────────────────────
  late Animation<double> _bgOpacity;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _glowOpacity;
  late Animation<double> _pulse1;
  late Animation<double> _pulse2;
  late Animation<double> _chartProgress;
  late Animation<double> _particleOpacity;
  late Animation<double> _exitFade;

  // Particle data (generated once)
  final List<_Particle> _particles = [];
  bool _navigationTriggered = false;

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _initAnimations();
    _runSequence();
  }

  void _generateParticles() {
    final rng = math.Random(42);
    const symbols = ['₹', '\$', '•', '◆', '▲'];
    for (int i = 0; i < 14; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 8 + 5,
        speed: rng.nextDouble() * 0.4 + 0.1,
        symbol: symbols[rng.nextInt(symbols.length)],
        opacity: rng.nextDouble() * 0.35 + 0.1,
        phase: rng.nextDouble() * math.pi * 2,
      ));
    }
  }

  void _initAnimations() {
    // 1. Background fade (0–300ms)
    _bgFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bgOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bgFadeCtrl, curve: Curves.easeOut),
    );

    // 2. Logo reveal (300–900ms)
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.7, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );
    _glowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    // 3. Neon pulse wave (looping, starts with logo)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulse1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulse2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // 4. Chart line draw (600–1400ms)
    _chartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _chartCtrl, curve: Curves.easeInOut),
    );

    // 5. Particles fade in (500–1000ms)
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _particleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _particleCtrl, curve: Curves.easeOut),
    );

    // 6. Exit fade-out (triggered after 2.2s total)
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
  }

  Future<void> _runSequence() async {
    // Phase 1 — background fade
    await _bgFadeCtrl.forward();

    // Phase 2 — logo + pulse start together
    _logoCtrl.forward();
    _pulseCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));

    // Phase 3 — chart draws
    _chartCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));

    // Phase 4 — particles float in
    _particleCtrl.forward();

    // Hold on brand for ~1s then check auth and exit
    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;
    await _exitCtrl.forward();

    if (!mounted || _navigationTriggered) return;
    _navigationTriggered = true;
    _navigate();
  }

  void _navigate() {
    try {
      final auth = Supabase.instance.client.auth;
      final isLoggedIn = LocalCacheService.getCachedData('is_logged_in') == true;
      final user = auth.currentUser;
      debugPrint('[SPLASH AUTH] isLoggedInCached: $isLoggedIn, currentUser: ${user?.email}, currentSession: ${auth.currentSession != null}');
      if (user != null && !isLoggedIn) {
        LocalCacheService.cacheData('is_logged_in', true);
      }
      if (mounted) {
        context.go((isLoggedIn || user != null) ? '/dashboard' : '/login');
      }
    } catch (e) {
      debugPrint('[SPLASH ERROR] Supabase auth check failed (falling back to login): $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _bgFadeCtrl.dispose();
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _chartCtrl.dispose();
    _particleCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bgFadeCtrl, _logoCtrl, _pulseCtrl, _chartCtrl,
        _particleCtrl, _exitCtrl,
      ]),
      builder: (context, _) {
        return FadeTransition(
          opacity: _exitFade,
          child: Opacity(
            opacity: _bgOpacity.value,
            child: Scaffold(
              backgroundColor: const Color(0xFF0A0A0F),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Layer 1: Radial ambient gradient ──────────────────────
                  _buildAmbientGlow(size),

                  // ── Layer 2: Neon pulse rings ──────────────────────────────
                  _buildPulseRings(size),

                  // ── Layer 3: Animated chart line ──────────────────────────
                  _buildChartLine(size),

                  // ── Layer 4: Floating particles ───────────────────────────
                  _buildParticles(size),

                  // ── Layer 5: Logo + wordmark ──────────────────────────────
                  _buildLogoCenter(size),

                  // ── Layer 6: Bottom tagline ───────────────────────────────
                  _buildTagline(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Ambient Glow ────────────────────────────────────────────────────────────
  Widget _buildAmbientGlow(Size size) {
    return Opacity(
      opacity: _glowOpacity.value * 0.6,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 0.75,
            colors: [
              Color(0x2200D9FF), // cyan glow
              Color(0x15A855F7), // purple mid
              Color(0x000A0A0F), // transparent edge
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }

  // ── Pulse Rings ─────────────────────────────────────────────────────────────
  Widget _buildPulseRings(Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    return Opacity(
      opacity: _logoOpacity.value,
      child: CustomPaint(
        size: size,
        painter: _PulseRingPainter(
          center: center,
          pulse1: _pulse1.value,
          pulse2: _pulse2.value,
        ),
      ),
    );
  }

  // ── Animated Chart Line ─────────────────────────────────────────────────────
  Widget _buildChartLine(Size size) {
    return Opacity(
      opacity: _chartProgress.value * 0.5,
      child: CustomPaint(
        size: size,
        painter: _ChartLinePainter(
          progress: _chartProgress.value,
          screenSize: size,
        ),
      ),
    );
  }

  // ── Floating Particles ──────────────────────────────────────────────────────
  Widget _buildParticles(Size size) {
    return Opacity(
      opacity: _particleOpacity.value,
      child: CustomPaint(
        size: size,
        painter: _ParticlePainter(
          particles: _particles,
          animValue: _pulseCtrl.value,
        ),
      ),
    );
  }

  // ── Logo + Wordmark ─────────────────────────────────────────────────────────
  Widget _buildLogoCenter(Size size) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glow container around logo
          Transform.scale(
            scale: _logoScale.value,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft glow backdrop
                  Opacity(
                    opacity: _glowOpacity.value * 0.7,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D9FF).withValues(alpha: 0.18),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                          BoxShadow(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                            blurRadius: 80,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Logo image
                  Image.asset(
                    'assets/icons/kanakku_logo.png',
                    width: 110,
                    height: 110,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Wordmark
          Opacity(
            opacity: _logoOpacity.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _logoOpacity.value) * 12),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00D9FF), Color(0xFF10B981), Color(0xFFCCFF00)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: const Text(
                      'KANAKKU',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Opacity(
                    opacity: _glowOpacity.value,
                    child: const Text(
                      'PERSONAL FINANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tagline ──────────────────────────────────────────────────────────────────
  Widget _buildTagline() {
    return Positioned(
      bottom: 52,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _glowOpacity.value,
        child: Column(
          children: [
            // Animated loading dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final dotPhase = (_pulseCtrl.value + i * 0.33) % 1.0;
                final dotOpacity = (math.sin(dotPhase * math.pi)).clamp(0.2, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00D9FF).withValues(alpha: dotOpacity),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            const Text(
              'Securing your finances...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter: Neon Pulse Rings
// ─────────────────────────────────────────────────────────────────────────────
class _PulseRingPainter extends CustomPainter {
  final Offset center;
  final double pulse1;
  final double pulse2;

  const _PulseRingPainter({
    required this.center,
    required this.pulse1,
    required this.pulse2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawRing(canvas, pulse1, 140, const Color(0xFF00D9FF));
    _drawRing(canvas, pulse2, 160, const Color(0xFFA855F7));
  }

  void _drawRing(Canvas canvas, double t, double maxRadius, Color color) {
    if (t <= 0) return;
    final radius = maxRadius * t;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.45;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.pulse1 != pulse1 || old.pulse2 != pulse2;
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter: Animated Chart Line
// ─────────────────────────────────────────────────────────────────────────────
class _ChartLinePainter extends CustomPainter {
  final double progress;
  final Size screenSize;

  const _ChartLinePainter({
    required this.progress,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Chart path positioned in lower-center area
    final w = size.width;
    final h = size.height;
    final cy = h * 0.62; // vertical anchor
    final chartW = w * 0.7;
    final startX = (w - chartW) / 2;

    // Define a gentle upward trending line with small bumps
    final points = [
      Offset(startX, cy + 22),
      Offset(startX + chartW * 0.12, cy + 18),
      Offset(startX + chartW * 0.22, cy + 28),
      Offset(startX + chartW * 0.35, cy + 10),
      Offset(startX + chartW * 0.48, cy + 15),
      Offset(startX + chartW * 0.60, cy - 2),
      Offset(startX + chartW * 0.72, cy + 5),
      Offset(startX + chartW * 0.84, cy - 14),
      Offset(startX + chartW, cy - 22),
    ];

    // Build a smooth path using quadratic bezier segments
    final fullPath = Path();
    fullPath.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      fullPath.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    fullPath.lineTo(points.last.dx, points.last.dy);

    // Clip to only draw `progress` portion of the path
    final pathMetrics = fullPath.computeMetrics();
    final animPath = Path();
    for (final metric in pathMetrics) {
      animPath.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }

    // Glowing stroke
    final glowPaint = Paint()
      ..color = const Color(0xFF00D9FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(animPath, glowPaint);

    // Sharp stroke on top
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00D9FF), Color(0xFF10B981), Color(0xFFCCFF00)],
      ).createShader(Rect.fromLTWH(startX, cy - 30, chartW, 60))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(animPath, linePaint);

    // Draw dot at the current tip
    if (progress > 0.05) {
      final metric2 = fullPath.computeMetrics().first;
      final tip = metric2.getTangentForOffset(metric2.length * progress);
      if (tip != null) {
        final dotPaint = Paint()
          ..color = const Color(0xFF00D9FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(tip.position, 5, dotPaint);
        canvas.drawCircle(
          tip.position, 3,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartLinePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Particle data model
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final String symbol;
  final double opacity;
  final double phase;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.symbol,
    required this.opacity,
    required this.phase,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter: Floating Particles
// ─────────────────────────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animValue;

  const _ParticlePainter({required this.particles, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final floatY = math.sin((animValue + p.phase) * math.pi * 2) * 12 * p.speed;
      final dx = p.x * size.width;
      final dy = p.y * size.height + floatY;

      final pulseOpacity = p.opacity *
          (0.5 + 0.5 * math.sin((animValue * math.pi * 2) + p.phase));

      final color = p.symbol == '₹'
          ? const Color(0xFF00D9FF)
          : p.symbol == '\$'
              ? const Color(0xFF10B981)
              : const Color(0xFFA855F7);

      final textPainter = TextPainter(
        text: TextSpan(
          text: p.symbol,
          style: TextStyle(
            fontSize: p.size,
            color: color.withValues(alpha: pulseOpacity),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.animValue != animValue;
}
