import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/score_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../models/ball_model.dart';
import '../models/innings_model.dart';
import '../models/player_model.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class ScoringScreen extends StatelessWidget {
  const ScoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScoreBloc, ScoreState>(
      listener: (context, state) {
        _syncMatchList(context, state);
        if (state.currentInnings != null) {
          final inn = state.currentInnings!;
          final totalOvers =
              context.read<MatchBloc>().state.settings?.totalOvers ?? 0;
          bool victory = !state.isFirstInnings &&
              inn.totalRuns >= (state.firstInnings?.totalRuns ?? 0) + 1;
          bool oversUp = inn.legalBallsCount >= totalOvers * 6;
          bool allOut = state.isLastManStanding
              ? (state.outPlayerIds.length + state.retiredHurtIds.length) >=
                  state.battingLineup.length
              : (state.outPlayerIds.length + state.retiredHurtIds.length) >=
                  state.battingLineup.length - 1;

          if (victory || oversUp || allOut) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (state.isFirstInnings) {
                if (!state.pendingBowlerChange || oversUp || allOut) {
                  _inningsBreak(context, state);
                }
              } else {
                context.push('/match/result');
              }
            });
          }
        }
      },
      child: BlocBuilder<ScoreBloc, ScoreState>(
        builder: (context, state) {
          if (state.firstInnings == null || state.currentInnings == null) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return _ScoringView(state: state);
        },
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────
  static void _syncMatchList(BuildContext context, ScoreState state) {
    final ms = context.read<MatchBloc>().state;
    if (ms.matchId == null) return;
    final first = state.firstInnings;
    final second = state.secondInnings;
    final bool done = second != null &&
        (second.totalRuns > (first?.totalRuns ?? 0) ||
            second.legalBallsCount >=
                (ms.settings?.totalOvers ?? 0) * 6 ||
            (state.outPlayerIds.length + state.retiredHurtIds.length) >=
                (state.isLastManStanding
                    ? state.battingLineup.length
                    : state.battingLineup.length - 1));
    final aName = ms.settings?.teamAName ?? '';
    final bName = ms.settings?.teamBName ?? '';
    int? aScore, aWkts, bScore, bWkts;
    String? aOv, bOv;
    if (first != null) {
      if (first.battingTeamName == aName) {
        aScore = first.totalRuns; aWkts = first.totalWickets; aOv = first.overDisplay;
      } else {
        bScore = first.totalRuns; bWkts = first.totalWickets; bOv = first.overDisplay;
      }
    }
    if (second != null) {
      if (second.battingTeamName == aName) {
        aScore = second.totalRuns; aWkts = second.totalWickets; aOv = second.overDisplay;
      } else {
        bScore = second.totalRuns; bWkts = second.totalWickets; bOv = second.overDisplay;
      }
    }
    context.read<MatchListBloc>().add(UpdateMatchInList(MatchSummary(
      id          : ms.matchId!,
      teamAName   : aName,
      teamBName   : bName,
      teamA       : ms.teamA,
      teamB       : ms.teamB,
      totalOvers  : ms.settings?.totalOvers ?? 0,
      status      : done ? 'completed' : 'in_progress',
      createdAt   : DateTime.now(),
      teamAScore  : aScore,
      teamAWickets: aWkts,
      teamAOvers  : aOv,
      teamBScore  : bScore,
      teamBWickets: bWkts,
      teamBOvers  : bOv,
      scoreData   : state.toJson(),
      groupId     : ms.settings?.groupId, // preserve group association on every update
      result      : done
          ? (second.totalRuns > first!.totalRuns
              ? '${second.battingTeamName} won'
              : first.totalRuns > second.totalRuns
                  ? '${first.battingTeamName} won'
                  : 'Match Tied')
          : null,
    )));
  }

  static void _inningsBreak(BuildContext context, ScoreState state) {
    final ms     = context.read<MatchBloc>().state;
    final first  = state.firstInnings!;
    final target = first.totalRuns + 1;
    final teamA  = ms.teamA!;
    final teamB  = ms.teamB!;
    final aBatted = first.battingTeamName == teamA.name;
    final chasers = aBatted ? teamB.name : teamA.name;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Innings Break',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return _InningsBreakDialog(
          state: state,
          target: target,
          chasers: chasers,
          aBatted: aBatted,
          teamA: teamA,
          teamB: teamB,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }


  static void _confirmDiscard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Discard Match?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'All scoring progress will be permanently lost.\nThis cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Keep Playing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final id = context.read<MatchBloc>().state.matchId;
                    if (id != null) context.read<MatchListBloc>().add(RemoveMatchFromList(id));
                    context.read<MatchBloc>().add(ResetMatch());
                    context.read<ScoreBloc>().add(ResetScoreboard());
                    Navigator.pop(ctx);
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Scoring View ───────────────────────────────────────────────
class CelebrationData {
  final String text;
  final Color color;

  CelebrationData({required this.text, required this.color});
}

class _ScoringView extends StatefulWidget {
  final ScoreState state;
  const _ScoringView({required this.state});
  @override
  State<_ScoringView> createState() => _ScoringViewState();
}

class _ScoringViewState extends State<_ScoringView> {
  final ValueNotifier<CelebrationData?> _celebration = ValueNotifier<CelebrationData?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScoringScreen._syncMatchList(context, widget.state);
    });
  }

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ScoringView old) {
    super.didUpdateWidget(old);
    final newBalls = widget.state.currentInnings?.balls ?? [];
    final oldBalls = old.state.currentInnings?.balls ?? [];
    if (newBalls.length > oldBalls.length) {
      final b = newBalls.last;
      _checkMilestone(old.state, widget.state);
      if (b.isWicket) _celebrate('OUT! 🎯', AppColors.wicket);
      else if (b.runs == 6) _celebrate('SIX! 🚀', AppColors.six);
      else if (b.runs == 4) _celebrate('FOUR! 💥', AppColors.four);
    }
  }

  void _checkMilestone(ScoreState old, ScoreState now) {
    final id = now.strikerId;
    if (id.isEmpty) return;
    final o = old.currentInnings?.batsmanStats[id];
    final n = now.currentInnings?.batsmanStats[id];
    if (o != null && n != null && o.runs < 50 && n.runs >= 50) {
      _celebrate('FIFTY! 🏏', AppColors.accent);
    }
  }

  void _celebrate(String text, Color color) {
    _celebration.value = CelebrationData(text: text, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,  // dark icons on white surface bar
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Column(children: [
          // ── App Bar ──────────────────────────────────────────
          _ScoringAppBar(state: state),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Scoreboard
                SliverToBoxAdapter(
                    child: FadeInEntrance(
                        delay: const Duration(milliseconds: 50),
                        child: _Scoreboard(state: state))),
                // Players
                SliverToBoxAdapter(
                    child: FadeInEntrance(
                        delay: const Duration(milliseconds: 120),
                        child: _PlayerStatus(state: state))),
                // This Over
                SliverToBoxAdapter(
                    child: FadeInEntrance(
                        delay: const Duration(milliseconds: 180),
                        child: _ThisOver(state: state))),
                // Over History
                SliverToBoxAdapter(
                    child: FadeInEntrance(
                        delay: const Duration(milliseconds: 220),
                        child: _OverHistory(state: state))),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
          // Action Panel
          FadeInEntrance(
              offset: const Offset(0, 40),
              delay: const Duration(milliseconds: 260),
              child: _ActionPanel(state: state)),
        ]),
        ValueListenableBuilder<CelebrationData?>(
          valueListenable: _celebration,
          builder: (context, data, _) {
            if (data == null) return const SizedBox.shrink();
            return ScoreCelebration(
              text: data.text,
              color: data.color,
              onFinish: () => _celebration.value = null,
            );
          },
        ),
      ]),
      ),  // Scaffold
    );   // AnnotatedRegion
  }
}

// ── App Bar ────────────────────────────────────────────────────
class _ScoringAppBar extends StatelessWidget {
  final ScoreState state;
  const _ScoringAppBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12, right: 12, bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        // Close
        _iconBtn(
          icon: Icons.close_rounded,
          color: AppColors.textSecondary,
          bg: AppColors.surfaceLight,
          onTap: () {
            ScoringScreen._syncMatchList(context, state);
            context.go('/home');
          },
        ),
        // Innings info
        Expanded(
          child: Column(children: [
            Text(
              state.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 1),
            Text(
              state.currentInnings!.battingTeamName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
          ]),
        ),
        // Undo
        if (state.history.isNotEmpty)
          _iconBtn(
            icon: Icons.undo_rounded,
            color: AppColors.warning,
            bg: AppColors.warning.withValues(alpha: 0.1),
            onTap: () => context.read<ScoreBloc>().add(UndoBall()),
          ),
        const SizedBox(width: 8),
        // Scorecard
        _iconBtn(
          icon: Icons.bar_chart_rounded,
          color: AppColors.primary,
          bg: AppColors.primary.withValues(alpha: 0.1),
          onTap: () => context.push('/scorecard', extra: state),
        ),
        const SizedBox(width: 8),
        // Delete
        _iconBtn(
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger,
          bg: AppColors.danger.withValues(alpha: 0.08),
          onTap: () => ScoringScreen._confirmDiscard(context),
        ),
      ]),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

// ── Scoreboard ─────────────────────────────────────────────────
class _Scoreboard extends StatelessWidget {
  final ScoreState state;
  const _Scoreboard({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    final total = context.read<MatchBloc>().state.settings?.totalOvers ?? 1;
    final rem = total * 6 - inn.legalBallsCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: AppDecorations.gradientCard(AppColors.headerGradient, radius: 24),
      child: Column(children: [
        // Main score + overs
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Runs / Wickets
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SCORE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 1.2)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedCounter(
                    value: inn.totalRuns,
                    style: const TextStyle(
                        fontSize: 68,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2),
                  ),
                  Text(' / ${inn.totalWickets}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60)),
                ],
              ),
            ]),
            const Spacer(),
            // Overs
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('OVERS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 1.2)),
              Text(inn.overDisplay,
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1)),
              Text('$rem balls left',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500)),
            ]),
          ],
        ),
        // Free Hit badge
        if (state.isFreeHit) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.lock_open_rounded, size: 13, color: Colors.white),
                SizedBox(width: 6),
                Text('FREE HIT',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1)),
              ]),
            ),
          ),
        ],
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
        ),
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat('CRR', inn.runRate.toStringAsFixed(2)),
            if (state.isFirstInnings)
              _stat('PROJECTED',
                  inn.legalBallsCount > 0
                      ? (inn.totalRuns / inn.legalBallsCount * total * 6)
                          .round()
                          .toString()
                      : '—')
            else ...[
              Builder(builder: (ctx) {
                final target = (state.firstInnings?.totalRuns ?? 0) + 1;
                final need = target - inn.totalRuns;
                final rrr = rem > 0 ? need / (rem / 6) : 0.0;
                return Row(children: [
                  _stat('NEED', '$need'),
                  const SizedBox(width: 28),
                  _stat('RRR', rrr.toStringAsFixed(2)),
                  const SizedBox(width: 28),
                  _stat('TARGET', '$target'),
                ]);
              }),
            ],
          ],
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      );
}

// ── Player Status ──────────────────────────────────────────────
class _PlayerStatus extends StatelessWidget {
  final ScoreState state;
  const _PlayerStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    Player? striker, nonStriker, bowler;
    try { striker = state.battingLineup.firstWhere((p) => p.id == state.strikerId); } catch (_) {}
    try { nonStriker = state.battingLineup.firstWhere((p) => p.id == state.nonStrikerId); } catch (_) {}
    try { bowler = state.bowlingLineup.firstWhere((p) => p.id == state.bowlerId); } catch (_) {}

    final sS = inn.batsmanStats[state.strikerId];
    final nsS = inn.batsmanStats[state.nonStrikerId];
    final bS = inn.bowlerStatsMap[state.bowlerId];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: AppDecorations.card(),
      child: Column(children: [
        // Batters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Expanded(child: _BatTile(
              name: striker?.name ?? '—',
              stats: sS,
              isStriker: true,
              playerId: state.strikerId,
              state: state,
            )),
            if (!state.isLastManStanding) ...[
              Container(width: 1, height: 50, color: AppColors.border),
              Expanded(child: _BatTile(
                name: nonStriker?.name ?? '—',
                stats: nsS,
                isStriker: false,
                playerId: state.nonStrikerId,
                state: state,
              )),
            ],
          ]),
        ),
        if (state.isLastManStanding)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.warning),
              SizedBox(width: 6),
              Text('LAST MAN STANDING',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      letterSpacing: 0.8)),
            ]),
          ),
        // Bowler strip
        if (bowler != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_baseball_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    bowler.isGuest ? '${bowler.name} (Guest)' : bowler.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
              ),
              _bStat('O', bS?.oversBowled ?? '0.0'),
              _bStat('R', '${bS?.runsConceded ?? 0}'),
              _bStat('W', '${bS?.wickets ?? 0}',
                  color: (bS?.wickets ?? 0) > 0 ? AppColors.wicket : null),
              _bStat('E', bS?.economy.toStringAsFixed(1) ?? '0.0'),
            ]),
          ),
      ]),
    );
  }

  Widget _bStat(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700)),
        Text(val,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textSecondary)),
      ]),
    );
  }
}

class _BatTile extends StatelessWidget {
  final String name;
  final BatsmanStats? stats;
  final bool isStriker;
  final String playerId;
  final ScoreState state;
  const _BatTile({
    required this.name,
    required this.stats,
    required this.isStriker,
    required this.playerId,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoreBloc>();
    Player? player;
    try {
      player = state.battingLineup.firstWhere((p) => p.id == playerId);
    } catch (_) {}
    final isGuest = player?.isGuest ?? false;

    return GestureDetector(
      onTap: () {
        if (playerId.isEmpty) {
          _showPicker(context, bloc, state, isStriker);
        } else if (!state.isLastManStanding &&
            state.strikerId.isNotEmpty &&
            state.nonStrikerId.isNotEmpty) {
          bloc.add(SwapStriker());
        }
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment:
              isStriker ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Name row
            Row(
              mainAxisAlignment: isStriker
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              children: [
                if (isStriker && playerId.isNotEmpty)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                Flexible(
                  child: Text(isGuest ? '$name (Guest)' : name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isStriker ? FontWeight.w700 : FontWeight.w500,
                          color: isStriker
                              ? AppColors.textPrimary
                              : AppColors.textSecondary)),
                ),
                if (playerId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _retire(context, bloc, state, playerId),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Icon(Icons.exit_to_app_rounded,
                          size: 13, color: AppColors.textMuted),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(Icons.add_circle_outline_rounded,
                        size: 13, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: isStriker
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${stats?.runs ?? 0}',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1)),
                Text('  (${stats?.ballsFaced ?? 0})',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            if (stats != null && stats!.ballsFaced > 0)
              Text('SR ${stats!.strikeRate.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  static void _showPicker(BuildContext context, ScoreBloc bloc,
      ScoreState state, bool isStriker) {
    final avail = _available(state);
    if (avail.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No batsmen left!')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PlayerPickerSheet(
        title: 'Select ${isStriker ? "Striker" : "Non-Striker"}',
        players: avail,
        state: state,
        onPick: (id) {
          bloc.add(SelectNextBatsman(playerId: id, isStriker: isStriker));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  static void _retire(BuildContext context, ScoreBloc bloc,
      ScoreState state, String playerId) {
    final rem = state.battingLineup.where((p) =>
        !state.outPlayerIds.contains(p.id) &&
        !state.retiredHurtIds.contains(p.id) &&
        p.id != state.strikerId &&
        p.id != state.nonStrikerId).toList();
    String? nextId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          final pName = state.battingLineup
              .firstWhere((p) => p.id == playerId)
              .name;
          return Container(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _handle(),
              const SizedBox(height: 20),
              Text('Retire $pName?',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Mark as retired hurt & bring in replacement.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),
              if (rem.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('REPLACEMENT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: rem.length,
                    itemBuilder: (c, i) {
                      final p = rem[i];
                      final sel = nextId == p.id;
                      return GestureDetector(
                        onTap: () => setSt(() => nextId = p.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.border),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: sel
                                      ? AppColors.primary
                                      : AppColors.border,
                                  child: Text(p.name[0],
                                      style: TextStyle(
                                          color: sel
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 6),
                                 Text(p.isGuest ? '${p.name} (Guest)' : p.name,
                                     style: const TextStyle(fontSize: 10),
                                     overflow: TextOverflow.ellipsis),
                              ]),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.tintedCard(AppColors.warning),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'No replacements. Innings continues as Last Man Standing.',
                            style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    bloc.add(RetirePlayer(
                        playerId: playerId, nextBatsmanId: nextId));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Confirm Retirement'),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  static List<Player> _available(ScoreState state) {
    final rem = state.battingLineup.where((p) =>
        !state.outPlayerIds.contains(p.id) &&
        !state.retiredHurtIds.contains(p.id) &&
        p.id != state.strikerId &&
        p.id != state.nonStrikerId).toList();
    final retired = state.retiredHurtIds
        .where((id) =>
            !state.outPlayerIds.contains(id) &&
            id != state.strikerId &&
            id != state.nonStrikerId)
        .map((id) =>
            state.battingLineup.firstWhere((p) => p.id == id))
        .toList();
    return {...rem, ...retired}.toList();
  }
}

// ── This Over ─────────────────────────────────────────────────
class _ThisOver extends StatelessWidget {
  final ScoreState state;
  const _ThisOver({required this.state});

  @override
  Widget build(BuildContext context) {
    final balls = state.currentInnings!.balls;
    final current = <Ball>[];
    int legal = 0;
    for (int i = balls.length - 1; i >= 0; i--) {
      current.insert(0, balls[i]);
      if (balls[i].isLegalBall) legal++;
      if (legal >= 6) break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.fiber_manual_record,
              size: 8, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('THIS OVER',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
          const Spacer(),
          Text('${legal}/6',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: current.isEmpty
              ? const Center(
                  child: Text('Waiting for first ball…',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)))
              : ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: current.map(_ballChip).toList(),
                ),
        ),
      ]),
    );
  }

  Widget _ballChip(Ball b) {
    Color color;
    String label;
    if (b.isWicket) { label = 'W'; color = AppColors.wicket; }
    else if (b.type == BallType.wide) { label = 'WD'; color = AppColors.wide; }
    else if (b.type == BallType.noBall) { label = 'NB'; color = AppColors.noBall; }
    else if (b.runs == 6) { label = '6'; color = AppColors.six; }
    else if (b.runs == 4) { label = '4'; color = AppColors.four; }
    else if (b.runs == 0) { label = '•'; color = AppColors.dot; }
    else { label = '${b.runs}'; color = AppColors.primary; }

    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: b.runs == 0 && !b.isWicket ? 0.12 : 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: label.length > 1 ? 11 : 14,
              fontWeight: FontWeight.w800,
              color: color == AppColors.dot
                  ? AppColors.textMuted
                  : color)),
    );
  }
}

// ── Over History ──────────────────────────────────────────────
class _OverHistory extends StatelessWidget {
  final ScoreState state;
  const _OverHistory({required this.state});

  @override
  Widget build(BuildContext context) {
    final ovs = state.currentInnings?.overSummaries ?? [];
    if (ovs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text('OVER HISTORY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: ovs.length,
            itemBuilder: (_, i) {
              final ov = ovs[i];
              final hasWkt = ov.wickets > 0;
              return Container(
                width: 60,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: hasWkt
                      ? AppColors.wicket.withValues(alpha: 0.07)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: hasWkt
                          ? AppColors.wicket.withValues(alpha: 0.25)
                          : AppColors.border),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('OV ${ov.overNumber}',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text('${ov.runs}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: hasWkt
                              ? AppColors.wicket
                              : AppColors.primary,
                          height: 1.1)),
                  if (hasWkt)
                    Text('${ov.wickets}W',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.wicket)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Action Panel ───────────────────────────────────────────────
class _ActionPanel extends StatelessWidget {
  final ScoreState state;
  const _ActionPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.pendingBowlerChange) return _BowlerPicker(state: state);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Run buttons
        Row(children: [
          _runBtn(context, '0', 0, bg: AppColors.surfaceLight, text: AppColors.textMuted),
          _runBtn(context, '1', 1, bg: AppColors.surfaceLight, text: AppColors.textSecondary),
          _runBtn(context, '2', 2, bg: AppColors.surfaceLight, text: AppColors.textSecondary),
          _runBtn(context, '3', 3, bg: AppColors.surfaceLight, text: AppColors.textSecondary),
          _runBtn(context, '4', 4,
              bg: AppColors.four.withValues(alpha: 0.12),
              text: AppColors.four),
          _runBtn(context, '6', 6,
              bg: AppColors.six.withValues(alpha: 0.12),
              text: AppColors.six),
        ]),
        const SizedBox(height: 10),
        // Extras + Wicket
        Row(children: [
          _extrasBtn(context, 'WD', 0, BallType.wide, AppColors.wide),
          _extrasBtn(context, 'NB', 0, BallType.noBall, AppColors.noBall),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _wicketDialog(context, state),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFB91C1C), AppColors.wicket]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.wicket.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_baseball_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('WICKET',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2)),
                    ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _runBtn(BuildContext context, String label, int runs,
      {required Color bg, required Color text}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => context
              .read<ScoreBloc>()
              .add(RecordBall(runs: runs, type: BallType.normal, extraRuns: 0)),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: text)),
          ),
        ),
      ),
    );
  }

  Widget _extrasBtn(BuildContext context, String label, int runs,
      BallType type, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => context.read<ScoreBloc>().add(
              RecordBall(runs: runs, type: type, extraRuns: 1)),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ),
      ),
    );
  }
}

// ── Bowler Picker ──────────────────────────────────────────────
class _BowlerPicker extends StatelessWidget {
  final ScoreState state;
  const _BowlerPicker({required this.state});

  @override
  Widget build(BuildContext context) {
    final bowlers =
        state.bowlingLineup.where((p) => p.id != state.bowlerId).toList();
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 24, 20, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('OVER COMPLETE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 10),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Select Next Bowler',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: bowlers.length,
            itemBuilder: (ctx, i) {
              final p = bowlers[i];
              return GestureDetector(
                onTap: () =>
                    context.read<ScoreBloc>().add(ChangeBowler(p.id)),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: AppDecorations.card(radius: 14),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(p.name[0],
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    Text(p.isGuest ? '${p.name} (Guest)' : p.name,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Wicket Dialog ──────────────────────────────────────────────
void _wicketDialog(BuildContext context, ScoreState state) {
  final bloc = context.read<ScoreBloc>();
  final avail = _BatTile._available(state);

  String? wktType;
  String? playerId = state.strikerId;
  int runs = 0;
  String? fielderId;
  String? nextId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSt) {
        final isRunOut = wktType == 'RUN OUT';
        final needsFielder = ['CAUGHT', 'STUMPED', 'RUN OUT'].contains(wktType);

        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _handle()),
              const SizedBox(height: 20),

              if (wktType == null) ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.wicket.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_baseball_rounded,
                        color: AppColors.wicket, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Wicket Fallen! 🎯',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text('Select dismissal type',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: (state.isFreeHit
                          ? ['RUN OUT']
                          : [
                              'BOWLED', 'CAUGHT', 'LBW',
                              'STUMPED', 'RUN OUT', 'OTHERS'
                            ])
                      .map((t) => GestureDetector(
                            onTap: () => setSt(() => wktType = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.wicket.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.wicket
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.wicket)),
                            ),
                          ))
                      .toList(),
                ),
                if (state.isFreeHit) ...[
                  const SizedBox(height: 12),
                  const Text('Only Run Out is possible on a Free Hit',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ] else if (needsFielder && fielderId == null) ...[
                Text(
                  wktType == 'RUN OUT' ? 'Fielder Involved?' : 'Who Caught It?',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.bowlingLineup.length,
                    itemBuilder: (_, i) {
                      final p = state.bowlingLineup[i];
                      return GestureDetector(
                        onTap: () => setSt(() => fielderId = p.id),
                        child: _pickerChip(p.name, false),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setSt(() => fielderId = state.bowlerId),
                  child: const Text('By Bowler'),
                ),
              ] else if (isRunOut && nextId == null && avail.isNotEmpty) ...[
                const Text('Run Out Details',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                const Text('WHO IS OUT?',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Row(children: [
                  _selBtn(
                      state.battingLineup
                          .firstWhere((p) => p.id == state.strikerId)
                          .name,
                      state.strikerId,
                      playerId,
                      (id) => setSt(() => playerId = id)),
                  const SizedBox(width: 10),
                  _selBtn(
                      state.battingLineup
                          .firstWhere((p) => p.id == state.nonStrikerId)
                          .name,
                      state.nonStrikerId,
                      playerId,
                      (id) => setSt(() => playerId = id)),
                ]),
                const SizedBox(height: 16),
                const Text('RUNS COMPLETED?',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Row(children: [0, 1, 2, 3].map((r) => GestureDetector(
                  onTap: () => setSt(() => runs = r),
                  child: Container(
                    width: 50, height: 50,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: runs == r
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: runs == r
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text('$r',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: runs == r
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                )).toList()),
                const SizedBox(height: 20),
                const Text('NEXT BATSMAN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: avail.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setSt(() => nextId = avail[i].id),
                      child: _pickerChip(avail[i].name, false),
                    ),
                  ),
                ),
              ] else if (nextId == null && avail.isNotEmpty) ...[
                const Text('Next Batsman',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: avail.length,
                    itemBuilder: (_, i) {
                      final p = avail[i];
                      return GestureDetector(
                        onTap: () => setSt(() => nextId = p.id),
                        child: _pickerChip(p.name, false),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Text('Confirm Wicket',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration:
                      AppDecorations.tintedCard(AppColors.wicket),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Type: $wktType',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    if (nextId != null && avail.any((p) => p.id == nextId))
                      Text(
                          'Next: ${avail.firstWhere((p) => p.id == nextId).name}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wicket,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      bloc.add(RecordBall(
                        runs: runs,
                        type: BallType.wicket,
                        isWicket: true,
                        wicketType: wktType,
                        outPlayerId: playerId,
                        fielderId: fielderId,
                        nextBatsmanId:
                            nextId == 'none' ? null : nextId,
                      ));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Record Wicket 🎯',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
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

// ── Player Picker Sheet ────────────────────────────────────────
class _PlayerPickerSheet extends StatelessWidget {
  final String title;
  final List<Player> players;
  final ScoreState state;
  final void Function(String id) onPick;

  const _PlayerPickerSheet({
    required this.title,
    required this.players,
    required this.state,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _handle()),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85),
              itemCount: players.length,
              itemBuilder: (_, i) {
                final p = players[i];
                final wasRetired = state.retiredHurtIds.contains(p.id);
                return GestureDetector(
                  onTap: () => onPick(p.id),
                  child: Container(
                    decoration: AppDecorations.card(radius: 14),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: wasRetired
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.1),
                        child: Text(p.name[0],
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: wasRetired
                                    ? AppColors.warning
                                    : AppColors.primary)),
                      ),
                      const SizedBox(height: 6),
                      Text(p.isGuest ? '${p.name} (Guest)' : p.name,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis),
                      if (wasRetired)
                        const Text('RE-ENTRY',
                            style: TextStyle(
                                fontSize: 8,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w800)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────
Widget _handle() => Container(
  width: 40, height: 4,
  decoration: BoxDecoration(
      color: AppColors.border, borderRadius: BorderRadius.circular(2)),
);

Widget _pickerChip(String name, bool selected) => Container(
  width: 80,
  margin: const EdgeInsets.only(right: 10),
  decoration: AppDecorations.card(radius: 14),
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.surfaceLight,
      child: Text(name[0],
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
    ),
    const SizedBox(height: 6),
    Text(name,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis),
  ]),
);

Widget _selBtn(String name, String id, String? current,
    Function(String) onSelect) {
  final sel = id == current;
  return Expanded(
    child: GestureDetector(
      onTap: () => onSelect(id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: sel
                    ? AppColors.primary
                    : AppColors.textSecondary)),
      ),
    ),
  );
}

// ── INNINGS BREAK DIALOG ──────────────────────────────────────────────
class _InningsBreakDialog extends StatefulWidget {
  final ScoreState state;
  final int target;
  final String chasers;
  final bool aBatted;
  final Team teamA;
  final Team teamB;

  const _InningsBreakDialog({
    required this.state,
    required this.target,
    required this.chasers,
    required this.aBatted,
    required this.teamA,
    required this.teamB,
  });

  @override
  State<_InningsBreakDialog> createState() => _InningsBreakDialogState();
}

class _InningsBreakDialogState extends State<_InningsBreakDialog> with TickerProviderStateMixin {
  late AnimationController _introCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _introCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.state.firstInnings!;
    final iconScale = CurvedAnimation(parent: _introCtrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    final contentFade = CurvedAnimation(parent: _introCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic));
    final slideUp = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(contentFade);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, // Reverted to app theme
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 10,
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Broadcast Hero Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 40, left: 24, right: 24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient, // Reverted to native gradient
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Decorative circles for cricket environment
                  Positioned(
                    right: -40,
                    top: -60,
                    child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  Positioned(
                    left: -40,
                    bottom: -30,
                    child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  Column(
                    children: [
                      ScaleTransition(
                        scale: iconScale,
                        child: Container(
                          width: 80, height: 80,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, // Light icon base
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                            ],
                          ),
                          child: const Icon(Icons.sports_cricket_rounded, color: AppColors.primary, size: 40),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: contentFade,
                        child: SlideTransition(
                          position: slideUp,
                          child: Column(
                            children: [
                              const Text('INNINGS BREAK', style: TextStyle(fontSize: 12, letterSpacing: 4, color: Colors.white70, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              Text(
                                first.battingTeamName,
                                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${first.totalRuns}/${first.totalWickets}',
                                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0, letterSpacing: -1),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text('(${first.overDisplay} overs)', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Target Reveal LED Scoreboard ──
            FadeTransition(
              opacity: contentFade,
              child: SlideTransition(
                position: slideUp,
                child: Container(
                  width: double.infinity,
                  color: AppColors.surface, 
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text('TARGET SET', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3.0)),
                      const SizedBox(height: 16),
                      
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) {
                          final pulse = Curves.easeInOut.transform(_pulseCtrl.value);
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight, 
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3 + (pulse * 0.4)), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.1 + (pulse * 0.1)),
                                  blurRadius: 20 + (pulse * 10),
                                  spreadRadius: pulse * 2,
                                )
                              ]
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${widget.target}',
                                  style: TextStyle(
                                    fontSize: 64, 
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(color: AppColors.primary.withValues(alpha: 0.3 * pulse), blurRadius: 10 * pulse),
                                    ]
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('RUNS TO WIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.textSecondary)),
                              ],
                            ),
                          );
                        }
                      ),
                      
                      const SizedBox(height: 24),
                      Text('Chasing: ${widget.chasers}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 32),

                      // Swipe to Chase integration!
                      _DialogSwipeToStart(
                        text: 'SWIPE TO CHASE',
                        onSwipe: () {
                          Navigator.pop(context);
                          context.push('/match/opening', extra: {
                            'battingTeamName': widget.aBatted ? widget.teamB.name : widget.teamA.name,
                            'battingPlayers' : widget.aBatted ? widget.teamB.players : widget.teamA.players,
                            'bowlingPlayers' : widget.aBatted ? widget.teamA.players : widget.teamB.players,
                            'target'         : widget.target,
                          });
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SWIPE COMPONENT FOR DIALOG ──────────────────
class _DialogSwipeToStart extends StatefulWidget {
  final VoidCallback onSwipe;
  final String text;

  const _DialogSwipeToStart({required this.onSwipe, required this.text});

  @override
  State<_DialogSwipeToStart> createState() => _DialogSwipeToStartState();
}

class _DialogSwipeToStartState extends State<_DialogSwipeToStart> {
  late final ValueNotifier<double> _dragNotifier;
  late final ValueNotifier<bool> _dragStateNotifier;
  bool _completed = false;
  final double _thumbSize = 52;

  @override
  void initState() {
    super.initState();
    _dragNotifier = ValueNotifier<double>(0);
    _dragStateNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    _dragStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackWidth = constraints.maxWidth - 12;
        final maxDrag = stackWidth - _thumbSize;

        return ValueListenableBuilder<bool>(
          valueListenable: _dragStateNotifier,
          builder: (context, isDragging, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDragging
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight.withValues(alpha: 0.5), 
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDragging ? AppColors.primary : AppColors.border,
                  width: 2.0,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _dragNotifier,
                      builder: (context, dragOffset, child) {
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: dragOffset > maxDrag * 0.2 ? 0.0 : 1.0,
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.text,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: isDragging ? AppColors.primary : AppColors.textPrimary), 
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.keyboard_double_arrow_right_rounded,
                              size: 20,
                              color: (isDragging ? AppColors.primary : AppColors.textSecondary).withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, dragOffset, _) {
                      return TweenAnimationBuilder<double>(
                        duration: isDragging ? Duration.zero : const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        tween: Tween<double>(begin: 0, end: dragOffset),
                        builder: (context, value, child) {
                          return Positioned(
                            left: value,
                            child: GestureDetector(
                              onHorizontalDragStart: (_) {
                                if (_completed) return;
                                _dragStateNotifier.value = true;
                              },
                              onHorizontalDragUpdate: (details) {
                                if (_completed) return;
                                double newOffset = _dragNotifier.value + details.delta.dx;
                                if (newOffset < 0) newOffset = 0;
                                if (newOffset >= maxDrag) {
                                  newOffset = maxDrag;
                                  _completed = true;
                                  _dragStateNotifier.value = false;
                                  _dragNotifier.value = newOffset;
                                  Future.delayed(const Duration(milliseconds: 200), widget.onSwipe);
                                  return;
                                }
                                _dragNotifier.value = newOffset;
                              },
                              onHorizontalDragEnd: (details) {
                                if (_completed) return;
                                _dragStateNotifier.value = false;
                                if (_dragNotifier.value > maxDrag * 0.7) {
                                  _completed = true;
                                  _dragNotifier.value = maxDrag;
                                  Future.delayed(const Duration(milliseconds: 300), widget.onSwipe);
                                } else {
                                  _dragNotifier.value = 0;
                                }
                              },
                              child: Container(
                                width: _thumbSize,
                                height: _thumbSize,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDragging ? 0.3 : 0.15),
                                      blurRadius: isDragging ? 12 : 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Transform.rotate(
                                  angle: value / 20,
                                  child: Image.asset(
                                    'assets/icons/ic_cricket_ball_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
