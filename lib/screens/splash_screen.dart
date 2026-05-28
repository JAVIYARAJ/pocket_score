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

                // ── Loading dots — pinned to bottom ───────────────
                Positioned(
                  bottom: 52,
                  left:   0,
                  right:  0,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: const Center(child: _LoadingDots()),
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
        // Top-right circle arc
        Positioned(
          top: -80, right: -80,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05), width: 40),
            ),
          ),
        ),
        // Bottom-left circle arc
        Positioned(
          bottom: -60, left: -60,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05), width: 30),
            ),
          ),
        ),
        // Faint pitch crease lines
        Positioned.fill(
          child: CustomPaint(painter: _CreasePainter()),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Faint pitch crease lines painted on the background
// ─────────────────────────────────────────────────────────────────────────────
class _CreasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    final y1 = size.height * 0.30;
    canvas.drawLine(Offset(size.width * 0.1, y1), Offset(size.width * 0.9, y1), p);

    final y2 = size.height * 0.70;
    canvas.drawLine(Offset(size.width * 0.1, y2), Offset(size.width * 0.9, y2), p);

    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.28),
      Offset(size.width / 2, size.height * 0.72),
      p,
    );
  }

  @override
  bool shouldRepaint(_CreasePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated three-dot loader at the bottom of the splash
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t    = ((_ctrl.value + i / 3) % 1.0);
          final ease = t * t * (3 - 2 * t); // smoothstep
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: 0.5 + 0.5 * ease,
              child: Opacity(
                opacity: 0.3 + 0.7 * ease,
                child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
