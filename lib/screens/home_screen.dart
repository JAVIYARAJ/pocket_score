import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/auth_cubit.dart' show AuthBloc;
import '../bloc/match_list_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/score_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../services/match_repository.dart';
import '../theme/app_theme.dart';
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
          // ── HERO HEADER ──────────────────────────────────────
          SliverToBoxAdapter(child: _HeroHeader(topPadding: top)),

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
    showModalBottomSheet(
      context       : context,
      useRootNavigator: true, // Prevents bottom nav from overlapping
      isDismissible : false,
      enableDrag    : false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerSetupSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// First-time player setup sheet — shown when the user has no preferences yet.
// Non-dismissible so the user always sets a role before playing.
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerSetupSheet extends StatefulWidget {
  @override
  State<_PlayerSetupSheet> createState() => _PlayerSetupSheetState();
}

class _PlayerSetupSheetState extends State<_PlayerSetupSheet> {
  String _role         = 'All-Rounder';
  String _battingStyle = 'Right-hand Bat';
  String _bowlingStyle = 'Right-arm Fast';

  void _save() {
    context.read<ProfileBloc>().add(UpdatePlayerPreferences(
      playerRole   : _role,
      battingStyle : _battingStyle,
      bowlingStyle : _bowlingStyle,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_cricket_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome to Pocket Score!',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('Set up your cricket profile to get started.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Role
            _label('PLAYER ROLE'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper']
                  .map((r) => _chip(r, _role == r,
                      () => setState(() => _role = r)))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Batting style
            _label('BATTING STYLE'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['Right-hand Bat', 'Left-hand Bat']
                  .map((b) => _chip(b, _battingStyle == b,
                      () => setState(() => _battingStyle = b)))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Bowling style
            _label('BOWLING STYLE'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                'Right-arm Fast',
                'Right-arm Spin',
                'Left-arm Fast',
                'Left-arm Spin',
                'None',
              ].map((w) => _chip(w, _bowlingStyle == w,
                      () => setState(() => _bowlingStyle = w)))
                  .toList(),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Start Playing 🏏',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textMuted,
            )),
      ),
    );
  }
}

// ── Hero Header ────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final double topPadding;
  const _HeroHeader({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Stack(
        children: [
          // ── Cricket Watermarks ──────────────────────────────
          Positioned(
            right: -20,
            top: topPadding - 10,
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
              // Top bar
              Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, ${context.read<AuthBloc>().userName?.split(' ').first ?? 'Scorer'} 🏏',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ready to step up to the crease?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _ProfileAvatarBtn(context: context),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // New Match / Live Match card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: BlocBuilder<MatchListBloc, MatchListState>(
                  builder: (context, state) {
                    final live = state.matches.cast<MatchSummary?>()
                        .firstWhere((m) => m?.status == 'in_progress',
                            orElse: () => null);
                    if (live != null) return _LiveBanner(match: live);
                    return _NewMatchCard(context);
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
                            'state': ScoreState.fromJson(last.scoreData!),
                            'overs': last.totalOvers,
                          });
                        } catch (_) {}
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

  Widget _NewMatchCard(BuildContext context) {
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

// ── Profile avatar button for home header ─────────────────────
class _ProfileAvatarBtn extends StatelessWidget {
  final BuildContext context;
  const _ProfileAvatarBtn({required this.context});

  @override
  Widget build(BuildContext ctx) {
    final cubit = context.read<AuthBloc>();
    final avatarUrl = cubit.avatarUrl;
    final name = cubit.userName ?? '';

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
    try {
      final data = await MatchRepository(Supabase.instance.client)
          .getLiveScore(widget.match.id);
      if (mounted) setState(() => _scoreData = data);
    } catch (_) {}
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
        .subscribe();
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
      if (_scoreData != null) score = ScoreState.fromJson(_scoreData!);
    } catch (_) {}

    final inn = score?.currentInnings;
    final battingTeam = inn?.battingTeamName ?? widget.match.teamAName;
    final runs = inn?.totalRuns ?? widget.match.teamAScore ?? 0;
    final wkts = inn?.totalWickets ?? widget.match.teamAWickets ?? 0;
    final overDisp = inn?.overDisplay ?? widget.match.teamAOvers ?? '0.0';
    final crr = inn != null ? inn.runRate.toStringAsFixed(2) : '—';

    final thisOver = <dynamic>[];
    if (inn != null) {
      final sums = inn.overSummaries;
      if (sums.isNotEmpty) thisOver.addAll(sums.last.balls as List);
    }

    String? strikerName, nonStrikerName;
    String strikerStat = '', nonStrikerStat = '';
    if (score != null && inn != null) {
      Player? findP(List<dynamic> players, String? id) {
        if (id == null || id.isEmpty) return null;
        try {
          return players.firstWhere((p) => p.id == id) as Player;
        } catch (_) {
          return null;
        }
      }

      final striker = findP(inn.battingPlayers, score.strikerId);
      final nonStriker = findP(inn.battingPlayers, score.nonStrikerId);
      final batStats = inn.batsmanStats;
      final sStats = batStats[score.strikerId];
      final nsStats = batStats[score.nonStrikerId];
      strikerName = striker?.name;
      nonStrikerName = nonStriker?.name;
      if (sStats != null) strikerStat = '${sStats.runs} (${sStats.ballsFaced})';
      if (nsStats != null) nonStrikerStat = '${nsStats.runs} (${nsStats.ballsFaced})';
    }

    final isChasing = (inn?.target ?? 0) > 0;
    final need = isChasing ? (inn!.target - runs) : 0;
    final totalBalls = widget.match.totalOvers * 6;
    final used = inn?.legalBallsCount ?? 0;
    final ballsLeft = totalBalls > 0 ? (totalBalls - used) : 0;

    return TapBounce(
      onTap: () => _watchLive(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Stack(
          children: [
            // Background watermark
            Positioned(
              right: -30,
              top: -30,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(Icons.sports_cricket_rounded,
                    size: 180, color: Colors.white.withValues(alpha: 0.04)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Row: LIVE Badge & Overs ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PulseAnimation(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: AppColors.danger.withValues(alpha: 0.3), blurRadius: 4),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: AppColors.danger, size: 8),
                              SizedBox(width: 6),
                              Text('LIVE',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.danger,
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${widget.match.totalOvers} OVERS',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  
                  // ── Teams ──
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.match.teamAName.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Text('VS',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accentLight)),
                      ),
                      Expanded(
                        child: Text(widget.match.teamBName.toUpperCase(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                              letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // ── Main Score ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left: Batting Team & Score
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(battingTeam.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentLight,
                                  letterSpacing: 1),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$runs',
                                  style: const TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1,
                                      letterSpacing: -2),
                                ),
                                const SizedBox(width: 4),
                                Text('/$wkts',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      height: 1),
                                ),
                                const SizedBox(width: 10),
                                Text('($overDisp)',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white60),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Right: CRR & Need
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildGlassChip('CRR', crr),
                          if (isChasing) ...[
                            const SizedBox(height: 8),
                            _buildGlassChip('REQ',
                                '$need${ballsLeft > 0 ? ' in $ballsLeft' : ''}',
                                isHighlight: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                  
                  // ── Batsmen ──
                  if (strikerName != null || nonStrikerName != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          if (strikerName != null)
                            _buildBatsmanRow(strikerName, strikerStat, true),
                          if (strikerName != null && nonStrikerName != null)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1, color: Colors.white12)),
                          if (nonStrikerName != null)
                            _buildBatsmanRow(nonStrikerName, nonStrikerStat, false),
                        ],
                      ),
                    ),
                  ],
                  
                  // ── This Over ──
                  if (thisOver.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('THIS OVER',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white54,
                                letterSpacing: 1.5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: thisOver
                                  .map((b) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _HomeBallChip(ball: b)))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // ── Actions ──
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _watchLive(context),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tv_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Spectate',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _resumeScoring(context),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Score Match',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassChip(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? Colors.white
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isHighlight
                ? Colors.white
                : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: isHighlight ? AppColors.primaryDark : Colors.white54,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isHighlight ? AppColors.primaryDark : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBatsmanRow(String name, String stat, bool isStriker) {
    return Row(
      children: [
        if (isStriker)
          const Icon(Icons.sports_cricket_rounded,
              color: AppColors.accentLight, size: 14)
        else
          const SizedBox(width: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isStriker ? FontWeight.w800 : FontWeight.w600,
              color: isStriker ? Colors.white : Colors.white70,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          stat,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isStriker ? FontWeight.bold : FontWeight.w600,
            color: isStriker ? Colors.white : Colors.white60,
          ),
        ),
      ],
    );
  }
}

// ── Compact ball chip for home screen ─────────────────────────
class _HomeBallChip extends StatelessWidget {
  final dynamic ball;
  const _HomeBallChip({required this.ball});

  @override
  Widget build(BuildContext context) {
    final isWicket = (ball.isWicket as bool?) ?? false;
    final runs     = (ball.runs     as int?)  ?? 0;
    final typeStr  = (ball.type?.toString() ?? '').toLowerCase();
    final isWide   = typeStr.contains('wide');
    final isNoBall = typeStr.contains('noball') ||
                     typeStr.contains('no_ball');

    Color  bg; String label; Color fg = Colors.white;
    if (isWicket)      { bg = AppColors.danger;  label = 'W'; }
    else if (runs == 6){ bg = AppColors.success;  label = '6'; }
    else if (runs == 4){ bg = AppColors.info;     label = '4'; }
    else if (isWide)   { bg = AppColors.warning;  label = 'Wd'; }
    else if (isNoBall) { bg = AppColors.accent;   label = runs > 0 ? 'Nb+$runs' : 'Nb'; }
    else if (runs == 0){ bg = Colors.white.withValues(alpha: 0.15); label = '·'; }
    else               { bg = Colors.white.withValues(alpha: 0.2); label = '$runs'; }

    final bool isSolid = isWicket || runs == 6 || runs == 4 || isWide || isNoBall;
    return Container(
      margin: const EdgeInsets.only(right: 5),
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: isSolid ? bg.withValues(alpha: 0.9) : bg,
        borderRadius: BorderRadius.circular(6),
        border: isSolid
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 10)),
    );
  }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 25,
                    child: Image.asset(
                      'assets/icons/wickets.png',
                      height: 40,
                      color: AppColors.primaryLight,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  Positioned(
                    bottom: 15,
                    right: 20,
                    child: Image.asset(
                      'assets/icons/ic_cricket_ball_icon.png',
                      height: 20,
                      color: AppColors.primary,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('No Matches Yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Tap "Start New Match" above\nto begin your first game',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.6),
            ),
          ],
        ),
      ),
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
              'state': ScoreState.fromJson(match.scoreData!),
              'overs': match.totalOvers,
            });
          } catch (_) {}
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
                const Spacer(),
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
                    Text(match.result!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            // MoM + scorecard
            if (isDone)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  _momRow(match),
                  const Spacer(),
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
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
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
      Text(mom.name,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted)),
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
            const SizedBox(height: 10),
            _optTile(context, 'Delete Match', 'Remove from history',
                Icons.delete_outline_rounded, AppColors.danger, _delete),
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
          Icon(Icons.chevron_right, color: AppColors.border, size: 20),
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
