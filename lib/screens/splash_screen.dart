import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import '../bloc/auth_cubit.dart'
    show AuthBloc, PocketAuthState, AuthInitial, AuthLoading;
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SplashScreen
//
// Pure display widget — no navigation. It calls [onComplete] when BOTH:
//   • the minimum display timer (2 500 ms) has elapsed, AND
//   • auth state has settled (not AuthInitial / AuthLoading).
//
// _AppRoot in main.dart owns the routing and replaces this widget once
// onComplete fires. That keeps a single, persistent auth listener alive
// for the entire app lifetime, so sign-in and sign-out always work.
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  /// Called exactly once when the splash is ready to hand off.
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Lottie ─────────────────────────────────────────────────────
  late final AnimationController _lottieCtrl;

  // ── Two-gate completion logic ──────────────────────────────────
  bool _minTimerDone = false;
  bool _authSettled  = false;

  // ── Branding text animation ────────────────────────────────────
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset>  _textSlide;

  static const _minDuration = Duration(milliseconds: 2500);
  static const _animAsset   = 'assets/icons/ic_splash_animation.json';

  @override
  void initState() {
    super.initState();

    _lottieCtrl = AnimationController(vsync: this);

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide   = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Start text fade-in after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _textCtrl.forward();
    });

    // Gate 1 — minimum display timer
    Timer(_minDuration, () {
      _minTimerDone = true;
      _maybeComplete();
    });

    // Gate 2 — check whether auth is already settled (cubit state set
    // synchronously in its constructor before the listener attaches).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAuthState(context.read<AuthBloc>().state);
    });
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  /// Evaluates a state; ignores transient loading states.
  void _checkAuthState(PocketAuthState state) {
    if (state is AuthInitial || state is AuthLoading) return;
    if (_authSettled) return;
    _authSettled = true;
    _maybeComplete();
  }

  /// Calls [onComplete] when both gates are open.
  void _maybeComplete() {
    if (!_minTimerDone || !_authSettled) return;
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    // BlocListener catches any state change AFTER mount (e.g. delayed auth).
    return BlocListener<AuthBloc, PocketAuthState>(
      listener: (_, state) => _checkAuthState(state),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor:                Colors.transparent,
          statusBarIconBrightness:       Brightness.light,
          statusBarBrightness:           Brightness.dark,
          systemNavigationBarColor:      Color(0xFF064E3B),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF064E3B),
          body: Container(
            width:  double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: Stack(
              children: [
                // ── Background decorations ─────────────────────────
                ..._decorations(),

                // ── Centred content ────────────────────────────────
                // Positioned.fill gives the Column a bounded height so
                // mainAxisAlignment: center works correctly.
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment:  MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cricket ball Lottie animation
                      SizedBox(
                        width:  200,
                        height: 200,
                        child: Lottie.asset(
                          _animAsset,
                          controller: _lottieCtrl,
                          onLoaded: (composition) {
                            _lottieCtrl
                              ..duration = composition.duration
                              ..repeat();
                          },
                          fit: BoxFit.contain,
                          delegates: LottieDelegates(
                            values: [
                              // Remove the white background circle so the
                              // ball floats on the green gradient.
                              ValueDelegate.color(
                                const ['Shape Layer 2', 'Ellipse 1', 'Fill 1'],
                                value: Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // App name + subtitle — fade + slide in
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Pocket Score',
                                style: TextStyle(
                                  fontSize:   36,
                                  fontWeight: FontWeight.w900,
                                  color:      Colors.white,
                                  letterSpacing: -1,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Text(
                                  '🏏  Box Cricket Scorer',
                                  style: TextStyle(
                                    fontSize:   14,
                                    fontWeight: FontWeight.w600,
                                    color:      Colors.white70,
                                    letterSpacing: 0.3,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _decorations() => [
        // Stadium Background, Pitch & Wickets
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              // Isometric pitch coordinates (must match _StadiumPainter)
              final topY = h * 0.20;
              final botY = h * 0.95;
              final bTopY = topY + (botY - topY) * 0.08; // Top bowling crease
              final bBotY = topY + (botY - topY) * 0.92; // Bottom bowling crease

              return Stack(
                children: [
                  // 1. The pitch
                  CustomPaint(
                    size: Size(w, h),
                    painter: _StadiumPainter(),
                  ),

                  // 2. Top Wickets (Standing) - Scaled down for perspective
                  Positioned(
                    left: w / 2 - 25,
                    top: bTopY - 50,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Image.asset(
                        'assets/icons/wicket_out_icon.png',
                        height: 50,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),

                  // 3. Bottom Wickets (Knocked Out) - Scaled up for foreground
                  Positioned(
                    left: w / 2 - 42,
                    top: bBotY - 85,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Image.asset(
                        'assets/icons/wickets.png',
                        height: 85, // 85px to account for flying bails padding, making the stump appear ~75px
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Beautiful 3D Stadium & Pitch Painter
// ─────────────────────────────────────────────────────────────────────────────
class _StadiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw alternating grass stripes
    final stripePaint = Paint();
    const stripeCount = 12;
    final stripeHeight = size.height / stripeCount;
    for (int i = 0; i < stripeCount; i++) {
      stripePaint.color = i.isEven 
          ? Colors.white.withValues(alpha: 0.03) 
          : Colors.transparent;
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        stripePaint,
      );
    }

    // 2. Draw a 3D isometric pitch in the center
    final pitchPath = Path();
    final topW = size.width * 0.35;
    final botW = size.width * 0.85;
    final topY = size.height * 0.20;
    final botY = size.height * 0.95;
    
    pitchPath.moveTo(size.width / 2 - topW / 2, topY);
    pitchPath.lineTo(size.width / 2 + topW / 2, topY);
    pitchPath.lineTo(size.width / 2 + botW / 2, botY);
    pitchPath.lineTo(size.width / 2 - botW / 2, botY);
    pitchPath.close();

    // A subtle dirt/sand color for the pitch, mixed into the green
    final pitchPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFD4B895).withValues(alpha: 0.05),
          const Color(0xFFD4B895).withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromLTWH(0, topY, size.width, botY - topY));
    canvas.drawPath(pitchPath, pitchPaint);

    // 3. Draw white crease lines inside the pitch
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Helper to get X width at a specific Y percentage
    double getWidthAt(double pct) => topW + (botW - topW) * pct;

    // Bowling crease Top (10%)
    final bTopY = topY + (botY - topY) * 0.08;
    final bTopW = getWidthAt(0.08);
    canvas.drawLine(
      Offset(size.width / 2 - bTopW / 2, bTopY),
      Offset(size.width / 2 + bTopW / 2, bTopY),
      linePaint,
    );

    // Popping crease Top (18%)
    final pTopY = topY + (botY - topY) * 0.18;
    final pTopW = getWidthAt(0.18);
    canvas.drawLine(
      Offset(size.width / 2 - pTopW / 2, pTopY),
      Offset(size.width / 2 + pTopW / 2, pTopY),
      linePaint,
    );

    // Popping crease Bottom (82%)
    final pBotY = topY + (botY - topY) * 0.82;
    final pBotW = getWidthAt(0.82);
    canvas.drawLine(
      Offset(size.width / 2 - pBotW / 2, pBotY),
      Offset(size.width / 2 + pBotW / 2, pBotY),
      linePaint,
    );

    // Bowling crease Bottom (92%)
    final bBotY = topY + (botY - topY) * 0.92;
    final bBotW = getWidthAt(0.92);
    canvas.drawLine(
      Offset(size.width / 2 - bBotW / 2, bBotY),
      Offset(size.width / 2 + bBotW / 2, bBotY),
      linePaint,
    );

    // 4. Stadium Spotlights
    final spotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(0, 0), radius: size.width));

    final spotPath1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(spotPath1, spotPaint);

    final spotPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width));

    final spotPath2 = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(spotPath2, spotPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
