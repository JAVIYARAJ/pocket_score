import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeletons with a shimmer sweep.
//
// Wrap skeleton shapes ([SkeletonBox], [SkeletonCircle], or the ready-made
// skeletons below) in one [Shimmer] — a single light band then sweeps across
// all of them together. Shapes should match the real content's layout so the
// screen doesn't jump when data arrives.
// ─────────────────────────────────────────────────────────────────────────────
class Shimmer extends StatefulWidget {
  final Widget child;
  /// Light (default) for skeletons on the app's pale background; dark for
  /// skeletons on green/navy headers.
  final bool dark;
  const Shimmer({super.key, required this.child, this.dark = false});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE6EAF0);
    final glow = widget.dark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFFF7F9FC);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // Band travels from off-screen left to off-screen right, diagonally.
        final t = _c.value * 2.6 - 0.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.0 + t * 2 - 0.6, -0.4),
            end: Alignment(-1.0 + t * 2 + 0.6, 0.4),
            colors: [base, glow, base],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A rounded placeholder block. Inside a [Shimmer] its colour is replaced by
/// the shimmer gradient, so any opaque colour works here.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EAF0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFFE6EAF0), shape: BoxShape.circle),
    );
  }
}

/// White card frame the skeletons sit in (not shimmered itself).
class _Frame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const _Frame({required this.child, this.padding = const EdgeInsets.all(14), this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Shimmer(child: child),
    );
  }
}

// ── Ready-made skeletons ─────────────────────────────────────────────────────

/// Match history card: status strip, two team scores, result line.
class MatchCardSkeleton extends StatelessWidget {
  const MatchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Frame(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SkeletonBox(width: 80, height: 12),
          SizedBox(width: 10),
          SkeletonBox(width: 70, height: 18, radius: 10),
          Spacer(),
          SkeletonBox(width: 50, height: 12),
        ]),
        SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 90, height: 13),
              SizedBox(height: 8),
              SkeletonBox(width: 70, height: 24),
            ]),
          ),
          SkeletonCircle(size: 32),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              SkeletonBox(width: 90, height: 13),
              SizedBox(height: 8),
              SkeletonBox(width: 70, height: 24),
            ]),
          ),
        ]),
        SizedBox(height: 16),
        SkeletonBox(height: 34, radius: 10),
      ]),
    );
  }
}

/// Group list card: avatar tile, name, meta line.
class GroupCardSkeleton extends StatelessWidget {
  const GroupCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Frame(
      child: Row(children: [
        SkeletonBox(width: 50, height: 50, radius: 14),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 150, height: 15),
            SizedBox(height: 8),
            SkeletonBox(width: 100, height: 11),
          ]),
        ),
        SkeletonBox(width: 22, height: 22, radius: 11),
      ]),
    );
  }
}

/// Generic row: avatar, two lines, optional trailing pill.
class ListTileSkeleton extends StatelessWidget {
  final bool trailing;
  const ListTileSkeleton({super.key, this.trailing = true});

  @override
  Widget build(BuildContext context) {
    return _Frame(
      child: Row(children: [
        const SkeletonCircle(size: 44),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 130, height: 14),
            SizedBox(height: 7),
            SkeletonBox(width: 80, height: 10),
          ]),
        ),
        if (trailing) const SkeletonBox(width: 58, height: 24, radius: 12),
      ]),
    );
  }
}

/// Leaderboard: tab bar, podium card and a few rank rows.
class LeaderboardSkeleton extends StatelessWidget {
  final int rows;
  const LeaderboardSkeleton({super.key, this.rows = 3});

  @override
  Widget build(BuildContext context) {
    Widget spot(double avatar, double block) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SkeletonCircle(size: avatar),
            const SizedBox(height: 8),
            const SkeletonBox(width: 60, height: 11),
            const SizedBox(height: 6),
            const SkeletonBox(width: 40, height: 14),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SkeletonBox(height: block, radius: 10),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Frame(padding: EdgeInsets.all(4), radius: 16, child: SkeletonBox(height: 38, radius: 12)),
      const SizedBox(height: 14),
      _Frame(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        radius: 24,
        child: Column(children: [
          const Row(children: [
            SkeletonBox(width: 96, height: 22, radius: 11),
            Spacer(),
            SkeletonBox(width: 110, height: 13),
          ]),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            spot(46, 38),
            spot(58, 52),
            spot(46, 28),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      for (var i = 0; i < rows; i++) ...[
        const ListTileSkeleton(),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

/// Live score screen: scoreboard block, batters, this-over strip.
class ScoreboardSkeleton extends StatelessWidget {
  const ScoreboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: const [
      _Frame(
        radius: 24,
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonBox(width: 80, height: 11),
          SizedBox(height: 12),
          Row(children: [
            SkeletonBox(width: 120, height: 48),
            Spacer(),
            SkeletonBox(width: 60, height: 36),
          ]),
          SizedBox(height: 20),
          Row(children: [
            SkeletonBox(width: 70, height: 26),
            Spacer(),
            SkeletonBox(width: 70, height: 26),
          ]),
        ]),
      ),
      SizedBox(height: 12),
      _Frame(
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 80, height: 13), SizedBox(height: 8), SkeletonBox(width: 50, height: 24),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SkeletonBox(width: 80, height: 13), SizedBox(height: 8), SkeletonBox(width: 50, height: 24),
          ])),
        ]),
      ),
      SizedBox(height: 12),
      _Frame(
        child: Row(children: [
          SkeletonCircle(size: 30), SizedBox(width: 8),
          SkeletonCircle(size: 30), SizedBox(width: 8),
          SkeletonCircle(size: 30), SizedBox(width: 8),
          SkeletonCircle(size: 30),
        ]),
      ),
    ]);
  }
}

/// A padded column of [count] copies of [item], for list screens.
class SkeletonList extends StatelessWidget {
  final int count;
  final Widget item;
  final EdgeInsetsGeometry padding;
  final double gap;
  const SkeletonList({
    super.key,
    required this.item,
    this.count = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 20),
    this.gap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: gap),
      itemBuilder: (_, __) => item,
    );
  }
}
