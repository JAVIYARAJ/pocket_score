import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/animations.dart';
import '../theme/app_theme.dart';
import '../widgets/setup_flow.dart' show CricketBallPainter;

/// First-launch intro: four swipeable pages, each with an animated cricket
/// illustration. Shown once (see OnboardingStore); [onDone] finishes it.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final String kicker;
  final String title;
  final String body;
  const _Page(this.kicker, this.title, this.body);
}

const _pages = [
  _Page('SCORING', 'Score every ball',
      'Runs, extras, wickets and free hits — ball by ball, with an undo for when you slip.'),
  _Page('GROUPS', 'Bring your squad',
      'Make a group, invite friends with a code or QR, and add guests who don\'t have the app.'),
  _Page('LIVE', 'Follow it live',
      'Friends watch every ball as it happens — scores update in real time.'),
  _Page('HALL OF FAME', 'Climb the rankings',
      'Every match builds your stats. Chase the Orange Cap, the Purple Cap and MVP.'),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
    } else {
      _pager.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    final pad = MediaQuery.of(context).padding;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF033D2E),
        body: Stack(children: [
          // Ground: deep green with mowing stripes and a boundary-rope arc
          const Positioned.fill(child: CustomPaint(painter: _GroundPainter())),
          Column(children: [
            // ── Top bar ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, pad.top + 12, 12, 0),
              child: Row(children: [
                const SizedBox.square(dimension: 22, child: CustomPaint(painter: CricketBallPainter())),
                const SizedBox(width: 8),
                const Text('Pocket Score',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2)),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: last ? 0 : 1,
                  child: TextButton(
                    onPressed: last ? null : widget.onDone,
                    child: Text('Skip',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            // ── Illustrations ───────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _pager,
                  builder: (context, child) {
                    final page = _pager.hasClients && _pager.position.haveDimensions
                        ? (_pager.page ?? _page.toDouble())
                        : _page.toDouble();
                    final d = (page - i).abs().clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 1 - d * 0.7,
                      child: Transform.scale(scale: 1 - d * 0.15, child: child),
                    );
                  },
                  child: Center(
                    child: Transform.scale(
                      scale: 1.12,
                      child: switch (i) {
                      0 => _ScoreIllo(active: _page == 0),
                      1 => _SquadIllo(active: _page == 1),
                      2 => _LiveIllo(active: _page == 2),
                      _ => _FameIllo(active: _page == 3),
                      },
                    ),
                  ),
                ),
              ),
            ),
            // ── Text + controls panel ───────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 26, 24, pad.bottom + 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Column(
                    key: ValueKey(_page),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pages[_page].kicker,
                          style: const TextStyle(
                              fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
                      const SizedBox(height: 6),
                      Text(_pages[_page].title,
                          style: const TextStyle(
                              fontSize: 27, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.6)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: Text(_pages[_page].body,
                            style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  // Progress: one ball per page, the current one in play
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 8),
                      width: i == _page ? 20 : 9,
                      height: i == _page ? 20 : 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _page ? AppColors.primaryLight : (i == _page ? null : AppColors.border),
                      ),
                      child: i == _page ? const CustomPaint(painter: CricketBallPainter()) : null,
                    ),
                  const Spacer(),
                  TapBounce(
                    onTap: _next,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      height: 56,
                      width: last ? 170 : 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Center(
                          child: last
                              ? const FittedBox(
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text("Let's play",
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                                    SizedBox(width: 8),
                                    Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 20),
                                  ]),
                                )
                              : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background
// ─────────────────────────────────────────────────────────────────────────────
class _GroundPainter extends CustomPainter {
  const _GroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF065F46), Color(0xFF033D2E), Color(0xFF022C22)],
        ).createShader(rect),
    );
    // Mowing stripes
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var y = 0.0; y < size.height; y += 64) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 32), stripe);
    }
    // Boundary rope arc + inner circle
    final rope = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.36), size.width * 0.72, rope);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.36), size.width * 0.42,
        rope..color = Colors.white.withValues(alpha: 0.05));
  }

  @override
  bool shouldRepaint(_GroundPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration base: replays its intro each time its page becomes active
// ─────────────────────────────────────────────────────────────────────────────
abstract class _Illo extends StatefulWidget {
  final bool active;
  const _Illo({required this.active});
}

abstract class _IlloState<T extends _Illo> extends State<T> with TickerProviderStateMixin {
  late final AnimationController intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    if (widget.active) intro.forward();
  }

  @override
  void didUpdateWidget(covariant T old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) intro.forward(from: 0);
  }

  @override
  void dispose() {
    intro.dispose();
    loop.dispose();
    super.dispose();
  }

  double phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((intro.value - begin) / (end - begin)).clamp(0.0, 1.0));

  Widget paint(BuildContext context);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([intro, loop]),
        builder: (context, _) => SizedBox(width: 300, height: 300, child: paint(context)),
      );
}

/// Pops a child in: scale with a little overshoot + fade.
Widget _pop(double t, Widget child) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
    );

// ── 1. Scoring: LED board counting up + ball chips popping in ────────────────
class _ScoreIllo extends _Illo {
  const _ScoreIllo({required super.active});
  @override
  State<_ScoreIllo> createState() => _ScoreIlloState();
}

class _ScoreIlloState extends _IlloState<_ScoreIllo> {
  static const _balls = [('4', AppColors.four), ('1', AppColors.primary), ('•', Color(0xFF94A3B8)),
    ('6', AppColors.six), ('W', AppColors.wicket), ('2', AppColors.primary)];

  @override
  Widget paint(BuildContext context) {
    final board = phase(0.0, 0.3, Curves.easeOutBack);
    final count = phase(0.15, 0.85);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _pop(board, Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1E293B), width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('THUNDER XI',
                style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: Color(0xFFFCD34D))),
            const Spacer(),
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.wicket.withValues(alpha: 0.5 + 0.5 * math.sin(loop.value * 2 * math.pi).abs()),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(148 * count).round()}',
                style: const TextStyle(
                  fontSize: 52, height: 1, fontWeight: FontWeight.w900, color: Color(0xFFFCD34D),
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: [Shadow(color: Color(0x99FCD34D), blurRadius: 16)],
                )),
            Text('/${(3 * count).round()}',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6))),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(18 * count).floor()}.${count > 0.95 ? 4 : 0}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('OVERS', style: TextStyle(fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.45))),
            ]),
          ]),
        ]),
      )),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final (i, (label, color)) in _balls.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _pop(
              phase(0.35 + i * 0.08, 0.55 + i * 0.08, Curves.easeOutBack),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)],
                ),
                alignment: Alignment.center,
                child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
      ]),
    ]);
  }
}

// ── 2. Squad: group card + avatars huddling + invite code ────────────────────
class _SquadIllo extends _Illo {
  const _SquadIllo({required super.active});
  @override
  State<_SquadIllo> createState() => _SquadIlloState();
}

class _SquadIlloState extends _IlloState<_SquadIllo> {
  static const _people = [
    ('R', Color(0xFF2563EB), -96.0, -4.0),
    ('A', Color(0xFFF59E0B), -48.0, -18.0),
    ('V', Color(0xFF10B981), 0.0, -26.0),
    ('D', Color(0xFFEF4444), 48.0, -18.0),
    ('+', Color(0xFF8B5CF6), 96.0, -4.0),
  ];

  @override
  Widget paint(BuildContext context) {
    final card = phase(0.0, 0.3, Curves.easeOutBack);
    final code = phase(0.7, 0.95, Curves.easeOutBack);
    final float = math.sin(loop.value * 2 * math.pi) * 3;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      // Group card
      Positioned(
        top: 118,
        child: _pop(card, Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: Column(children: [
            const Text('Sunday Smashers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            const Text('12 members  ·  4 guests', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Transform.scale(
              scale: code.clamp(0.0, 1.15),
              child: Opacity(
                opacity: code.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('XK7P2M',
                        style: TextStyle(fontSize: 15, letterSpacing: 3, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                  ]),
                ),
              ),
            ),
          ]),
        )),
      ),
      // Avatars huddle on top of the card
      for (final (i, (letter, color, dx, dy)) in _people.indexed)
        Positioned(
          top: 92 + dy + (i.isEven ? float : -float),
          left: 150 + dx - 26,
          child: _pop(
            phase(0.2 + i * 0.08, 0.45 + i * 0.08, Curves.easeOutBack),
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Text(letter, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ),
    ]);
  }
}

// ── 3. Live: match card with LIVE pulse, ticking score and a SIX! burst ──────
class _LiveIllo extends _Illo {
  const _LiveIllo({required super.active});
  @override
  State<_LiveIllo> createState() => _LiveIlloState();
}

class _LiveIlloState extends _IlloState<_LiveIllo> {
  @override
  Widget paint(BuildContext context) {
    final card = phase(0.0, 0.3, Curves.easeOutBack);
    final runs = phase(0.25, 0.6);
    final six = phase(0.6, 0.85, Curves.elasticOut);
    final viewers = phase(0.75, 1.0, Curves.easeOutBack);
    final pulse = (math.sin(loop.value * 2 * math.pi) + 1) / 2;
    final score = 80 + (6 * runs).round();

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Stack(clipBehavior: Clip.none, children: [
      _pop(card, Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.wicket, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4 + 0.6 * pulse), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text('LIVE', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Colors.white)),
              ]),
            ),
            const Spacer(),
            const Text('Target 141', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 12),
          const Text('Storm Riders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$score/2',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text('(9.3 ov)', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
          ]),
          const SizedBox(height: 10),
          // Chase progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 7, color: AppColors.surfaceLight),
              FractionallySizedBox(
                widthFactor: score / 141,
                child: Container(height: 7, decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text('Need ${141 - score} from 63 balls',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      )),
      // SIX! burst
      Positioned(
        top: -30,
        right: -18,
        child: Transform.rotate(
          angle: -0.18,
          child: Transform.scale(
            scale: six.clamp(0.0, 1.3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF15803D)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.six.withValues(alpha: 0.5), blurRadius: 14)],
              ),
              child: const Text('SIX!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ),
          ),
        ),
      ),
      ]),
      const SizedBox(height: 18),
      // Viewers watching
      _pop(viewers, Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, c) in [const Color(0xFF2563EB), const Color(0xFFF59E0B), const Color(0xFFEC4899)].indexed)
              Transform.translate(
                offset: Offset(-6.0 * i, 0),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
            const Text('8 friends watching',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        )),
    ]);
  }
}

// ── 4. Fame: podium builds up, crown drops, cap badges appear ────────────────
class _FameIllo extends _Illo {
  const _FameIllo({required super.active});
  @override
  State<_FameIllo> createState() => _FameIlloState();
}

class _FameIlloState extends _IlloState<_FameIllo> {
  static const _metal = [
    [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
    [Color(0xFFF1F5F9), Color(0xFF94A3B8), Color(0xFF475569)],
    [Color(0xFFFED7AA), Color(0xFFEA580C), Color(0xFF9A3412)],
  ];

  @override
  Widget paint(BuildContext context) {
    final crown = phase(0.55, 0.85, Curves.bounceOut);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      // Cap badges
      Wrap(spacing: 8, children: [
        for (final (i, (label, color)) in [
          ('ORANGE CAP', const Color(0xFFF97316)),
          ('PURPLE CAP', const Color(0xFF8B5CF6)),
          ('MVP', const Color(0xFFF59E0B)),
        ].indexed)
          _pop(
            phase(0.7 + i * 0.07, 0.9 + i * 0.03, Curves.easeOutBack),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.7)),
              ),
              child: Text(label, style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w900, color: color)),
            ),
          ),
      ]),
      const SizedBox(height: 40),
      Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final rank in [2, 1, 3]) _step(rank, crown),
      ]),
    ]);
  }

  Widget _step(int rank, double crown) {
    final metal = _metal[rank - 1];
    final first = rank == 1;
    final start = rank == 3 ? 0.0 : rank == 2 ? 0.1 : 0.2;
    final rise = phase(start, start + 0.35, Curves.easeOutBack);
    final pop = phase(start + 0.2, start + 0.45, Curves.easeOutBack);
    final height = first ? 110.0 : rank == 2 ? 80.0 : 60.0;
    final shine = (loop.value * 1.6 - 0.3);

    return SizedBox(
      width: 86,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          _pop(pop, Container(
            width: first ? 60 : 48, height: first ? 60 : 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [metal[0], metal[1], metal[2]]),
              boxShadow: [BoxShadow(color: metal[1].withValues(alpha: 0.5), blurRadius: first ? 18 : 10)],
            ),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111827)),
              alignment: Alignment.center,
              child: Text(const {1: 'R', 2: 'A', 3: 'V'}[rank]!,
                  style: TextStyle(fontSize: first ? 24 : 19, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          )),
          if (first)
            Positioned(
              top: -28 - 30 * (1 - crown),
              child: Opacity(
                opacity: crown,
                child: Icon(Icons.workspace_premium_rounded, size: 30, color: metal[1],
                    shadows: [Shadow(color: metal[1], blurRadius: 12)]),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1, rise.clamp(0.0, 1.15), 1),
          child: Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [metal[0], metal[1], metal[2]]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + shine * 2 - 0.4, -1),
                    end: Alignment(-1 + shine * 2 + 0.4, 1),
                    colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: first ? 36 : 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1,
                        shadows: [Shadow(color: metal[2], blurRadius: 4, offset: const Offset(0, 2))])),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
