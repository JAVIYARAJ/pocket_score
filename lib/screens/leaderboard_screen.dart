import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';
import '../widgets/leaderboard_widgets.dart';
import '../widgets/premium_header.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0); // 0=Batters, 1=Bowlers, 2=Impact
  final ValueNotifier<String?> _filterNotifier = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _tabNotifier.dispose();
    _filterNotifier.dispose();
    super.dispose();
  }

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
            PremiumHeader(
              category: 'RANKINGS',
              title: 'Player Stats',
              showBackButton: false,
              trailing: ScaleEntrance(
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
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _filterNotifier,
                    builder: (context, selectedFilter, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _tabNotifier,
                        builder: (context, tabIndex, _) {
                          return Row(
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
                                      value: selectedFilter,
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
                                      onChanged: (val) => _filterNotifier.value = val,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Tabs
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final tabWidth = constraints.maxWidth / 3;
                                      return SizedBox(
                                        height: 38,
                                        child: Stack(
                                          children: [
                                            AnimatedPositioned(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.fastOutSlowIn,
                                              left: tabIndex * tabWidth,
                                              top: 0,
                                              bottom: 0,
                                              width: tabWidth,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(24),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.primary.withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                _tabText('Batters', 0, tabIndex),
                                                _tabText('Bowlers', 1, tabIndex),
                                                _tabText('Impact', 2, tabIndex),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      );
                    }
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<MatchListBloc, MatchListState>(
                builder: (context, mState) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: _filterNotifier,
                    builder: (context, selectedFilter, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _tabNotifier,
                        builder: (context, tabIndex, _) {
                          // Players are derived from scoreData inside each match.
                          // Guest players are filtered out in calculateAllPlayerStats.
                          final statsMap = calculateAllPlayerStats(
                              mState.matches, const [],
                              scopeGroupId: selectedFilter,
                              scopeTournamentId: selectedFilter);
                              final statsList =
                                  statsMap.values.where((s) => s.matches > 0).toList();

                              // Sort by selected tab rank score
                              statsList.sort((a, b) {
                                double scoreA = tabIndex == 0
                                    ? (a.battingRankScore ?? -1.0)
                                    : tabIndex == 1
                                        ? (a.bowlingRankScore ?? -1.0)
                                        : (a.impactRankScore ?? -1.0);
                                double scoreB = tabIndex == 0
                                    ? (b.battingRankScore ?? -1.0)
                                    : tabIndex == 1
                                        ? (b.bowlingRankScore ?? -1.0)
                                        : (b.impactRankScore ?? -1.0);

                                int cmp = scoreB.compareTo(scoreA); // Descending
                                if (cmp == 0) {
                                  // Tie breakers: More matches played
                                  cmp = b.matches.compareTo(a.matches);
                                  if (cmp == 0 && tabIndex == 0) {
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
                                double? s = tabIndex == 0
                                    ? p.battingRankScore
                                    : tabIndex == 1
                                        ? p.bowlingRankScore
                                        : p.impactRankScore;
                                return s != null;
                              }).toList();
                              final top3 = validStats.take(3).toList();
                              final hasPodium = top3.isNotEmpty;

                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: ListView.builder(
                                  key: ValueKey('list_${tabIndex}_$selectedFilter'),
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                                  itemCount: statsList.length + (hasPodium ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (hasPodium && index == 0) {
                                      return LeaderboardTopThreePodium(
                                          key: ValueKey(
                                              'podium_${tabIndex}_$selectedFilter'),
                                          top3,
                                          tabIndex);
                                    }

                                    final itemIndex = hasPodium ? index - 1 : index;
                                    final p = statsList[itemIndex];
                                    final score = tabIndex == 0
                                        ? p.battingRankScore
                                        : tabIndex == 1
                                            ? p.bowlingRankScore
                                            : p.impactRankScore;
                                    final prevScore = tabIndex == 0
                                        ? p.previousBattingRankScore
                                        : tabIndex == 1
                                            ? p.previousBowlingRankScore
                                            : p.previousImpactRankScore;

                                    final int rank = itemIndex + 1;

                                    return FadeInEntrance(
                                      key: ValueKey('item_${p.id}_$tabIndex'),
                                      delay: Duration(milliseconds: 100 * (index + 4)),
                                      offset: const Offset(0, 30),
                                      child: LeaderboardRankCard(
                                        key: ValueKey(p.id),
                                        stats: p,
                                        tabIndex: tabIndex,
                                        rank: rank,
                                        score: score,
                                        prevScore: prevScore,
                                      ),
                                    );
                                  },
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

  Widget _tabText(String label, int i, int currentIndex) {
    final bool active = currentIndex == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tabNotifier.value = i,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
