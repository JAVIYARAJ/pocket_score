part of '../scoring_screen.dart';

// Innings-break and super-over-break dialogs.

// ── INNINGS BREAK DIALOG ──────────────────────────────────────────────
class _InningsBreakDialog extends StatefulWidget {
  final ScoreState state;
  final int target;
  final String chasers;
  final bool aBatted;
  final Team teamA;
  final Team teamB;

  const _InningsBreakDialog({
    required this.state,
    required this.target,
    required this.chasers,
    required this.aBatted,
    required this.teamA,
    required this.teamB,
  });

  @override
  State<_InningsBreakDialog> createState() => _InningsBreakDialogState();
}

class _InningsBreakDialogState extends State<_InningsBreakDialog> with TickerProviderStateMixin {
  late AnimationController _introCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _introCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.state.firstInnings!;
    final iconScale = CurvedAnimation(parent: _introCtrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    final contentFade = CurvedAnimation(parent: _introCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic));
    final slideUp = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(contentFade);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, // Reverted to app theme
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 10,
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Broadcast Hero Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 40, left: 24, right: 24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient, // Reverted to native gradient
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Decorative circles for cricket environment
                  Positioned(
                    right: -40,
                    top: -60,
                    child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  Positioned(
                    left: -40,
                    bottom: -30,
                    child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  Column(
                    children: [
                      ScaleTransition(
                        scale: iconScale,
                        child: Container(
                          width: 80, height: 80,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, // Light icon base
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                            ],
                          ),
                          child: const Icon(Icons.sports_cricket_rounded, color: AppColors.primary, size: 40),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: contentFade,
                        child: SlideTransition(
                          position: slideUp,
                          child: Column(
                            children: [
                              const Text('INNINGS BREAK', style: TextStyle(fontSize: 12, letterSpacing: 4, color: Colors.white70, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              Text(
                                first.battingTeamName,
                                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${first.totalRuns}/${first.totalWickets}',
                                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0, letterSpacing: -1),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text('(${first.overDisplay} overs)', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Target Reveal LED Scoreboard ──
            FadeTransition(
              opacity: contentFade,
              child: SlideTransition(
                position: slideUp,
                child: Container(
                  width: double.infinity,
                  color: AppColors.surface, 
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text('TARGET SET', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3.0)),
                      const SizedBox(height: 16),
                      
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) {
                          final pulse = Curves.easeInOut.transform(_pulseCtrl.value);
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight, 
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3 + (pulse * 0.4)), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.1 + (pulse * 0.1)),
                                  blurRadius: 20 + (pulse * 10),
                                  spreadRadius: pulse * 2,
                                )
                              ]
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${widget.target}',
                                  style: TextStyle(
                                    fontSize: 64, 
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(color: AppColors.primary.withValues(alpha: 0.3 * pulse), blurRadius: 10 * pulse),
                                    ]
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('RUNS TO WIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.textSecondary)),
                              ],
                            ),
                          );
                        }
                      ),
                      
                      const SizedBox(height: 24),
                      Text('Chasing: ${widget.chasers}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 32),

                      // Swipe to Chase integration!
                      _DialogSwipeToStart(
                        text: 'SWIPE TO CHASE',
                        onSwipe: () {
                          Navigator.pop(context);
                          context.push('/match/opening', extra: {
                            'battingTeamName': widget.aBatted ? widget.teamB.name : widget.teamA.name,
                            'battingPlayers' : widget.aBatted ? widget.teamB.players : widget.teamA.players,
                            'bowlingPlayers' : widget.aBatted ? widget.teamA.players : widget.teamB.players,
                            'target'         : widget.target,
                          });
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SUPER OVER BREAK DIALOG ──────────────────────────────────────────────
class _SuperOverBreakDialog extends StatefulWidget {
  final Innings soFirstInnings;
  final int target;
  final Team chasingTeam;
  final Team bowlingTeam;

  const _SuperOverBreakDialog({
    required this.soFirstInnings,
    required this.target,
    required this.chasingTeam,
    required this.bowlingTeam,
  });

  @override
  State<_SuperOverBreakDialog> createState() => _SuperOverBreakDialogState();
}

class _SuperOverBreakDialogState extends State<_SuperOverBreakDialog> with TickerProviderStateMixin {
  late AnimationController _introCtrl;
  late AnimationController _pulseCtrl;

  static const _soGradient = LinearGradient(
    colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _introCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soInn = widget.soFirstInnings;
    final iconScale   = CurvedAnimation(parent: _introCtrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    final contentFade = CurvedAnimation(parent: _introCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic));
    final slideUp     = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(contentFade);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 40, left: 24, right: 24),
              decoration: const BoxDecoration(gradient: _soGradient),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(right: -40, top: -60, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
                  Positioned(left: -40, bottom: -30, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
                  Column(
                    children: [
                      ScaleTransition(
                        scale: iconScale,
                        child: Container(
                          width: 80, height: 80,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)],
                          ),
                          child: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 40),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: contentFade,
                        child: SlideTransition(
                          position: slideUp,
                          child: Column(
                            children: [
                              const Text('SUPER OVER', style: TextStyle(fontSize: 12, letterSpacing: 4, color: Colors.white70, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              Text(soInn.battingTeamName, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text(
                                '${soInn.totalRuns}/${soInn.totalWickets}',
                                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0, letterSpacing: -1),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text('(${soInn.overDisplay} over)', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Target ──
            FadeTransition(
              opacity: contentFade,
              child: SlideTransition(
                position: slideUp,
                child: Container(
                  width: double.infinity,
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text('TARGET SET', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3.0)),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) {
                          final pulse = Curves.easeInOut.transform(_pulseCtrl.value);
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3 + (pulse * 0.4)), width: 2),
                              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.1 + (pulse * 0.1)), blurRadius: 20 + (pulse * 10), spreadRadius: pulse * 2)],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${widget.target}',
                                  style: TextStyle(
                                    fontSize: 64, fontWeight: FontWeight.w900, color: AppColors.accent, height: 1.0,
                                    shadows: [Shadow(color: AppColors.accent.withValues(alpha: 0.3 * pulse), blurRadius: 10 * pulse)],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('RUNS TO WIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.textSecondary)),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text('Chasing: ${widget.chasingTeam.name}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 32),
                      _DialogSwipeToStart(
                        text: 'SWIPE TO BAT',
                        onSwipe: () {
                          Navigator.pop(context);
                          context.push('/match/super-over/opening', extra: {
                            'battingTeam' : widget.chasingTeam,
                            'bowlingTeam' : widget.bowlingTeam,
                            'target'      : widget.target,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SWIPE COMPONENT FOR DIALOG ──────────────────
class _DialogSwipeToStart extends StatefulWidget {
  final VoidCallback onSwipe;
  final String text;

  const _DialogSwipeToStart({required this.onSwipe, required this.text});

  @override
  State<_DialogSwipeToStart> createState() => _DialogSwipeToStartState();
}

class _DialogSwipeToStartState extends State<_DialogSwipeToStart> {
  late final ValueNotifier<double> _dragNotifier;
  late final ValueNotifier<bool> _dragStateNotifier;
  bool _completed = false;
  final double _thumbSize = 52;

  @override
  void initState() {
    super.initState();
    _dragNotifier = ValueNotifier<double>(0);
    _dragStateNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    _dragStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackWidth = constraints.maxWidth - 12;
        final maxDrag = stackWidth - _thumbSize;

        return ValueListenableBuilder<bool>(
          valueListenable: _dragStateNotifier,
          builder: (context, isDragging, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDragging
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight.withValues(alpha: 0.5), 
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDragging ? AppColors.primary : AppColors.border,
                  width: 2.0,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    left: _thumbSize,
                    child: Center(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _dragNotifier,
                        builder: (context, dragOffset, child) {
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: dragOffset > maxDrag * 0.2 ? 0.0 : 1.0,
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.text,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: isDragging ? AppColors.primary : AppColors.textPrimary), 
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.keyboard_double_arrow_right_rounded,
                                size: 20,
                                color: (isDragging ? AppColors.primary : AppColors.textSecondary).withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, dragOffset, _) {
                      return TweenAnimationBuilder<double>(
                        duration: isDragging ? Duration.zero : const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        tween: Tween<double>(begin: 0, end: dragOffset),
                        builder: (context, value, child) {
                          return Positioned(
                            left: value,
                            child: GestureDetector(
                              onHorizontalDragStart: (_) {
                                if (_completed) return;
                                _dragStateNotifier.value = true;
                              },
                              onHorizontalDragUpdate: (details) {
                                if (_completed) return;
                                double newOffset = _dragNotifier.value + details.delta.dx;
                                if (newOffset < 0) newOffset = 0;
                                if (newOffset >= maxDrag) {
                                  newOffset = maxDrag;
                                  _completed = true;
                                  _dragStateNotifier.value = false;
                                  _dragNotifier.value = newOffset;
                                  Future.delayed(const Duration(milliseconds: 200), widget.onSwipe);
                                  return;
                                }
                                _dragNotifier.value = newOffset;
                              },
                              onHorizontalDragEnd: (details) {
                                if (_completed) return;
                                _dragStateNotifier.value = false;
                                if (_dragNotifier.value > maxDrag * 0.7) {
                                  _completed = true;
                                  _dragNotifier.value = maxDrag;
                                  Future.delayed(const Duration(milliseconds: 300), widget.onSwipe);
                                } else {
                                  _dragNotifier.value = 0;
                                }
                              },
                              child: Container(
                                width: _thumbSize,
                                height: _thumbSize,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDragging ? 0.3 : 0.15),
                                      blurRadius: isDragging ? 12 : 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Transform.rotate(
                                  angle: value / 20,
                                  child: Image.asset(
                                    'assets/icons/ic_cricket_ball_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
