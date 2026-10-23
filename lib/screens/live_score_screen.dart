import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/score_bloc.dart';
import '../services/match_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import '../theme/animations.dart';
import '../models/ball_model.dart';
import '../models/innings_model.dart';
import '../models/player_model.dart';
import '../widgets/live_widgets.dart';
import '../utils/stats_utils.dart' show parsedScore;

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
  final int?   powerPlayOvers;

  const LiveScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
    this.totalOvers = 0,
    this.powerPlayOvers,
  });

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen>
    with WidgetsBindingObserver {
  late final MatchRepository _repo;

  // Score state — fetched via RPC, refreshed on every Realtime event.
  Map<String, dynamic>? _scoreData;
  bool   _loading = true;
  bool   _ended   = false;
  String? _error;
  RealtimeChannel? _channel;
  // Realtime events can arrive faster than fetches complete; only the newest
  // request may update the screen, or the score could jump backwards.
  int _fetchSeq = 0;

  final ValueNotifier<_CelebrationData?> _celebration = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _repo = MatchRepository(Supabase.instance.client);
    WidgetsBinding.instance.addObserver(this);
    _fetch();
    _subscribeRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Updates published while the app was in the background were missed.
    if (state == AppLifecycleState.resumed) _fetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _celebration.dispose();
    super.dispose();
  }

  // ── RPC fetch ─────────────────────────────────────────────────────────────
  Future<void> _fetch() async {
    final seq = ++_fetchSeq;
    try {
      final data = await _repo.getLiveScore(widget.matchId);
      if (!mounted || seq != _fetchSeq) return;
      _checkCelebration(_scoreData, data);
      setState(() {
        _scoreData = data;
        _loading   = false;
        _ended     = data == null;
        _error     = null;
      });
    } catch (e) {
      if (!mounted || seq != _fetchSeq) return;
      // Keep showing the last score through a network blip; the next
      // realtime event or reconnect refetches.
      if (_scoreData != null) return;
      setState(() {
        _error   = 'Couldn\'t load the live score. Check your connection.';
        _loading = false;
      });
    }
  }

  void _checkCelebration(Map<String, dynamic>? oldData, Map<String, dynamic>? newData) {
    if (oldData == null || newData == null || _loading) return;
    try {
      final oldBalls = parsedScore(oldData).currentInnings?.balls ?? const <Ball>[];
      final newBalls = parsedScore(newData).currentInnings?.balls ?? const <Ball>[];
      if (newBalls.length <= oldBalls.length) return;
      final b = newBalls.last;
      if (b.isWicket) {
        _celebration.value = _CelebrationData(text: 'OUT! 🎯', color: AppColors.wicket);
      } else if (b.runs == 6) {
        _celebration.value = _CelebrationData(text: 'SIX! 🚀', color: AppColors.six);
      } else if (b.runs == 4) {
        _celebration.value = _CelebrationData(text: 'FOUR! 💥', color: AppColors.four);
      }
    } catch (_) {
      // Celebrations are decorative; a bad snapshot just skips one.
    }
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
        // (Re)joining the channel — first connect or after a dropped socket —
        // means events may have been missed, so resync.
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) _fetch();
        });
  }

  @override
  Widget build(BuildContext context) {
    ScoreState? score;
    Widget? fallback;
    if (_loading) {
      fallback = const _LoadingView();
    } else if (_error != null) {
      fallback = _ErrorView(message: _error!);
    } else if (_ended || _scoreData == null) {
      fallback = const _EndedView();
    } else {
      try {
        score = parsedScore(_scoreData!);
        if (score.currentInnings == null) fallback = const _LoadingView();
      } catch (_) {
        fallback = const _ErrorView(message: 'Could not parse score data.');
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
            if (fallback == null)
              _LiveBody(
                score: score!,
                teamAName: widget.teamAName,
                teamBName: widget.teamBName,
                totalOvers: widget.totalOvers,
                powerPlayOvers: widget.powerPlayOvers,
              )
            else
              Column(children: [
                _PlainHeader(title: '${widget.teamAName}  vs  ${widget.teamBName}'),
                Expanded(child: fallback),
              ]),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Header used while loading / ended / on error.
// ─────────────────────────────────────────────────────────────────────────────
class _PlainHeader extends StatelessWidget {
  final String title;
  const _PlainHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(children: [
        const _GlassBack(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ]),
    );
  }
}

class _GlassBack extends StatelessWidget {
  const _GlassBack();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.canPop() ? context.pop() : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Body — broadcast-style hero, then this over, batting, bowling and the
// recent-overs timeline. Cards stagger in on open; after that only the parts
// that change animate.
// ─────────────────────────────────────────────────────────────────────────────
class _LiveBody extends StatelessWidget {
  final ScoreState score;
  final String teamAName;
  final String teamBName;
  final int totalOvers;
  final int? powerPlayOvers;
  const _LiveBody({
    required this.score,
    required this.teamAName,
    required this.teamBName,
    this.totalOvers = 0,
    this.powerPlayOvers,
  });

  @override
  Widget build(BuildContext context) {
    final inn = score.currentInnings!;
    final summaries = inn.overSummaries;
    final thisOver = summaries.isEmpty ? const <Ball>[] : summaries.last.balls;
    // Earlier overs, newest first; the latest over is already shown above.
    final pastOvers = summaries.isEmpty
        ? const <OverSummary>[]
        : summaries.sublist(0, summaries.length - 1).reversed.take(6).toList();

    Widget stagger(int i, Widget child) => FadeInEntrance(
          delay: Duration(milliseconds: 120 + 70 * i),
          offset: const Offset(0, 16),
          child: child,
        );

    return ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        _LiveHero(
          score: score,
          teamAName: teamAName,
          teamBName: teamBName,
          totalOvers: totalOvers,
          powerPlayOvers: powerPlayOvers,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            stagger(0, _ThisOverCard(score: score, balls: thisOver)),
            const SizedBox(height: 12),
            stagger(1, _BattingCard(score: score)),
            const SizedBox(height: 12),
            stagger(2, _BowlingCard(score: score)),
            if (pastOvers.isNotEmpty) ...[
              const SizedBox(height: 12),
              stagger(3, _OversTimeline(overs: pastOvers)),
            ],
          ]),
        ),
      ],
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _LiveHero extends StatelessWidget {
  final ScoreState score;
  final String teamAName;
  final String teamBName;
  final int totalOvers;
  final int? powerPlayOvers;
  const _LiveHero({
    required this.score,
    required this.teamAName,
    required this.teamBName,
    required this.totalOvers,
    required this.powerPlayOvers,
  });

  @override
  Widget build(BuildContext context) {
    final inn = score.currentInnings!;
    final batting = inn.battingTeamName;
    final bowling = batting == teamAName ? teamBName : teamAName;
    final isSuperOver = score.isSuperOver;
    final overs = isSuperOver ? 1 : totalOvers;
    final ballsLeft = (overs * 6 - inn.legalBallsCount).clamp(0, 9999);
    final isChasing = inn.target > 0;
    final need = inn.target - inn.totalRuns;
    final rrr = isChasing && ballsLeft > 0 ? need / ballsLeft * 6 : 0.0;
    final inPowerPlay =
        !isSuperOver && powerPlayOvers != null && inn.legalBallsCount ~/ 6 < powerPlayOvers!;
    final extras = inn.balls.fold<int>(0, (s, b) => s + b.extraRuns);
    final lastBall = inn.balls.isEmpty ? null : inn.balls.last;

    final stage = isSuperOver ? 'SUPER OVER' : (score.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS');

    return EventGlow(
      eventKey: inn.balls.length,
      color: highlightFor(lastBall),
      radius: 28,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 16, 18),
        decoration: BoxDecoration(
          gradient: isSuperOver
              ? const LinearGradient(
                  colors: [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : AppColors.headerGradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Stack(children: [
          Positioned(
            right: -30,
            top: 30,
            child: Icon(Icons.sports_cricket_rounded, size: 170, color: Colors.white.withValues(alpha: 0.04)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top bar ──
            Row(children: [
              const _GlassBack(),
              const Spacer(),
              const LiveBadge(),
              const SizedBox(width: 8),
              Text('SPECTATING',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Colors.white.withValues(alpha: 0.6))),
            ]),
            const SizedBox(height: 16),

            // ── Teams ──
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(children: [
                _crest(batting, true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(batting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('vs $bowling',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.55))),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _tag(stage, isSuperOver ? Icons.bolt_rounded : null),
                  if (inPowerPlay) ...[
                    const SizedBox(height: 4),
                    _tag('POWER PLAY', Icons.flash_on_rounded, gold: true),
                  ],
                ]),
              ]),
            ),
            const SizedBox(height: 18),

            // ── Score ──
            Center(child: RollingScore(runs: inn.totalRuns, wickets: inn.totalWickets, size: 58)),
            const SizedBox(height: 6),
            Center(
              child: Text('${inn.overDisplay}${overs > 0 ? ' / $overs' : ''} overs',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.65))),
            ),
            const SizedBox(height: 16),

            // ── Chase ──
            if (isChasing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  ChaseMeter(runs: inn.totalRuns, target: inn.target, height: 7),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(
                      need <= 0 ? 'Target reached!' : 'Need $need off $ballsLeft',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.accentLight),
                    ),
                    const Spacer(),
                    Text('Target ${inn.target}',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
            ],

            // ── Rates strip ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(children: [
                _rate('CRR', inn.runRate.toStringAsFixed(2)),
                _divider(),
                if (isChasing) ...[
                  _rate('RRR', rrr > 0 ? rrr.toStringAsFixed(2) : '—', highlight: true),
                  _divider(),
                ],
                _rate('EXTRAS', '$extras'),
                _divider(),
                _rate('WKTS LEFT', '${(isSuperOver ? 2 : _wicketsAvailable(inn)) - inn.totalWickets}'),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  /// Wickets the batting side can lose before the innings ends.
  int _wicketsAvailable(Innings inn) {
    final n = inn.battingPlayers.length;
    if (n <= 1) return 1;
    return score.isLastManStanding ? n : n - 1;
  }

  Widget _crest(String name, bool batting) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.goldGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(name.isEmpty ? '?' : name.trim()[0].toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
      );

  Widget _tag(String text, IconData? icon, {bool gold = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: gold ? AppColors.accentLight.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: gold ? AppColors.accentLight : Colors.white),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: gold ? AppColors.accentLight : Colors.white.withValues(alpha: 0.85))),
        ]),
      );

  Widget _rate(String label, String value, {bool highlight = false}) => Expanded(
        child: Column(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(value,
                key: ValueKey(value),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: highlight ? AppColors.accentLight : Colors.white)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.5))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.12));
}

// ── Shared card shell ─────────────────────────────────────────────────────────
class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: AppDecorations.card(radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: AppColors.textMuted)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

String _nameOf(List<Player> players, String id) =>
    players.where((p) => p.id == id).firstOrNull?.name ?? '—';

/// Current bowler's name: from the innings, else the match line-up.
String _bowlerName(ScoreState score) {
  final n = _nameOf(score.currentInnings!.bowlingPlayers, score.bowlerId);
  return n != '—' ? n : _nameOf(score.bowlingLineup, score.bowlerId);
}

// ── This over ─────────────────────────────────────────────────────────────────
class _ThisOverCard extends StatelessWidget {
  final ScoreState score;
  final List<Ball> balls;
  const _ThisOverCard({required this.score, required this.balls});

  @override
  Widget build(BuildContext context) {
    final runs = balls.fold<int>(0, (s, b) => s + b.totalRuns);
    final bowler = score.bowlerId.isEmpty ? null : _bowlerName(score);
    return _Panel(
      title: 'THIS OVER',
      icon: Icons.sports_baseball_rounded,
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text('$runs run${runs == 1 ? '' : 's'}',
            key: ValueKey(runs),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OverTrack(balls: balls, size: 36),
        if (score.pendingBowlerChange || bowler != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (score.pendingBowlerChange) ...[
              PulseAnimation(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Over complete · new bowler coming on…',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
            ] else
              Expanded(
                child: Text('$bowler to bowl',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
          ]),
        ],
      ]),
    );
  }
}

// ── Batting ───────────────────────────────────────────────────────────────────
class _BattingCard extends StatelessWidget {
  final ScoreState score;
  const _BattingCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final inn = score.currentInnings!;
    final rows = <Widget>[
      if (score.strikerId.isNotEmpty) _batterRow(inn, score.strikerId, true),
      if (score.nonStrikerId.isNotEmpty) _batterRow(inn, score.nonStrikerId, false),
    ];

    // Partnership since the last wicket.
    var pRuns = 0, pBalls = 0;
    for (final b in inn.balls.reversed) {
      if (b.isWicket) break;
      pRuns += b.totalRuns;
      if (b.isLegalBall) pBalls++;
    }
    final lastOut = inn.balls.lastWhere((b) => b.isWicket, orElse: () => _noBall);
    final lastStats = identical(lastOut, _noBall) ? null : inn.batsmanStats[lastOut.dismissedId];

    return _Panel(
      title: 'BATTING',
      icon: Icons.sports_cricket_rounded,
      child: Column(children: [
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Waiting for the next batter…',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
        if (pBalls > 0 || lastStats != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (pBalls > 0)
              _footChip(Icons.handshake_rounded, "Partnership $pRuns ($pBalls)", AppColors.primary),
            if (lastStats != null)
              _footChip(
                  Icons.close_rounded,
                  'Last out: ${_nameOf(inn.battingPlayers, lastOut.dismissedId)} '
                  '${lastStats.runs} (${lastStats.ballsFaced})',
                  AppColors.danger),
          ]),
        ],
      ]),
    );
  }

  Widget _batterRow(Innings inn, String id, bool onStrike) {
    final s = inn.batsmanStats[id];
    final runs = s?.runs ?? 0;
    final balls = s?.ballsFaced ?? 0;
    final sr = s?.strikeRate ?? 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: onStrike ? AppColors.surfaceGreen : AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: onStrike ? AppColors.primaryLight.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Column(children: [
        Row(children: [
          Icon(onStrike ? Icons.sports_cricket_rounded : Icons.person_rounded,
              size: 15, color: onStrike ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_nameOf(inn.battingPlayers, id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(end: runs),
            duration: const Duration(milliseconds: 500),
            builder: (_, v, __) => Text('$v',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ),
          Text(' ($balls)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _mini('4s', '${s?.fours ?? 0}', AppColors.four),
          const SizedBox(width: 10),
          _mini('6s', '${s?.sixes ?? 0}', AppColors.six),
          const SizedBox(width: 12),
          // Strike-rate bar: full at 200.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 4,
                color: AppColors.border,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (sr / 200).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v,
                    child: Container(color: onStrike ? AppColors.primaryLight : AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('SR ${sr.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _mini(String label, String value, Color c) => Text.rich(
        TextSpan(children: [
          TextSpan(text: value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c)),
          TextSpan(
              text: ' $label',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        ]),
      );

  Widget _footChip(IconData icon, String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
          ),
        ]),
      );
}

/// Sentinel for "no wicket yet" in [Iterable.lastWhere].
const _noBall = Ball(runs: 0, type: BallType.normal, strikerId: '', bowlerId: '');

// ── Bowling ───────────────────────────────────────────────────────────────────
class _BowlingCard extends StatelessWidget {
  final ScoreState score;
  const _BowlingCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final inn = score.currentInnings!;
    // A bowler who has just come on has no stats yet — still show them.
    final s = inn.bowlerStatsMap[score.bowlerId];
    final hasBowler = score.bowlerId.isNotEmpty && !score.pendingBowlerChange;

    return _Panel(
      title: 'BOWLING',
      icon: Icons.sports_handball_rounded,
      child: !hasBowler
          ? Row(children: [
              PulseAnimation(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Awaiting bowler selection…',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warning)),
            ])
          : Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_bowlerName(score),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${s?.oversBowled ?? '0.0'} ov  ·  Econ ${(s?.economy ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text('${s?.wickets ?? 0}-${s?.runsConceded ?? 0}',
                      key: ValueKey('${s?.wickets}-${s?.runsConceded}'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.danger)),
                ),
              ),
            ]),
    );
  }
}

// ── Recent overs ──────────────────────────────────────────────────────────────
class _OversTimeline extends StatelessWidget {
  final List<OverSummary> overs;
  const _OversTimeline({required this.overs});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'RECENT OVERS',
      icon: Icons.timeline_rounded,
      child: Column(children: [
        for (var i = 0; i < overs.length; i++) ...[
          if (i > 0) const Divider(height: 14, color: AppColors.borderLight),
          Row(children: [
            SizedBox(
              width: 40,
              child: Text('Ov ${overs[i].overNumber}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            ),
            Expanded(child: OverTrack(balls: overs[i].balls, size: 24)),
            const SizedBox(width: 8),
            Text('${overs[i].runs}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ]),
        ],
      ]),
    );
  }
}

// ── State views ───────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const ScoreboardSkeleton();
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
