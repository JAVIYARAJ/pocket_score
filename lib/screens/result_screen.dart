import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/score_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/scorecard_widget.dart';

import '../main.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  late Animation<double> _fade;
  late ScoreState _savedState; // Save before reset

  @override
  void initState() {
    super.initState();
    _savedState = context.read<ScoreBloc>().state;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _ctrl.forward();
    _finalize();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _finalize() {
    final first = _savedState.firstInnings;
    final second = _savedState.secondInnings;
    if (first == null || second == null) return;

    String result;
    if (second.totalRuns > first.totalRuns) {
      final w = _savedState.battingLineup.length - 1 - second.totalWickets;
      result = '${second.battingTeamName} won by $w wicket${w != 1 ? "s" : ""}!';
    } else if (second.totalRuns < first.totalRuns) {
      result = '${first.battingTeamName} won by ${first.totalRuns - second.totalRuns} runs!';
    } else {
      result = "It's a TIE!";
    }

    final matchId = context.read<MatchBloc>().state.matchId;
    if (matchId != null) {
      final ml = context.read<MatchListBloc>().state.matches;
      final ex = ml.where((m) => m.id == matchId).firstOrNull;
      if (ex != null && ex.status != 'completed') {
        final matchState = context.read<MatchBloc>().state;
        // Save with full score data for scorecard viewing later
        final scoreJson = _savedState.copyWith(history: const []).toJson();
        context.read<MatchListBloc>().add(UpdateMatchInList(ex.copyWith(
          status: 'completed', result: result,
          teamAScore: first.totalRuns, teamAWickets: first.totalWickets, teamAOvers: first.overDisplay,
          teamBScore: second.totalRuns, teamBWickets: second.totalWickets, teamBOvers: second.overDisplay,
          scoreData: scoreJson,
          teamA: matchState.teamA,
          teamB: matchState.teamB,
        )));
      }
    }
  }

  void _goHome() {
    context.read<MatchBloc>().add(ResetMatch());
    context.read<ScoreBloc>().add(ResetScoreboard());
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AppEntryPoint()), (r) => false);
  }

  void _viewScorecard() {
    ScorecardView.showAsBottomSheet(context, _savedState);
  }

  @override
  Widget build(BuildContext context) {
    final first = _savedState.firstInnings;
    final second = _savedState.secondInnings;
    if (first == null || second == null) {
      return Scaffold(body: Center(child: ElevatedButton(onPressed: _goHome, child: const Text('Go Home'))));
    }

    String winnerText;
    bool isTie = false;
    if (second.totalRuns > first.totalRuns) {
      final w = _savedState.battingLineup.length - 1 - second.totalWickets;
      winnerText = '${second.battingTeamName} won by $w wicket${w != 1 ? "s" : ""}!';
    } else if (second.totalRuns < first.totalRuns) {
      winnerText = '${first.battingTeamName} won by ${first.totalRuns - second.totalRuns} runs!';
    } else {
      winnerText = "It's a TIE!";
      isTie = true;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Trophy
              ScaleEntrance(
                delay: const Duration(milliseconds: 200),
                startScale: 0.0,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isTie ? AppColors.scoreGradient : AppColors.successGradient,
                    boxShadow: [BoxShadow(color: (isTie ? AppColors.primary : AppColors.success).withValues(alpha: 0.3), blurRadius: 40)],
                  ),
                  child: const Icon(Icons.emoji_events, size: 64, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),

              FadeInEntrance(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    const Text('MATCH FINISHED', style: TextStyle(fontSize: 14, letterSpacing: 2, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(winnerText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.2)),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Score comparison
              FadeInEntrance(
                delay: const Duration(milliseconds: 500),
                offset: const Offset(0, 30),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.glassCard(opacity: 0.06),
                  child: Row(
                    children: [
                      Expanded(child: _scoreCol(first.battingTeamName, first.totalRuns, first.totalWickets, first.overDisplay)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                        child: const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 12)),
                      ),
                      Expanded(child: _scoreCol(second.battingTeamName, second.totalRuns, second.totalWickets, second.overDisplay)),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // View Scorecard button
              FadeTransition(
                opacity: _fade,
                child: OutlinedButton.icon(
                  onPressed: _viewScorecard,
                  icon: const Icon(Icons.assessment, size: 18),
                  label: const Text('View Full Scorecard', style: TextStyle(fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Home button
              FadeTransition(
                opacity: _fade,
                child: ElevatedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home, size: 18),
                  label: const Text('Back to Home', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreCol(String team, int runs, int wickets, String overs) {
    return Column(
      children: [
        Text(team, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text('$runs/$wickets', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text('($overs ov)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
