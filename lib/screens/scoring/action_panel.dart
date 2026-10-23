part of '../scoring_screen.dart';

// Run / extras / wicket pad used to record each delivery.

// ── Action Panel ───────────────────────────────────────────────
class _ActionPanel extends StatelessWidget {
  final ScoreState state;
  const _ActionPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final totalOvers = context.read<MatchBloc>().state.settings?.totalOvers ?? 0;
    // The last over of an innings also sets pendingBowlerChange, but nobody
    // bowls next — show the way on instead of a bowler picker.
    if (state.isInningsOver(totalOvers)) return _InningsOverPanel(state: state);
    if (state.pendingBowlerChange) return _BowlerPicker(state: state);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Run buttons
        Row(children: [
          _runBtn(context, '0', 0, bg: AppColors.surfaceLight, text: AppColors.textMuted),
          _runBtn(context, '1', 1, bg: AppColors.surfaceLight, text: AppColors.textSecondary),
          _runBtn(context, '2', 2, bg: AppColors.surfaceLight, text: AppColors.textSecondary),
          _runBtn(context, '3', 3, bg: AppColors.surfaceLight, text: AppColors.textSecondary),
          _runBtn(context, '4', 4,
              bg: AppColors.four.withValues(alpha: 0.12),
              text: AppColors.four),
          _runBtn(context, '6', 6,
              bg: AppColors.six.withValues(alpha: 0.12),
              text: AppColors.six),
        ]),
        const SizedBox(height: 10),
        // Extras + Wicket
        Row(children: [
          _extrasBtn(context, 'WD', 0, BallType.wide, AppColors.wide),
          _noBallBtn(context),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _wicketDialog(context, state),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFB91C1C), AppColors.wicket]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.wicket.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_baseball_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('WICKET',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2)),
                    ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _runBtn(BuildContext context, String label, int runs,
      {required Color bg, required Color text}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            if (!_acceptsBalls(context)) return;
            context
                .read<ScoreBloc>()
                .add(RecordBall(runs: runs, type: BallType.normal, extraRuns: 0));
          },
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: text)),
          ),
        ),
      ),
    );
  }

  Widget _extrasBtn(BuildContext context, String label, int runs,
      BallType type, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            if (!_acceptsBalls(context)) return;
            context.read<ScoreBloc>().add(
                RecordBall(runs: runs, type: type, extraRuns: 1));
          },
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ),
      ),
    );
  }

  Widget _noBallBtn(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            if (_acceptsBalls(context)) _noBallSheet(context);
          },
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.noBall.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.noBall.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Text('NB',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.noBall)),
          ),
        ),
      ),
    );
  }

  void _noBallSheet(BuildContext context) {
    final bloc = context.read<ScoreBloc>();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.noBall.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('NO BALL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noBall,
                        letterSpacing: 1)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('How many runs off the bat?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text(
              '+1 penalty run is added automatically.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [0, 1, 2, 3, 4, 6].map((runs) {
                Color bg, fg;
                if (runs == 6) { bg = AppColors.six.withValues(alpha: 0.12); fg = AppColors.six; }
                else if (runs == 4) { bg = AppColors.four.withValues(alpha: 0.12); fg = AppColors.four; }
                else { bg = AppColors.surfaceLight; fg = AppColors.textSecondary; }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        bloc.add(RecordBall(
                          runs: runs,
                          type: BallType.noBall,
                          extraRuns: 1,
                        ));
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fg.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          runs == 0 ? 'Nb' : 'Nb+$runs',
                          style: TextStyle(
                              fontSize: runs == 0 ? 16 : 13,
                              fontWeight: FontWeight.w800,
                              color: fg),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
