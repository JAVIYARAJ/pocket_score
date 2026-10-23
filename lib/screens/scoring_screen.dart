import 'dart:math' show max;
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
import '../widgets/live_widgets.dart';
import '../widgets/setup_flow.dart' show CricketBallPainter;

part 'scoring/scoreboard.dart';
part 'scoring/over_strips.dart';
part 'scoring/action_panel.dart';
part 'scoring/bowler_picker.dart';
part 'scoring/batter_picker.dart';
part 'scoring/wicket_dialog.dart';
part 'scoring/break_dialogs.dart';

class ScoringScreen extends StatelessWidget {
  const ScoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    int totalOvers() =>
        context.read<MatchBloc>().state.settings?.totalOvers ?? 0;
    return BlocListener<ScoreBloc, ScoreState>(
      listener: (context, state) {
        _syncMatchList(context, state);
      },
      child: BlocListener<ScoreBloc, ScoreState>(
        // Navigate only when an innings *becomes* over, so later emissions
        // (bowler pick, strike swap) can't open the break/result a second time.
        listenWhen: (prev, curr) =>
            !prev.isInningsOver(totalOvers()) &&
            curr.isInningsOver(totalOvers()),
        listener: (context, state) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) goToInningsEnd(context, state);
          });
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
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────
  /// Innings break, super-over break or result — whichever follows the
  /// innings that just ended.
  static void goToInningsEnd(BuildContext context, ScoreState state) {
    if (state.isSuperOver) {
      if (state.isSuperOverFirstInnings) {
        _superOverBreak(context, state);
      } else {
        context.push('/match/result');
      }
    } else if (state.isFirstInnings) {
      _inningsBreak(context, state);
    } else {
      context.push('/match/result');
    }
  }

  static void _syncMatchList(BuildContext context, ScoreState state) {
    final ms = context.read<MatchBloc>().state;
    if (ms.matchId == null) return;
    final first = state.firstInnings;
    final second = state.secondInnings;
    // A super over in progress means the match isn't decided yet; the result
    // screen records the final outcome when it ends.
    final bool done = second != null &&
        !state.isSuperOver &&
        !state.isFirstInnings &&
        state.isInningsOver(ms.settings?.totalOvers ?? 0);
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
      id                : ms.matchId!,
      teamAName         : aName,
      teamBName         : bName,
      teamA             : ms.teamA,
      teamB             : ms.teamB,
      totalOvers        : ms.settings?.totalOvers ?? 0,
      status            : done ? 'completed' : 'in_progress',
      createdAt         : DateTime.now(),
      teamAScore        : aScore,
      teamAWickets      : aWkts,
      teamAOvers        : aOv,
      teamBScore        : bScore,
      teamBWickets      : bWkts,
      teamBOvers        : bOv,
      scoreData         : state.toJson(),
      groupId           : ms.settings?.groupId,
      maxOversPerBowler : ms.settings?.maxOversPerBowler,
      powerPlayOvers    : ms.settings?.powerPlayOvers,
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


  static void _superOverBreak(BuildContext context, ScoreState state) {
    final ms    = context.read<MatchBloc>().state;
    final soInn = state.superOverFirstInnings!;
    final target = soInn.totalRuns + 1;
    final teamA  = ms.teamA!;
    final teamB  = ms.teamB!;
    // The team that batted in SO first innings bats first; the other chases
    final firstBattingTeam = soInn.battingTeamName == teamA.name ? teamA : teamB;
    final chasingTeam      = soInn.battingTeamName == teamA.name ? teamB : teamA;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Super Over Break',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return _SuperOverBreakDialog(
          soFirstInnings : soInn,
          target         : target,
          chasingTeam    : chasingTeam,
          bowlingTeam    : firstBattingTeam,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curve),
          child: FadeTransition(opacity: anim1, child: child),
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
  static void _confirmEndGame(BuildContext context, ScoreState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('End Game?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'This will record the current score as the final result and close the match.',
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Keep Playing',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _forceCompleteMatch(context, state);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('End Game',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static void _forceCompleteMatch(BuildContext context, ScoreState state) {
    final ms = context.read<MatchBloc>().state;
    if (ms.matchId == null) return;

    final first  = state.firstInnings;
    final second = state.secondInnings;
    final aName  = ms.settings?.teamAName ?? '';
    final bName  = ms.settings?.teamBName ?? '';

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

    String result = 'Match ended';
    if (first != null && second != null) {
      if (second.totalRuns > first.totalRuns) {
        result = '${second.battingTeamName} won';
      } else if (first.totalRuns > second.totalRuns) {
        result = '${first.battingTeamName} won';
      } else {
        result = 'Match Tied';
      }
    } else if (first != null) {
      result = '${first.battingTeamName} innings complete';
    }

    context.read<MatchListBloc>().add(UpdateMatchInList(MatchSummary(
      id                : ms.matchId!,
      teamAName         : aName,
      teamBName         : bName,
      teamA             : ms.teamA,
      teamB             : ms.teamB,
      totalOvers        : ms.settings?.totalOvers ?? 0,
      status            : 'completed',
      createdAt         : DateTime.now(),
      teamAScore        : aScore,
      teamAWickets      : aWkts,
      teamAOvers        : aOv,
      teamBScore        : bScore,
      teamBWickets      : bWkts,
      teamBOvers        : bOv,
      scoreData         : state.toJson(),
      groupId           : ms.settings?.groupId,
      maxOversPerBowler : ms.settings?.maxOversPerBowler,
      powerPlayOvers    : ms.settings?.powerPlayOvers,
      result            : result,
    )));

    context.push('/match/result');
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
      _checkMilestone(old.state, widget.state);
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
        statusBarIconBrightness: Brightness.light, // light icons on the dark header
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: AppColors.bg,
      // No text input on this view (sheets handle their own insets); letting
      // the keyboard shrink it would squeeze the header and pad.
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        Column(children: [
          // Everything above the pad scrolls, so a tall bottom panel (e.g. the
          // bowler picker) never pushes the layout past a short screen.
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Score header
                SliverToBoxAdapter(child: _ScoreHero(state: state)),
                // Players
                SliverToBoxAdapter(
                    child: FadeInEntrance(
                        delay: const Duration(milliseconds: 80),
                        child: _PlayerStatus(state: state))),
                // Over History
                SliverToBoxAdapter(
                    child: FadeInEntrance(
                        delay: const Duration(milliseconds: 160),
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
