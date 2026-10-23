import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/animations.dart';
import '../theme/app_theme.dart';

/// The six screens of match setup — conveniently, one over. The header shows
/// progress as the six balls of an over, with the current one in play.
enum SetupStep {
  match('Match'),
  squads('Squads'),
  lineups('Line-ups'),
  rules('Rules'),
  toss('Toss'),
  openers('Openers');

  final String label;
  const SetupStep(this.label);
}

/// Shared frame for every match-setup screen: stadium header with the over
/// tracker, scrollable [body], and an optional pinned [bottomBar].
class SetupScaffold extends StatelessWidget {
  /// Null hides the over tracker (e.g. choosing openers for the 2nd innings).
  final SetupStep? step;
  final String title;
  /// Small caps line above the title; defaults to "Ball n of 6 · Step".
  final String? eyebrow;
  final Widget? subtitle;
  final Widget? trailing;
  /// Extra content at the bottom of the header (e.g. squad counters).
  final Widget? headerBottom;
  final Widget body;
  final Widget? bottomBar;

  const SetupScaffold({
    super.key,
    this.step,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.headerBottom,
    required this.body,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            _SetupHeader(
              step: step,
              title: title,
              eyebrow: eyebrow,
              subtitle: subtitle,
              trailing: trailing,
              bottom: headerBottom,
            ),
            Expanded(child: body),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  final SetupStep? step;
  final String title;
  final String? eyebrow;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  const _SetupHeader({
    required this.step,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    final s = step;
    final eyebrowText = eyebrow ??
        (s != null ? 'BALL ${s.index + 1} OF 6  ·  ${s.label.toUpperCase()}' : null);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _MowedPitchPainter())),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
                        TapBounce(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyebrowText != null)
                              Text(
                                eyebrowText,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 1.8,
                                  color: AppColors.accentLight.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              DefaultTextStyle.merge(
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500),
                                child: subtitle!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                  if (s != null) ...[
                    const SizedBox(height: 18),
                    OverTracker(current: s),
                  ],
                  if (bottom != null) ...[
                    const SizedBox(height: 16),
                    bottom!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six balls of an over: bowled (done), in play (current), still to come.
class OverTracker extends StatelessWidget {
  final SetupStep current;
  const OverTracker({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final step in SetupStep.values) ...[
          Expanded(child: _BallMark(step: step, current: current)),
        ],
      ],
    );
  }
}

class _BallMark extends StatelessWidget {
  final SetupStep step;
  final SetupStep current;
  const _BallMark({required this.step, required this.current});

  @override
  Widget build(BuildContext context) {
    final done = step.index < current.index;
    final now = step == current;
    return Column(
      children: [
        SizedBox(
          height: 26,
          child: Row(
            children: [
              // Connector from the previous ball
              Expanded(
                child: step.index == 0
                    ? const SizedBox()
                    : Container(
                        height: 2,
                        color: Colors.white
                            .withValues(alpha: step.index <= current.index ? 0.55 : 0.15),
                      ),
              ),
              if (now)
                const _LiveBall()
              else
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: done ? 1 : 0.35),
                      width: 1.6,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          size: 11, color: AppColors.primaryDark)
                      : null,
                ),
              Expanded(
                child: step.index == SetupStep.values.length - 1
                    ? const SizedBox()
                    : Container(
                        height: 2,
                        color: Colors.white
                            .withValues(alpha: step.index < current.index ? 0.55 : 0.15),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          step.label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: now ? FontWeight.w800 : FontWeight.w600,
            color: Colors.white.withValues(alpha: now ? 1 : (done ? 0.75 : 0.45)),
          ),
        ),
      ],
    );
  }
}

/// The ball currently in play — a red cricket ball with a gently pulsing glow.
class _LiveBall extends StatefulWidget {
  const _LiveBall();
  @override
  State<_LiveBall> createState() => _LiveBallState();
}

class _LiveBallState extends State<_LiveBall> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D6A).withValues(alpha: 0.35 + _c.value * 0.35),
              blurRadius: 8 + _c.value * 8,
              spreadRadius: _c.value * 2,
            ),
          ],
        ),
        child: child,
      ),
      child: const SizedBox.square(
        dimension: 24,
        child: CustomPaint(painter: CricketBallPainter()),
      ),
    );
  }
}

/// A red leather cricket ball with a white seam.
class CricketBallPainter extends CustomPainter {
  const CricketBallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFF0506A), Color(0xFFC81E3A), Color(0xFF7F0D22)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final seam = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c.translate(-r * 1.2, 0), radius: r * 1.05),
        -0.7, 1.4, false, seam);
    canvas.drawCircle(c.translate(-r * 0.35, -r * 0.4), r * 0.18,
        Paint()..color = Colors.white.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(CricketBallPainter oldDelegate) => false;
}

/// Mowing stripes and a faint pitch outline over the header gradient.
class _MowedPitchPainter extends CustomPainter {
  const _MowedPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.035);
    const w = 34.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 9);
    final span = size.width + size.height;
    for (var x = -span; x < span; x += w * 2) {
      canvas.drawRect(Rect.fromLTWH(x, -span, w, span * 2), stripe);
    }
    canvas.restore();

    // Boundary rope arc in the corner
    canvas.drawCircle(
      Offset(size.width + 30, -40),
      150,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MowedPitchPainter oldDelegate) => false;
}

/// Pinned primary action at the bottom of a setup screen.
class SetupCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  /// Optional line above the button (e.g. "2 of 3 picked").
  final Widget? hint;

  const SetupCta({
    super.key,
    required this.label,
    this.icon = Icons.arrow_forward_rounded,
    required this.onTap,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                DefaultTextStyle.merge(
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  child: hint!,
                ),
                const SizedBox(height: 10),
              ],
              TapBounce(
                onTap: enabled ? onTap! : () {},
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: enabled ? AppColors.primaryGradient : null,
                    color: enabled ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: enabled ? Colors.white : AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(icon,
                          size: 20,
                          color: enabled ? Colors.white : AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White rounded card used across the setup screens.
class SetupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  const SetupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint != null ? Color.alphaBlend(tint!.withValues(alpha: 0.05), AppColors.surface) : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: tint != null ? tint!.withValues(alpha: 0.25) : AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

/// Section title used inside setup screens: icon tile + title (+ trailing).
class SetupSectionTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? caption;
  final Widget? trailing;

  const SetupSectionTitle({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              if (caption != null)
                Text(caption!,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Team crest: initial on a team-coloured badge.
class TeamCrest extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const TeamCrest({super.key, required this.name, required this.color, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.15)!, Color.lerp(color, Colors.black, 0.25)!],
        ),
        border: Border.all(color: Colors.white, width: size * 0.05),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: size * 0.25, offset: Offset(0, size * 0.08)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1)),
    );
  }
}

/// Team colours used throughout setup and scoring.
class TeamColors {
  static const a = AppColors.info;
  static const b = AppColors.accent;
}
