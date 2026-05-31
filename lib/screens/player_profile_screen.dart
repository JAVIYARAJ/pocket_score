import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayerProfileScreen — view any registered player's cricket profile & stats.
// ─────────────────────────────────────────────────────────────────────────────
class PlayerProfileScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  final String? avatarUrl;

  const PlayerProfileScreen({
    super.key,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final _tabNotifier = ValueNotifier<int>(0);
  late final Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _tabNotifier.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetch() async {
    final result = await Supabase.instance.client
        .rpc('get_player_profile_stats', params: {'p_user_id': widget.userId});
    return result != null ? Map<String, dynamic>.from(result as Map) : null;
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
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _buildSkeleton(context);
            }
            if (snap.hasError || snap.data == null) {
              return _buildError(context);
            }
            final profile = Map<String, dynamic>.from(
                snap.data!['profile'] as Map? ?? {});
            final statsRaw = Map<String, dynamic>.from(
                snap.data!['stats'] as Map? ?? {});
            final playerStats = _buildStats(profile, statsRaw);
            return _buildContent(context, profile, playerStats);
          },
        ),
      ),
    );
  }

  // ── Build PlayerStats from raw RPC numbers ────────────────────────────────
  PlayerStats _buildStats(
      Map<String, dynamic> profile, Map<String, dynamic> raw) {
    final id   = widget.userId;
    final name = profile['full_name'] as String? ??
        widget.displayName ?? 'Player';
    final roleStr = profile['player_role'] as String? ?? 'allRounder';
    final role = PlayerRole.values.firstWhere(
      (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
      orElse: () => PlayerRole.allRounder,
    );

    final p = PlayerStats(id: id, name: name, role: role);
    p.matches        = _i(raw['matches']);
    p.inningsBatted  = _i(raw['innings_batted']);
    p.runs           = _i(raw['runs']);
    p.ballsFaced     = _i(raw['balls_faced']);
    p.fours          = _i(raw['fours']);
    p.sixes          = _i(raw['sixes']);
    p.dismissals     = _i(raw['dismissals']);
    p.fifties        = _i(raw['fifties']);
    p.hundreds       = _i(raw['hundreds']);
    p.highestScore   = _i(raw['highest_score']);
    p.matchesBowled  = _i(raw['matches_bowled']);
    p.wickets        = _i(raw['wickets']);
    p.runsConceded   = _i(raw['runs_conceded']);
    p.ballsBowled    = _i(raw['balls_bowled']);
    p.dotBalls       = _i(raw['dot_balls']);
    p.catches        = _i(raw['catches']);
    p.runOuts        = _i(raw['run_outs']);

    final bbW = raw['best_bowling_wickets'];
    if (bbW != null) {
      p.bestBowlingWickets = _i(bbW);
      p.bestBowlingRuns    = _i(raw['best_bowling_runs']);
    }

    final recentBat = raw['recent_batting_innings'];
    if (recentBat is List) {
      p.recentBattingInnings = recentBat.map((e) => (e as num).toInt()).toList();
    }
    final recentBowl = raw['recent_bowling_innings'];
    if (recentBowl is List) {
      p.recentBowlingInnings = recentBowl.map((e) => (e as num).toInt()).toList();
    }

    p.battingRankScore = RankCalculator.calcGullyBattingRank(p, 'gully');
    p.bowlingRankScore = RankCalculator.calcGullyBowlingRank(p, 'gully');
    p.impactRankScore  = RankCalculator.calcImpactPlayerRank(p, 'gully');
    return p;
  }

  int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  // ── Full content ──────────────────────────────────────────────────────────
  Widget _buildContent(BuildContext context, Map<String, dynamic> profile,
      PlayerStats s) {
    final top     = MediaQuery.of(context).padding.top;
    final name    = profile['full_name'] as String? ?? widget.displayName ?? 'Player';
    final avatar  = profile['avatar_url'] as String? ?? widget.avatarUrl;
    final role    = profile['player_role'] as String? ?? 'All-Rounder';
    final batting = profile['batting_style'] as String? ?? '—';
    final bowling = profile['bowling_style'] as String? ?? '—';
    final ovr     = s.impactRankScore?.round() ?? 0;
    final ovrColor = ovr >= 80 ? Colors.amber
        : ovr >= 60 ? Colors.cyanAccent
        : AppColors.textMuted;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Header — green gradient + cricket pitch ───────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 12, 20, 28),
                  child: Column(
                    children: [
                      // Back + title
                      Row(children: [
                        TapBounce(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const Spacer(),
                        const Text('PLAYER PROFILE',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const SizedBox(width: 34),
                      ]),
                      const SizedBox(height: 20),

                      // ── Glassmorphic player card ───────────────────────
                      FadeInEntrance(
                        offset: const Offset(0, 20),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: ovr >= 80
                                            ? [Colors.amber, Colors.orangeAccent]
                                            : [AppColors.primaryLight, Colors.cyan],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (ovr >= 80
                                                  ? Colors.amber
                                                  : AppColors.primaryLight)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 34,
                                      backgroundColor: AppColors.primary,
                                      backgroundImage: (avatar != null &&
                                              avatar.isNotEmpty)
                                          ? NetworkImage(avatar)
                                          : null,
                                      child: (avatar == null || avatar.isEmpty)
                                          ? Text(
                                              name[0].toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Name + role
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(name,
                                            style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: -0.3)),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.flash_on_rounded,
                                                  color: Colors.amber,
                                                  size: 12),
                                              const SizedBox(width: 4),
                                              Text(role.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      letterSpacing: 0.8)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // OVR badge
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: ovrColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color:
                                              ovrColor.withValues(alpha: 0.4),
                                          width: 2),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('$ovr',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: ovrColor,
                                                height: 1)),
                                        Text('OVR',
                                            style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: ovrColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Colors.white12),
                              const SizedBox(height: 14),

                              // Batting / Bowling style row
                              Row(children: [
                                Expanded(
                                    child: _styleColumn(
                                        '🏏 BATTING', batting)),
                                Container(
                                    width: 1,
                                    height: 28,
                                    color: Colors.white12),
                                Expanded(
                                    child: _styleColumn(
                                        '⚾ BOWLING', bowling)),
                              ]),
                              const SizedBox(height: 14),
                              const Divider(height: 1, color: Colors.white12),
                              const SizedBox(height: 14),

                              // Career quick-stats strip
                              Row(
                                children: [
                                  _quickStat('Matches', '${s.matches}'),
                                  _vDivider(),
                                  _quickStat('Runs', '${s.runs}'),
                                  _vDivider(),
                                  _quickStat('Wickets', '${s.wickets}'),
                                  _vDivider(),
                                  _quickStat('Catches', '${s.catches}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tab selector ─────────────────────────────────────────────────
          ValueListenableBuilder<int>(
            valueListenable: _tabNotifier,
            builder: (context, tab, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _tabSelector(tab),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _tabContent(tab, s),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 0.3)),
        ]),
      );

  Widget _vDivider() => Container(width: 1, height: 28, color: Colors.white12);

  Widget _styleColumn(String label, String value) => Column(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ]);

  // ── Tab selector ────────────────────────────────────────────────────────
  Widget _tabSelector(int active) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / 3;
        return SizedBox(
          height: 38,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              left: active * w,
              top: 0, bottom: 0, width: w,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
              ),
            ),
            Row(children: [
              _tab(0, '🏏 Batting', active),
              _tab(1, '⚾ Bowling', active),
              _tab(2, '⚡ Impact', active),
            ]),
          ]),
        );
      }),
    );
  }

  Widget _tab(int i, String label, int active) => Expanded(
        child: TapBounce(
          onTap: () => _tabNotifier.value = i,
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active == i ? Colors.white : AppColors.textMuted,
                letterSpacing: 0.4,
              ),
              child: Text(label),
            ),
          ),
        ),
      );

  // ── Tab content ─────────────────────────────────────────────────────────
  Widget _tabContent(int tab, PlayerStats s) {
    if (tab == 0) return _battingTab(s);
    if (tab == 1) return _bowlingTab(s);
    return _impactTab(s);
  }

  // ── Batting tab ──────────────────────────────────────────────────────────
  Widget _battingTab(PlayerStats s) {
    if (s.inningsBatted == 0) return _empty('No batting data yet.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent form strip
        if (s.recentBattingInnings.isNotEmpty) ...[
          _sectionLabel('RECENT FORM', Icons.show_chart_rounded, AppColors.info),
          const SizedBox(height: 10),
          _recentBattingStrip(s.recentBattingInnings),
          const SizedBox(height: 20),
        ],

        _sectionLabel('BATTING STATS', Icons.sports_cricket_rounded, AppColors.primary),
        const SizedBox(height: 10),

        _grid([
          _card('Innings',     '${s.inningsBatted}',         Icons.calendar_today_rounded, AppColors.primary),
          _card('Runs',        '${s.runs}',                  Icons.scoreboard_outlined,    AppColors.info),
          _card('Average',     s.average > 0 ? s.average.toStringAsFixed(1) : '—',
              Icons.trending_up_rounded, Colors.amber),
          _card('Strike Rate', s.strikeRate > 0 ? s.strikeRate.toStringAsFixed(1) : '—',
              Icons.bolt_rounded, Colors.orange),
          _card('Highest',     s.highestScore > 0 ? '${s.highestScore}' : '—',
              Icons.emoji_events_rounded, Colors.amber),
          _card('Not Outs',    '${s.notOuts}',               Icons.shield_rounded,         AppColors.success),
          _card('Fours (4s)',  '${s.fours}',                 Icons.arrow_outward_rounded,  Colors.blue),
          _card('Sixes (6s)',  '${s.sixes}',                 Icons.rocket_launch_rounded,  Colors.purple),
          _card('Fifties',     '${s.fifties}',               Icons.stars_rounded,          Colors.orange),
          _card('Hundreds',    '${s.hundreds}',              Icons.workspace_premium_rounded, Colors.amber),
          _card('Boundary %',  s.boundaryPercent > 0 ? '${s.boundaryPercent.toStringAsFixed(1)}%' : '—',
              Icons.percent_rounded, AppColors.accent),
          _card('Matches',     '${s.matches}',               Icons.sports_cricket_rounded, AppColors.success),
        ]),
      ],
    );
  }

  // ── Bowling tab ──────────────────────────────────────────────────────────
  Widget _bowlingTab(PlayerStats s) {
    if (s.matchesBowled == 0) return _empty('No bowling data yet.');
    final bestFigures = s.bestBowlingWickets != null
        ? '${s.bestBowlingWickets}/${s.bestBowlingRuns}'
        : '—';
    final bowlAvg = s.bowlingAverage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent bowling form strip
        if (s.recentBowlingInnings.isNotEmpty) ...[
          _sectionLabel('RECENT FORM', Icons.show_chart_rounded, AppColors.danger),
          const SizedBox(height: 10),
          _recentBowlingStrip(s.recentBowlingInnings),
          const SizedBox(height: 20),
        ],

        _sectionLabel('BOWLING STATS', Icons.sports_baseball_rounded, AppColors.danger),
        const SizedBox(height: 10),

        _grid([
          _card('Wickets',     '${s.wickets}',               Icons.sports_baseball_rounded, AppColors.danger),
          _card('Economy',     s.economy > 0 ? s.economy.toStringAsFixed(2) : '—',
              Icons.speed_rounded, Colors.indigo),
          _card('Overs',       _overs(s.ballsBowled),        Icons.timer_rounded,           AppColors.accent),
          _card('Dot Ball %',
              s.dotBallPercent > 0 ? '${s.dotBallPercent.toStringAsFixed(1)}%' : '—',
              Icons.circle_outlined, Colors.teal),
          _card('Bowl Average',
              bowlAvg != null ? bowlAvg.toStringAsFixed(1) : '—',
              Icons.trending_down_rounded, Colors.deepPurple),
          _card('Best Figures', bestFigures,                 Icons.emoji_events_rounded,    Colors.amber),
          _card('Catches',     '${s.catches}',               Icons.front_hand_rounded,      Colors.amber),
          _card('Run Outs',    '${s.runOuts}',               Icons.run_circle_rounded,      Colors.deepOrange),
          _card('Matches',     '${s.matchesBowled}',         Icons.sports_cricket_rounded,  AppColors.success),
        ]),
      ],
    );
  }

  // ── Impact tab ───────────────────────────────────────────────────────────
  Widget _impactTab(PlayerStats s) {
    final ovr  = s.impactRankScore;
    final bat  = s.battingRankScore;
    final bowl = s.bowlingRankScore;
    if (ovr == null && bat == null && bowl == null) {
      return _empty('Not enough data to compute an impact rating.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating circles
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (bat != null) _ratingCircle('BAT', bat, AppColors.info),
                  _ratingCircle('OVR', ovr ?? 0, AppColors.primary, big: true),
                  if (bowl != null) _ratingCircle('BOWL', bowl, AppColors.danger),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              // Rating description
              _ratingBreakdownRow('Batting',  bat,  AppColors.info),
              const SizedBox(height: 6),
              _ratingBreakdownRow('Bowling', bowl, AppColors.danger),
              const SizedBox(height: 6),
              _ratingBreakdownRow('Overall',  ovr,  AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _sectionLabel('CAREER SUMMARY', Icons.bar_chart_rounded, AppColors.primary),
        const SizedBox(height: 10),

        _grid([
          _card('Matches',     '${s.matches}',               Icons.sports_cricket_rounded, AppColors.primary),
          _card('Runs',        '${s.runs}',                  Icons.scoreboard_outlined,    AppColors.info),
          _card('Wickets',     '${s.wickets}',               Icons.sports_baseball_rounded, AppColors.danger),
          _card('Catches',     '${s.catches}',               Icons.front_hand_rounded,     Colors.amber),
          _card('Highest',     s.highestScore > 0 ? '${s.highestScore}' : '—',
              Icons.emoji_events_rounded, Colors.amber),
          _card('Best Figures',
              s.bestBowlingWickets != null ? '${s.bestBowlingWickets}/${s.bestBowlingRuns}' : '—',
              Icons.workspace_premium_rounded, Colors.deepPurple),
          _card('50s / 100s',  '${s.fifties} / ${s.hundreds}', Icons.stars_rounded, Colors.orange),
          _card('Run Outs',    '${s.runOuts}',               Icons.run_circle_rounded,     Colors.deepOrange),
        ]),
      ],
    );
  }

  // ── Recent form strips ───────────────────────────────────────────────────
  Widget _recentBattingStrip(List<int> innings) {
    final recent = innings.reversed.take(8).toList().reversed.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: recent.map((runs) {
              final color = _battingFormColor(runs);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Container(
                        height: _battingBarHeight(runs),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$runs',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _legendDot(Colors.grey, '0-9'),
            const SizedBox(width: 12),
            _legendDot(AppColors.info, '10-29'),
            const SizedBox(width: 12),
            _legendDot(AppColors.success, '30-49'),
            const SizedBox(width: 12),
            _legendDot(Colors.amber, '50+'),
          ]),
        ],
      ),
    );
  }

  Widget _recentBowlingStrip(List<int> innings) {
    final recent = innings.reversed.take(8).toList().reversed.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Row(
        children: recent.map((wkts) {
          final color = wkts == 0
              ? Colors.grey
              : wkts == 1
                  ? AppColors.info
                  : wkts == 2
                      ? AppColors.success
                      : wkts >= 3
                          ? Colors.amber
                          : Colors.grey;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: max(8.0, wkts * 14.0),
                    constraints: const BoxConstraints(maxHeight: 48),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$wkts',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _battingFormColor(int runs) {
    if (runs >= 50) return Colors.amber;
    if (runs >= 30) return AppColors.success;
    if (runs >= 10) return AppColors.info;
    return Colors.grey;
  }

  double _battingBarHeight(int runs) {
    if (runs >= 100) return 56;
    if (runs >= 50)  return 44;
    if (runs >= 30)  return 32;
    if (runs >= 10)  return 20;
    return 10;
  }

  Widget _legendDot(Color color, String label) => Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ]);

  // ── Section label ────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, IconData icon, Color color) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.2)),
      ]);

  // ── Rating row with progress bar ─────────────────────────────────────────
  Widget _ratingBreakdownRow(String label, double? score, Color color) {
    if (score == null) return const SizedBox.shrink();
    final pct = score.clamp(0.0, 100.0) / 100.0;
    return Row(children: [
      SizedBox(
        width: 56,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 7,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(score.round().toString(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color)),
    ]);
  }

  Widget _ratingCircle(String label, double score, Color color,
      {bool big = false}) {
    final size = big ? 88.0 : 68.0;
    return Column(children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: big ? 3 : 2),
          color: color.withValues(alpha: 0.08),
        ),
        alignment: Alignment.center,
        child: Text(
          score.round().toString(),
          style: TextStyle(
              fontSize: big ? 28 : 20,
              fontWeight: FontWeight.w900,
              color: color),
        ),
      ),
      const SizedBox(height: 6),
      Text(label,
          style: TextStyle(
              fontSize: big ? 11 : 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5)),
    ]);
  }

  Widget _grid(List<Widget> cards) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: cards,
      );

  Widget _card(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1)),
          ],
        ),
      );

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(children: [
            const Icon(Icons.sports_cricket_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
      );

  String _overs(int balls) => '${balls ~/ 6}.${balls % 6}';

  // ── Loading skeleton ─────────────────────────────────────────────────────
  Widget _buildSkeleton(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Column(children: [
      Container(
        height: top + 260,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(children: [
                TapBounce(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
            const Spacer(),
            const CircularProgressIndicator(
                color: Colors.white54, strokeWidth: 2),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildError(BuildContext context) {
    return Column(children: [
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TapBounce(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textMuted, size: 18),
            ),
          ),
        ),
      ),
      const Expanded(
        child: Center(
          child: Text('Could not load player profile.',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal pitch painter
// ─────────────────────────────────────────────────────────────────────────────
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(cx, cy),
            width: size.width * 0.35,
            height: size.height * 0.65),
        paint);
    canvas.drawLine(
        Offset(cx - size.width * 0.2, cy - size.height * 0.2),
        Offset(cx + size.width * 0.2, cy - size.height * 0.2),
        paint);
    canvas.drawLine(
        Offset(cx - size.width * 0.2, cy + size.height * 0.2),
        Offset(cx + size.width * 0.2, cy + size.height * 0.2),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
