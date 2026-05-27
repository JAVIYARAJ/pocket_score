import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_cubit.dart' show AuthCubit;
import '../bloc/match_list_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../widgets/scorecard_widget.dart';
import 'player_screen.dart';
import 'match_setup_screen.dart';
import 'scoring_screen.dart';
import '../utils/stats_utils.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'groups_screen.dart';
import '../theme/animations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      ), // Scaffold
    );   // AnnotatedRegion
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
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
            child: Row(
              children: [
                _ProfileAvatarBtn(context: context),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${context.read<AuthCubit>().userName?.split(' ').first ?? 'Scorer'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ready for the next match?',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _ModernHeaderIconBtn(
                  icon: Icons.group_rounded,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const GroupsScreen())),
                ),
                const SizedBox(width: 8),
                _ModernHeaderIconBtn(
                  icon: Icons.emoji_events_rounded,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen())),
                ),
                const SizedBox(width: 8),
                _ModernHeaderIconBtn(
                  icon: Icons.people_rounded,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const PlayerScreen())),
                ),
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
                      ScorecardView.showAsBottomSheet(
                          context, ScoreState.fromJson(last.scoreData!));
                    } catch (_) {}
                  }
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 14, color: Colors.white60),
                      const SizedBox(width: 8),
                      const Text('LAST RESULT',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white60,
                              letterSpacing: 0.8)),
                      const SizedBox(width: 12),
                      Text(last.teamAName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('${last.teamAScore ?? 0}/${last.teamAWickets ?? 0}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('vs',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ),
                      Text(last.teamBName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('${last.teamBScore ?? 0}/${last.teamBWickets ?? 0}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Colors.white38),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _NewMatchCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<MatchBloc>().add(ResetMatch());
        context.read<ScoreBloc>().add(ResetScoreboard());
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MatchSetupScreen()));
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
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start New Match',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  SizedBox(height: 3),
                  Text('Set up teams and begin scoring',
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
    final cubit = context.read<AuthCubit>();
    final avatarUrl = cubit.avatarUrl;
    final name = cubit.userName ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 2),
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

class _ModernHeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ModernHeaderIconBtn(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Live Match Banner ──────────────────────────────────────────
class _LiveBanner extends StatelessWidget {
  final MatchSummary match;
  const _LiveBanner({required this.match});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ScoringScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    PulseAnimation(
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('LIVE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                            letterSpacing: 1)),
                  ]),
                ),
                const Spacer(),
                Text('${match.totalOvers} Overs',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _liveTeam(match.teamAName, match.teamAScore,
                    match.teamAWickets, match.teamAOvers, false),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [
                    Text('VS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.textMuted.withValues(alpha: 0.5))),
                  ]),
                ),
                _liveTeam(match.teamBName, match.teamBScore,
                    match.teamBWickets, match.teamBOvers, true),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Continue Scoring',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveTeam(String name, int? score, int? wkts, String? overs, bool right) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${score ?? 0}/${wkts ?? 0}',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1)),
          Text('(${overs ?? "0.0"} ov)',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
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
              child: const Icon(Icons.sports_cricket_rounded,
                  size: 48, color: AppColors.primaryLight),
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
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ScoringScreen()));
        } else if (isDone && match.scoreData != null) {
          try {
            ScorecardView.showAsBottomSheet(
                context, ScoreState.fromJson(match.scoreData!));
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
                    child: const Center(
                      child: Text('vs',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted)),
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
        Navigator.pop(context);
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
        totalOvers: match.totalOvers);
    context.read<MatchBloc>().add(
        CreateMatch(s, DateTime.now().millisecondsSinceEpoch.toString()));
    if (match.teamA != null && match.teamB != null) {
      context.read<MatchBloc>().add(SelectTeams(match.teamA!, match.teamB!));
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const MatchSetupScreen()));
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
