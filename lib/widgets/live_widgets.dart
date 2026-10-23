import 'package:flutter/material.dart';

import '../models/ball_model.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Building blocks for live-match views: the home live card and the spectator
// screen. Each animates only when its data changes, so a realtime update
// reads as motion (score rolls, newest ball pops in, chase bar fills) rather
// than a jump.
// ─────────────────────────────────────────────────────────────────────────────

/// Label and colour for one delivery, shared by every ball strip.
(String, Color) ballFace(Ball b) {
  if (b.isWicket) return ('W', AppColors.wicket);
  if (b.type == BallType.wide) return ('WD', AppColors.wide);
  if (b.type == BallType.noBall) return (b.runs > 0 ? 'Nb+${b.runs}' : 'NB', AppColors.noBall);
  if (b.runs == 6) return ('6', AppColors.six);
  if (b.runs == 4) return ('4', AppColors.four);
  if (b.runs == 0) return ('•', AppColors.dot);
  return ('${b.runs}', AppColors.primary);
}

/// Pulsing "LIVE" pill: a solid dot with a ring that ripples outwards.
class LiveBadge extends StatefulWidget {
  final String label;
  final Color color;
  const LiveBadge({super.key, this.label = 'LIVE', this.color = const Color(0xFFFF4D4F)});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 12,
          height: 12,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_c.value);
              return Stack(alignment: Alignment.center, children: [
                Container(
                  width: 6 + 6 * t,
                  height: 6 + 6 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.55 * (1 - t)),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(width: 5),
        Text(widget.label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: widget.color, letterSpacing: 1.6)),
      ]),
    );
  }
}

/// "runs/wickets" where runs count up to each new value and the wicket
/// number flips in, so every realtime update is visible at a glance.
class RollingScore extends StatelessWidget {
  final int runs;
  final int wickets;
  final double size;
  final Color color;
  const RollingScore({
    super.key,
    required this.runs,
    required this.wickets,
    this.size = 40,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final big = TextStyle(
        fontSize: size, fontWeight: FontWeight.w900, color: color, height: 1, letterSpacing: -1.5);
    final small = TextStyle(
        fontSize: size * 0.55, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.7), height: 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(end: runs),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text('$v', style: big),
        ),
        Text('/', style: small),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: Text('$wickets', key: ValueKey(wickets), style: small),
        ),
      ],
    );
  }
}

/// The over in progress as six slots: bowled balls (plus any extras) in
/// order, then empty rings for the legal deliveries still to come. The newest
/// ball springs into place.
class OverTrack extends StatelessWidget {
  final List<Ball> balls;
  final double size;

  /// Light rings for dark backgrounds.
  final bool onDark;
  const OverTrack({super.key, required this.balls, this.size = 26, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    // A finished over shows in full; otherwise pad to six legal deliveries.
    final legal = balls.where((b) => b.isLegalBall).length;
    final empty = legal >= 6 ? 0 : 6 - legal;
    final gap = size * 0.22;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: [
        for (var i = 0; i < balls.length; i++)
          Padding(
            padding: EdgeInsets.only(right: gap),
            child: _PopIn(key: ValueKey('ball$i'), child: _ballDot(balls[i])),
          ),
        for (var i = 0; i < empty; i++)
          Padding(
            padding: EdgeInsets.only(right: gap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: onDark ? Colors.white.withValues(alpha: 0.22) : AppColors.border,
                  width: 1.4,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _ballDot(Ball b) {
    final (label, color) = ballFace(b);
    final boundary = b.isWicket || b.runs == 4 || b.runs == 6;
    final isDot = color == AppColors.dot;
    final Color fill;
    final Color text;
    if (boundary) {
      fill = color;
      text = Colors.white;
    } else if (onDark) {
      fill = Colors.white.withValues(alpha: isDot ? 0.10 : 0.18);
      text = isDot ? Colors.white60 : (color == AppColors.primary ? Colors.white : color);
    } else {
      fill = color.withValues(alpha: 0.12);
      text = isDot ? AppColors.textMuted : color;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        boxShadow: boundary
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: size * 0.35)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
            fontSize: size * (label.length > 2 ? 0.28 : (label.length > 1 ? 0.34 : 0.44)),
            fontWeight: FontWeight.w900,
            color: text,
          )),
    );
  }
}

/// Springs a newly built child in once; existing children (same key) stay put.
class _PopIn extends StatelessWidget {
  final Widget child;
  const _PopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
      ),
    );
  }
}

/// Thin bar showing how much of the target has been scored; fills smoothly
/// as runs come in.
class ChaseMeter extends StatelessWidget {
  final int runs;
  final int target;
  final bool onDark;
  final double height;
  const ChaseMeter({
    super.key,
    required this.runs,
    required this.target,
    this.onDark = true,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final p = target > 0 ? (runs / target).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: onDark ? Colors.white.withValues(alpha: 0.14) : AppColors.surfaceLight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: p),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glow that flares in [color] whenever [eventKey] changes (e.g. a boundary
/// or wicket) and then fades, around any card.
class EventGlow extends StatelessWidget {
  final Object eventKey;
  final Color? color;
  final double radius;
  final Widget child;
  const EventGlow({
    super.key,
    required this.eventKey,
    required this.color,
    required this.child,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (color == null) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(eventKey),
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      child: child,
      builder: (_, t, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            if (t > 0) BoxShadow(color: color!.withValues(alpha: 0.65 * t), blurRadius: 28 * t, spreadRadius: 2 * t),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Colour to flare for the latest delivery, or null for an ordinary ball.
Color? highlightFor(Ball? b) {
  if (b == null) return null;
  if (b.isWicket) return AppColors.wicket;
  if (b.runs == 6) return AppColors.six;
  if (b.runs == 4) return AppColors.four;
  return null;
}
