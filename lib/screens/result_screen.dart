import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'pdf_preview_screen.dart';
import '../bloc/score_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../models/innings_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/match_pdf_generator.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slideUp;
  late ScoreState _savedState;
  String _resultString = '';

  @override
  void initState() {
    super.initState();
    _savedState = context.read<ScoreBloc>().state;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade   = CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut));
    _slideUp = CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _finalize();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _finalize() {
    final first  = _savedState.firstInnings;
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

    // Override result if super over was played
    final soFirst  = _savedState.superOverFirstInnings;
    final soSecond = _savedState.superOverSecondInnings;
    if (soFirst != null && soSecond != null) {
      if (soSecond.totalRuns > soFirst.totalRuns) {
        result = '${soSecond.battingTeamName} won the Super Over!';
      } else if (soSecond.totalRuns < soFirst.totalRuns) {
        result = '${soFirst.battingTeamName} won the Super Over!';
      } else {
        result = "Super Over Tied!";
      }
    }

    _resultString = result;

    final matchId = context.read<MatchBloc>().state.matchId;
    if (matchId != null) {
      final ml = context.read<MatchListBloc>().state.matches;
      final ex = ml.where((m) => m.id == matchId).firstOrNull;
      if (ex != null) {
        final matchState = context.read<MatchBloc>().state;
        final scoreJson  = _savedState.copyWith(history: const []).toJson();
        final String teamAName = ex.teamAName;
        int? teamAScore, teamAWickets, teamBScore, teamBWickets;
        String? teamAOvers, teamBOvers;

        if (first.battingTeamName == teamAName) {
          teamAScore = first.totalRuns;  teamAWickets = first.totalWickets;  teamAOvers = first.overDisplay;
          teamBScore = second.totalRuns; teamBWickets = second.totalWickets; teamBOvers = second.overDisplay;
        } else {
          teamBScore = first.totalRuns;  teamBWickets = first.totalWickets;  teamBOvers = first.overDisplay;
          teamAScore = second.totalRuns; teamAWickets = second.totalWickets; teamAOvers = second.overDisplay;
        }

        context.read<MatchListBloc>().add(UpdateMatchInList(ex.copyWith(
          status: 'completed', result: result,
          teamAScore: teamAScore, teamAWickets: teamAWickets, teamAOvers: teamAOvers,
          teamBScore: teamBScore, teamBWickets: teamBWickets, teamBOvers: teamBOvers,
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
    context.go('/home');
  }

  void _viewScorecard() {
    context.push('/scorecard', extra: {
      'state': _savedState,
      'overs': context.read<MatchBloc>().state.settings?.totalOvers ?? 0,
    });
  }

  void _startSuperOver() {
    final ms    = context.read<MatchBloc>().state;
    final teamA = ms.teamA!;
    final teamB = ms.teamB!;
    // First innings batting team bats first in super over
    final firstBatted = _savedState.firstInnings!.battingTeamName;
    final battingTeam  = firstBatted == teamA.name ? teamA : teamB;
    final bowlingTeam  = firstBatted == teamA.name ? teamB : teamA;
    context.push('/match/super-over/opening', extra: {
      'battingTeam': battingTeam,
      'bowlingTeam': bowlingTeam,
      'target'     : 0,
    });
  }

  void _openPdfPreview() {
    final ms    = context.read<MatchBloc>().state;
    final overs = ms.settings?.totalOvers ?? 0;
    final id    = ms.matchId ?? 'score';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          buildPdf : () => generateMatchResultPdf(_savedState, _resultString, DateTime.now(), overs),
          filename : 'match_result_$id.pdf',
          title    : _resultString,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first  = _savedState.firstInnings;
    final second = _savedState.secondInnings;
    if (first == null || second == null) {
      return Scaffold(
        body: Center(child: ElevatedButton(onPressed: _goHome, child: const Text('Go Home'))),
      );
    }

    final soFirst  = _savedState.superOverFirstInnings;
    final soSecond = _savedState.superOverSecondInnings;
    final hasSuperOver = soFirst != null && soSecond != null;

    // Build result strings — regular innings
    String winnerTeam;
    String winnerSubtext;
    bool isTie = false;
    if (second.totalRuns > first.totalRuns) {
      final w = _savedState.battingLineup.length - 1 - second.totalWickets;
      winnerTeam    = second.battingTeamName;
      winnerSubtext = 'won by $w wicket${w != 1 ? "s" : ""}';
    } else if (second.totalRuns < first.totalRuns) {
      winnerTeam    = first.battingTeamName;
      winnerSubtext = 'won by ${first.totalRuns - second.totalRuns} runs';
    } else {
      winnerTeam    = 'TIE';
      winnerSubtext = 'Both teams level!';
      isTie = true;
    }

    // Override display strings if super over was played
    if (hasSuperOver) {
      if (soSecond.totalRuns > soFirst.totalRuns) {
        winnerTeam    = soSecond.battingTeamName;
        winnerSubtext = 'won the Super Over!';
        isTie         = false;
      } else if (soSecond.totalRuns < soFirst.totalRuns) {
        winnerTeam    = soFirst.battingTeamName;
        winnerSubtext = 'won the Super Over!';
        isTie         = false;
      } else {
        winnerTeam    = 'TIE';
        winnerSubtext = 'Super Over tied too!';
        isTie         = true;
      }
    }

    final isTiedBeforeSuperOver = (second.totalRuns == first.totalRuns) && !hasSuperOver;

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
          // ── Gradient Header ──────────────────────────────────────
          _ResultHeader(
            ctrl         : _ctrl,
            winnerTeam   : winnerTeam,
            winnerSubtext: winnerSubtext,
            isTie        : isTie,
            hasSuperOver : hasSuperOver,
          ),
          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: AnimatedBuilder(
              animation: _slideUp,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, 24 * (1 - _slideUp.value)),
                child: Opacity(opacity: _slideUp.value.clamp(0.0, 1.0), child: child),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  children: [
                    // Regular innings score comparison
                    _ScoreCard(first: first, second: second),

                    // Super over scores (shown only after SO completed)
                    if (hasSuperOver) ...[
                      const SizedBox(height: 16),
                      _SuperOverScoreCard(soFirst: soFirst, soSecond: soSecond),
                    ],

                    const SizedBox(height: 32),

                    // Start Super Over button (only when tied, before SO)
                    if (isTiedBeforeSuperOver) ...[
                      FadeTransition(
                        opacity: _fade,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF92400E), Color(0xFFD97706)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _startSuperOver,
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: const Text('Play Super Over'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Share as PDF button
                    FadeTransition(
                      opacity: _fade,
                      child: OutlinedButton.icon(
                        onPressed: _openPdfPreview,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('Share as PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scorecard button
                    FadeTransition(
                      opacity: _fade,
                      child: OutlinedButton.icon(
                        onPressed: _viewScorecard,
                        icon: const Icon(Icons.bar_chart_rounded, size: 18),
                        label: const Text('View Full Scorecard'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Home button (gradient)
                    FadeTransition(
                      opacity: _fade,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _goHome,
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: const Text('Back to Home'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ), // Scaffold
    );   // AnnotatedRegion
  }
}

// ── Gradient result header ─────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  final AnimationController ctrl;
  final String winnerTeam;
  final String winnerSubtext;
  final bool isTie;
  final bool hasSuperOver;

  const _ResultHeader({
    required this.ctrl,
    required this.winnerTeam,
    required this.winnerSubtext,
    required this.isTie,
    this.hasSuperOver = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 40),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Trophy / tie icon
          ScaleEntrance(
            delay: const Duration(milliseconds: 50),
            startScale: 0.0,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isTie ? AppColors.scoreGradient : AppColors.goldGradient,
                boxShadow: [BoxShadow(
                  color: (isTie ? AppColors.scoreBlue : AppColors.accent).withValues(alpha: 0.55),
                  blurRadius: 28,
                  spreadRadius: 4,
                )],
              ),
              child: Icon(
                hasSuperOver
                    ? (isTie ? Icons.handshake_rounded : Icons.bolt_rounded)
                    : (isTie ? Icons.handshake_rounded : Icons.emoji_events_rounded),
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Text content
          FadeInEntrance(
            delay: const Duration(milliseconds: 200),
            child: Column(
              children: [
                const Text(
                  'MATCH RESULT',
                  style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white60, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  isTie ? "It's a Tie!" : winnerTeam,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    isTie ? 'Both teams level!' : winnerSubtext,
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Innings score comparison card ─────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final Innings first;
  final Innings second;

  const _ScoreCard({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'INNINGS SUMMARY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score row
          Row(
            children: [
              Expanded(child: _scoreCol(first.battingTeamName, first.totalRuns, first.totalWickets, first.overDisplay)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('VS', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
                ),
              ),
              Expanded(child: _scoreCol(second.battingTeamName, second.totalRuns, second.totalWickets, second.overDisplay)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreCol(String team, int runs, int wickets, String overs) {
    return Column(
      children: [
        Text(
          team,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          '$runs/$wickets',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1),
        ),
        Text('($overs ov)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

// ── Super Over score card ─────────────────────────────────────────
class _SuperOverScoreCard extends StatelessWidget {
  final Innings soFirst;
  final Innings soSecond;

  const _SuperOverScoreCard({required this.soFirst, required this.soSecond});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF92400E), Color(0xFFD97706)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.bolt_rounded, size: 13, color: AppColors.accent),
              const SizedBox(width: 4),
              const Text('SUPER OVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _soScoreCol(soFirst.battingTeamName, soFirst.totalRuns, soFirst.totalWickets, soFirst.overDisplay)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
                  child: const Text('VS', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
                ),
              ),
              Expanded(child: _soScoreCol(soSecond.battingTeamName, soSecond.totalRuns, soSecond.totalWickets, soSecond.overDisplay)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _soScoreCol(String team, int runs, int wickets, String overs) {
    return Column(
      children: [
        Text(team, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text('$runs/$wickets', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: -1)),
        Text('($overs ov)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
