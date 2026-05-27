import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/player_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';
import '../widgets/leaderboard_widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tabIndex = 0; // 0=Batters, 1=Bowlers, 2=Impact
  String? _selectedFilter;

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
        body: Column(
          children: [
            // Custom App Bar — green gradient header
            Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 24,
                  right: 24,
                  bottom: 28),
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: FadeInEntrance(
                delay: const Duration(milliseconds: 100),
                offset: const Offset(0, -20),
                child: Row(
                  children: [
                    TapBounce(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RANKINGS',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 3,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Player Stats',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    ScaleEntrance(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.goldGradient,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 16)
                          ],
                        ),
                        child: const Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dropdown & Tabs
            BlocBuilder<MatchListBloc, MatchListState>(
                builder: (context, mState) {
              final Set<String> groups = {};
              for (var m in mState.matches) {
                if (m.groupId != null) {
                  groups.add(m.groupId!);
                } else if (m.tournamentId != null) {
                  groups.add(m.tournamentId!);
                }
              }
              final filterList = groups.toList();

              return FadeInEntrance(
                delay: const Duration(milliseconds: 200),
                offset: const Offset(0, 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (filterList.isNotEmpty) ...[
                        TapBounce(
                          onTap: () {}, // Dropdown handles its own tap
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.surfaceLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButton<String?>(
                              value: _selectedFilter,
                              hint: const Text('All Matches',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              dropdownColor: AppColors.surfaceLight,
                              underline: const SizedBox(),
                              icon: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.textMuted, size: 18)),
                              isDense: true,
                              items: [
                                const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Matches',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold))),
                                ...filterList.map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold)))),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedFilter = val),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tabText('Batters', 0),
                            _tabText('Bowlers', 1),
                            _tabText('Impact', 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, pState) {
                  return BlocBuilder<MatchListBloc, MatchListState>(
                    builder: (context, mState) {
                      final statsMap = calculateAllPlayerStats(
                          mState.matches, pState.players,
                          scopeGroupId: _selectedFilter,
                          scopeTournamentId: _selectedFilter);
                      final statsList =
                          statsMap.values.where((s) => s.matches > 0).toList();

                      // Sort by selected tab rank score
                      statsList.sort((a, b) {
                        double scoreA = _tabIndex == 0
                            ? (a.battingRankScore ?? -1.0)
                            : _tabIndex == 1
                                ? (a.bowlingRankScore ?? -1.0)
                                : (a.impactRankScore ?? -1.0);
                        double scoreB = _tabIndex == 0
                            ? (b.battingRankScore ?? -1.0)
                            : _tabIndex == 1
                                ? (b.bowlingRankScore ?? -1.0)
                                : (b.impactRankScore ?? -1.0);

                        int cmp = scoreB.compareTo(scoreA); // Descending
                        if (cmp == 0) {
                          // Tie breakers: More matches played
                          cmp = b.matches.compareTo(a.matches);
                          if (cmp == 0 && _tabIndex == 0) {
                            // higher boundary %
                            cmp =
                                b.boundaryPercent.compareTo(a.boundaryPercent);
                          }
                        }
                        return cmp;
                      });

                      if (statsList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics_outlined,
                                  size: 64,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.1)),
                              const SizedBox(height: 16),
                              const Text('No records found yet.',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500)),
                              const Text('Play some matches to see rankings!',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        );
                      }

                      final validStats = statsList.where((p) {
                        double? s = _tabIndex == 0
                            ? p.battingRankScore
                            : _tabIndex == 1
                                ? p.bowlingRankScore
                                : p.impactRankScore;
                        return s != null;
                      }).toList();
                      final top3 = validStats.take(3).toList();
                      final hasPodium = top3.isNotEmpty;

                      return ListView.builder(
                        key: ValueKey('list_${_tabIndex}_${_selectedFilter}'),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        itemCount: statsList.length + (hasPodium ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (hasPodium && index == 0) {
                            return LeaderboardTopThreePodium(
                                key: ValueKey(
                                    'podium_${_tabIndex}_${_selectedFilter}'),
                                top3,
                                _tabIndex);
                          }

                          final itemIndex = hasPodium ? index - 1 : index;
                          final p = statsList[itemIndex];
                          final score = _tabIndex == 0
                              ? p.battingRankScore
                              : _tabIndex == 1
                                  ? p.bowlingRankScore
                                  : p.impactRankScore;
                          final prevScore = _tabIndex == 0
                              ? p.previousBattingRankScore
                              : _tabIndex == 1
                                  ? p.previousBowlingRankScore
                                  : p.previousImpactRankScore;

                          final int rank = itemIndex + 1;

                          return FadeInEntrance(
                            key: ValueKey('item_${p.id}_${_tabIndex}'),
                            delay: Duration(milliseconds: 100 * (index + 4)),
                            offset: const Offset(0, 30),
                            child: LeaderboardRankCard(
                              key: ValueKey(p.id),
                              stats: p,
                              tabIndex: _tabIndex,
                              rank: rank,
                              score: score,
                              prevScore: prevScore,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // AnnotatedRegion
  }

  Widget _tabText(String label, int i) {
    final bool active = _tabIndex == i;
    return TapBounce(
      onTap: () => setState(() => _tabIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? Colors.white : AppColors.textMuted)),
      ),
    );
  }
}
