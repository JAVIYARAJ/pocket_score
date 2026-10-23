import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';
import '../widgets/leaderboard_widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: BlocBuilder<MatchListBloc, MatchListState>(
          builder: (context, mState) {
            // Players are derived from scoreData inside each match.
            // Guest players are filtered out in calculateAllPlayerStats.
            final players = calculateAllPlayerStats(mState.matches, const [])
                .values
                .where((s) => s.matches > 0)
                .toList();
            final completed = mState.matches.where((m) => m.status == 'completed').length;

            return LeaderboardBoard(
              players: players,
              bottomPadding: 120,
              header: _HallOfFameHeader(players: players.length, matches: completed),
              empty: const EmptyState(
                art: EmptyArt.stats,
                title: 'The podium is empty',
                message: 'Play some matches and the top performers will climb up here.',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HallOfFameHeader extends StatelessWidget {
  final int players;
  final int matches;
  const _HallOfFameHeader({required this.players, required this.matches});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RANKINGS',
                style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentLight.withValues(alpha: 0.9))),
            const SizedBox(height: 2),
            const Text('Hall of Fame',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Row(children: [
              _pill(Icons.people_alt_rounded, '$players player${players == 1 ? '' : 's'}'),
              const SizedBox(width: 8),
              _pill(Icons.sports_cricket_rounded, '$matches match${matches == 1 ? '' : 'es'}'),
            ]),
          ]),
        ),
        ScaleEntrance(
          delay: const Duration(milliseconds: 200),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.55), blurRadius: 22)],
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 34),
          ),
        ),
      ]),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
        ]),
      );
}
