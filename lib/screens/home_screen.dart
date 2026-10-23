import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/auth_cubit.dart' show AuthBloc;
import '../bloc/group_cubit.dart' show GroupBloc;
import '../bloc/match_list_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/score_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../models/match_models.dart';
import '../services/match_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import '../widgets/empty_state.dart';
import '../widgets/live_widgets.dart';
import '../models/ball_model.dart';
import '../widgets/player_card_sheet.dart';
import '../utils/stats_utils.dart';
import '../theme/animations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return BlocListener<ProfileBloc, ProfileState>(
      // Show the player-profile setup sheet the first time a user signs in
      // and hasn't set their preferences yet.
      listenWhen: (prev, curr) =>
          curr is ProfileLoaded && !curr.profile.hasPreferences &&
          prev is! ProfileLoaded,
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _showFirstTimeSetup(context);
        });
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── STICKY TOP BAR ───────────────────────────────────
          SliverPersistentHeader(pinned: true, delegate: _HomeTopBar(topPadding: top)),

          // ── HERO HEADER ──────────────────────────────────────
          const SliverToBoxAdapter(child: _HeroHeader()),

          // ── SECTION TITLE ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Match History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  BlocBuilder<MatchListBloc, MatchListState>(
                    builder: (_, state) => _Pill(
                      '${state.matches.length} matches',
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── MATCH LIST ────────────────────────────────────────
          BlocBuilder<MatchListBloc, MatchListState>(
            builder: (context, state) {
              if (!state.synced && state.matches.isEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const MatchCardSkeleton(),
                  ),
                );
              }
              if (state.matches.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyMatches(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => FadeInEntrance(
                      delay: Duration(milliseconds: 60 * i),
                      offset: const Offset(0, 24),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MatchCard(match: state.matches[i]),
                      ),
                    ),
                    childCount: state.matches.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      ), // Scaffold
      ), // AnnotatedRegion
    );   // BlocListener
  }

  void _showFirstTimeSetup(BuildContext context) {
    PlayerCardSheet.show(context, firstTime: true);
  }
}

/// Horizontal so the pinned top bar and the hero below it meet without a seam.
const _homeGradient = LinearGradient(
  colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ── Sticky top bar ─────────────────────────────────────────────
/// Greeting + profile button. Stays pinned; the greeting shrinks and the
/// subtitle fades as the page scrolls under it.
class _HomeTopBar extends SliverPersistentHeaderDelegate {
  final double topPadding;
  const _HomeTopBar({required this.topPadding});

  static const _expanded = 96.0;
  static const _collapsed = 62.0;

  @override
  double get maxExtent => topPadding + _expanded;

  @override
  double get minExtent => topPadding + _collapsed;

  @override
  bool shouldRebuild(_HomeTopBar old) => old.topPadding != topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (_expanded - _collapsed)).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        gradient: _homeGradient,
        boxShadow: t >= 1
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 3))]
            : null,
      ),
      padding: EdgeInsets.fromLTRB(20, topPadding + 8, 20, 8),
      child: Row(children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Greeting(fontSize: 28 - 8 * t),
              // Collapses to nothing as the bar shrinks.
              ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  heightFactor: 1 - t,
                  child: Opacity(
                    opacity: 1 - t,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Ready to step up to the crease?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Transform.scale(scale: 1 - 0.15 * t, child: const _ProfileAvatarBtn()),
      ]),
    );
  }
}

/// "Hi, Name 🏏". Its own widget because the header delegate builds during
/// layout, where `context.select` (used by [_displayName]) isn't allowed.
class _Greeting extends StatelessWidget {
  final double fontSize;
  const _Greeting({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Hi, ${_displayName(context)?.split(' ').first ?? 'Scorer'} 🏏',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Hero Header ────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _homeGradient),
      child: Stack(
        children: [
          // ── Cricket Watermarks ──────────────────────────────
          Positioned(
            right: -20,
            top: -60,
            child: Opacity(
              opacity: 0.15,
              child: Transform.rotate(
                angle: 0.2,
                child: Image.asset(
                  'assets/icons/wickets.png',
                  height: 160,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: 40,
            child: Opacity(
              opacity: 0.08,
              child: Transform.rotate(
                angle: -0.4,
                child: Image.asset(
                  'assets/icons/ic_cricket_ball_icon.png',
                  height: 120,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          // ── Foreground Content ──────────────────────────────
          Column(
            children: [
              const SizedBox(height: 4),

              // New Match / Live Match card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: BlocBuilder<MatchListBloc, MatchListState>(
                  builder: (context, state) {
                    final live = state.matches.cast<MatchSummary?>()
                        .firstWhere((m) => m?.status == 'in_progress',
                            orElse: () => null);
                    if (live != null) return _LiveBanner(match: live);
                    return _newMatchCard(context);
                  },
                ),
              ),

              // Latest result strip
              BlocBuilder<MatchListBloc, MatchListState>(
                builder: (context, state) {
                  final done = state.matches
                      .where((m) => m.status == 'completed')
                      .toList();
                  if (done.isEmpty) {
                    return const SizedBox(height: 24);
                  }
                  final last = done.first;
                  return GestureDetector(
                    onTap: () {
                      if (last.scoreData != null) {
                        try {
                          context.push('/scorecard', extra: {
                            'state': parsedScore(last.scoreData!),
                            'overs': last.totalOvers,
                          });
                        } catch (_) {
                          // Unreadable score data: nothing to open.
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emoji_events_rounded,
                                        size: 11, color: AppColors.accentLight),
                                    SizedBox(width: 4),
                                    Text('LAST RESULT',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.8)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'View Scorecard',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                  size: 14, color: Colors.white.withValues(alpha: 0.7)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        last.teamAName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${last.teamAScore ?? 0}/${last.teamAWickets ?? 0}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'vs',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${last.teamBScore ?? 0}/${last.teamBWickets ?? 0}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        last.teamBName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _newMatchCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<MatchBloc>().add(ResetMatch());
        context.read<ScoreBloc>().add(ResetScoreboard());
        context.push('/match/setup');
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_cricket_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Host a Match',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      )),
                  SizedBox(height: 3),
                  Text('Set up teams and start scoring',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's edited profile name, falling back to their Google name.
String? _displayName(BuildContext context) {
  final saved = context.select<ProfileBloc, String?>((b) {
    final s = b.state;
    return s is ProfileLoaded ? s.profile.fullName?.trim() : null;
  });
  if (saved != null && saved.isNotEmpty) return saved;
  return context.read<AuthBloc>().userName;
}

// ── Profile avatar button for home header ─────────────────────
class _ProfileAvatarBtn extends StatelessWidget {
  const _ProfileAvatarBtn();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthBloc>();
    final avatarUrl = cubit.avatarUrl;
    final name = _displayName(context) ?? '';

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _initials(name),
                )
              : _initials(name),
        ),
      ),
    );
  }

  Widget _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final ini = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          ini,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Match Banner — real-time score updates via Supabase Realtime channel.
// Shown on the home screen whenever a match is in_progress.
// ─────────────────────────────────────────────────────────────────────────────
class _LiveBanner extends StatefulWidget {
  final MatchSummary match;
  const _LiveBanner({required this.match});

  @override
  State<_LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends State<_LiveBanner> {
  Map<String, dynamic>? _scoreData;
  RealtimeChannel? _channel;
  int _fetchSeq = 0; // only the newest fetch may update the banner

  @override
  void initState() {
    super.initState();
    _fetch();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetch() async {
    final seq = ++_fetchSeq;
    try {
      final data = await MatchRepository(Supabase.instance.client)
          .getLiveScore(widget.match.id);
      if (mounted && seq == _fetchSeq) setState(() => _scoreData = data);
    } catch (_) {
      // Best effort: the card keeps its last snapshot until the next update.
    }
  }

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('home_live_${widget.match.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_scores',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.match.id,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) _fetch();
        });
  }

  void _watchLive(BuildContext context) {
    context.push('/live/${widget.match.id}', extra: {
      'teamAName'    : widget.match.teamAName,
      'teamBName'    : widget.match.teamBName,
      'totalOvers'   : widget.match.totalOvers,
      'powerPlayOvers': widget.match.powerPlayOvers,
    });
  }

  void _resumeScoring(BuildContext context) {
    final match = widget.match;
    // Only the scorer may change the scoreboard; the server rejects anyone
    // else's writes, so don't let them start.
    if (!match.isOwnedBy(context.read<AuthBloc>().userId)) {
      _watchLive(context);
      return;
    }

    // Prefer the freshest score data: live_scores row (already in _scoreData)
    // falling back to the matches.score_data column stored in MatchSummary.
    final rawScore = _scoreData ?? match.scoreData;
    if (rawScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved scoring data found for this match.')),
      );
      return;
    }

    try {
      final savedScore = ScoreState.fromJson(rawScore);
      // Restore both blocs — _MainShell will automatically overlay ScoringScreen
      // as soon as ScoreBloc.state.firstInnings != null.
      context.read<MatchBloc>().add(RestoreMatch(match));
      context.read<ScoreBloc>().add(
        RestoreScore(savedState: savedScore, matchId: match.id),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not restore match. Data may be corrupted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ScoreState? score;
    try {
      if (_scoreData != null) score = parsedScore(_scoreData!);
    } catch (_) {
      // Unreadable snapshot: the card falls back to the summary totals.
    }
    return _LiveCard(
      match: widget.match,
      score: score,
      canScore: widget.match.isOwnedBy(context.read<AuthBloc>().userId),
      onWatch: () => _watchLive(context),
      onScore: () => _resumeScoring(context),
    );
  }
}

/// Compact live-match card. Pure view: [score] is the latest snapshot (null
/// until it loads), and only the match's scorer gets the Score action.
class _LiveCard extends StatelessWidget {
  final MatchSummary match;
  final ScoreState? score;
  final bool canScore;
  final VoidCallback onWatch;
  final VoidCallback onScore;
  const _LiveCard({
    required this.match,
    required this.score,
    required this.canScore,
    required this.onWatch,
    required this.onScore,
  });

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final inn = score?.currentInnings;
    final battingTeam = inn?.battingTeamName ?? match.teamAName;
    final bowlingTeam = battingTeam == match.teamAName ? match.teamBName : match.teamAName;
    final runs = inn?.totalRuns ?? match.teamAScore ?? 0;
    final wkts = inn?.totalWickets ?? match.teamAWickets ?? 0;
    final overDisp = inn?.overDisplay ?? match.teamAOvers ?? '0.0';
    final thisOver = inn == null || inn.overSummaries.isEmpty
        ? const <Ball>[]
        : inn.overSummaries.last.balls;

    final target = inn?.target ?? 0;
    final isChasing = target > 0;
    final overs = score?.isSuperOver == true ? 1 : match.totalOvers;
    final ballsLeft = overs * 6 - (inn?.legalBallsCount ?? 0);
    final need = target - runs;

    final stage = score == null
        ? 'IN PLAY'
        : score.isSuperOver
            ? 'SUPER OVER'
            : (score.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS');

    ({String name, String stat})? batter(String? id) {
      if (inn == null || id == null || id.isEmpty) return null;
      final p = inn.battingPlayers.where((p) => p.id == id).firstOrNull;
      if (p == null) return null;
      final s = inn.batsmanStats[id];
      return (name: p.name, stat: s == null ? '0 (0)' : '${s.runs} (${s.ballsFaced})');
    }

    final striker = batter(score?.strikerId);
    final nonStriker = batter(score?.nonStrikerId);

    String? bowlerLine;
    if (inn != null && score != null && score.bowlerId.isNotEmpty) {
      final name = inn.bowlingPlayers.where((p) => p.id == score.bowlerId).firstOrNull?.name;
      final s = inn.bowlerStatsMap[score.bowlerId];
      if (name != null) {
        bowlerLine = '$name  ${s?.wickets ?? 0}-${s?.runsConceded ?? 0} (${s?.oversBowled ?? '0.0'})';
      }
    }
    final lastBall = inn == null || inn.balls.isEmpty ? null : inn.balls.last;

    return EventGlow(
      eventKey: inn?.balls.length ?? 0,
      color: highlightFor(lastBall),
      radius: 22,
      child: TapBounce(
        onTap: () => onWatch(),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Status line ──
                Row(children: [
                  const LiveBadge(),
                  const SizedBox(width: 8),
                  Text(stage,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: Colors.white.withValues(alpha: 0.6))),
                  const Spacer(),
                  Text('${match.totalOvers} OV',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: Colors.white.withValues(alpha: 0.5))),
                ]),
                const SizedBox(height: 12),

                // ── Teams + score ──
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(battingTeam,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('vs $bowlingTeam',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.55))),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    RollingScore(runs: runs, wickets: wkts, size: 30),
                    const SizedBox(height: 3),
                    Text(
                        '$overDisp ov${inn != null ? '  ·  CRR ${inn.runRate.toStringAsFixed(1)}' : ''}',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6))),
                  ]),
                ]),

                // ── Chase ──
                if (isChasing) ...[
                  const SizedBox(height: 10),
                  ChaseMeter(runs: runs, target: target, height: 5),
                  const SizedBox(height: 5),
                  Text(
                    need <= 0
                        ? 'Target reached'
                        : 'Need $need off ${ballsLeft.clamp(0, 999)} · target $target',
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accentLight),
                  ),
                ],

                // ── Batters ──
                if (striker != null || nonStriker != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _batterChip(striker, onStrike: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _batterChip(nonStriker, onStrike: false)),
                  ]),
                ],

                // ── Bowler ──
                if (bowlerLine != null) ...[
                  const SizedBox(height: 7),
                  Row(children: [
                    Icon(Icons.sports_baseball_rounded,
                        size: 12, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        score!.pendingBowlerChange ? 'New bowler coming on…' : bowlerLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.75)),
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 12),

                // ── This over + actions ──
                Row(children: [
                  Expanded(child: OverTrack(balls: thisOver, size: 20, onDark: true)),
                  const SizedBox(width: 10),
                  if (canScore) ...[
                    _roundAction(Icons.visibility_rounded, () => onWatch()),
                    const SizedBox(width: 8),
                    _pillAction('Score', Icons.edit_rounded, AppColors.goldGradient,
                        () => onScore()),
                  ] else
                    _pillAction('Watch live', Icons.visibility_rounded, null,
                        () => onWatch()),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _batterChip(({String name, String stat})? b, {required bool onStrike}) {
    if (b == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: onStrike ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        if (onStrike) ...[
          const Icon(Icons.sports_cricket_rounded, size: 11, color: AppColors.accentLight),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(b.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.white.withValues(alpha: onStrike ? 1 : 0.75))),
        ),
        const SizedBox(width: 4),
        Text(b.stat,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: onStrike ? 1 : 0.7))),
      ]),
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      );

  /// [gradient] null gives the glass style used for spectators.
  Widget _pillAction(String label, IconData icon, Gradient? gradient, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? Colors.white.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(18),
            border: gradient == null ? Border.all(color: Colors.white.withValues(alpha: 0.2)) : null,
            boxShadow: gradient != null
                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      );
}

// ── Pill badge ─────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3)),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────
class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      art: EmptyArt.matches,
      title: 'The pitch is ready',
      message: 'No matches yet. Tap "Start New Match" above\nto bowl the first ball.',
    );
  }
}

// ── Match Card ─────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final MatchSummary match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'in_progress';
    final isDone = match.status == 'completed';

    return GestureDetector(
      onTap: () {
        if (isLive) {
          // Open the detailed live view (same Cricbuzz-style screen as group)
          context.push('/live/${match.id}', extra: {
            'teamAName'     : match.teamAName,
            'teamBName'     : match.teamBName,
            'totalOvers'    : match.totalOvers,
            'powerPlayOvers': match.powerPlayOvers,
          });
        } else if (isDone && match.scoreData != null) {
          try {
            context.push('/scorecard', extra: {
              'state': parsedScore(match.scoreData!),
              'overs': match.totalOvers,
            });
          } catch (_) {
            // Unreadable score data: nothing to open.
          }
        }
      },
      onLongPress: () => _options(context),
      child: Container(
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            // Header strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.danger.withValues(alpha: 0.06)
                    : isDone
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : AppColors.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                _statusBadge(isLive, isDone),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _kindBadge(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${match.totalOvers} overs',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            // Score row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                _teamCol(match.teamAName, match.teamAScore,
                    match.teamAWickets, false),
                Column(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/ic_cricket_ball_icon.png',
                        height: 16,
                      ),
                    ),
                  ),
                ]),
                _teamCol(match.teamBName, match.teamBScore,
                    match.teamBWickets, true),
              ]),
            ),
            // Result / footer
            if (match.result != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        size: 13,
                        color: AppColors.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    // Long team names: wrap instead of overflowing the card.
                    Flexible(
                      child: Text(match.result!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            // MoM + scorecard
            if (isDone)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(child: _momRow(match)),
                  const SizedBox(width: 8),
                  const Row(children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 13, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text('SCORECARD',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8)),
                  ]),
                ]),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  /// Group match (with the group's name) or solo match.
  Widget _kindBadge(BuildContext context) {
    final groupId = match.groupId;
    final groupName = groupId == null
        ? null
        : context.select<GroupBloc, String?>((b) =>
            b.state.groups.where((g) => g.id == groupId).firstOrNull?.name);
    final isGroup = groupId != null;
    final color = isGroup ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isGroup ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isGroup ? Icons.groups_rounded : Icons.person_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            // Group no longer in the list (e.g. left it): still say it's a group match.
            isGroup ? (groupName ?? 'Group') : 'Solo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ]),
    );
  }

  Widget _statusBadge(bool isLive, bool isDone) {
    Color c = isDone
        ? AppColors.success
        : isLive
            ? AppColors.danger
            : AppColors.textMuted;
    String label = isDone ? 'COMPLETED' : isLive ? 'LIVE' : 'SETUP';
    return Row(children: [
      if (isLive) ...[
        PulseAnimation(
          child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
      ],
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 0.8)),
    ]);
  }

  Widget _teamCol(
      String name, int? runs, int? wkts, bool alignEnd) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(name,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  height: 1.2),
              overflow: TextOverflow.ellipsis),
          if (runs != null)
            Text('$runs/$wkts',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2)),
        ],
      ),
    );
  }

  Widget _momRow(MatchSummary match) {
    final mom = calculateManOfTheMatch(match);
    if (mom == null) return const SizedBox.shrink();
    return Row(children: [
      const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFD97706)),
      const SizedBox(width: 5),
      Flexible(
        child: Text(mom.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
      ),
    ]);
  }

  void _options(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('MATCH OPTIONS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.5)),
            const SizedBox(height: 20),
            _optTile(context, 'Start Rematch', 'Same teams & settings',
                Icons.replay_rounded, AppColors.primary, _rematch),
            // Only the scorer's matches can be deleted (enforced server-side).
            if (match.isOwnedBy(context.read<AuthBloc>().userId)) ...[
              const SizedBox(height: 10),
              _optTile(context, 'Delete Match', 'Remove from history',
                  Icons.delete_outline_rounded, AppColors.danger, _delete),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _optTile(BuildContext context, String title, String sub,
      IconData icon, Color c, Function(BuildContext) action) {
    return GestureDetector(
      onTap: () {
        context.pop();
        action(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ])),
          const Icon(Icons.chevron_right, color: AppColors.border, size: 20),
        ]),
      ),
    );
  }

  void _rematch(BuildContext context) {
    context.read<MatchBloc>().add(ResetMatch());
    context.read<ScoreBloc>().add(ResetScoreboard());
    final s = MatchSettings(
        teamAName: match.teamAName,
        teamBName: match.teamBName,
        totalOvers: match.totalOvers,
        groupId: match.groupId);
    context.read<MatchBloc>().add(
        CreateMatch(s, DateTime.now().millisecondsSinceEpoch.toString()));
    if (match.teamA != null && match.teamB != null) {
      context.read<MatchBloc>().add(SelectTeams(match.teamA!, match.teamB!));
    }
    context.push('/match/setup', extra: {'isRematch': true});
  }

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Match?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () {
              context
                  .read<MatchListBloc>()
                  .add(RemoveMatchFromList(match.id));
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
