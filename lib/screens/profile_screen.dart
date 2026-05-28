import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart' show AuthBloc, PocketAuthState, SignOut;
import '../bloc/match_list_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Profile Screen with a premium Cricket-friendly UI
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);
  @override
  void dispose() {
    _activeTabNotifier.dispose();
    super.dispose();
  }

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
        body: BlocBuilder<AuthBloc, PocketAuthState>(
          builder: (context, authState) {
            final authBloc = context.read<AuthBloc>();
            final user = authBloc.currentUser;
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return BlocBuilder<MatchListBloc, MatchListState>(
              builder: (context, matchListState) {
                final completed = matchListState.matches
                    .where((m) => m.status == 'completed')
                    .toList();

                // Compute player stats.
                final statsMap = calculateAllPlayerStats(completed, const []);
                final myStats = statsMap[user.id];

                // Global Scorer totals
                int totalRunsScored = 0;
                int totalWicketsFallen = 0;
                int totalFours = 0;
                int totalSixes = 0;
                for (final s in statsMap.values) {
                  totalRunsScored += s.runs;
                  totalWicketsFallen += s.wickets;
                  totalFours += s.fours;
                  totalSixes += s.sixes;
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── STADIUM & PITCH HEADER ──
                      _buildStadiumHeader(context, top, user, myStats),
                      const SizedBox(height: 24),

                      ValueListenableBuilder<int>(
                        valueListenable: _activeTabNotifier,
                        builder: (context, activeTabIndex, _) {
                          return Column(
                            children: [
                              // ── CUSTOM SEGMENTED TAB SELECTOR ──
                              _buildCustomSegmentedTabBar(activeTabIndex),
                              const SizedBox(height: 20),

                              // ── TAB CONTENT ──
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (activeTabIndex == 0)
                                      _buildBattingStats(myStats),
                                    if (activeTabIndex == 1)
                                      _buildBowlingStats(myStats),
                                    if (activeTabIndex == 2)
                                      _buildScoringStats(
                                        matchListState.matches.length,
                                        completed.length,
                                        totalRunsScored,
                                        totalWicketsFallen,
                                        totalFours,
                                        totalSixes,
                                      ),

                                    const SizedBox(height: 24),
                                    _buildAccountCard(user),
                                    const SizedBox(height: 16),
                                    _buildActionsCard(context),
                                    const SizedBox(height: 120),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── CUSTOM SEGMENTED TAB BAR ──
  Widget _buildCustomSegmentedTabBar(int activeTabIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
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
                  left: activeTabIndex * tabWidth,
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
                    _buildTabButton(0, '🏏 BATTING', activeTabIndex),
                    _buildTabButton(1, '⚾ BOWLING', activeTabIndex),
                    _buildTabButton(2, '📝 SCORING', activeTabIndex),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int activeTabIndex) {
    final isSelected = activeTabIndex == index;
    return Expanded(
      child: TapBounce(
        onTap: () {
          _activeTabNotifier.value = index;
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textMuted,
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER WITH DEEP GREEN GRASS WATERMARK & PLAYER CARD ──
  Widget _buildStadiumHeader(BuildContext context, double topPadding, User user, PlayerStats? myStats) {
    final profileState = context.watch<ProfileBloc>().state;
    final profile     = profileState is ProfileLoaded ? profileState.profile : null;
    final role        = profile?.playerRole   ?? 'All-Rounder';
    final battingStyle = profile?.battingStyle ?? 'Right-hand Bat';
    final bowlingStyle = profile?.bowlingStyle ?? 'Right-arm Fast';

    final rating = myStats?.impactRankScore?.round() ?? 60;
    final ratingColor = rating >= 80 ? Colors.amber : (rating >= 60 ? Colors.cyanAccent : AppColors.textMuted);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Cricket Pitch Background Painter
          Positioned.fill(
            child: CustomPaint(
              painter: CricketPitchPainter(),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 28),
            child: Column(
              children: [
                // Top title bar
                Row(
                  children: [
                    if (context.canPop())
                      TapBounce(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      )
                    else
                      const SizedBox(width: 34),
                    const Spacer(),
                    const Text(
                      'PLAYER PROFILE',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 34),
                  ],
                ),
                const SizedBox(height: 24),

                // ── GLASSMORPHIC TRADING PLAYER CARD ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Glow Avatar Frame
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: rating >= 80
                                    ? [Colors.amber, Colors.orangeAccent]
                                    : [AppColors.primaryLight, Colors.cyan],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (rating >= 80 ? Colors.amber : AppColors.primaryLight).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                user.userMetadata?['avatar_url'] as String? ?? '',
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: AppColors.primary,
                                  child: Center(
                                    child: Text(
                                      (user.userMetadata?['name'] as String? ?? 'P')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Name and Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  user.userMetadata?['name'] as String? ?? 'Scorer',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        role.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rating Score Badge
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ratingColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: ratingColor.withValues(alpha: 0.4), width: 2),
                              boxShadow: [
                                BoxShadow(color: ratingColor.withValues(alpha: 0.1), blurRadius: 8),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$rating',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: ratingColor,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  'OVR',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: ratingColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: Colors.white12),
                      const SizedBox(height: 14),

                      // Player Style attributes row
                      Row(
                        children: [
                          Expanded(
                            child: _buildCardDetail('BATTING', battingStyle, Icons.sports_cricket_rounded),
                          ),
                          Container(width: 1, height: 28, color: Colors.white12),
                          Expanded(
                            child: _buildCardDetail('BOWLING', bowlingStyle, Icons.sports_baseball_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Edit Button
                      TapBounce(
                        onTap: () => _showEditProfileSheet(context, user, role, battingStyle, bowlingStyle),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_rounded, color: Colors.white70, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Customize Player Card',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
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
        ],
      ),
    );
  }

  Widget _buildCardDetail(String title, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white60, size: 12),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }

  // ── BATTING CAREER STATS PANEL ──
  Widget _buildBattingStats(PlayerStats? myStats) {
    if (myStats == null || myStats.inningsBatted == 0) {
      return _buildEmptyStatsBanner('No Batting stats recorded yet.\nPlay matches to update your career stats.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Career Batting Stats'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard('Matches Batted', '${myStats.inningsBatted}', Icons.calendar_today_rounded, AppColors.primary),
            _buildStatCard('Total Runs', '${myStats.runs}', Icons.scoreboard_outlined, AppColors.info),
            _buildStatCard('Average', myStats.average > 0 ? myStats.average.toStringAsFixed(2) : '—', Icons.trending_up_rounded, Colors.amber),
            _buildStatCard('Strike Rate', myStats.strikeRate > 0 ? myStats.strikeRate.toStringAsFixed(1) : '—', Icons.bolt_rounded, Colors.orange),
            _buildStatCard('Fours (4s)', '${myStats.fours}', Icons.arrow_outward_rounded, Colors.blue),
            _buildStatCard('Sixes (6s)', '${myStats.sixes}', Icons.rocket_launch_rounded, Colors.purple),
          ],
        ),
      ],
    );
  }

  // ── BOWLING CAREER STATS PANEL ──
  Widget _buildBowlingStats(PlayerStats? myStats) {
    if (myStats == null || myStats.matchesBowled == 0) {
      return _buildEmptyStatsBanner('No Bowling stats recorded yet.\nPlay matches to update your career stats.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Career Bowling Stats'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard('Matches Bowled', '${myStats.matchesBowled}', Icons.timer_rounded, AppColors.accent),
            _buildStatCard('Wickets', '${myStats.wickets}', Icons.sports_baseball_rounded, AppColors.danger),
            _buildStatCard('Economy Rate', myStats.economy > 0 ? myStats.economy.toStringAsFixed(2) : '—', Icons.speed_rounded, Colors.indigo),
            _buildStatCard('Dot Ball %', myStats.dotBallPercent > 0 ? '${myStats.dotBallPercent.toStringAsFixed(1)}%' : '—', Icons.circle_outlined, Colors.teal),
            _buildStatCard('Catches', '${myStats.catches}', Icons.front_hand_rounded, Colors.amber),
            _buildStatCard('Run Outs', '${myStats.runOuts}', Icons.run_circle_rounded, Colors.deepOrange),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyStatsBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          const Icon(Icons.sports_cricket_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── SCORING SUMMARY PANEL ──
  Widget _buildScoringStats(int totalMatches, int completedMatches, int runs, int wickets, int fours, int sixes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Scoring Management'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard('Matches Managed', '$totalMatches', Icons.assignment_rounded, AppColors.primary),
            _buildStatCard('Completed', '$completedMatches', Icons.check_circle_outline_rounded, AppColors.success),
            _buildStatCard('Runs Managed', '$runs', Icons.sports_score_rounded, AppColors.info),
            _buildStatCard('Wickets Managed', '$wickets', Icons.sports_kabaddi_rounded, AppColors.danger),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── ACCOUNT & APP SETTINGS CARD ──
  Widget _buildAccountCard(User user) {
    final memberSince = _formatDate(user.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Account details'),
        const SizedBox(height: 12),
        Container(
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.mail_outline_rounded,
                iconColor: AppColors.info,
                label: 'Email Address',
                value: user.email ?? '—',
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
                label: 'Account ID',
                value: user.id.length > 8 ? '${user.id.substring(0, 8)}…' : user.id,
                mono: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ACTIONS CARD (SIGN OUT) ──
  Widget _buildActionsCard(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.logout_rounded,
            iconColor: AppColors.danger,
            label: 'Sign Out Account',
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  void _confirmSignOut(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign Out?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your match statistics and player profiles\nare securely stored in the cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<AuthBloc>().add(const SignOut());
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

  // ── CUSTOM PLAYER CARD EDITING SHEET ──
  // ── CUSTOM PLAYER CARD EDITING SHEET ──
  String _getRoleEmoji(String role) {
    switch (role) {
      case 'Batsman': return '🏏';
      case 'Bowler': return '⚾';
      case 'All-Rounder': return '⚡';
      case 'Wicketkeeper': return '🧤';
      default: return '🏏';
    }
  }

  String _getBattingEmoji(String style) {
    switch (style) {
      case 'Right-hand Bat': return '👉';
      case 'Left-hand Bat': return '👈';
      default: return '🏏';
    }
  }

  String _getBowlingEmoji(String style) {
    switch (style) {
      case 'Right-arm Fast': return '⚡';
      case 'Right-arm Spin': return '🌀';
      case 'Left-arm Fast': return '⚡';
      case 'Left-arm Spin': return '🌀';
      default: return '❌';
    }
  }

  Widget _buildCustomSelectorCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? iconEmoji,
  }) {
    return TapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconEmoji != null) ...[
              Text(iconEmoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, User user, String currentRole, String currentBatting, String currentBowling) {
    String selectedRole = currentRole;
    String selectedBatting = currentBatting;
    String selectedBowling = currentBowling;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Player Customization',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Personalize your cricket profile card',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── ROLE SELECTOR ──
                  const Row(
                    children: [
                      Icon(Icons.sports_cricket_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'PLAYER ROLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ['Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper'].map((r) {
                      return _buildCustomSelectorCard(
                        label: r,
                        isSelected: selectedRole == r,
                        iconEmoji: _getRoleEmoji(r),
                        onTap: () => setSheetState(() => selectedRole = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── BATTING SELECTOR ──
                  const Row(
                    children: [
                      Icon(Icons.pan_tool_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'BATTING STYLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ['Right-hand Bat', 'Left-hand Bat'].map((b) {
                      return _buildCustomSelectorCard(
                        label: b,
                        isSelected: selectedBatting == b,
                        iconEmoji: _getBattingEmoji(b),
                        onTap: () => setSheetState(() => selectedBatting = b),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── BOWLING SELECTOR ──
                  const Row(
                    children: [
                      Icon(Icons.adjust_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'BOWLING STYLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ['Right-arm Fast', 'Right-arm Spin', 'Left-arm Fast', 'Left-arm Spin', 'None'].map((w) {
                      return _buildCustomSelectorCard(
                        label: w,
                        isSelected: selectedBowling == w,
                        iconEmoji: _getBowlingEmoji(w),
                        onTap: () => setSheetState(() => selectedBowling = w),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Save Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            context.read<ProfileBloc>().add(
                              UpdatePlayerPreferences(
                                playerRole   : selectedRole,
                                battingStyle : selectedBatting,
                                bowlingStyle : selectedBowling,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          child: const Text('Save Card', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CRICKET PITCH BACKGROUND PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class CricketPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pitchWidth = size.width * 0.44;
    final pitchHeight = size.height * 0.72;
    final left = (size.width - pitchWidth) / 2;
    final top = (size.height - pitchHeight) / 2;

    // Draw pitch boundaries
    canvas.drawRect(Rect.fromLTWH(left, top, pitchWidth, pitchHeight), paint);

    // Draw Creases
    final topCreaseY = top + pitchHeight * 0.12;
    canvas.drawLine(Offset(left - 12, topCreaseY), Offset(left + pitchWidth + 12, topCreaseY), paint);

    final bottomCreaseY = top + pitchHeight * 0.88;
    canvas.drawLine(Offset(left - 12, bottomCreaseY), Offset(left + pitchWidth + 12, bottomCreaseY), paint);

    // Stumps lines
    final stumpPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final middleX = left + pitchWidth / 2;
    canvas.drawLine(Offset(middleX - 6, topCreaseY), Offset(middleX + 6, topCreaseY), stumpPaint);
    canvas.drawLine(Offset(middleX - 6, bottomCreaseY), Offset(middleX + 6, bottomCreaseY), stumpPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE DISPLAY ELEMENTS
// ─────────────────────────────────────────────────────────────────────────────
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
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: mono ? 12 : 13,
                fontWeight: FontWeight.bold,
                color: mono ? AppColors.textMuted : AppColors.textPrimary,
                fontFamily: mono ? 'monospace' : null,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
