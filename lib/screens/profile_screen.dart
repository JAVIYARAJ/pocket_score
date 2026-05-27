import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../bloc/auth_cubit.dart'
    show AuthCubit, PocketAuthState;
import '../bloc/match_list_bloc.dart';
import '../bloc/player_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
        body: BlocBuilder<AuthCubit, PocketAuthState>(
          builder: (context, authState) {
            final cubit = context.read<AuthCubit>();
            final user = cubit.currentUser;
            return CustomScrollView(
              slivers: [
                // ── Gradient header ───────────────────────────────────
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    topPadding: top,
                    name: cubit.userName ?? 'Scorer',
                    email: cubit.userEmail ?? '',
                    avatarUrl: cubit.avatarUrl,
                    user: user,
                  ),
                ),

                // ── Activity stats ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _ActivityStats(),
                  ),
                ),

                // ── Performance summary ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _PerformanceSummary(),
                  ),
                ),

                // ── Account info ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _AccountCard(user: user),
                  ),
                ),

                // ── Actions ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _ActionsCard(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — green gradient + avatar + name
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final double topPadding;
  final String name;
  final String email;
  final String? avatarUrl;
  final sb.User? user;

  const _ProfileHeader({
    required this.topPadding,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button row
          Row(
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
              const Spacer(),
              const Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3,
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Invisible spacer to balance the back button
              const SizedBox(width: 36),
            ],
          ),

          const SizedBox(height: 28),

          // Avatar
          FadeInEntrance(
            delay: const Duration(milliseconds: 120),
            offset: Offset.zero,
            child: _Avatar(name: name, avatarUrl: avatarUrl, size: 90),
          ),

          const SizedBox(height: 16),

          // Name
          FadeInEntrance(
            delay: const Duration(milliseconds: 180),
            offset: const Offset(0, 12),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Email
          FadeInEntrance(
            delay: const Duration(milliseconds: 220),
            offset: const Offset(0, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline_rounded,
                    color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // "Signed in with Google" badge
          FadeInEntrance(
            delay: const Duration(milliseconds: 260),
            offset: Offset.zero,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      size: 13, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'Signed in with Google',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar widget — network image with initials fallback
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _Avatar({required this.name, required this.avatarUrl, required this.size});

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final border = Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(child: _inner()),
    );
    return border;
  }

  Widget _inner() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initialsCircle(),
      );
    }
    return _initialsCircle();
  }

  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity stats — 3 stat chips in a row
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchListBloc, MatchListState>(
      builder: (context, matchState) {
        return BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, playerState) {
            final total = matchState.matches.length;
            final completed = matchState.matches
                .where((m) => m.status == 'completed')
                .length;
            final players = playerState.players.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Activity'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        value: '$total',
                        label: 'Matches',
                        icon: Icons.sports_cricket_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        value: '$completed',
                        label: 'Completed',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        value: '$players',
                        label: 'Players',
                        icon: Icons.people_rounded,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance summary — derived from all matches
// ─────────────────────────────────────────────────────────────────────────────
class _PerformanceSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchListBloc, MatchListState>(
      builder: (context, matchState) {
        return BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, playerState) {
            // Derive aggregate numbers across all completed matches
            int totalRuns = 0;
            int totalWickets = 0;
            int totalSixes = 0;
            int totalFours = 0;
            String? topScorerName;
            int topScorerRuns = 0;
            String? topBowlerName;
            int topBowlerWickets = 0;

            final completed = matchState.matches
                .where((m) => m.status == 'completed')
                .toList();

            if (completed.isNotEmpty && playerState.players.isNotEmpty) {
              final statsMap = calculateAllPlayerStats(
                completed,
                playerState.players,
              );

              for (final s in statsMap.values) {
                totalRuns += s.runs;
                totalWickets += s.wickets;
                totalSixes += s.sixes;
                totalFours += s.fours;

                if (s.runs > topScorerRuns) {
                  topScorerRuns = s.runs;
                  topScorerName = s.name;
                }
                if (s.wickets > topBowlerWickets) {
                  topBowlerWickets = s.wickets;
                  topBowlerName = s.name;
                }
              }
            }

            if (completed.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Tournament Summary'),
                const SizedBox(height: 12),

                // Aggregate run/wicket row
                Container(
                  decoration: AppDecorations.card(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _AggStat(
                            value: _fmt(totalRuns),
                            label: 'Total Runs',
                            icon: Icons.sports_cricket_rounded,
                            color: AppColors.info,
                          ),
                          _vertDivider(),
                          _AggStat(
                            value: '$totalWickets',
                            label: 'Wickets',
                            icon: Icons.sports_baseball_rounded,
                            color: AppColors.danger,
                          ),
                          _vertDivider(),
                          _AggStat(
                            value: '$totalSixes',
                            label: 'Sixes',
                            icon: Icons.bolt_rounded,
                            color: AppColors.success,
                          ),
                          _vertDivider(),
                          _AggStat(
                            value: '$totalFours',
                            label: 'Fours',
                            icon: Icons.arrow_forward_rounded,
                            color: AppColors.accent,
                          ),
                        ],
                      ),

                      if (topScorerName != null || topBowlerName != null) ...[
                        const Divider(height: 24, color: AppColors.border),
                        if (topScorerName != null)
                          _TopPlayerRow(
                            icon: Icons.sports_cricket_rounded,
                            iconColor: AppColors.info,
                            label: 'Top Scorer',
                            name: topScorerName,
                            stat: '$topScorerRuns runs',
                          ),
                        if (topScorerName != null && topBowlerName != null)
                          const SizedBox(height: 10),
                        if (topBowlerName != null)
                          _TopPlayerRow(
                            icon: Icons.sports_baseball_rounded,
                            iconColor: AppColors.danger,
                            label: 'Top Bowler',
                            name: topBowlerName,
                            stat: '$topBowlerWickets wkts',
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _vertDivider() => Container(
        width: 1,
        height: 44,
        color: AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account info card
// ─────────────────────────────────────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final sb.User? user;
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final memberSince = _formatDate(user?.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Account'),
        const SizedBox(height: 12),
        Container(
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.mail_outline_rounded,
                iconColor: AppColors.info,
                label: 'Email',
                value: user?.email ?? '—',
              ),
              const Divider(height: 1, color: AppColors.border, indent: 56),
              _InfoRow(
                icon: Icons.login_rounded,
                iconColor: AppColors.accent,
                label: 'Provider',
                value: 'Google',
              ),
              const Divider(height: 1, color: AppColors.border, indent: 56),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                iconColor: AppColors.primary,
                label: 'Member Since',
                value: memberSince,
              ),
              const Divider(height: 1, color: AppColors.border, indent: 56),
              _InfoRow(
                icon: Icons.fingerprint_rounded,
                iconColor: AppColors.textMuted,
                label: 'User ID',
                value: _shortId(user?.id),
                mono: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  String _shortId(String? id) {
    if (id == null) return '—';
    return '${id.substring(0, 8)}…';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actions card — sign out
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Account Actions'),
        const SizedBox(height: 12),
        Container(
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              _ActionRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.danger,
                label: 'Sign Out',
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context) {
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
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.danger, size: 28),
            ),
            const SizedBox(height: 16),

            const Text(
              'Sign Out?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your match history and player data\nare safely stored in the cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // close sheet
                      Navigator.pop(context); // close profile screen
                      context.read<AuthCubit>().signOut();
                    },
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AggStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _AggStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPlayerRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String name;
  final String stat;

  const _TopPlayerRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.name,
    required this.stat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            stat,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: mono ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: mono ? AppColors.textMuted : AppColors.textPrimary,
                fontFamily: mono ? 'monospace' : null,
                letterSpacing: mono ? 0.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.border, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — section label above a card
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text) => Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
