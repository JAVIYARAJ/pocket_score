import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../widgets/scorecard_widget.dart';
import 'player_screen.dart';
import 'match_setup_screen.dart';
import 'scoring_screen.dart';
import '../utils/stats_utils.dart';
import '../bloc/player_bloc.dart';
import '../models/player_model.dart';
import '../theme/animations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── HERO HEADER ───
          SliverToBoxAdapter(
            child: BlurInEntrance(
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 24, bottom: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pocket Score', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5)),
                            SizedBox(height: 4),
                            Text('Box Cricket Scoring', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                          ],
                        ),
                        Row(
                          children: [
                            _iconBtn(context, Icons.insights_rounded, 'Leaderboard', () => _showStatsSheet(context)),
                            const SizedBox(width: 12),
                            _iconBtn(context, Icons.people_outline, 'Players', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
                            }),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Live Match / New Match Section
                    BlocBuilder<MatchListBloc, MatchListState>(
                      builder: (context, state) {
                        final liveMatch = state.matches.cast<MatchSummary?>().firstWhere((m) => m?.status == 'in_progress', orElse: () => null);
                        
                        if (liveMatch != null) {
                          return _LiveMatchHero(match: liveMatch);
                        }

                        return ScaleEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: () {
                              context.read<MatchBloc>().add(ResetMatch());
                              context.read<ScoreBloc>().add(ResetScoreboard());
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchSetupScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: AppDecorations.gradientCard(AppColors.primaryGradient),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('New Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                        SizedBox(height: 2),
                                        Text('Start a new cricket match', style: TextStyle(fontSize: 13, color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
  
                    // Latest Result Section (only if no live match or just show below)
                    BlocBuilder<MatchListBloc, MatchListState>(
                      builder: (context, state) {
                        final completed = state.matches.where((m) => m.status == 'completed').toList();
                        if (completed.isEmpty) return const SizedBox.shrink();
                        final last = completed.first;
                        return FadeInEntrance(
                          delay: const Duration(milliseconds: 400),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: GestureDetector(
                              onTap: () {
                                if (last.scoreData != null) {
                                  try {
                                    final scoreState = ScoreState.fromJson(last.scoreData!);
                                    ScorecardView.showAsBottomSheet(context, scoreState);
                                  } catch (_) {}
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: AppDecorations.glassCard(opacity: 0.08),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.history, size: 14, color: AppColors.accent),
                                        const SizedBox(width: 6),
                                        const Text('LATEST RESULT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _heroTeamScore(last.teamAName, last.teamAScore, last.teamAWickets, CrossAxisAlignment.start),
                                        const Text('VS', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w900)),
                                        _heroTeamScore(last.teamBName, last.teamBScore, last.teamBWickets, CrossAxisAlignment.end),
                                      ],
                                    ),
                                    if (last.result != null) ...[
                                      const SizedBox(height: 12),
                                      Text(last.result!, style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── MATCH HISTORY LIST ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                children: [
                  const Text('Match History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const Spacer(),
                  BlocBuilder<MatchListBloc, MatchListState>(
                    builder: (_, state) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${state.matches.length} Matches', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          BlocBuilder<MatchListBloc, MatchListState>(
            builder: (context, state) {
              if (state.matches.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
                          child: Icon(Icons.sports_cricket, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                        ),
                        const SizedBox(height: 20),
                        const Text('No matches yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => FadeInEntrance(
                      delay: Duration(milliseconds: 100 * index),
                      offset: const Offset(-20, 0),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MatchCard(match: state.matches[index]),
                      ),
                    ),
                    childCount: state.matches.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _heroTeamScore(String name, int? runs, int? wickets, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text('${runs ?? 0}/${wickets ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      ],
    );
  }

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.98,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Player Rankings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        Text('Based on all matches recorded', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 32),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BlocBuilder<PlayerBloc, PlayerState>(
                  builder: (context, pState) {
                    return BlocBuilder<MatchListBloc, MatchListState>(
                      builder: (context, mState) {
                        // Refresh stats every time sheet is opened
                        final statsMap = calculateAllPlayerStats(mState.matches, pState.players);
                        final statsList = statsMap.values.where((s) => s.matches > 0).toList();
                        
                        // Sort by Runs primarily, then Wickets
                        statsList.sort((a, b) {
                          int cmp = b.runs.compareTo(a.runs);
                          if (cmp == 0) return b.wickets.compareTo(a.wickets);
                          return cmp;
                        });

                        if (statsList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.analytics_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.1)),
                                const SizedBox(height: 16),
                                const Text('No records found yet.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                                const Text('Play some matches to see rankings!', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: statsList.length,
                          itemBuilder: (context, index) => _PlayerStatCard(stats: statsList[index], rank: index + 1),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _iconBtn(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, size: 22, color: AppColors.textSecondary),
      ),
    );
  }
}

class _LiveMatchHero extends StatelessWidget {
  final MatchSummary match;
  const _LiveMatchHero({required this.match});

  @override
  Widget build(BuildContext context) {
    return ScaleEntrance(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScoringScreen())),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.gradientCard(AppColors.primaryGradient),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        PulseAnimation(child: Icon(Icons.circle, size: 6, color: Colors.redAccent)),
                        SizedBox(width: 6),
                        Text('LIVE SCOREBOARD', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  Text('${match.totalOvers} OVERS', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _liveTeamInfo(match.teamAName, match.teamAScore, match.teamAWickets, match.teamAOvers, CrossAxisAlignment.start)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  Expanded(child: _liveTeamInfo(match.teamBName, match.teamBScore, match.teamBWickets, match.teamBOvers, CrossAxisAlignment.end)),
                ],
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('TAP TO CONTINUE SCORING', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveTeamInfo(String name, int? score, int? wickets, String? overs, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('${score ?? 0}/${wickets ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        Text('(${overs ?? "0.0"} ov)', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchSummary match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'in_progress';
    final isDone = match.status == 'completed';
    final statusColor = isDone ? AppColors.success : isLive ? AppColors.warning : AppColors.textMuted;

    return GestureDetector(
      onTap: () {
        if (isLive) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ScoringScreen()));
        } else if (isDone && match.scoreData != null) {
          try {
            final scoreState = ScoreState.fromJson(match.scoreData!);
            ScorecardView.showAsBottomSheet(context, scoreState);
          } catch (_) {}
        }
      },
      onLongPress: () => _showOptions(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.glassCard(opacity: 0.04).copyWith(
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    isDone ? 'COMPLETED' : isLive ? 'LIVE' : 'SETUP',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 1),
                  ),
                ),
                const Spacer(),
                Text(match.totalOvers.toString() + ' OV', style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.teamAName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (match.teamAScore != null)
                        Text('${match.teamAScore}/${match.teamAWickets}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('VS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(match.teamBName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (match.teamBScore != null)
                        Text('${match.teamBScore}/${match.teamBWickets}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
            if (match.result != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                child: Text(match.result!, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
              ),
            ],
            if (isDone) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMoMSmall(match),
                  const Spacer(),
                  const Icon(Icons.analytics_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text('SCORECARD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoMSmall(MatchSummary match) {
    final mom = calculateManOfTheMatch(match);
    if (mom == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 14),
        const SizedBox(width: 6),
        Text(mom.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      ],
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('MATCH OPTIONS', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMuted, fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 24),
            _optionTile(context, 'Start Rematch', 'Use same teams and settings', Icons.restart_alt_rounded, AppColors.primary, () {
              Navigator.pop(ctx);
              _startRematch(context);
            }),
            const SizedBox(height: 12),
            _optionTile(context, 'Delete Match', 'Permanently remove from history', Icons.delete_forever_rounded, AppColors.danger, () {
              Navigator.pop(ctx);
              _showDeleteConfirm(context);
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.1))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(sub, style: TextStyle(color: AppColors.textMuted, fontSize: 12))])),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  void _startRematch(BuildContext context) {
    context.read<MatchBloc>().add(ResetMatch());
    context.read<ScoreBloc>().add(ResetScoreboard());
    final settings = MatchSettings(teamAName: match.teamAName, teamBName: match.teamBName, totalOvers: match.totalOvers);
    context.read<MatchBloc>().add(CreateMatch(settings, DateTime.now().millisecondsSinceEpoch.toString()));
    if (match.teamA != null && match.teamB != null) {
      context.read<MatchBloc>().add(SelectTeams(match.teamA!, match.teamB!));
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchSetupScreen()));
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Match?'),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { context.read<MatchListBloc>().add(RemoveMatchFromList(match.id)); Navigator.pop(ctx); }, child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }
}

class _PlayerStatCard extends StatelessWidget {
  final PlayerStats stats;
  final int rank;
  const _PlayerStatCard({required this.stats, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColor = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : rank == 3 ? const Color(0xFFCD7F32) : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isTop3 ? rankColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(width: 28, alignment: Alignment.center, child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.w900, color: rankColor, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(stats.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(stats.role.name.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppColors.textMuted, letterSpacing: 0.5))])),
          _statItem('M', '${stats.matches}'),
          _statItem('R', '${stats.runs}', isBold: true),
          _statItem('W', '${stats.wickets}', color: AppColors.wicket),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {bool isBold = false, Color? color}) {
    return Container(
      width: 44,
      margin: const EdgeInsets.only(left: 8),
      child: Column(children: [Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: color ?? AppColors.textPrimary))]),
    );
  }
}
