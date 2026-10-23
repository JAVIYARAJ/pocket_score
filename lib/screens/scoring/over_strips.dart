part of '../scoring_screen.dart';

// Current-over helper and the compact history of completed overs.

// ── This Over ─────────────────────────────────────────────────
/// The over actually in progress — not simply the last six legal balls,
/// which would mix in the previous over mid-way through this one.
List<Ball> _currentOverBalls(ScoreState state) {
  final inn = state.currentInnings!;
  final ovs = inn.overSummaries;
  final completed = inn.legalBallsCount ~/ 6;
  if (ovs.length > completed) return ovs.last.balls; // in progress (may be extras only)
  if (state.pendingBowlerChange && ovs.isNotEmpty) return ovs.last.balls; // just finished
  return const []; // new over, no ball yet
}

// ── Over History ──────────────────────────────────────────────
class _OverHistory extends StatelessWidget {
  final ScoreState state;
  const _OverHistory({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings;
    if (inn == null) return const SizedBox.shrink();
    // Completed overs only (the over in progress is in "This over" above),
    // newest first so the latest is visible without scrolling.
    final completed = inn.legalBallsCount ~/ 6;
    final ovs = inn.overSummaries.take(completed).toList().reversed.toList();
    if (ovs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 9, 0, 9),
      decoration: AppDecorations.card(radius: 14),
      child: Row(children: [
        const Text('OVERS',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1)),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 12),
              itemCount: ovs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final ov = ovs[i];
                final hasWkt = ov.wickets > 0;
                final color = hasWkt ? AppColors.wicket : AppColors.primary;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: hasWkt
                        ? AppColors.wicket.withValues(alpha: 0.07)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: hasWkt
                            ? AppColors.wicket.withValues(alpha: 0.25)
                            : AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${ov.overNumber}',
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted)),
                    const SizedBox(width: 5),
                    Text('${ov.runs}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    if (hasWkt) ...[
                      const SizedBox(width: 3),
                      Text('${ov.wickets}W',
                          style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.wicket)),
                    ],
                  ]),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
