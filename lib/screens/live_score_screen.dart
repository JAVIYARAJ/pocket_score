import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/score_bloc.dart';
import '../services/match_repository.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

class _CelebrationData {
  final String text;
  final Color color;
  _CelebrationData({required this.text, required this.color});
}

/// Spectator screen — subscribes to a live match via Supabase Realtime.
/// Anyone who has the match ID can open this screen to watch the score update
/// in real-time without being the scorer.
class LiveScoreScreen extends StatefulWidget {
  final String matchId;
  final String teamAName;
  final String teamBName;
  final int    totalOvers;

  const LiveScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    this.totalOvers = 0,
  });

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  late final MatchRepository _repo;

  // Score state — fetched via RPC, refreshed on every Realtime event.
  Map<String, dynamic>? _scoreData;
  bool   _loading = true;
  bool   _ended   = false;
  String? _error;
  RealtimeChannel? _channel;

  final ValueNotifier<_CelebrationData?> _celebration = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _repo = MatchRepository(Supabase.instance.client);
    _fetch();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _celebration.dispose();
    super.dispose();
  }

  // ── RPC fetch ─────────────────────────────────────────────────────────────
  Future<void> _fetch() async {
    try {
      final data = await _repo.getLiveScore(widget.matchId);
      if (!mounted) return;
      _checkCelebration(_scoreData, data);
      setState(() {
        _scoreData = data;
        _loading   = false;
        _ended     = data == null;
        _error     = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _checkCelebration(Map<String, dynamic>? oldData, Map<String, dynamic>? newData) {
    if (oldData == null || newData == null || _loading) return;
    try {
      final oldScore = ScoreState.fromJson(oldData);
      final newScore = ScoreState.fromJson(newData);
      final oldBalls = oldScore.currentInnings?.balls ?? [];
      final newBalls = newScore.currentInnings?.balls ?? [];
      if (newBalls.length > oldBalls.length) {
        final b = newBalls.last;
        if (b.isWicket == true) {
          _celebration.value = _CelebrationData(text: 'OUT! 🎯', color: AppColors.wicket);
        } else if ((b.runs as int?) == 6) {
          _celebration.value = _CelebrationData(text: 'SIX! 🚀', color: AppColors.six);
        } else if ((b.runs as int?) == 4) {
          _celebration.value = _CelebrationData(text: 'FOUR! 💥', color: AppColors.four);
        }
      }
    } catch (_) {}
  }

  // ── Realtime channel — no raw table query ─────────────────────────────────
  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('live_score_${widget.matchId}')
        .onPostgresChanges(
          event : PostgresChangeEvent.all,
          schema: 'public',
          table : 'live_scores',
          filter: PostgresChangeFilter(
            type  : PostgresChangeFilterType.eq,
            column: 'match_id',
            value : widget.matchId,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const _LoadingView();
    } else if (_error != null) {
      body = _ErrorView(message: _error!);
    } else if (_ended || _scoreData == null) {
      body = const _EndedView();
    } else {
      try {
        final score = ScoreState.fromJson(_scoreData!);
        body = _LiveBody(score: score, totalOvers: widget.totalOvers);
      } catch (_) {
        body = const _ErrorView(message: 'Could not parse score data.');
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(child: body),
              ],
            ),
            ValueListenableBuilder<_CelebrationData?>(
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PremiumHeader(
      title: '${widget.teamAName}  vs  ${widget.teamBName}',
      titleWidget: Text(
        '${widget.teamAName}  vs  ${widget.teamBName}',
        style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: -0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitleWidget: Row(
        children: [
          PulseAnimation(
            child: Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE SPECTATOR',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: Color(0xFF4ADE80), letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Body — Cricbuzz-style full scorecard
// ─────────────────────────────────────────────────────────────────────────────
class _LiveBody extends StatelessWidget {
  final ScoreState score;
  final int        totalOvers;
  const _LiveBody({required this.score, this.totalOvers = 0});

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _name(List<dynamic> players, String? id) {
    if (id == null || id.isEmpty) return '—';
    try {
      final p = players.firstWhere((p) => p.id == id);
      return p.name as String;
    } catch (_) {
      return '—';
    }
  }

  String _fmt(double v, [int dp = 2]) => v.toStringAsFixed(dp);

  // Balls belonging to the current (incomplete) over
  List<dynamic> _thisOverBalls(dynamic innings) {
    final summaries = innings.overSummaries as List;
    if (summaries.isEmpty) return const [];
    return (summaries.last.balls as List);
  }

  // Partnership since last wicket
  ({int runs, int balls}) _partnership(dynamic innings) {
    int runs = 0, balls = 0;
    for (final b in (innings.balls as List).reversed) {
      if (b.isWicket == true) break;
      runs  += b.totalRuns as int;
      balls += (b.isLegalBall == true) ? 1 : 0;
    }
    return (runs: runs, balls: balls);
  }

  // Last dismissed batsman — name, runs, balls faced
  ({String name, int runs, int balls})? _lastWicket(dynamic innings) {
    final allBalls = innings.balls as List;
    for (final b in allBalls.reversed) {
      if (b.isWicket != true) continue;
      final pid   = b.strikerId as String;
      final stats = (innings.batsmanStats as Map)[pid];
      final name  = _name(innings.battingPlayers as List, pid);
      if (name == '—' || stats == null) return null;
      return (
        name: name,
        runs: (stats.runs  as int?) ?? 0,
        balls: (stats.ballsFaced as int?) ?? 0,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final innings = score.currentInnings;
    if (innings == null) return const _LoadingView();

    final batStats  = innings.batsmanStats;
    final bowlStats = innings.bowlerStatsMap;
    final striker   = batStats[score.strikerId];
    final nonStrike = batStats[score.nonStrikerId];
    final bowler    = bowlStats[score.bowlerId];

    final batPlayers  = innings.battingPlayers;
    final bowlPlayers = innings.bowlingPlayers;

    final isSuperOver    = score.isSuperOver;
    final isChasing      = innings.target > 0;
    final runsNeeded     = innings.target - innings.totalRuns;
    final legalBalls     = innings.legalBallsCount;
    // Super over is always 1 over (6 balls); regular match uses totalOvers setting
    final effectiveOvers = isSuperOver ? 1 : totalOvers;
    final ballsRemaining = (effectiveOvers * 6) - legalBalls;
    final rrr = (isChasing && ballsRemaining > 0)
        ? (runsNeeded / ballsRemaining) * 6
        : 0.0;

    final partnership = _partnership(innings);
    final lastWkt     = _lastWicket(innings);
    final thisOver    = _thisOverBalls(innings);
    final recent      = (innings.balls as List).length > 12
        ? (innings.balls as List).sublist((innings.balls as List).length - 12)
        : (innings.balls as List);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── 1. SCORE CARD ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isSuperOver
                  ? const LinearGradient(
                      colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : AppColors.scoreGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isSuperOver ? AppColors.accent : AppColors.primary).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Innings label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSuperOver) ...[
                            const Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isSuperOver
                                ? 'SUPER OVER'
                                : (score.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS'),
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: Colors.white70, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  innings.battingTeamName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Main score
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${innings.totalRuns}',
                        style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1),
                      ),
                      TextSpan(
                        text: '/${innings.totalWickets}',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${innings.overDisplay} overs',
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600),
                ),

                // Chase info
                if (isChasing) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _scorePill('TARGET', '${innings.target}',
                          Colors.orange),
                      _scorePill(
                          'NEED',
                          '$runsNeeded runs${ballsRemaining > 0 ? '\n${ballsRemaining}b' : ''}',
                          AppColors.danger),
                      _scorePill('RRR',
                          rrr > 0 ? _fmt(rrr) : '—', Colors.cyanAccent),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // CRR row (always shown)
          Row(children: [
            Expanded(
              child: _InfoTile(
                label : 'CRR',
                value : _fmt(innings.runRate),
                color : AppColors.primary,
                icon  : Icons.speed_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label : 'WICKETS',
                value : '${innings.totalWickets}/${isSuperOver ? 2 : 10}',
                color : AppColors.danger,
                icon  : Icons.sports_baseball_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                label : 'EXTRAS',
                value : '${innings.balls.fold<int>(0, (s, b) => s + (b.extraRuns as int? ?? 0))}',
                color : AppColors.textMuted,
                icon  : Icons.add_circle_outline_rounded,
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── 2. BATSMEN ────────────────────────────────────────────────────
          _sectionLabel('BATTING'),
          const SizedBox(height: 8),
          Container(
            decoration: AppDecorations.card(),
            child: Column(
              children: [
                // Header row
                _batsmanHeader(),
                const Divider(height: 1, color: AppColors.border),
                // Striker
                if (score.strikerId.isNotEmpty)
                  _batsmanRow(
                    name    : _name(batPlayers, score.strikerId),
                    stats   : striker,
                    isStriker: true,
                  ),
                if (score.nonStrikerId.isNotEmpty) ...[
                  const Divider(height: 1, color: AppColors.border),
                  _batsmanRow(
                    name    : _name(batPlayers, score.nonStrikerId),
                    stats   : nonStrike,
                    isStriker: false,
                  ),
                ],
                // Partnership + Last Wicket footer
                if (partnership.balls > 0 || lastWkt != null) ...[
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    child: Row(
                      children: [
                        if (partnership.balls > 0) ...[
                          const Icon(Icons.handshake_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(
                            "P'ship : ${partnership.runs}(${partnership.balls})",
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                        if (partnership.balls > 0 && lastWkt != null)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 1,
                            height: 14,
                            color: AppColors.border,
                          ),
                        if (lastWkt != null) ...[
                          const Icon(Icons.sports_cricket_rounded,
                              size: 12, color: AppColors.danger),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Last: ${lastWkt.name} ${lastWkt.runs}(${lastWkt.balls})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 3. CURRENT BOWLER ─────────────────────────────────────────────
          _sectionLabel('BOWLING'),
          const SizedBox(height: 8),
          Container(
            decoration: AppDecorations.card(),
            child: Column(
              children: [
                _bowlerHeader(),
                if (score.pendingBowlerChange) ...[
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      PulseAnimation(
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.warning, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Awaiting bowler selection…',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning),
                      ),
                    ]),
                  ),
                ] else if (score.bowlerId.isNotEmpty && bowler != null) ...[
                  const Divider(height: 1, color: AppColors.border),
                  _bowlerRow(
                    name  : _name(bowlPlayers, score.bowlerId),
                    stats : bowler,
                  ),
                ] else ...[
                  const Divider(height: 1, color: AppColors.border),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('—',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 4. THIS OVER ──────────────────────────────────────────────────
          if (thisOver.isNotEmpty) ...[
            _sectionLabel('THIS OVER'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppDecorations.card(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: thisOver
                      .map((b) => _BallChip(ball: b))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 5. RECENT BALLS (last 12) ─────────────────────────────────────
          if (recent.length > (thisOver.isEmpty ? 0 : thisOver.length)) ...[
            _sectionLabel('RECENT'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppDecorations.card(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: recent
                      .map((b) => _BallChip(ball: b))
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _scorePill(String label, String value, Color color) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(value,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.2)),
    ]);
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      );

  Widget _batsmanHeader() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Expanded(
              child: Text('Batsman',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted))),
          _ColHead('R'),
          _ColHead('B'),
          _ColHead('4s'),
          _ColHead('6s'),
          _ColHead('SR'),
        ]),
      );

  Widget _batsmanRow({
    required String name,
    required dynamic stats,
    required bool isStriker,
  }) {
    final r  = (stats?.runs   as int?)?.toString()  ?? '0';
    final b  = (stats?.ballsFaced as int?)?.toString() ?? '0';
    final f  = (stats?.fours  as int?)?.toString()  ?? '0';
    final s  = (stats?.sixes  as int?)?.toString()  ?? '0';
    final sr = stats?.strikeRate != null
        ? _fmt(stats!.strikeRate as double, 1)
        : '0.0';

    return Container(
      color: isStriker
          ? AppColors.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isStriker ? FontWeight.w800 : FontWeight.w600,
                    color: isStriker
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
              ),
            ),
            if (isStriker) ...[
              const SizedBox(width: 4),
              const Text('*',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ],
          ]),
        ),
        _ColVal(r,  isStriker),
        _ColVal(b,  false),
        _ColVal(f,  false),
        _ColVal(s,  false),
        _ColVal(sr, false),
      ]),
    );
  }

  Widget _bowlerHeader() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Expanded(
              child: Text('Bowler',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted))),
          _ColHead('O'),
          _ColHead('R'),
          _ColHead('W'),
          _ColHead('Eco'),
        ]),
      );

  Widget _bowlerRow({required String name, required dynamic stats}) {
    final o   = stats?.oversBowled ?? '0.0';
    final r   = (stats?.runsConceded as int?)?.toString() ?? '0';
    final w   = (stats?.wickets as int?)?.toString() ?? '0';
    final eco = stats?.economy != null
        ? _fmt(stats!.economy as double)
        : '0.00';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
        _ColVal('$o',  false),
        _ColVal(r,     false),
        _ColVal(w,     true, color: AppColors.danger),
        _ColVal(eco,   false),
      ]),
    );
  }
}

// ── Column header ─────────────────────────────────────────────
class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
      );
}

// ── Column value ─────────────────────────────────────────────
class _ColVal extends StatelessWidget {
  final String text;
  final bool   bold;
  final Color? color;
  const _ColVal(this.text, this.bold, {this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.w800 : FontWeight.w600,
                color: color ??
                    (bold
                        ? AppColors.textPrimary
                        : AppColors.textSecondary))),
      );
}

// ── Info tile (CRR / Wickets / Extras row) ───────────────────
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final IconData icon;
  const _InfoTile({required this.label, required this.value,
      required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.6),
                  letterSpacing: 0.8)),
        ]),
      );
}

// ── Ball chip ─────────────────────────────────────────────────
class _BallChip extends StatelessWidget {
  final dynamic ball;
  const _BallChip({required this.ball});

  @override
  Widget build(BuildContext context) {
    final isWicket = (ball.isWicket as bool?) ?? false;
    final runs     = (ball.runs     as int?)  ?? 0;
    final typeStr  = (ball.type?.toString() ?? '').toLowerCase();
    final isWide   = typeStr.contains('wide');
    final isNoBall = typeStr.contains('noball') ||
                     typeStr.contains('no_ball');
    final extraR   = (ball.extraRuns as int?) ?? 0;

    Color  bg; Color fg; String label;
    if (isWicket) {
      bg = AppColors.danger;  fg = Colors.white;
      label = extraR > 0 ? '$extraR+W' : 'W';
    } else if (runs == 6) {
      bg = AppColors.success; fg = Colors.white; label = '6';
    } else if (runs == 4) {
      bg = AppColors.info;    fg = Colors.white; label = '4';
    } else if (isWide) {
      bg = AppColors.warning.withValues(alpha: 0.15);
      fg = AppColors.warning;
      label = extraR > 0 ? 'Wd+$extraR' : 'Wd';
    } else if (isNoBall) {
      bg = AppColors.accent.withValues(alpha: 0.15);
      fg = AppColors.accent;
      label = runs > 0 ? 'Nb+$runs' : 'Nb';
    } else if (runs == 0) {
      bg = AppColors.bg;
      fg = AppColors.textMuted;
      label = '·';
    } else {
      bg = AppColors.surfaceLight;
      fg = AppColors.textSecondary;
      label = '$runs';
    }

    final size = label.length > 2 ? 44.0 : 38.0;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: size, height: 38,
      decoration: BoxDecoration(
        color : bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: label.length > 2 ? 10 : 13)),
    );
  }
}

// ── State views ───────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        SizedBox(height: 16),
        Text(
          'Connecting to live score…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ],
    ),
  );
}

class _EndedView extends StatelessWidget {
  const _EndedView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sports_cricket_outlined, size: 52, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        const Text(
          'Match has ended',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'The live score is no longer available.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Go Back'),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text(
            'Connection error',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    ),
  );
}
