/// Shared leaderboard widgets used by both LeaderboardScreen and
/// the embedded leaderboard inside GroupDetailScreen.
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardTopThreePodium
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardTopThreePodium extends StatefulWidget {
  final List<PlayerStats> top3;
  final int tabIndex;

  const LeaderboardTopThreePodium(this.top3, this.tabIndex, {super.key});

  @override
  State<LeaderboardTopThreePodium> createState() =>
      _LeaderboardTopThreePodiumState();
}

class _LeaderboardTopThreePodiumState extends State<LeaderboardTopThreePodium>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _heightAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _heightAnimations = List.generate(3, (i) {
      final double start = i * 0.15;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, start + 0.4, curve: Curves.easeOutBack),
      );
    });

    _opacityAnimations = List.generate(3, (i) {
      final double start = i * 0.15;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, start + 0.2, curve: Curves.easeIn),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.top3.isEmpty) return const SizedBox.shrink();
    // Display order: 2nd place (left), 1st place (centre), 3rd place (right)
    const List<int> order = [1, 0, 2];

    Widget podiumItem(int i) {
      if (i >= widget.top3.length) return const Expanded(child: SizedBox());
      final p = widget.top3[i];
      final rank = i + 1;
      final double baseHeight = rank == 1 ? 140 : rank == 2 ? 100 : 80;
      final color = rank == 1
          ? const Color(0xFFF59E0B)
          : rank == 2
              ? const Color(0xFF94A3B8)
              : const Color(0xFFD97706);
      final deepColor = rank == 1
          ? const Color(0xFFD97706)
          : rank == 2
              ? const Color(0xFF64748B)
              : const Color(0xFFB45309);
      return Expanded(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (ctx, child) => Opacity(
            opacity: _opacityAnimations[i].value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _heightAnimations[i].value)),
              child: _buildStep(
                  p, rank, baseHeight * _heightAnimations[i].value, color, deepColor),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          podiumItem(order[0]),
          const SizedBox(width: 12),
          podiumItem(order[1]),
          const SizedBox(width: 12),
          podiumItem(order[2]),
        ],
      ),
    );
  }

  Widget _buildStep(PlayerStats p, int rank, double height, Color color,
      Color deepColor) {
    final score = widget.tabIndex == 0
        ? p.battingRankScore
        : widget.tabIndex == 1
            ? p.bowlingRankScore
            : p.impactRankScore;
    final isFirst = rank == 1;

    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: isFirst ? 68 : 56,
            height: isFirst ? 68 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4))
              ],
              border: Border.all(color: color, width: isFirst ? 2.5 : 2),
            ),
            alignment: Alignment.center,
            child: Text(p.name[0].toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontSize: isFirst ? 28 : 22)),
          ),
          if (isFirst)
            Positioned(
              top: -18,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [color, deepColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Text(p.name,
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
              color: AppColors.textPrimary),
          overflow: TextOverflow.ellipsis,
          maxLines: 1),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10)),
        child: Text((score ?? 0).toStringAsFixed(1),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      ),
      const SizedBox(height: 16),
      Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.02),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Stack(alignment: Alignment.topCenter, children: [
          Positioned(
            top: 10,
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: color.withValues(alpha: 0.2),
                    height: 1)),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardRankCard
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardRankCard extends StatefulWidget {
  final PlayerStats stats;
  final int tabIndex; // 0 Batting · 1 Bowling · 2 Impact
  final int? rank;
  final double? score;
  final double? prevScore;

  const LeaderboardRankCard({
    super.key,
    required this.stats,
    required this.tabIndex,
    required this.rank,
    required this.score,
    required this.prevScore,
  });

  @override
  State<LeaderboardRankCard> createState() => _LeaderboardRankCardState();
}

class _LeaderboardRankCardState extends State<LeaderboardRankCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final bool noData = widget.score == null;

    final isTop3 = widget.rank != null && widget.rank! <= 3;
    final rankColor = widget.rank == 1
        ? const Color(0xFFF59E0B)
        : widget.rank == 2
            ? const Color(0xFF94A3B8)
            : widget.rank == 3
                ? const Color(0xFFD97706)
                : AppColors.textMuted;

    IconData trendIcon = Icons.remove;
    Color trendColor = AppColors.textMuted;
    if (widget.score != null && widget.prevScore != null) {
      if (widget.score! > widget.prevScore!) {
        trendIcon = Icons.arrow_upward;
        trendColor = AppColors.success;
      } else if (widget.score! < widget.prevScore!) {
        trendIcon = Icons.arrow_downward;
        trendColor = AppColors.danger;
      }
    } else if (widget.score != null && widget.prevScore == null) {
      trendIcon = Icons.arrow_upward;
      trendColor = AppColors.success;
    }

    return TapBounce(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: noData ? AppColors.bg : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTop3
                  ? rankColor.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.5),
              width: isTop3 ? 1.5 : 1,
            ),
            boxShadow: noData
                ? null
                : [
                    BoxShadow(
                        color: isTop3
                            ? rankColor.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: noData
                        ? const Icon(Icons.lock_outline,
                            size: 16, color: AppColors.textMuted)
                        : Text('#${widget.rank}',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: rankColor,
                                fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: noData
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(s.role.name.toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.6),
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                  if (noData)
                    const Text('NOT ENOUGH DATA',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted))
                  else ...[
                    if (widget.tabIndex == 0)
                      _miniStat('R', '${s.runs}')
                    else if (widget.tabIndex == 1)
                      _miniStat('W', '${s.wickets}', AppColors.danger)
                    else ...[
                      _miniStat('R', '${s.runs}'),
                      _miniStat('W', '${s.wickets}', AppColors.danger),
                    ],
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: trendColor.withValues(alpha: 0.15)),
                      child:
                          Icon(trendIcon, size: 12, color: trendColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTop3
                            ? rankColor.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isTop3
                                ? rankColor.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(widget.score!.toStringAsFixed(1),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isTop3 ? rankColor : AppColors.primary)),
                    ),
                  ],
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                if (widget.tabIndex == 0)
                  _battingDetails(s)
                else if (widget.tabIndex == 1)
                  _bowlingDetails(s)
                else
                  _impactDetails(s),
                if (noData) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Play more matches to earn a rank score.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _battingDetails(PlayerStats s) => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _detailItem('INNS', '${s.inningsBatted}'),
          _detailItem('RUNS', '${s.runs}'),
          _detailItem('AVG', s.average.toStringAsFixed(1)),
          _detailItem('SR', s.strikeRate.toStringAsFixed(1)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _detailItem('50s', '${s.fifties}'),
          _detailItem('4s', '${s.fours}'),
          _detailItem('6s', '${s.sixes}'),
          _detailItem('BND %', '${s.boundaryPercent.toStringAsFixed(0)}%'),
        ]),
      ]);

  Widget _bowlingDetails(PlayerStats s) {
    final overs = '${s.ballsBowled ~/ 6}.${s.ballsBowled % 6}';
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _detailItem('MAT', '${s.matchesBowled}'),
        _detailItem('WKTS', '${s.wickets}'),
        _detailItem('ECO', s.economy.toStringAsFixed(1)),
        _detailItem('W/M', s.wicketsPerMatch.toStringAsFixed(1)),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _detailItem('OVERS', overs),
        _detailItem('RUNS', '${s.runsConceded}'),
        _detailItem('DOT %', '${s.dotBallPercent.toStringAsFixed(0)}%'),
      ]),
    ]);
  }

  Widget _impactDetails(PlayerStats s) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _detailItem(
            'BAT RNK', s.battingRankScore?.toStringAsFixed(1) ?? '-'),
        _detailItem(
            'BOWL RNK', s.bowlingRankScore?.toStringAsFixed(1) ?? '-'),
        _detailItem('FLD PTS', '${s.fieldingBonus}'),
      ]);

  Widget _detailItem(String label, String val) => Column(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      ]);

  Widget _miniStat(String label, String val, [Color? color]) {
    final c = color ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: c.withValues(alpha: 0.7),
                fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(val,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: c)),
      ]),
    );
  }
}
