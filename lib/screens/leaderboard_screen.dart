import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/player_bloc.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
        ),
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 24, bottom: 24),
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
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFAAAAAA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text('Rankings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ScaleEntrance(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.1), blurRadius: 20)],
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 32),
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
                  if (m.groupId != null) groups.add(m.groupId!);
                  else if (m.tournamentId != null) groups.add(m.tournamentId!);
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: DropdownButton<String?>(
                                value: _selectedFilter,
                                hint: const Text('All Matches', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                dropdownColor: AppColors.surfaceLight,
                                underline: const SizedBox(),
                                icon: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18)),
                                isDense: true,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Matches', style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                                  ...filterList.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold)))),
                                ],
                                onChanged: (val) => setState(() => _selectedFilter = val),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Tabs
                        _tabText('Batters', 0),
                        const SizedBox(width: 8),
                        _tabText('Bowlers', 1),
                        const SizedBox(width: 8),
                        _tabText('Impact', 2),
                      ],
                    ),
                  ),
                );
              }
            ),

            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, pState) {
                  return BlocBuilder<MatchListBloc, MatchListState>(
                    builder: (context, mState) {
                      final statsMap = calculateAllPlayerStats(mState.matches, pState.players, scopeGroupId: _selectedFilter, scopeTournamentId: _selectedFilter);
                      final statsList = statsMap.values.where((s) => s.matches > 0).toList();

                      // Sort by selected tab rank score
                      statsList.sort((a, b) {
                        double scoreA = _tabIndex == 0 ? (a.battingRankScore ?? -1.0) : _tabIndex == 1 ? (a.bowlingRankScore ?? -1.0) : (a.impactRankScore ?? -1.0);
                        double scoreB = _tabIndex == 0 ? (b.battingRankScore ?? -1.0) : _tabIndex == 1 ? (b.bowlingRankScore ?? -1.0) : (b.impactRankScore ?? -1.0);

                        int cmp = scoreB.compareTo(scoreA); // Descending
                        if (cmp == 0) {
                          // Tie breakers: More matches played
                          cmp = b.matches.compareTo(a.matches);
                          if (cmp == 0 && _tabIndex == 0) {
                            // higher boundary %
                            cmp = b.boundaryPercent.compareTo(a.boundaryPercent);
                          }
                        }
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

                      final validStats = statsList.where((p) {
                        double? s = _tabIndex == 0 ? p.battingRankScore : _tabIndex == 1 ? p.bowlingRankScore : p.impactRankScore;
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
                            return _TopThreePodium(
                              key: ValueKey('podium_${_tabIndex}_${_selectedFilter}'),
                              top3, 
                              _tabIndex
                            );
                          }

                          final itemIndex = hasPodium ? index - 1 : index;
                          final p = statsList[itemIndex];
                          final score = _tabIndex == 0 ? p.battingRankScore : _tabIndex == 1 ? p.bowlingRankScore : p.impactRankScore;
                          final prevScore = _tabIndex == 0 ? p.previousBattingRankScore : _tabIndex == 1 ? p.previousBowlingRankScore : p.previousImpactRankScore;

                          final bool noData = score == null;
                          final int rank = itemIndex + 1;

                          return FadeInEntrance(
                            key: ValueKey('item_${p.id}_${_tabIndex}'),
                            delay: Duration(milliseconds: 100 * (index + 4)),
                            offset: const Offset(0, 30),
                            child: _RankCard(
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
      ),
    );
  }

  Widget _tabText(String label, int i) {
    final bool active = _tabIndex == i;
    return TapBounce(
      onTap: () => setState(() => _tabIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w900 : FontWeight.bold, color: active ? AppColors.primary : AppColors.textMuted)),
      ),
    );
  }
}

class _TopThreePodium extends StatefulWidget {
  final List<PlayerStats> top3;
  final int tabIndex;

  const _TopThreePodium(this.top3, this.tabIndex, {super.key});

  @override
  State<_TopThreePodium> createState() => _TopThreePodiumState();
}

class _TopThreePodiumState extends State<_TopThreePodium> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _heightAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _heightAnimations = List.generate(3, (i) {
      final double start = i * 0.15;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, start + 0.4, curve: Curves.easeOutBack),
      );
    });

    _opacityAnimations = List.generate(3, (i) {
      final double start = i * 0.15;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, start + 0.2, curve: Curves.easeIn),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.top3.isEmpty) return const SizedBox.shrink();
    final List<int> order = [1, 0, 2];

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: order.map((i) {
          if (i >= widget.top3.length) return const Expanded(child: SizedBox());

          final p = widget.top3[i];
          final rank = i + 1;
          final double baseHeight = rank == 1 ? 150 : rank == 2 ? 110 : 90;
          final color = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFE0E0E0) : const Color(0xFFCD7F32);
          final deepColor = rank == 1 ? const Color(0xFFB8860B) : rank == 2 ? const Color(0xFF9E9E9E) : const Color(0xFF8B4513);

          return Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (ctx, child) {
                return Opacity(
                  opacity: _opacityAnimations[i].value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _heightAnimations[i].value)),
                    child: _buildStep(p, rank, baseHeight * _heightAnimations[i].value, color, deepColor),
                  ),
                );
              },
            ),
          );
        }).toList().expand((w) => [w, if (w != order.last) const SizedBox(width: 12)]).toList(),
      ),
    );
  }

  Widget _buildStep(PlayerStats p, int rank, double height, Color color, Color deepColor) {
    final score = widget.tabIndex == 0 ? p.battingRankScore : widget.tabIndex == 1 ? p.bowlingRankScore : widget.tabIndex == 2 ? p.impactRankScore : 0.0;
    final isFirst = rank == 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isFirst ? 64 : 52,
              height: isFirst ? 64 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), deepColor.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 2),
                ],
                border: Border.all(color: color.withValues(alpha: 0.8), width: isFirst ? 3 : 2),
              ),
              alignment: Alignment.center,
              child: Text(p.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: isFirst ? 28 : 20)),
            ),
            if (isFirst)
              Positioned(
                top: -20,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                ),
              )
          ],
        ),
        const SizedBox(height: 12),
        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5), overflow: TextOverflow.ellipsis, maxLines: 1),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(score!.toStringAsFixed(1), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.35), deepColor.withValues(alpha: 0.05), Colors.transparent],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))
            ],
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 6,
                child: Text('$rank', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.15), height: 1)),
              ),
            ],
          ),
        )
      ]
    );
  }
}

class _RankCard extends StatefulWidget {
  final PlayerStats stats;
  final int tabIndex; // 0 Batting, 1 Bowling, 2 Impact
  final int? rank; // null if not enough data
  final double? score;
  final double? prevScore;

  const _RankCard({super.key, required this.stats, required this.tabIndex, required this.rank, required this.score, required this.prevScore});

  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final bool noData = widget.score == null;

    final isTop3 = widget.rank != null && widget.rank! <= 3;
    final rankColor = widget.rank == 1 ? const Color(0xFFFFD700) : widget.rank == 2 ? const Color(0xFFC0C0C0) : widget.rank == 3 ? const Color(0xFFCD7F32) : AppColors.textMuted;

    IconData trendIcon = Icons.remove;
    Color trendColor = AppColors.textMuted;
    if (widget.score != null && widget.prevScore != null) {
      if (widget.score! > widget.prevScore!) { trendIcon = Icons.arrow_upward; trendColor = AppColors.success; }
      else if (widget.score! < widget.prevScore!) { trendIcon = Icons.arrow_downward; trendColor = AppColors.danger; }
    } else if (widget.score != null && widget.prevScore == null) {
      trendIcon = Icons.arrow_upward; trendColor = AppColors.success;
    }

    return TapBounce(
      onTap: () {
        if (!noData) setState(() => _expanded = !_expanded);
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: noData ? [Colors.white.withValues(alpha: 0.02), Colors.transparent] : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isTop3 ? rankColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05), width: isTop3 ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: 32, alignment: Alignment.center, child: noData ? const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted) : Text('#${widget.rank}', style: TextStyle(fontWeight: FontWeight.w900, color: rankColor, fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: noData ? AppColors.textMuted : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(s.role.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted.withValues(alpha: 0.6), letterSpacing: 0.8))
                  ])),
                  if (noData)
                    const Text('NOT ENOUGH DATA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted))
                  else ...[
                    if (widget.tabIndex == 0)
                      _miniStat('R', '${s.runs}')
                    else if (widget.tabIndex == 1)
                      _miniStat('W', '${s.wickets}', AppColors.danger)
                    else ...[
                      _miniStat('R', '${s.runs}'),
                      _miniStat('W', '${s.wickets}', AppColors.danger),
                    ],
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: trendColor.withValues(alpha: 0.15)),
                      child: Icon(trendIcon, size: 12, color: trendColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(widget.score!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
                    )
                  ]
                ],
              ),
              if (_expanded && !noData) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                const SizedBox(height: 12),
                if (widget.tabIndex == 0) _battingDetails(s)
                else if (widget.tabIndex == 1) _bowlingDetails(s)
                else _impactDetails(s)
              ],
              if (noData && _expanded) ...[
                const SizedBox(height: 8),
                const Text('Needs minimum matches to qualify.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _battingDetails(PlayerStats s) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('INNS', '${s.inningsBatted}'),
            _detailItem('RUNS', '${s.runs}'),
            _detailItem('AVG', s.average.toStringAsFixed(1)),
            _detailItem('SR', s.strikeRate.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('50s', '${s.fifties}'),
            _detailItem('4s', '${s.fours}'),
            _detailItem('6s', '${s.sixes}'),
            _detailItem('BND %', '${s.boundaryPercent.toStringAsFixed(0)}%'),
          ],
        ),
      ],
    );
  }

  Widget _bowlingDetails(PlayerStats s) {
    final String overs = '${s.ballsBowled ~/ 6}.${s.ballsBowled % 6}';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('MAT', '${s.matchesBowled}'),
            _detailItem('WKTS', '${s.wickets}'),
            _detailItem('ECO', s.economy.toStringAsFixed(1)),
            _detailItem('W/M', s.wicketsPerMatch.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('OVERS', overs),
            _detailItem('RUNS', '${s.runsConceded}'),
            _detailItem('DOT %', '${s.dotBallPercent.toStringAsFixed(0)}%'),
          ],
        ),
      ],
    );
  }

  Widget _impactDetails(PlayerStats s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _detailItem('BAT RNK', s.battingRankScore?.toStringAsFixed(1) ?? '-'),
        _detailItem('BOWL RNK', s.bowlingRankScore?.toStringAsFixed(1) ?? '-'),
        _detailItem('FLD PTS', '${s.fieldingBonus}'),
      ],
    );
  }

  Widget _detailItem(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ]
    );
  }

  Widget _miniStat(String label, String val, [Color? color]) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (color ?? Colors.white).withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: (color ?? AppColors.textPrimary).withValues(alpha: 0.7), fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color ?? AppColors.textPrimary)),
        ]
      )
    );
  }
}
