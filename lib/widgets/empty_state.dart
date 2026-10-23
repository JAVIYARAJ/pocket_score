import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/app_theme.dart';

/// Which hand-drawn cricket illustration an [EmptyState] shows.
enum EmptyArt {
  /// Stumps with a bouncing ball — no matches played yet.
  matches,

  /// A huddle of three players — no groups / teams yet.
  groups,

  /// One player with two open "+" slots — no members / players yet.
  members,

  /// Empty podium with a floating trophy — no rankings / stats yet.
  stats,

  /// Swinging bat and ball — no batting data yet.
  batting,

  /// Spinning ball heading for the stumps — no bowling data yet.
  bowling,

  /// Rain cloud over the covers — "rain stopped play" load errors.
  offline,
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Shared empty / no-data state with an animated cricket illustration.
///
/// Use [compact] inside cards (e.g. a stats section); the default size is meant
/// to fill an empty screen or tab.
/// ─────────────────────────────────────────────────────────────────────────────
class EmptyState extends StatefulWidget {
  final EmptyArt art;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final artSize = compact ? 110.0 : 180.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 36, vertical: compact ? 16 : 24),
        child: FadeInEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                child: SizedBox.square(
                  dimension: artSize,
                  child: CustomPaint(
                    painter: _EmptyArtPainter(widget.art, _loop),
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: compact ? 15 : 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: AppColors.textMuted,
                    height: 1.5),
              ),
              if (widget.action != null) ...[
                SizedBox(height: compact ? 14 : 24),
                widget.action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _EmptyArtPainter extends CustomPainter {
  final EmptyArt art;
  final Animation<double> t;

  _EmptyArtPainter(this.art, this.t) : super(repaint: t);

  static const _wood = Color(0xFFE2B26B);
  static const _woodDark = Color(0xFFB7853F);
  static const _ball = Color(0xFFC81E3A);
  static const _skin = Color(0xFFF0C08A);

  /// 0 → 1 → 0 smooth wave over one loop.
  double get _wave => (1 - math.cos(t.value * 2 * math.pi)) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    _backdrop(canvas, s);
    switch (art) {
      case EmptyArt.matches:
        _matches(canvas, s);
      case EmptyArt.groups:
        _groups(canvas, s);
      case EmptyArt.members:
        _members(canvas, s);
      case EmptyArt.stats:
        _stats(canvas, s);
      case EmptyArt.batting:
        _batting(canvas, s);
      case EmptyArt.bowling:
        _bowling(canvas, s);
      case EmptyArt.offline:
        _offline(canvas, s);
    }
  }

  // Soft turf disc + pitch strip, shared by every illustration.
  void _backdrop(Canvas c, double s) {
    final center = Offset(s / 2, s / 2);
    c.drawCircle(
      center,
      s * 0.47,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.primaryLight.withValues(alpha: 0.16),
          AppColors.primary.withValues(alpha: 0.04),
        ]).createShader(Rect.fromCircle(center: center, radius: s * 0.47)),
    );
    c.drawOval(
      Rect.fromCenter(
          center: Offset(s / 2, s * 0.80), width: s * 0.78, height: s * 0.14),
      Paint()..color = AppColors.primary.withValues(alpha: 0.12),
    );
    // Pitch strip
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(s / 2, s * 0.80),
              width: s * 0.34,
              height: s * 0.07),
          Radius.circular(s * 0.03)),
      Paint()..color = const Color(0xFFE9DCB5).withValues(alpha: 0.9),
    );
  }

  void _shadow(Canvas c, Offset at, double w, double opacity) {
    c.drawOval(
      Rect.fromCenter(center: at, width: w, height: w * 0.28),
      Paint()..color = Colors.black.withValues(alpha: opacity),
    );
  }

  void _stumps(Canvas c, Offset base, double s, {double scale = 1}) {
    final h = s * 0.36 * scale;
    final w = s * 0.032 * scale;
    final gap = s * 0.062 * scale;
    final fill = Paint()..color = _wood;
    final edge = Paint()
      ..color = _woodDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.008 * scale;
    for (var i = -1; i <= 1; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(base.dx + i * gap - w / 2, base.dy - h, w, h),
          Radius.circular(w / 2));
      c.drawRRect(r, fill);
      c.drawRRect(r, edge);
    }
    // Bails
    for (var i = 0; i < 2; i++) {
      final x = base.dx - gap + i * gap;
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - w * 0.2, base.dy - h - w * 0.75, gap + w * 0.4,
              w * 0.6),
          Radius.circular(w * 0.3));
      c.drawRRect(r, fill);
      c.drawRRect(r, edge);
    }
  }

  void _cricketBall(Canvas c, Offset at, double r, {double spin = 0}) {
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Color(0xFFE8475F), _ball, Color(0xFF8E1026)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(spin);
    final seam = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13
      ..strokeCap = StrokeCap.round;
    c.drawArc(Rect.fromCircle(center: Offset(-r * 1.25, 0), radius: r * 1.1),
        -0.75, 1.5, false, seam);
    c.restore();
    // Highlight
    c.drawCircle(at + Offset(-r * 0.38, -r * 0.42), r * 0.18,
        Paint()..color = Colors.white.withValues(alpha: 0.45));
  }

  void _player(Canvas c, Offset feet, double s, Color jersey,
      {double scale = 1, bool cap = true}) {
    final u = s * scale;
    final bodyW = u * 0.26;
    final bodyH = u * 0.22;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(feet.dx - bodyW / 2, feet.dy - bodyH, bodyW, bodyH),
      topLeft: Radius.circular(bodyW * 0.5),
      topRight: Radius.circular(bodyW * 0.5),
    );
    c.drawRRect(body, Paint()..color = jersey);
    // Collar
    c.drawPath(
      Path()
        ..moveTo(feet.dx - bodyW * 0.14, feet.dy - bodyH)
        ..lineTo(feet.dx, feet.dy - bodyH + bodyW * 0.16)
        ..lineTo(feet.dx + bodyW * 0.14, feet.dy - bodyH)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    final headR = u * 0.075;
    final head = Offset(feet.dx, feet.dy - bodyH - headR * 0.85);
    c.drawCircle(head, headR, Paint()..color = _skin);
    if (cap) {
      final capRect = Rect.fromCircle(center: head, radius: headR * 1.04);
      c.drawArc(capRect, math.pi, math.pi, true, Paint()..color = jersey);
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(head.dx, head.dy - headR * 0.12, headR * 1.25,
                headR * 0.24),
            Radius.circular(headR * 0.12)),
        Paint()..color = Color.lerp(jersey, Colors.black, 0.25)!,
      );
    }
  }

  void _dashedCircle(Canvas c, Offset at, double r, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    const dashes = 14;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * math.pi / dashes;
      c.drawArc(Rect.fromCircle(center: at, radius: r), a, math.pi / dashes,
          false, p);
    }
  }

  void _plus(Canvas c, Offset at, double r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    c.drawLine(at - Offset(r, 0), at + Offset(r, 0), p);
    c.drawLine(at - Offset(0, r), at + Offset(0, r), p);
  }

  // ── Illustrations ──

  void _matches(Canvas c, double s) {
    _stumps(c, Offset(s * 0.42, s * 0.80), s);
    // Ball bounces on the pitch in front of the stumps.
    final bounce = math.sin(t.value * math.pi).abs();
    final ground = s * 0.765;
    final y = ground - bounce * s * 0.34;
    final x = s * 0.68;
    _shadow(c, Offset(x, s * 0.80), s * (0.13 - bounce * 0.05),
        0.18 - bounce * 0.1);
    _cricketBall(c, Offset(x, y), s * 0.055, spin: t.value * 2 * math.pi);
  }

  void _groups(Canvas c, double s) {
    final bob = _wave * s * 0.02;
    _player(c, Offset(s * 0.28, s * 0.79 - bob), s, AppColors.scoreBlueLight,
        scale: 0.85);
    _player(c, Offset(s * 0.72, s * 0.79 - (s * 0.02 - bob)), s,
        AppColors.accent,
        scale: 0.85);
    _player(c, Offset(s * 0.5, s * 0.80), s, AppColors.primary, scale: 1.05);
    // Sparkle badge
    final badge = Offset(s * 0.74, s * 0.27);
    c.drawCircle(badge, s * 0.065,
        Paint()..color = AppColors.primaryLight.withValues(alpha: 0.9));
    _plus(c, badge, s * 0.03, Colors.white);
  }

  void _members(Canvas c, double s) {
    final pulse = 0.85 + _wave * 0.15;
    for (final x in [s * 0.22, s * 0.78]) {
      final at = Offset(x, s * 0.58);
      _dashedCircle(c, at, s * 0.1,
          AppColors.primary.withValues(alpha: 0.25 + _wave * 0.25));
      _plus(c, at, s * 0.035 * pulse, AppColors.primary.withValues(alpha: 0.6));
    }
    _player(c, Offset(s * 0.5, s * 0.80), s, AppColors.primary, scale: 1.1);
  }

  void _stats(Canvas c, double s) {
    final base = s * 0.80;
    final w = s * 0.17;
    final blocks = [
      (x: s * 0.33, h: s * 0.17, color: AppColors.scoreBlueLight, label: '2'),
      (x: s * 0.50, h: s * 0.26, color: AppColors.primary, label: '1'),
      (x: s * 0.67, h: s * 0.11, color: AppColors.accent, label: '3'),
    ];
    for (final b in blocks) {
      final rect = Rect.fromLTWH(b.x - w / 2, base - b.h, w, b.h);
      c.drawRRect(
        RRect.fromRectAndCorners(rect,
            topLeft: Radius.circular(s * 0.025),
            topRight: Radius.circular(s * 0.025)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [b.color, b.color.withValues(alpha: 0.7)],
          ).createShader(rect),
      );
      final tp = TextPainter(
        text: TextSpan(
            text: b.label,
            style: TextStyle(
                color: Colors.white,
                fontSize: s * 0.075,
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(b.x - tp.width / 2, base - b.h + s * 0.02));
    }
    // Trophy floats above the empty top step.
    final float = _wave * s * 0.035;
    _trophy(c, Offset(s * 0.5, base - s * 0.30 - float), s * 0.15);
    // Twinkles
    final tw = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.4 + _wave * 0.6);
    c.drawCircle(Offset(s * 0.30, s * 0.30), s * 0.012, tw);
    c.drawCircle(Offset(s * 0.71, s * 0.24), s * 0.016, tw);
  }

  void _trophy(Canvas c, Offset bottom, double h) {
    final w = h * 0.9;
    final cupTop = bottom.dy - h;
    final rect = Rect.fromLTWH(bottom.dx - w / 2, cupTop, w, h);
    final gold = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    // Handles
    final handle = Paint()
      ..color = const Color(0xFFE6A417)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.08;
    c.drawArc(
        Rect.fromCircle(
            center: Offset(bottom.dx - w * 0.38, cupTop + h * 0.22),
            radius: h * 0.15),
        math.pi * 0.5,
        math.pi,
        false,
        handle);
    c.drawArc(
        Rect.fromCircle(
            center: Offset(bottom.dx + w * 0.38, cupTop + h * 0.22),
            radius: h * 0.15),
        -math.pi * 0.5,
        math.pi,
        false,
        handle);
    // Cup
    c.drawPath(
      Path()
        ..moveTo(bottom.dx - w * 0.38, cupTop)
        ..lineTo(bottom.dx + w * 0.38, cupTop)
        ..quadraticBezierTo(bottom.dx + w * 0.36, cupTop + h * 0.55,
            bottom.dx + w * 0.06, cupTop + h * 0.62)
        ..lineTo(bottom.dx - w * 0.06, cupTop + h * 0.62)
        ..quadraticBezierTo(
            bottom.dx - w * 0.36, cupTop + h * 0.55, bottom.dx - w * 0.38, cupTop)
        ..close(),
      gold,
    );
    // Stem + base
    c.drawRect(
        Rect.fromLTWH(bottom.dx - w * 0.06, cupTop + h * 0.6, w * 0.12, h * 0.2),
        gold);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bottom.dx - w * 0.26, cupTop + h * 0.8, w * 0.52,
                h * 0.2),
            Radius.circular(h * 0.04)),
        Paint()..color = const Color(0xFFB45309));
    // Shine
    c.drawLine(
        Offset(bottom.dx - w * 0.2, cupTop + h * 0.1),
        Offset(bottom.dx - w * 0.14, cupTop + h * 0.4),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = h * 0.05
          ..strokeCap = StrokeCap.round);
  }

  void _batting(Canvas c, double s) {
    // Ball waits in front of the bat.
    final ballAt = Offset(s * 0.70, s * 0.70);
    _shadow(c, Offset(ballAt.dx, s * 0.80), s * 0.1, 0.14);
    _cricketBall(c, ballAt, s * 0.05);

    // Bat swings gently around the handle grip.
    final pivot = Offset(s * 0.36, s * 0.24);
    final angle = -0.45 + _wave * 0.35;
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(angle);
    final handle = RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * 0.025, 0, s * 0.05, s * 0.18),
        Radius.circular(s * 0.02));
    c.drawRRect(handle, Paint()..color = const Color(0xFF1F2937));
    // Grip stripes
    final grip = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = s * 0.012;
    for (var i = 1; i < 5; i++) {
      final y = i * s * 0.035;
      c.drawLine(Offset(-s * 0.025, y), Offset(s * 0.025, y), grip);
    }
    final blade = RRect.fromRectAndCorners(
      Rect.fromLTWH(-s * 0.06, s * 0.17, s * 0.12, s * 0.38),
      topLeft: Radius.circular(s * 0.03),
      topRight: Radius.circular(s * 0.03),
      bottomLeft: Radius.circular(s * 0.05),
      bottomRight: Radius.circular(s * 0.05),
    );
    c.drawRRect(
        blade,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF3D19C), _wood],
          ).createShader(blade.outerRect));
    c.drawRRect(
        blade,
        Paint()
          ..color = _woodDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.008);
    c.restore();

    // Motion arcs
    final arc = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12 + _wave * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      c.drawArc(Rect.fromCircle(center: pivot, radius: s * (0.5 + i * 0.07)),
          0.55, 0.45, false, arc);
    }
  }

  void _bowling(Canvas c, double s) {
    _stumps(c, Offset(s * 0.72, s * 0.80), s, scale: 0.8);
    // Ball drifts toward the stumps, spinning.
    final x = s * 0.30 + _wave * s * 0.08;
    final at = Offset(x, s * 0.46);
    final trail = Paint()
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      trail.color = AppColors.danger.withValues(alpha: 0.25 - i * 0.07);
      final y = at.dy + (i - 1) * s * 0.04;
      c.drawLine(Offset(at.dx - s * (0.1 + i * 0.03), y),
          Offset(at.dx - s * (0.2 + i * 0.03), y), trail);
    }
    _shadow(c, Offset(x, s * 0.80), s * 0.1, 0.1);
    _cricketBall(c, at, s * 0.075, spin: t.value * 2 * math.pi);
  }

  void _offline(Canvas c, double s) {
    _stumps(c, Offset(s * 0.5, s * 0.80), s, scale: 0.75);
    // Covers over the pitch.
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(s / 2, s * 0.80),
              width: s * 0.44,
              height: s * 0.06),
          Radius.circular(s * 0.03)),
      Paint()..color = AppColors.scoreBlueLight.withValues(alpha: 0.55),
    );

    // Rain drops fall from the cloud on a loop.
    final drop = Paint()
      ..color = AppColors.info.withValues(alpha: 0.55)
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final phase = (t.value + i * 0.21) % 1.0;
      final x = s * (0.33 + i * 0.085);
      final y = s * 0.36 + phase * s * 0.28;
      drop.color = AppColors.info.withValues(alpha: 0.55 * (1 - phase));
      c.drawLine(Offset(x, y), Offset(x - s * 0.012, y + s * 0.045), drop);
    }

    // Cloud
    final drift = (_wave - 0.5) * s * 0.03;
    final cloud = Paint()..color = const Color(0xFF94A3B8);
    final cx = s * 0.5 + drift;
    final cy = s * 0.30;
    c.drawCircle(Offset(cx - s * 0.12, cy + s * 0.02), s * 0.08, cloud);
    c.drawCircle(Offset(cx, cy - s * 0.03), s * 0.11, cloud);
    c.drawCircle(Offset(cx + s * 0.12, cy + s * 0.02), s * 0.08, cloud);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - s * 0.2, cy + s * 0.01, s * 0.4, s * 0.09),
            Radius.circular(s * 0.045)),
        cloud);
  }

  @override
  bool shouldRepaint(_EmptyArtPainter old) => old.art != art;
}
