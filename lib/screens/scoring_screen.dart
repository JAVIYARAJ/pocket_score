import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/score_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../models/ball_model.dart';
import '../models/innings_model.dart';
import '../models/player_model.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/scorecard_widget.dart';
import 'result_screen.dart';
import 'opening_selection_screen.dart';

class ScoringScreen extends StatelessWidget {
  const ScoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScoreBloc, ScoreState>(
      listener: (context, state) {
        _updateMatchList(context, state);
        
        if (state.currentInnings != null) {
          final innings = state.currentInnings!;
          bool victoryReached = !state.isFirstInnings && innings.totalRuns >= (state.firstInnings?.totalRuns ?? 0) + 1;
          bool oversCompleted = innings.legalBallsCount >= (context.read<MatchBloc>().state.settings?.totalOvers ?? 0) * 6;
          bool allOut = state.isLastManStanding 
              ? (state.outPlayerIds.length + state.retiredHurtIds.length) >= state.battingLineup.length
              : (state.outPlayerIds.length + state.retiredHurtIds.length) >= state.battingLineup.length - 1;

          if (victoryReached || oversCompleted || allOut) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (state.isFirstInnings) {
                if (!state.pendingBowlerChange || oversCompleted || allOut) {
                  _showInningsBreak(context, state);
                }
              } else {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultScreen()));
              }
            });
          }
        }
      },
      child: BlocBuilder<ScoreBloc, ScoreState>(
        builder: (context, state) {
          if (state.firstInnings == null || state.currentInnings == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return _ScoringView(state: state);
        },
      ),
    );
  }

  static void _updateMatchList(BuildContext context, ScoreState state) {
    final matchState = context.read<MatchBloc>().state;
    if (matchState.matchId == null) return;

    final first = state.firstInnings;
    final second = state.secondInnings;

    final bool isDone = second != null && (
      second.totalRuns > (first?.totalRuns ?? 0) || 
      second.legalBallsCount >= (matchState.settings?.totalOvers ?? 0) * 6 ||
      ((state.outPlayerIds.length + state.retiredHurtIds.length) >= (state.isLastManStanding ? state.battingLineup.length : state.battingLineup.length - 1))
    );

    final String teamAName = matchState.settings?.teamAName ?? '';
    final String teamBName = matchState.settings?.teamBName ?? '';

    int? teamAScore, teamAWickets, teamBScore, teamBWickets;
    String? teamAOvers, teamBOvers;

    if (first != null) {
      if (first.battingTeamName == teamAName) {
        teamAScore = first.totalRuns; teamAWickets = first.totalWickets; teamAOvers = first.overDisplay;
      } else {
        teamBScore = first.totalRuns; teamBWickets = first.totalWickets; teamBOvers = first.overDisplay;
      }
    }
    if (second != null) {
      if (second.battingTeamName == teamAName) {
        teamAScore = second.totalRuns; teamAWickets = second.totalWickets; teamAOvers = second.overDisplay;
      } else {
        teamBScore = second.totalRuns; teamBWickets = second.totalWickets; teamBOvers = second.overDisplay;
      }
    }

    context.read<MatchListBloc>().add(UpdateMatchInList(MatchSummary(
      id: matchState.matchId!,
      teamAName: teamAName,
      teamBName: teamBName,
      teamA: matchState.teamA,
      teamB: matchState.teamB,
      totalOvers: matchState.settings?.totalOvers ?? 0,
      status: isDone ? 'completed' : 'in_progress',
      createdAt: DateTime.now(), 
      teamAScore: teamAScore,
      teamAWickets: teamAWickets,
      teamAOvers: teamAOvers,
      teamBScore: teamBScore,
      teamBWickets: teamBWickets,
      teamBOvers: teamBOvers,
      scoreData: state.toJson(),
      result: isDone
          ? (second!.totalRuns > first!.totalRuns 
              ? '${second.battingTeamName} won' 
              : (first.totalRuns > second.totalRuns 
                  ? '${first.battingTeamName} won' 
                  : 'Match Tied'))
          : null,
    )));
  }

  static void _showInningsBreak(BuildContext context, ScoreState state) {
    final matchSettings = context.read<MatchBloc>().state.settings;
    final secondTeamName = matchSettings?.teamBName ?? 'Chasing Team';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Innings Completed'),
        content: Text('First innings finished at ${state.firstInnings?.totalRuns}/${state.firstInnings?.totalWickets}.\n\nTarget for $secondTeamName: ${(state.firstInnings?.totalRuns ?? 0) + 1}'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final matchState = context.read<MatchBloc>().state;
              final teamA = matchState.teamA!;
              final teamB = matchState.teamB!;
              final firstInningsBattingTeam = state.firstInnings!.battingTeamName;
              final isTeamABattedFirst = firstInningsBattingTeam == teamA.name;
              
              Navigator.push(context, MaterialPageRoute(builder: (_) => OpeningSelectionScreen(
                battingTeamName: isTeamABattedFirst ? teamB.name : teamA.name,
                battingPlayers: isTeamABattedFirst ? teamB.players : teamA.players,
                bowlingPlayers: isTeamABattedFirst ? teamA.players : teamB.players,
                target: (state.firstInnings?.totalRuns ?? 0) + 1,
              )));
            },
            child: const Text('Start Second Innings'),
          ),
        ],
      ),
    );
  }

  static void _discardMatch(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Match?'),
        content: const Text('This will permanently delete the current match and all its progress. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final matchId = context.read<MatchBloc>().state.matchId;
              if (matchId != null) {
                context.read<MatchListBloc>().add(RemoveMatchFromList(matchId));
              }
              context.read<MatchBloc>().add(ResetMatch());
              context.read<ScoreBloc>().add(ResetScoreboard());
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _showScorecard(BuildContext context, ScoreState state) {
    ScorecardView.showAsBottomSheet(context, state);
  }

  // ─── MINIMALIST HEADER ───
  static Widget _buildHeaderInternal(BuildContext context, ScoreState state) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 16, right: 16, bottom: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _updateMatchList(context, state);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.05)),
          ),
          const Spacer(),
          Column(
            children: [
              Text(state.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.textMuted)),
              Text(state.currentInnings!.battingTeamName.toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const Spacer(),
          if (state.history.isNotEmpty)
            IconButton(
              onPressed: () => context.read<ScoreBloc>().add(UndoBall()),
              icon: const Icon(Icons.undo_rounded, color: AppColors.warning, size: 20),
              style: IconButton.styleFrom(backgroundColor: AppColors.warning.withValues(alpha: 0.1)),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _discardMatch(context),
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 20),
            style: IconButton.styleFrom(backgroundColor: AppColors.danger.withValues(alpha: 0.1)),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showScorecard(context, state),
            icon: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  // ─── MODERN SCOREBOARD ───
  static Widget _buildMainScoreInternal(BuildContext context, ScoreState state) {
    final inn = state.currentInnings!;
    final totalOvers = context.read<MatchBloc>().state.settings?.totalOvers ?? 1;
    final totalBalls = totalOvers * 6;
    final remBalls = totalBalls - inn.legalBallsCount;
    final crr = inn.runRate;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: AppDecorations.gradientCard(AppColors.scoreGradient),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RUNS', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCounter(
                        value: inn.totalRuns,
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
                      ),
                      Text(' / ${inn.totalWickets}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('OVERS', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text(inn.overDisplay, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                  Text('$remBalls BALLS LEFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (state.isFreeHit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                  child: const Text('FREE HIT', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('CRR', crr.toStringAsFixed(2)),
              if (state.isFirstInnings) ...[
                Builder(builder: (_) {
                  final proj = (inn.legalBallsCount > 0) ? (inn.totalRuns / inn.legalBallsCount) * totalBalls : 0.0;
                  return _statItem('PROJECTED', proj.round().toString());
                }),
              ] else ...[
                Builder(builder: (_) {
                  final target = (state.firstInnings?.totalRuns ?? 0) + 1;
                  final need = target - inn.totalRuns;
                  final rrr = (remBalls > 0) ? (need / (remBalls / 6)) : 0.0;
                  return Row(
                    children: [
                      _statItem('NEED', '$need'),
                      const SizedBox(width: 24),
                      _statItem('RRR', rrr.toStringAsFixed(2)),
                    ],
                  );
                }),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── PLAYER STATUS ───
  static Widget _buildPlayerStatusInternal(BuildContext context, ScoreState state) {
    final inn = state.currentInnings!;
    final batStats = inn.batsmanStats;
    final bowlStats = inn.bowlerStatsMap;

    Player? striker, nonStriker, bowler;
    try { striker = state.battingLineup.firstWhere((p) => p.id == state.strikerId); } catch (_) {}
    try { nonStriker = state.battingLineup.firstWhere((p) => p.id == state.nonStrikerId); } catch (_) {}
    try { bowler = state.bowlingLineup.firstWhere((p) => p.id == state.bowlerId); } catch (_) {}

    final sS = batStats[state.strikerId];
    final nsS = batStats[state.nonStrikerId];
    final bS = bowlStats[state.bowlerId];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: AppDecorations.glassCard(opacity: 0.04),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _modernBatTile(context, striker?.name ?? '—', sS, true, state.strikerId)),
                if (!state.isLastManStanding) ...[
                  Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.05)),
                  Expanded(child: _modernBatTile(context, nonStriker?.name ?? '—', nsS, false, state.nonStrikerId)),
                ],
              ],
            ),
          ),
          if (state.isLastManStanding)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: const Text('LAST MAN STANDING', style: TextStyle(color: AppColors.warning, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          if (bowler != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sports_baseball_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(bowler.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  _bowlStat('O', bS?.oversBowled ?? '0.0'),
                  _bowlStat('R', '${bS?.runsConceded ?? 0}'),
                  _bowlStat('W', '${bS?.wickets ?? 0}'),
                  _bowlStat('E', bS?.economy.toStringAsFixed(1) ?? '0.0'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _modernBatTile(BuildContext context, String name, BatsmanStats? s, bool isStriker, String playerId) {
    final bloc = context.read<ScoreBloc>();
    final state = bloc.state;
    
    return GestureDetector(
      onTap: () {
        if (playerId.isEmpty) {
          _showPlayerPicker(context, bloc, state, isStriker);
        } else if (!state.isLastManStanding && state.strikerId.isNotEmpty && state.nonStrikerId.isNotEmpty) {
          bloc.add(SwapStriker());
        }
      },
      child: Container(
        color: Colors.transparent, // For hit testing
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: isStriker ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: isStriker ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                if (isStriker && playerId.isNotEmpty) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                Flexible(child: Text(name, style: TextStyle(fontWeight: isStriker ? FontWeight.bold : FontWeight.w500, fontSize: 13, color: isStriker ? Colors.white : AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                if (playerId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showRetireBottomSheet(context, bloc, state, playerId),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.exit_to_app_rounded, size: 12, color: AppColors.textMuted),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.add_circle_outline_rounded, size: 12, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: isStriker ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Text('${s?.runs ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                Text(' (${s?.ballsFaced ?? 0})', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bowlStat(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          const SizedBox(width: 3),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── RECENT BALLS ───
  static Widget _buildRecentBallsInternal(ScoreState state) {
    final inn = state.currentInnings!;
    final balls = inn.balls;
    final currentOverBalls = <Ball>[];
    int count = 0;
    for (int i = balls.length - 1; i >= 0; i--) {
      currentOverBalls.insert(0, balls[i]);
      if (balls[i].isLegalBall) count++;
      if (count >= 6) break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('THIS OVER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
            Spacer(),
            Icon(Icons.history_rounded, size: 12, color: AppColors.textMuted),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: currentOverBalls.isEmpty 
              ? [const Center(child: Text('WAITING FOR FIRST BALL...', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)))]
              : currentOverBalls.map((b) => _ballCircle(b)).toList(),
          ),
        ),
      ],
    );
  }

  static Widget _buildOverHistoryInternal(ScoreState state) {
    final summaries = state.currentInnings?.overSummaries ?? [];
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Row(
          children: [
            Text('OVER HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
            Spacer(),
            Icon(Icons.bar_chart_rounded, size: 12, color: AppColors.textMuted),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: summaries.length,
            itemBuilder: (context, i) {
              final ov = summaries[i];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: AppDecorations.glassCard(opacity: 0.05).copyWith(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('OV ${ov.overNumber}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 1),
                    Text('${ov.runs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryLight)),
                    if (ov.wickets > 0)
                      Text('${ov.wickets} WKT', style: const TextStyle(fontSize: 8, color: AppColors.wicket, fontWeight: FontWeight.w900)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget _ballCircle(Ball b) {
    String label; Color bg;
    if (b.isWicket) { label = 'W'; bg = AppColors.wicket; }
    else if (b.type == BallType.wide) { label = 'WD'; bg = AppColors.wide; }
    else if (b.type == BallType.noBall) { label = 'NB'; bg = AppColors.noBall; }
    else if (b.runs == 4) { label = '4'; bg = AppColors.four; }
    else if (b.runs == 6) { label = '6'; bg = AppColors.six; }
    else { label = '${b.runs}'; bg = b.runs == 0 ? AppColors.surfaceLight : AppColors.primary; }

    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: bg.withValues(alpha: 0.3), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: bg == AppColors.surfaceLight ? AppColors.textSecondary : bg)),
    );
  }

  // ─── ACTION PANEL ───
  static Widget _buildActionPanelInternal(BuildContext context, ScoreState state) {
    if (state.pendingBowlerChange) {
      return _buildBowlerPicker(context, state);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Run Row
          Row(
            children: [
              _actionBtn(context, '0', 0, BallType.normal, Colors.white10),
              _actionBtn(context, '1', 1, BallType.normal, Colors.white10),
              _actionBtn(context, '2', 2, BallType.normal, Colors.white10),
              _actionBtn(context, '3', 3, BallType.normal, Colors.white10),
              _actionBtn(context, '4', 4, BallType.normal, AppColors.four.withValues(alpha: 0.2), textColor: AppColors.four),
              _actionBtn(context, '6', 6, BallType.normal, AppColors.six.withValues(alpha: 0.2), textColor: AppColors.six),
            ],
          ),
          const SizedBox(height: 12),
          // Extras Row
          Row(
            children: [
              _actionBtn(context, 'WD', 0, BallType.wide, AppColors.wide.withValues(alpha: 0.1), textColor: AppColors.wide, extra: 1),
              _actionBtn(context, 'NB', 0, BallType.noBall, AppColors.noBall.withValues(alpha: 0.1), textColor: AppColors.noBall, extra: 1),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _handleBall(context, 0, BallType.wicket, 0),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.wicket,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.wicket.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: const Text('WICKET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _actionBtn(BuildContext context, String label, int runs, BallType type, Color bg, {Color? textColor, int extra = 0}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => _handleBall(context, runs, type, extra),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor ?? AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }

  static Widget _buildBowlerPicker(BuildContext context, ScoreState state) {
    final bowlers = state.bowlingLineup.where((p) => p.id != state.bowlerId).toList();
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('OVER COMPLETED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.warning, letterSpacing: 2)),
          const SizedBox(height: 4),
          const Text('Select Next Bowler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: bowlers.length,
              itemBuilder: (context, i) {
                final p = bowlers[i];
                return GestureDetector(
                  onTap: () => context.read<ScoreBloc>().add(ChangeBowler(p.id)),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: AppDecorations.glassCard(opacity: 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(radius: 20, backgroundColor: AppColors.warning.withValues(alpha: 0.2), child: Text(p.name[0], style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOGIC ───
  static void _handleBall(BuildContext context, int runs, BallType type, int extra) {
    final state = context.read<ScoreBloc>().state;
    if (type == BallType.wicket) { 
        _showWicketDialog(context, state); 
    } else { 
        context.read<ScoreBloc>().add(RecordBall(runs: runs, type: type, extraRuns: extra)); 
    }
  }

  static void _showWicketDialog(BuildContext ctx, ScoreState state) {
    final bloc = ctx.read<ScoreBloc>();
    final rem = state.battingLineup.where((p) => 
      !state.outPlayerIds.contains(p.id) && 
      p.id != state.strikerId && 
      p.id != state.nonStrikerId
    ).toSet().toList();
    final retired = state.retiredHurtIds.where((id) => !state.outPlayerIds.contains(id) && id != state.strikerId && id != state.nonStrikerId).toList();
    final available = (rem + retired.map((id) => state.battingLineup.firstWhere((p) => p.id == id)).toList()).toSet().toList();
    
    String? selectedWicketType;
    String? playerOutId; 
    int runsOnBall = 0;
    String? fielderId;
    String? nextBatsmanId;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isRunOut = selectedWicketType == 'RUN OUT';
          bool needsFielder = ['CAUGHT', 'STUMPED', 'RUN OUT'].contains(selectedWicketType);
          
          playerOutId ??= state.strikerId;

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(c).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.all(Radius.circular(2))))),
                const SizedBox(height: 24),
                
                if (selectedWicketType == null) ...[
                  const Text('WICKET FALLEN! 🎯', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const Text('Select wicket type to continue', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  Builder(builder: (context) {
                    final isRestricted = state.isFreeHit;
                    final types = isRestricted ? ['RUN OUT'] : ['BOWLED', 'CAUGHT', 'LBW', 'STUMPED', 'RUN OUT', 'OTHERS'];
                    
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: types.map((type) => GestureDetector(
                        onTap: () => setModalState(() => selectedWicketType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: AppDecorations.glassCard(opacity: 0.1).copyWith(
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.primaryLight)),
                        ),
                      )).toList(),
                    );
                  }),
                  if (state.isFreeHit)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('Only Run Out is possible on a Free Hit', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ] else if (needsFielder && fielderId == null) ...[
                   Text(selectedWicketType == 'RUN OUT' ? 'FIELDER INVOLVED' : 'WHO TOOK THE CATCH?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                   const SizedBox(height: 16),
                   SizedBox(
                     height: 100,
                     child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                       itemCount: state.bowlingLineup.length,
                       itemBuilder: (context, i) {
                         final p = state.bowlingLineup[i];
                         return GestureDetector(
                           onTap: () => setModalState(() => fielderId = p.id),
                           child: Container(
                             width: 80, margin: const EdgeInsets.only(right: 12),
                             decoration: AppDecorations.glassCard(opacity: 0.05),
                             child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                               CircleAvatar(radius: 18, backgroundColor: AppColors.surfaceLight, child: Text(p.name[0])),
                               const SizedBox(height: 8),
                               Text(p.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                             ]),
                           ),
                         );
                       },
                     ),
                   ),
                   const SizedBox(height: 20),
                   TextButton(onPressed: () => setModalState(() => fielderId = state.bowlerId), child: const Text('BY BOWLER')),
                ] else if (isRunOut && (nextBatsmanId == null && available.isNotEmpty)) ...[
                   const Text('RUN OUT DETAILS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                   const SizedBox(height: 16),
                   const Text('WHO IS OUT?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                        _outPlayerSelect(state.battingLineup.firstWhere((p) => p.id == state.strikerId).name, state.strikerId, playerOutId, (id) => setModalState(() => playerOutId = id)),
                        const SizedBox(width: 12),
                        _outPlayerSelect(state.battingLineup.firstWhere((p) => p.id == state.nonStrikerId).name, state.nonStrikerId, playerOutId, (id) => setModalState(() => playerOutId = id)),
                     ],
                   ),
                   const SizedBox(height: 20),
                   const Text('RUNS COMPLETED?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                   const SizedBox(height: 8),
                   Row(
                     children: [0, 1, 2, 3].map((r) => GestureDetector(
                       onTap: () => setModalState(() => runsOnBall = r),
                       child: Container(
                         width: 50, height: 50, margin: const EdgeInsets.only(right: 12),
                         decoration: BoxDecoration(color: runsOnBall == r ? AppColors.primary : Colors.white10, shape: BoxShape.circle),
                         alignment: Alignment.center,
                         child: Text('$r', style: const TextStyle(fontWeight: FontWeight.bold)),
                       ),
                     )).toList(),
                   ),
                   const SizedBox(height: 30),
                   if (available.isNotEmpty) ...[
                     const Text('NEXT BATSMAN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 12),
                     SizedBox(
                       height: 80,
                       child: ListView.builder(
                         scrollDirection: Axis.horizontal,
                         itemCount: available.length,
                         itemBuilder: (context, i) {
                           final p = available[i];
                           return GestureDetector(
                             onTap: () => setModalState(() => nextBatsmanId = p.id),
                             child: Container(
                               width: 120, margin: const EdgeInsets.only(right: 12),
                               decoration: AppDecorations.glassCard(opacity: 0.05),
                               alignment: Alignment.center,
                               child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                             ),
                           );
                         },
                       ),
                     ),
                   ] else ...[
                     ElevatedButton(onPressed: () => setModalState(() => nextBatsmanId = 'none'), child: const Text('NO MORE BATSMEN')),
                   ],
                ] else if (nextBatsmanId == null && available.isNotEmpty) ...[
                   const Text('NEXT BATSMAN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                   const SizedBox(height: 16),
                   SizedBox(
                     height: 120,
                     child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                       itemCount: available.length,
                       itemBuilder: (context, i) {
                         final p = available[i];
                         return GestureDetector(
                           onTap: () => setModalState(() => nextBatsmanId = p.id),
                           child: Container(
                             width: 100, margin: const EdgeInsets.only(right: 12),
                             decoration: AppDecorations.glassCard(opacity: 0.05),
                             child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                               CircleAvatar(radius: 24, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(p.name[0])),
                               const SizedBox(height: 8),
                               Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                               Text(p.role.name.toUpperCase(), style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
                             ]),
                           ),
                         );
                       },
                     ),
                   ),
                ] else ...[
                   const Text('CONFIRM WICKET', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                   const SizedBox(height: 12),
                   Text('Type: $selectedWicketType', style: const TextStyle(color: AppColors.textSecondary)),
                   if (nextBatsmanId != null && nextBatsmanId != 'none' && available.any((p) => p.id == nextBatsmanId)) 
                      Text('Next: ${available.firstWhere((p) => p.id == nextBatsmanId).name}', style: const TextStyle(color: AppColors.primaryLight)),
                   const SizedBox(height: 30),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: () {
                         bloc.add(RecordBall(
                           runs: runsOnBall,
                           type: BallType.wicket,
                           isWicket: true,
                           wicketType: selectedWicketType,
                           outPlayerId: playerOutId,
                           fielderId: fielderId,
                           nextBatsmanId: nextBatsmanId == 'none' ? null : nextBatsmanId,
                         ));
                         Navigator.pop(ctx);
                       },
                       style: ElevatedButton.styleFrom(backgroundColor: AppColors.wicket, padding: const EdgeInsets.symmetric(vertical: 16)),
                       child: const Text('RECORD WICKET', style: TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static void _showRetireBottomSheet(BuildContext context, ScoreBloc bloc, ScoreState state, String playerId) {
    final rem = state.battingLineup.where((p) => 
      !state.outPlayerIds.contains(p.id) && 
      !state.retiredHurtIds.contains(p.id) &&
      p.id != state.strikerId && 
      p.id != state.nonStrikerId
    ).toList();
    
    String? nextPlayerId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) {
          final playerName = state.battingLineup.firstWhere((p) => p.id == playerId).name;
          
          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(c).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.all(Radius.circular(2))))),
                const SizedBox(height: 24),
                Text('Retire $playerName? ⚠️', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('Mark player as Retired Hurt and bring in a replacement.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                
                const SizedBox(height: 32),
                if (rem.isNotEmpty) ...[
                  const Text('SELECT REPLACEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: rem.length,
                      itemBuilder: (ctx, i) {
                        final p = rem[i];
                        bool isSel = nextPlayerId == p.id;
                        return GestureDetector(
                          onTap: () => setModalState(() => nextPlayerId = p.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 90, margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSel ? AppColors.primary : Colors.white10),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              CircleAvatar(
                                radius: 18, 
                                backgroundColor: isSel ? AppColors.primary : AppColors.surfaceLight,
                                child: Text(p.name[0], style: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 8),
                              Text(p.name, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                     child: const Row(
                       children: [
                         Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                         SizedBox(width: 12),
                         Expanded(child: Text('No more batsmen available. Innings will proceed as Last Man Standing.', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold))),
                       ],
                     ),
                   ),
                ],
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      bloc.add(RetirePlayer(playerId: playerId, nextBatsmanId: nextPlayerId));
                      Navigator.pop(c);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('CONFIRM RETIREMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _showPlayerPicker(BuildContext context, ScoreBloc bloc, ScoreState state, bool isStriker) {
    final rem = state.battingLineup.where((p) => 
      !state.outPlayerIds.contains(p.id) && 
      !state.retiredHurtIds.contains(p.id) &&
      p.id != state.strikerId && 
      p.id != state.nonStrikerId
    ).toSet().toList();
    final retired = state.retiredHurtIds.where((id) => !state.outPlayerIds.contains(id) && id != state.strikerId && id != state.nonStrikerId).toList();
    final available = (rem + retired.map((id) => state.battingLineup.firstWhere((p) => p.id == id)).toList()).toSet().toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No more batsmen available!')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.all(Radius.circular(2))))),
            const SizedBox(height: 24),
            Text('Select ${isStriker ? "Striker" : "Non-Striker"}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.8),
                itemCount: available.length,
                itemBuilder: (context, i) {
                  final p = available[i];
                  bool wasRetired = state.retiredHurtIds.contains(p.id);
                  return GestureDetector(
                    onTap: () {
                      bloc.add(SelectNextBatsman(playerId: p.id, isStriker: isStriker));
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: AppDecorations.glassCard(opacity: 0.05).copyWith(
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 20, 
                            backgroundColor: wasRetired ? Colors.orange.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                            child: Text(p.name[0], style: TextStyle(color: wasRetired ? Colors.orange : AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                          if (wasRetired) const Text('RE-ENTRY', style: TextStyle(fontSize: 7, color: Colors.orange, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _outPlayerSelect(String name, String id, String? current, Function(String) onSelect) {
    bool isSel = id == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? AppColors.primary : Colors.white10),
          ),
          child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? AppColors.primaryLight : AppColors.textPrimary)),
        ),
      ),
    );
  }
}

class _ScoringView extends StatefulWidget {
  final ScoreState state;
  const _ScoringView({required this.state});

  @override
  State<_ScoringView> createState() => _ScoringViewState();
}

class _ScoringViewState extends State<_ScoringView> {
  String? _celebrationText;
  Color? _celebrationColor;

  @override
  void initState() {
    super.initState();
    // Initial sync to ensure home screen shows live data immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScoringScreen._updateMatchList(context, widget.state);
    });
  }

  @override
  void didUpdateWidget(_ScoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newState = widget.state;
    final oldState = oldWidget.state;

    // Detect NEW BALL events
    final newBalls = newState.currentInnings?.balls ?? [];
    final oldBalls = oldState.currentInnings?.balls ?? [];

    if (newBalls.length > oldBalls.length) {
      final lastBall = newBalls.last;
      
      // 1. Check for player milestones (50 runs)
      _checkMilestones(oldState, newState);

      // 2. Check for standard ball celebrations
      if (lastBall.isWicket) {
        _triggerCelebration('OUT!', AppColors.wicket);
      } else if (lastBall.runs == 6) {
        _triggerCelebration('SIX!', AppColors.six);
      } else if (lastBall.runs == 4) {
        _triggerCelebration('FOUR!', AppColors.four);
      }
    }
  }

  void _checkMilestones(ScoreState oldState, ScoreState newState) {
    final newStrikerId = newState.strikerId;

    if (newStrikerId.isEmpty) return;

    final oldStats = oldState.currentInnings?.batsmanStats[newStrikerId];
    final newStats = newState.currentInnings?.batsmanStats[newStrikerId];

    if (oldStats != null && newStats != null) {
      if (oldStats.runs < 50 && newStats.runs >= 50) {
        _triggerCelebration('HALF CENTURY!', AppColors.warning);
      }
    }
  }

  void _triggerCelebration(String text, Color color) {
    setState(() {
      _celebrationText = text;
      _celebrationColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              FadeInEntrance(
                offset: const Offset(0, -20),
                child: _ScoringBodyHeader(state: state),
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: FadeInEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _ScoringBodyMainScore(state: state),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeInEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: _ScoringBodyPlayerStatus(state: state),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          FadeInEntrance(
                            delay: const Duration(milliseconds: 300),
                            child: _ScoringBodyRecentBalls(state: state),
                          ),
                          FadeInEntrance(
                            delay: const Duration(milliseconds: 400),
                            child: _ScoringBodyOverHistory(state: state),
                          ),
                        ]),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
              FadeInEntrance(
                offset: const Offset(0, 50),
                delay: const Duration(milliseconds: 500),
                child: _ScoringBodyActionPanel(state: state),
              ),
            ],
          ),
          if (_celebrationText != null)
            ScoreCelebration(
              text: _celebrationText!,
              color: _celebrationColor!,
              onFinish: () => setState(() => _celebrationText = null),
            ),
        ],
      ),
    );
  }
}

class _ScoringBodyHeader extends StatelessWidget {
  final ScoreState state;
  const _ScoringBodyHeader({required this.state});
  @override
  Widget build(BuildContext context) { return ScoringScreen._buildHeaderInternal(context, state); }
}

class _ScoringBodyMainScore extends StatelessWidget {
  final ScoreState state;
  const _ScoringBodyMainScore({required this.state});
  @override
  Widget build(BuildContext context) { return ScoringScreen._buildMainScoreInternal(context, state); }
}

class _ScoringBodyPlayerStatus extends StatelessWidget {
  final ScoreState state;
  const _ScoringBodyPlayerStatus({required this.state});
  @override
  Widget build(BuildContext context) { return ScoringScreen._buildPlayerStatusInternal(context, state); }
}

class _ScoringBodyRecentBalls extends StatelessWidget {
  final ScoreState state;
  const _ScoringBodyRecentBalls({required this.state});
  @override
  Widget build(BuildContext context) { return ScoringScreen._buildRecentBallsInternal(state); }
}

class _ScoringBodyOverHistory extends StatelessWidget {
  final ScoreState state;
  const _ScoringBodyOverHistory({required this.state});
  @override
  Widget build(BuildContext context) { return ScoringScreen._buildOverHistoryInternal(state); }
}

class _ScoringBodyActionPanel extends StatelessWidget {
  final ScoreState state;
  const _ScoringBodyActionPanel({required this.state});
  @override
  Widget build(BuildContext context) { return ScoringScreen._buildActionPanelInternal(context, state); }
}
