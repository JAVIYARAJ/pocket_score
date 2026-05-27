import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/group_cubit.dart';
import '../bloc/player_bloc.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';
import '../services/group_repository.dart';
import '../bloc/score_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';
import '../widgets/leaderboard_widgets.dart';
import '../widgets/scorecard_widget.dart';
import 'live_score_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupDetailScreen — 3-tab view: Matches | Leaderboard | Members
// ─────────────────────────────────────────────────────────────────────────────
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final GroupRepository _repo;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _repo = GroupRepository(Supabase.instance.client);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Leave group dialog ────────────────────────────────────────────────────
  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Group',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to leave "${widget.group.name}"? You can rejoin using the invite code.',
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<GroupCubit>().leaveGroup(widget.group.id);
      if (mounted) Navigator.pop(context);
    }
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
        body: Column(
          children: [
            _GroupDetailHeader(
              group: widget.group,
              tabController: _tab,
              onLeave: _confirmLeave,
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _MatchesTab(repo: _repo, groupId: widget.group.id),
                  _LeaderboardTab(repo: _repo, groupId: widget.group.id),
                  _MembersTab(repo: _repo, groupId: widget.group.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — gradient + invite code chip + TabBar
// ─────────────────────────────────────────────────────────────────────────────
class _GroupDetailHeader extends StatelessWidget {
  final Group group;
  final TabController tabController;
  final VoidCallback onLeave;

  const _GroupDetailHeader({
    required this.group,
    required this.tabController,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row: back, name, invite code, overflow ──────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 12),
            child: FadeInEntrance(
              delay: const Duration(milliseconds: 80),
              offset: const Offset(0, -16),
              child: Row(
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GROUP',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2.5,
                                color: Colors.white60,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(group.name,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Invite code chip + copy button
                  TapBounce(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: group.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Invite code "${group.inviteCode}" copied!'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(group.inviteCode,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2)),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded,
                              size: 14, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Overflow menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (val) {
                      if (val == 'leave') onLeave();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app_rounded,
                                color: AppColors.danger, size: 18),
                            SizedBox(width: 10),
                            Text('Leave Group',
                                style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── TabBar ─────────────────────────────────────────────
          TabBar(
            controller: tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            indicatorColor: Colors.white,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Matches'),
              Tab(text: 'Leaderboard'),
              Tab(text: 'Members'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Matches
// Uses a FutureBuilder for the initial reliable load, then a StreamBuilder
// for live updates.  Storing both in initState prevents them from being
// recreated on every rebuild (which would reset ConnectionState → waiting).
// ─────────────────────────────────────────────────────────────────────────────
class _MatchesTab extends StatefulWidget {
  final GroupRepository repo;
  final String groupId;
  const _MatchesTab({required this.repo, required this.groupId});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab>
    with AutomaticKeepAliveClientMixin {
  late final Future<List<MatchSummary>> _initialFuture;
  late final Stream<List<MatchSummary>> _liveStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Both are created once in initState — safe from rebuild-driven recreation.
    _initialFuture = widget.repo.getGroupMatches(widget.groupId);
    _liveStream    = widget.repo.watchGroupMatches(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // FutureBuilder gives us a fast, guaranteed first render.
    // StreamBuilder overlays real-time updates on top once the subscription
    // is active, but falls back to the Future data if the stream is slow.
    return FutureBuilder<List<MatchSummary>>(
      future: _initialFuture,
      builder: (context, futureSnap) {
        // Before the initial HTTP call resolves, show the spinner once.
        if (futureSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }

        // Once we have the initial data, overlay the realtime stream.
        return StreamBuilder<List<MatchSummary>>(
          stream: _liveStream,
          // seed with the future data so we never flash an empty state while
          // waiting for the first stream event.
          initialData: futureSnap.data ?? const [],
          builder: (context, streamSnap) {
            if (streamSnap.hasError) {
              return _CentreMsg(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load matches',
                  sub: streamSnap.error.toString());
            }
            final matches = streamSnap.data ?? futureSnap.data ?? const [];
            if (matches.isEmpty) {
              return const _CentreMsg(
                icon: Icons.sports_cricket_rounded,
                title: 'No matches yet',
                sub: 'Start a match and assign it to this group.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              itemCount: matches.length,
              itemBuilder: (ctx, i) => FadeInEntrance(
                key: ValueKey(matches[i].id),
                delay: Duration(milliseconds: 50 * i),
                offset: const Offset(0, 16),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GroupMatchCard(match: matches[i]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match card for the Matches tab
// ─────────────────────────────────────────────────────────────────────────────
class _GroupMatchCard extends StatelessWidget {
  final MatchSummary match;
  const _GroupMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'live';
    final isCompleted = match.status == 'completed';

    return TapBounce(
      onTap: () {
        if (isLive) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveScoreScreen(
                matchId: match.id,
                teamAName: match.teamAName,
                teamBName: match.teamBName,
              ),
            ),
          );
        } else if (isCompleted && match.scoreData != null) {
          final state = ScoreState.fromJson(match.scoreData!);
          ScorecardView.showAsBottomSheet(context, state);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLive
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.5),
            width: isLive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isLive
                  ? AppColors.success.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status chip + date
            Row(
              children: [
                _StatusChip(status: match.status),
                const Spacer(),
                Text(
                  _dateLabel(match.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Teams + scores
            Row(
              children: [
                Expanded(
                  child: _TeamScore(
                    name: match.teamAName,
                    score: match.teamAScore,
                    wickets: match.teamAWickets,
                    overs: match.teamAOvers,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('VS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted)),
                ),
                Expanded(
                  child: _TeamScore(
                    name: match.teamBName,
                    score: match.teamBScore,
                    wickets: match.teamBWickets,
                    overs: match.teamBOvers,
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
            if (isCompleted && match.result != null) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              Text(match.result!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'live';
    final isCompleted = status == 'completed';
    final color = isLive
        ? AppColors.success
        : isCompleted
            ? AppColors.textMuted
            : AppColors.warning;
    final label =
        isLive ? '● LIVE' : isCompleted ? 'COMPLETED' : status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

class _TeamScore extends StatelessWidget {
  final String name;
  final int? score;
  final int? wickets;
  final String? overs;
  final CrossAxisAlignment align;

  const _TeamScore({
    required this.name,
    this.score,
    this.wickets,
    this.overs,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(name,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (score != null) ...[
          const SizedBox(height: 2),
          Text(
            '$score/${wickets ?? 0}',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary),
          ),
          if (overs != null)
            Text('($overs ov)',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Leaderboard (embedded, group-filtered)
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardTab extends StatefulWidget {
  final GroupRepository repo;
  final String groupId;
  const _LeaderboardTab({required this.repo, required this.groupId});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab>
    with AutomaticKeepAliveClientMixin {
  int _tabIndex = 0; // 0=Batters, 1=Bowlers, 2=Impact

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<MatchSummary>>(
      future: widget.repo.getGroupMatches(widget.groupId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        if (snap.hasError) {
          return _CentreMsg(
              icon: Icons.bar_chart_outlined,
              title: 'Could not load stats',
              sub: snap.error.toString());
        }
        final matches = snap.data ?? const [];
        return BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, pState) {
            final statsMap = calculateAllPlayerStats(
              matches,
              pState.players,
              scopeGroupId: widget.groupId,
            );
            final statsList =
                statsMap.values.where((s) => s.matches > 0).toList();

            statsList.sort((a, b) {
              double sA = _tabIndex == 0
                  ? (a.battingRankScore ?? -1.0)
                  : _tabIndex == 1
                      ? (a.bowlingRankScore ?? -1.0)
                      : (a.impactRankScore ?? -1.0);
              double sB = _tabIndex == 0
                  ? (b.battingRankScore ?? -1.0)
                  : _tabIndex == 1
                      ? (b.bowlingRankScore ?? -1.0)
                      : (b.impactRankScore ?? -1.0);
              return sB.compareTo(sA);
            });

            return Column(
              children: [
                // Tab selector
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.surfaceLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color:
                                  AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tabChip('Batters', 0),
                            _tabChip('Bowlers', 1),
                            _tabChip('Impact', 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: statsList.isEmpty
                      ? const _CentreMsg(
                          icon: Icons.analytics_outlined,
                          title: 'No stats yet',
                          sub: 'Complete matches in this group to see rankings.',
                        )
                      : _LeaderboardList(
                          statsList: statsList,
                          tabIndex: _tabIndex,
                          groupId: widget.groupId,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tabChip(String label, int i) {
    final active = _tabIndex == i;
    return TapBounce(
      onTap: () => setState(() => _tabIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w800 : FontWeight.w600,
                color: active ? Colors.white : AppColors.textMuted)),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<PlayerStats> statsList;
  final int tabIndex;
  final String groupId;

  const _LeaderboardList({
    required this.statsList,
    required this.tabIndex,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final validStats = statsList.where((p) {
      final s = tabIndex == 0
          ? p.battingRankScore
          : tabIndex == 1
              ? p.bowlingRankScore
              : p.impactRankScore;
      return s != null;
    }).toList();
    final top3 = validStats.take(3).toList();
    final hasPodium = top3.isNotEmpty;

    return ListView.builder(
      key: ValueKey('grp_list_${tabIndex}_$groupId'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: statsList.length + (hasPodium ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasPodium && index == 0) {
          return LeaderboardTopThreePodium(
            key: ValueKey('grp_podium_${tabIndex}_$groupId'),
            top3,
            tabIndex,
          );
        }
        final itemIndex = hasPodium ? index - 1 : index;
        final p = statsList[itemIndex];
        final score = tabIndex == 0
            ? p.battingRankScore
            : tabIndex == 1
                ? p.bowlingRankScore
                : p.impactRankScore;
        final prevScore = tabIndex == 0
            ? p.previousBattingRankScore
            : tabIndex == 1
                ? p.previousBowlingRankScore
                : p.previousImpactRankScore;

        return FadeInEntrance(
          key: ValueKey('grp_item_${p.id}_$tabIndex'),
          delay: Duration(milliseconds: 60 * (index + 2)),
          offset: const Offset(0, 20),
          child: LeaderboardRankCard(
            key: ValueKey('grp_card_${p.id}'),
            stats: p,
            tabIndex: tabIndex,
            rank: itemIndex + 1,
            score: score,
            prevScore: prevScore,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Members
// ─────────────────────────────────────────────────────────────────────────────
class _MembersTab extends StatefulWidget {
  final GroupRepository repo;
  final String groupId;
  const _MembersTab({required this.repo, required this.groupId});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab>
    with AutomaticKeepAliveClientMixin {
  late final Future<List<GroupMember>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getGroupMembers(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<GroupMember>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        if (snap.hasError) {
          return _CentreMsg(
              icon: Icons.people_outline_rounded,
              title: 'Could not load members',
              sub: snap.error.toString());
        }
        final members = snap.data ?? const [];
        if (members.isEmpty) {
          return const _CentreMsg(
            icon: Icons.people_outline_rounded,
            title: 'No members yet',
            sub: 'Share the invite code to add friends.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          itemCount: members.length,
          itemBuilder: (ctx, i) => FadeInEntrance(
            key: ValueKey(members[i].userId),
            delay: Duration(milliseconds: 50 * i),
            offset: const Offset(0, 12),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberTile(member: members[i]),
            ),
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMember member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          // Name + join date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  'Joined ${_joinLabel(member.joinedAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Role badge
          if (member.isAdmin)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('ADMIN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5)),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text('MEMBER',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5)),
            ),
        ],
      ),
    );
  }

  String _joinLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()}mo ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable centered empty/error message
// ─────────────────────────────────────────────────────────────────────────────
class _CentreMsg extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _CentreMsg({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 52, color: AppColors.textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(sub,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
