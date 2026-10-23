part of '../scoring_screen.dart';

// "This over" strip and the compact over history.

// ── This Over ─────────────────────────────────────────────────
class _ThisOver extends StatelessWidget {
  final ScoreState state;
  const _ThisOver({required this.state});

  @override
  Widget build(BuildContext context) {
    // The over actually in progress — not simply the last six legal balls,
    // which would mix in the previous over mid-way through this one.
    final inn = state.currentInnings!;
    final ovs = inn.overSummaries;
    final completed = inn.legalBallsCount ~/ 6;
    final List<Ball> current;
    if (ovs.length > completed) {
      current = ovs.last.balls;            // over in progress (may be extras only)
    } else if (state.pendingBowlerChange && ovs.isNotEmpty) {
      current = ovs.last.balls;            // over just finished, picking a bowler
    } else {
      current = const [];                  // new over, no ball yet
    }
    final legal = current.where((b) => b.isLegalBall).length;

    // One compact row: label, the over's balls, then the legal-ball count.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: AppDecorations.card(radius: 14),
      child: Row(children: [
        const Icon(Icons.fiber_manual_record, size: 7, color: AppColors.primary),
        const SizedBox(width: 5),
        const Text('THIS OVER',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1)),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 30,
            child: current.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Waiting for first ball…',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)))
                : ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: current.map(_ballChip).toList(),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$legal/6',
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _ballChip(Ball b) {
    final (label, color) = _ballFace(b);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: b.runs == 0 && !b.isWicket ? 0.12 : 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: label.length > 2 ? 8 : (label.length > 1 ? 9.5 : 12),
              fontWeight: FontWeight.w800,
              color: color == AppColors.dot
                  ? AppColors.textMuted
                  : color)),
    );
  }
}

/// Label and colour for one delivery, shared by the over strip and recaps.
(String, Color) _ballFace(Ball b) {
  if (b.isWicket) return ('W', AppColors.wicket);
  if (b.type == BallType.wide) return ('WD', AppColors.wide);
  if (b.type == BallType.noBall) return (b.runs > 0 ? 'Nb+${b.runs}' : 'NB', AppColors.noBall);
  if (b.runs == 6) return ('6', AppColors.six);
  if (b.runs == 4) return ('4', AppColors.four);
  if (b.runs == 0) return ('•', AppColors.dot);
  return ('${b.runs}', AppColors.primary);
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
