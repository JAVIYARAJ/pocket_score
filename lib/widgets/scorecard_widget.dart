import 'package:flutter/material.dart';
import '../bloc/score_bloc.dart';
import '../models/ball_model.dart';
import '../models/innings_model.dart';
import '../theme/app_theme.dart';
import '../utils/stats_utils.dart';

/// Reusable scorecard widget that can be used in both ScoringScreen and ResultScreen.
class ScorecardView extends StatelessWidget {
  final ScoreState state;
  final ScrollController? scrollController;
  final bool isFullScreen;

  const ScorecardView({
    super.key,
    required this.state,
    this.scrollController,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isFullScreen ? 16 : 24,
        vertical: isFullScreen ? 16 : 24,
      ),
      children: [
        if (!isFullScreen) ...[
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text('SCORECARD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 24),
        ],
        _buildMoMSection(state),
        if (state.firstInnings != null) _inningsSection(context, state.firstInnings!, isFirst: true),
        if (state.secondInnings != null) ...[
          const SizedBox(height: 24),
          _inningsSection(context, state.secondInnings!, isFirst: false),
        ],
        const SizedBox(height: 24),
        // Extras summary
        if (state.firstInnings != null) _extrasSummary(state.firstInnings!),
        if (state.secondInnings != null) ...[
          const SizedBox(height: 12),
          _extrasSummary(state.secondInnings!),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _inningsSection(BuildContext context, Innings inn, {required bool isFirst}) {
    final bats = inn.batsmanStats;
    final bowls = inn.bowlerStatsMap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: AppColors.scoreGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(inn.battingTeamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Text('${inn.totalRuns}/${inn.totalWickets}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  const SizedBox(width: 6),
                  Text('(${inn.overDisplay} ov)', style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),

        // Run Rate bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.card,
          child: Row(
            children: [
              _statBadge('RR', inn.runRate.toStringAsFixed(2), AppColors.primary),
              const SizedBox(width: 8),
              _statBadge('Extras', '${inn.balls.fold<int>(0, (s, b) => s + b.extraRuns)}', AppColors.warning),
              if (inn.target > 0) ...[
                const SizedBox(width: 8),
                _statBadge('Target', '${inn.target}', AppColors.danger),
              ],
            ],
          ),
        ),

        // Batting table
        Container(
          decoration: const BoxDecoration(color: AppColors.card),
          child: Column(
            children: [
              _headerRow(['Batsman', 'R', 'B', '4s', '6s', 'SR'], flexes: [5, 1, 1, 1, 1, 2]),
              ...bats.entries.map((e) {
                final name = _findName(inn, e.key);
                final s = e.value;
                return _batRow(inn, name, s);
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bowling header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.sports_baseball, size: 14, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Bowling', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),

        // Bowling table
        Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Column(
            children: [
              _headerRow(['Bowler', 'O', 'R', 'W', 'Eco', 'Ext'], flexes: [5, 2, 1, 1, 2, 3]),
              ...bowls.entries.map((e) {
                final name = _findName(inn, e.key);
                final s = e.value;
                return _dataRow(
                  [name, s.oversBowled, '${s.runsConceded}', '${s.wickets}', s.economy.toStringAsFixed(1), '${s.wides}wd ${s.noBalls}nb'],
                  flexes: [5, 2, 1, 1, 2, 3],
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Overs Summary header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.history, size: 14, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Overs Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),

        // Overs Summary table
        Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Column(
            children: [
              _headerRow(['Over', 'Runs', 'Wkts', 'Total'], flexes: [3, 1, 1, 1]),
              ...inn.overSummaries.asMap().entries.map((entry) {
                final i = entry.key;
                final ov = entry.value;
                int cumulativeRuns = 0;
                int cumulativeWickets = 0;
                for (int j = 0; j <= i; j++) {
                  cumulativeRuns += inn.overSummaries[j].runs;
                  cumulativeWickets += inn.overSummaries[j].wickets;
                }
                return _dataRow([
                  'Over ${ov.overNumber}',
                  '${ov.runs}',
                  '${ov.wickets}',
                  '$cumulativeRuns/$cumulativeWickets',
                ], flexes: [3, 1, 1, 1]);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _batRow(Innings inn, String name, BatsmanStats s) {
    bool isNotOut = !s.isOut;
    final otherVals = ['${s.runs}', '${s.ballsFaced}', '${s.fours}', '${s.sixes}', s.strikeRate.toStringAsFixed(1)];
    final otherFlexes = [1, 1, 1, 1, 2];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNotOut ? AppColors.accent.withValues(alpha: 0.04) : null,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isNotOut ? "* " : ""}$name',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isNotOut ? AppColors.accent : AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getDismissalInfo(inn, s),
                  style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500),
                  maxLines: 2,
                  softWrap: true,
                ),
              ],
            ),
          ),
          ...List.generate(otherVals.length, (index) {
            return Expanded(
              flex: otherFlexes[index],
              child: Text(
                otherVals[index],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getDismissalInfo(Innings inn, BatsmanStats s) {
    if (!s.isOut) return 'not out';
    final type = s.wicketType ?? 'out';
    final fName = s.outFielderId != null ? _findName(inn, s.outFielderId!) : 'fielder';
    final bName = s.outBowlerId != null ? _findName(inn, s.outBowlerId!) : 'bowler';

    switch (type) {
      case 'BOWLED': return 'b $bName';
      case 'CAUGHT': return 'c $fName b $bName';
      case 'LBW': return 'lbw b $bName';
      case 'STUMPED': return 'st $fName b $bName';
      case 'RUN OUT': return 'run out ($fName)';
      default: return type.toLowerCase();
    }
  }

  String _findName(Innings inn, String id) {
    try {
      final p = inn.battingPlayers.firstWhere((p) => p.id == id);
      return p.isGuest ? '${p.name} (Guest)' : p.name;
    } catch (_) {}
    try {
      final p = inn.bowlingPlayers.firstWhere((p) => p.id == id);
      return p.isGuest ? '${p.name} (Guest)' : p.name;
    } catch (_) {
      return '—';
    }
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _headerRow(List<String> labels, {List<int>? flexes}) {
    final defaultFlex = List.generate(labels.length, (i) => i == 0 ? 3 : 1);
    final activeFlexes = flexes ?? defaultFlex;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(color: AppColors.surfaceLight),
      child: Row(
        children: labels.asMap().entries.map((e) => Expanded(
          flex: activeFlexes[e.key],
          child: Text(e.value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
        )).toList(),
      ),
    );
  }

  Widget _dataRow(List<String> values, {bool highlight = false, List<int>? flexes}) {
    final defaultFlex = List.generate(values.length, (i) => i == 0 ? 3 : 1);
    final activeFlexes = flexes ?? defaultFlex;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accent.withValues(alpha: 0.04) : null,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: values.asMap().entries.map((e) => Expanded(
          flex: activeFlexes[e.key],
          child: Text(
            e.value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: e.key == 0 || e.key == 1 ? FontWeight.w600 : FontWeight.normal,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
      ),
    );
  }

  Widget _extrasSummary(Innings inn) {
    final totalExtras = inn.balls.fold<int>(0, (s, b) => s + b.extraRuns);
    final wides = inn.balls.where((b) => b.type == BallType.wide).length;
    final noBalls = inn.balls.where((b) => b.type == BallType.noBall).length;
    if (totalExtras == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.glassCard(opacity: 0.04),
      child: Row(
        children: [
          Text('${inn.battingTeamName} Extras: ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text('$totalExtras', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${wides}wd  ${noBalls}nb', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildMoMSection(ScoreState state) {
    // Only show if the match is essentially finished (at least one innings completed)
    if (state.firstInnings == null || state.firstInnings!.balls.isEmpty) return const SizedBox.shrink();
    
    final mom = calculateMoMFromState(state);
    if (mom == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PLAYER OF THE MATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white70)),
                Text(mom.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show as bottom sheet from any screen
  static void showAsBottomSheet(BuildContext context, ScoreState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => ScorecardView(state: state, scrollController: sc),
      ),
    );
  }
}
