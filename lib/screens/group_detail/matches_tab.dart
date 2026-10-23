part of '../group_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Matches
// Initial load via RPC (get_group_matches).
// Live updates via Supabase Realtime channel — on any change the tab
// re-fetches through the same RPC so there are zero raw table queries.
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
  List<MatchSummary> _matches  = [];
  bool              _loading   = true;
  String?           _error;
  RealtimeChannel?  _channel;
  // Only the newest fetch may update the list (realtime events can overlap).
  int               _fetchSeq  = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Initial + refresh fetch via RPC ────────────────────────────────────────
  Future<void> _fetch() async {
    final seq = ++_fetchSeq;
    try {
      final matches = await widget.repo.getGroupMatches(widget.groupId);
      if (mounted && seq == _fetchSeq) {
        setState(() { _matches = matches; _loading = false; _error = null; });
      }
    } catch (e) {
      // Keep the list we have through a network blip.
      if (mounted && seq == _fetchSeq && (_loading || _error != null)) {
        setState(() { _error = groupErrorMessage(e); _loading = false; });
      }
    }
  }

  // ── Realtime channel — no raw table queries ────────────────────────────────
  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('grp_matches_${widget.groupId}')
        .onPostgresChanges(
          event : PostgresChangeEvent.all,
          schema: 'public',
          table : 'matches',
          filter: PostgresChangeFilter(
            type  : PostgresChangeFilterType.eq,
            column: 'group_id',
            value : widget.groupId,
          ),
          callback: (_) => _fetch(),
        )
        // Resync on every (re)join — events during a dropped connection are lost.
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) _fetch();
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const SkeletonList(
        item: MatchCardSkeleton(),
        count: 3,
        padding: EdgeInsets.fromLTRB(16, 20, 16, 40),
        gap: 12,
      );
    }

    if (_error != null) {
      return _CentreMsg(
          art  : EmptyArt.offline,
          title: 'Could not load matches',
          sub  : _error!);
    }

    if (_matches.isEmpty) {
      return const _CentreMsg(
        art  : EmptyArt.matches,
        title: 'The pitch is waiting',
        sub  : 'No matches in this group yet. Start one and pick this group to see it here.',
      );
    }

    return ListView.builder(
      padding    : const EdgeInsets.fromLTRB(16, 20, 16, 40),
      itemCount  : _matches.length,
      itemBuilder: (ctx, i) => FadeInEntrance(
        key  : ValueKey(_matches[i].id),
        delay: Duration(milliseconds: 50 * i),
        offset: const Offset(0, 16),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child  : _GroupMatchCard(match: _matches[i]),
        ),
      ),
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
    final isLive = match.status == 'in_progress';
    final isCompleted = match.status == 'completed';

    return TapBounce(
      onTap: () {
        if (isLive) {
          context.push('/live/${match.id}', extra: {
            'teamAName'     : match.teamAName,
            'teamBName'     : match.teamBName,
            'totalOvers'    : match.totalOvers,
            'powerPlayOvers': match.powerPlayOvers,
          });
        } else if (isCompleted && match.scoreData != null) {
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
    final isLive = status == 'in_progress';
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
            textAlign: align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2),
            maxLines: 2,
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
