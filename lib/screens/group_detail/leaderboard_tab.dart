part of '../group_detail_screen.dart';

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
  late final Future<List<MatchSummary>> _future;

  @override
  void initState() {
    super.initState();
    // Stored once — prevents a new network call on every rebuild.
    _future = widget.repo.getGroupMatches(widget.groupId);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<MatchSummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const NeverScrollableScrollPhysics(),
            children: const [LeaderboardSkeleton()],
          );
        }
        if (snap.hasError) {
          return _CentreMsg(
              art: EmptyArt.offline,
              title: 'Could not load stats',
              sub: snap.error.toString());
        }
        final matches = snap.data ?? const [];
        final players = calculateAllPlayerStats(
          matches,
          const [],
          scopeGroupId: widget.groupId,
        ).values.where((s) => s.matches > 0).toList();

        return LeaderboardBoard(
          players: players,
          empty: const _CentreMsg(
            art: EmptyArt.stats,
            title: 'The podium is empty',
            sub: 'Finish a match in this group and the rankings will show up here.',
          ),
        );
      },
    );
  }
}
