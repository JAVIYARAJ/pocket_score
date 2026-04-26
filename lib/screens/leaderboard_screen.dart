import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/match_list_bloc.dart';
import '../bloc/player_bloc.dart';
import '../models/match_models.dart';
import '../theme/animations.dart';
import '../theme/app_theme.dart';
import '../utils/stats_utils.dart';
import '../utils/pdf_utils.dart';
import '../models/player_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tabIndex = 0; // 0=Batters, 1=Bowlers, 2=Impact, 3=Fielding
  String? _selectedFilter;
  DateTime? _selectedDate = DateTime.now(); // Default to Today

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
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFAAAAAA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text('Player Rankings', 
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Share Button
                    TapBounce(
                      onTap: () => _shareReport(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TapBounce(
                      onTap: () => _showFilterBottomSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null ? 'All Time' : _isSameDay(_selectedDate!, DateTime.now()) ? 'Today' : '${_selectedDate!.day}/${_selectedDate!.month}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tabs Header
            FadeInEntrance(
              delay: const Duration(milliseconds: 200),
              offset: const Offset(0, 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tabText('Batting', 0),
                      const SizedBox(width: 8),
                      _tabText('Bowling', 1),
                      const SizedBox(width: 8),
                      _tabText('Impact', 2),
                      const SizedBox(width: 8),
                      _tabText('Fielding', 3),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, pState) {
                  return BlocBuilder<MatchListBloc, MatchListState>(
                    builder: (context, mState) {
                      final statsMap = calculateAllPlayerStats(mState.matches, pState.players, scopeGroupId: _selectedFilter, scopeTournamentId: _selectedFilter, scopeDate: _selectedDate);
                      final statsList = statsMap.values.where((s) => s.matches > 0).toList();

                      // Sort by selected tab rank score
                      statsList.sort((a, b) {
                        double scoreA = _tabIndex == 0 ? (a.battingRankScore ?? -1.0) : _tabIndex == 1 ? (a.bowlingRankScore ?? -1.0) : _tabIndex == 2 ? (a.impactRankScore ?? -1.0) : (a.catches.toDouble() * 2 + a.runOuts.toDouble() * 3);
                        double scoreB = _tabIndex == 0 ? (b.battingRankScore ?? -1.0) : _tabIndex == 1 ? (b.bowlingRankScore ?? -1.0) : _tabIndex == 2 ? (b.impactRankScore ?? -1.0) : (b.catches.toDouble() * 2 + b.runOuts.toDouble() * 3);

                        int cmp = scoreB.compareTo(scoreA); // Descending
                        if (cmp == 0) {
                          // Tie breakers: More matches played
                          cmp = b.matches.compareTo(a.matches);
                          if (cmp == 0 && _tabIndex == 0) {
                            // higher boundary %
                            cmp = b.boundaryPercent.compareTo(a.boundaryPercent);
                          } else if (cmp == 0 && _tabIndex == 3) {
                            // more catches
                            cmp = b.catches.compareTo(a.catches);
                          }
                        }
                        return cmp;
                      });

                      if (statsList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.1)),
                              const SizedBox(height: 16),
                              const Text('No records found yet.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                              const Text('Play some matches to see rankings!', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        );
                      }

                      final validStats = statsList.where((p) {
                        if (_tabIndex == 3) return true; // Fielding always valid if matches > 0
                        double? s = _tabIndex == 0 ? p.battingRankScore : _tabIndex == 1 ? p.bowlingRankScore : p.impactRankScore;
                        return s != null;
                      }).toList();
                      final top3 = validStats.take(3).toList();
                      final hasPodium = top3.isNotEmpty;


                      return ListView.builder(
                        key: ValueKey('list_${_tabIndex}_$_selectedFilter'),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        itemCount: statsList.length + (hasPodium ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (hasPodium && index == 0) {
                            return _TopThreePodium(
                              key: ValueKey('podium_${_tabIndex}_$_selectedFilter'),
                              top3, 
                              _tabIndex
                            );
                          }

                          final itemIndex = hasPodium ? index - 1 : index;
                          final p = statsList[itemIndex];
                          final score = _tabIndex == 0 ? p.battingRankScore : _tabIndex == 1 ? p.bowlingRankScore : _tabIndex == 2 ? p.impactRankScore : (p.catches * 2 + p.runOuts * 3).toDouble();
                          final prevScore = _tabIndex == 0 ? p.previousBattingRankScore : _tabIndex == 1 ? p.previousBowlingRankScore : _tabIndex == 2 ? p.previousImpactRankScore : null;

                          final int rank = itemIndex + 1;

                          return FadeInEntrance(
                            key: ValueKey('item_${p.id}_$_tabIndex'),
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
          color: active ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary.withOpacity(0.5) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w900 : FontWeight.bold, color: active ? AppColors.primary : AppColors.textMuted)),
      ),
    );
  }

  void _shareReport(BuildContext context) async {
    final mState = context.read<MatchListBloc>().state;
    final pState = context.read<PlayerBloc>().state;

    final statsMap = calculateAllPlayerStats(
      mState.matches, 
      pState.players, 
      scopeGroupId: _selectedFilter, 
      scopeTournamentId: _selectedFilter, 
      scopeDate: _selectedDate
    );

    final List<PlayerStats> allStats = statsMap.values.where((s) => s.matches > 0).toList();

    List<PlayerStats> getSorted(int type) {
      final list = List<PlayerStats>.from(allStats.where((p) {
        if (type == 3) return true; // fielding always valid if matches > 0
        double? s = type == 0 ? p.battingRankScore : type == 1 ? p.bowlingRankScore : type == 2 ? p.impactRankScore : null;
        return s != null;
      }));
      list.sort((a, b) {
        double scoreA = type == 0 ? (a.battingRankScore ?? -1.0) : type == 1 ? (a.bowlingRankScore ?? -1.0) : type == 2 ? (a.impactRankScore ?? -1.0) : (a.catches * 2 + a.runOuts * 3).toDouble();
        double scoreB = type == 0 ? (b.battingRankScore ?? -1.0) : type == 1 ? (b.bowlingRankScore ?? -1.0) : type == 2 ? (b.impactRankScore ?? -1.0) : (b.catches * 2 + b.runOuts * 3).toDouble();
        return scoreB.compareTo(scoreA);
      });
      return list;
    }

    final List<MatchSummary> filteredMatches = mState.matches.where((m) {
      if (_selectedDate != null) {
        if (!_isSameDay(m.createdAt, _selectedDate!)) return false;
      }
      if (_selectedFilter != null) {
        if (m.groupId != _selectedFilter && m.tournamentId != _selectedFilter) return false;
      }
      return true;
    }).toList();

    List<MatchMoM> matchMoMs = [];
    for (var m in filteredMatches) {
      final mStatsMap = calculateAllPlayerStats([m], pState.players);
      final mStatsList = mStatsMap.values.where((s) => s.matches > 0).toList();
      
      // Determine winning team for ICC-style MoM weighting
      String? winner;
      if (m.status == 'completed') {
        if ((m.teamAScore ?? 0) > (m.teamBScore ?? 0)) winner = m.teamAName;
        else if ((m.teamBScore ?? 0) > (m.teamAScore ?? 0)) winner = m.teamBName;
      }

      mStatsList.sort((a, b) {
        bool wonA = false;
        bool wonB = false;
        if (winner != null) {
          final inTeamA = m.teamA?.players.any((p) => p.id == a.id) ?? false;
          final inTeamB = m.teamB?.players.any((p) => p.id == a.id) ?? false;
          wonA = (inTeamA && winner == m.teamAName) || (inTeamB && winner == m.teamBName);
          
          final inTeamA_B = m.teamA?.players.any((p) => p.id == b.id) ?? false;
          final inTeamB_B = m.teamB?.players.any((p) => p.id == b.id) ?? false;
          wonB = (inTeamA_B && winner == m.teamAName) || (inTeamB_B && winner == m.teamBName);
        }
        
        double impactA = RankCalculator.calculateMatchImpact(a, won: wonA);
        double impactB = RankCalculator.calculateMatchImpact(b, won: wonB);
        return impactB.compareTo(impactA);
      });

      if (mStatsList.isNotEmpty) {
        final mom = mStatsList.first;
        String perf = "";
        if (mom.runs > 0) perf += "${mom.runs} runs";
        if (mom.wickets > 0) perf += (perf.isEmpty ? "" : ", ") + "${mom.wickets} wkts";
        if (mom.catches > 0) perf += (perf.isEmpty ? "" : ", ") + "${mom.catches} catches";
        if (mom.runOuts > 0) perf += (perf.isEmpty ? "" : ", ") + "${mom.runOuts} runouts";
        
        matchMoMs.add(MatchMoM(
          matchName: "${m.teamAName} vs ${m.teamBName}",
          momName: mom.name,
          performance: perf.isEmpty ? "All-round effort" : perf,
        ));
      }
    }

    String filterTag = 'All Time';
    if (_selectedDate != null) {
      if (_isSameDay(_selectedDate!, DateTime.now())) {
        filterTag = 'Today';
      } else {
        filterTag = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
      }
    }
    if (_selectedFilter != null) {
      filterTag += ' - $_selectedFilter';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF Report...'), duration: Duration(seconds: 1)),
    );

    await PdfUtils.shareRankingsPdf(
      batters: getSorted(0),
      bowlers: getSorted(1),
      impact: getSorted(2),
      fielding: getSorted(3),
      matchMoMs: matchMoMs,
      filterTag: filterTag,
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Rankings Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 24),
                
                const Text('TIME PERIOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateChip('All Time', null, setSheetState)),
                    const SizedBox(width: 12),
                    Expanded(child: _dateChip('Today', DateTime.now(), setSheetState)),
                  ],
                ),
                const SizedBox(height: 12),
                _dateChip(
                  _selectedDate == null || _isSameDay(_selectedDate!, DateTime.now()) 
                    ? 'Pick Specific Date' 
                    : 'Selected: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  _selectedDate,
                  setSheetState,
                  isPicker: true
                ),
                
                const SizedBox(height: 32),
                BlocBuilder<MatchListBloc, MatchListState>(
                  builder: (context, mState) {
                    final Set<String> groups = {};
                    for (var m in mState.matches) {
                      if (m.groupId != null) groups.add(m.groupId!);
                      else if (m.tournamentId != null) groups.add(m.tournamentId!);
                    }
                    if (groups.isEmpty) return const SizedBox.shrink();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GROUP / TOURNAMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: DropdownButton<String?>(
                            value: _selectedFilter,
                            hint: const Text('All Matches', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                            dropdownColor: AppColors.surfaceLight,
                            underline: const SizedBox(),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Matches', style: TextStyle(color: Colors.white))),
                              ...groups.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: Colors.white)))),
                            ],
                            onChanged: (val) {
                              setSheetState(() => _selectedFilter = val);
                              setState(() => _selectedFilter = val);
                            },
                          ),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 32),
                TapBounce(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _dateChip(String label, DateTime? date, StateSetter setSheetState, {bool isPicker = false}) {
    bool active = false;
    if (!isPicker) {
      if (date == null) {
        active = _selectedDate == null;
      } else {
        active = _selectedDate != null && _isSameDay(_selectedDate!, date);
      }
    } else {
      active = _selectedDate != null && !_isSameDay(_selectedDate!, DateTime.now()) && !_isSameDay(_selectedDate!, DateTime(0)); // check against null/today
    }

    return TapBounce(
      onTap: () async {
        if (isPicker) {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surfaceLight,
                    onSurface: AppColors.textPrimary,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setSheetState(() => _selectedDate = picked);
            setState(() => _selectedDate = picked);
          }
        } else {
          setSheetState(() => _selectedDate = date);
          setState(() => _selectedDate = date);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? AppColors.primary.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPicker) ...[
              Icon(Icons.calendar_month_rounded, size: 16, color: active ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? AppColors.primary : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
        children: [
          for (int i = 0; i < order.length; i++) ...[
            Builder(builder: (context) {
              final idx = order[i];
              if (idx >= widget.top3.length) return const Expanded(child: SizedBox());

              final p = widget.top3[idx];
              final rank = idx + 1;
              final double baseHeight = rank == 1 ? 150 : rank == 2 ? 110 : 90;
              final color = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFE0E0E0) : const Color(0xFFCD7F32);
              final deepColor = rank == 1 ? const Color(0xFFB8860B) : rank == 2 ? const Color(0xFF9E9E9E) : const Color(0xFF8B4513);

              return Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (ctx, child) {
                    return Opacity(
                      opacity: _opacityAnimations[idx].value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _heightAnimations[idx].value)),
                        child: _buildStep(p, rank, baseHeight * _heightAnimations[idx].value, color, deepColor),
                      ),
                    );
                  },
                ),
              );
            }),
            if (i < order.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(PlayerStats p, int rank, double height, Color color, Color deepColor) {
    final score = widget.tabIndex == 0 ? p.battingRankScore : widget.tabIndex == 1 ? p.bowlingRankScore : widget.tabIndex == 2 ? p.impactRankScore : (p.catches * 2 + p.runOuts * 3).toDouble();
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
                  colors: [color.withOpacity(0.2), deepColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, spreadRadius: 2),
                ],
                border: Border.all(color: color.withOpacity(0.8), width: isFirst ? 3 : 2),
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
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
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
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(score!.toStringAsFixed(widget.tabIndex == 3 ? 0 : 1), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.35), deepColor.withOpacity(0.05), Colors.transparent],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
            ],
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 6,
                child: Text('$rank', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color.withOpacity(0.15), height: 1)),
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
              colors: noData ? [Colors.white.withOpacity(0.02), Colors.transparent] : [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isTop3 ? rankColor.withOpacity(0.4) : Colors.white.withOpacity(0.05), width: isTop3 ? 1.5 : 1),
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
                    Text(s.role.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted.withOpacity(0.6), letterSpacing: 0.8))
                  ])),
                  if (noData)
                    const Text('NOT ENOUGH DATA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted))
                  else ...[
                    if (widget.tabIndex == 0)
                      _miniStat('R', '${s.runs}')
                    else if (widget.tabIndex == 1)
                      _miniStat('W', '${s.wickets}', AppColors.danger)
                    else if (widget.tabIndex == 2) ...[
                      _miniStat('R', '${s.runs}'),
                      _miniStat('W', '${s.wickets}', AppColors.danger),
                    ] else
                      _miniStat('C', '${s.catches}', Colors.orange),
                    const SizedBox(width: 4),
                    if (widget.tabIndex != 3) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: trendColor.withOpacity(0.15)),
                        child: Icon(trendIcon, size: 12, color: trendColor),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(widget.score!.toStringAsFixed(widget.tabIndex == 3 ? 0 : 1), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
                    )
                  ]
                ],
              ),
              if (_expanded && !noData) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 12),
                if (widget.tabIndex == 0) _battingDetails(s)
                else if (widget.tabIndex == 1) _bowlingDetails(s)
                else if (widget.tabIndex == 2) _impactDetails(s)
                else _fieldingDetails(s)
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
            _detailItem('MAT', '${s.matches}'),
            _detailItem('INNS', '${s.inningsBatted}'),
            _detailItem('RUNS', '${s.runs}'),
            _detailItem('AVG', s.average.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('S/R', s.strikeRate.toStringAsFixed(1)),
            _detailItem('4s/6s', '${s.fours}/${s.sixes}'),
            _detailItem('50s', '${s.fifties}'),
            _detailItem('BDRY%', '${s.boundaryPercent.toStringAsFixed(0)}%'),
          ],
        ),
      ],
    );
  }

  Widget _bowlingDetails(PlayerStats s) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('MAT', '${s.matches}'),
            _detailItem('INNS', '${s.matchesBowled}'),
            _detailItem('WKTS', '${s.wickets}'),
            _detailItem('ECON', s.economy.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _detailItem('OVERS', s.oversBowled),
            _detailItem('RUNS', '${s.runsConceded}'),
            _detailItem('W/M', s.wicketsPerMatch.toStringAsFixed(1)),
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
        _detailItem('BATTING', s.battingRankScore?.toStringAsFixed(1) ?? '-'),
        _detailItem('BOWLING', s.bowlingRankScore?.toStringAsFixed(1) ?? '-'),
        _detailItem('FIELDING', '${s.fieldingBonus}'),
      ],
    );
  }

  Widget _fieldingDetails(PlayerStats s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _detailItem('CATCHES', '${s.catches}'),
        _detailItem('RUN OUTS', '${s.runOuts}'),
        _detailItem('BONUS', '+${s.fieldingBonus}'),
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
        color: (color ?? Colors.white).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (color ?? Colors.white).withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: (color ?? AppColors.textPrimary).withOpacity(0.7), fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color ?? AppColors.textPrimary)),
        ]
      )
    );
  }
}
