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
      padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Runs off the bat
        Row(children: [
          for (final r in const [0, 1, 2, 3]) _runKey(context, r),
          _runKey(context, 4,
              gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
              caption: 'FOUR'),
          _runKey(context, 6,
              gradient: const LinearGradient(colors: [Color(0xFF15803D), Color(0xFF22C55E)]),
              caption: 'SIX'),
        ]),
        const SizedBox(height: 8),
        // Extras + wicket
        Row(children: [
          Expanded(
            child: _PadKey(
              onTap: () {
                if (!_acceptsBalls(context)) return;
                HapticFeedback.lightImpact();
                context.read<ScoreBloc>().add(RecordBall(runs: 0, type: BallType.wide, extraRuns: 1));
              },
              color: AppColors.wide,
              label: 'WD',
              caption: 'WIDE +1',
            ),
          ),
          Expanded(
            child: _PadKey(
              onTap: () {
                if (!_acceptsBalls(context)) return;
                HapticFeedback.lightImpact();
                _noBallSheet(context);
              },
              color: AppColors.noBall,
              label: 'NB',
              caption: 'NO BALL',
            ),
          ),
          Expanded(
            flex: 2,
            child: _PadKey(
              onTap: () {
                HapticFeedback.heavyImpact();
                _wicketDialog(context, state);
              },
              gradient: const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFFEF4444)]),
              color: AppColors.wicket,
              label: 'WICKET',
              icon: Icons.sports_baseball_rounded,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _runKey(BuildContext context, int runs, {Gradient? gradient, String? caption}) {
    return Expanded(
      child: _PadKey(
        onTap: () {
          if (!_acceptsBalls(context)) return;
          gradient != null ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
          context.read<ScoreBloc>().add(RecordBall(runs: runs, type: BallType.normal, extraRuns: 0));
        },
        gradient: gradient,
        color: runs == 0 ? AppColors.textMuted : AppColors.textPrimary,
        label: runs == 0 ? '•' : '$runs',
        caption: caption ?? (runs == 0 ? 'DOT' : null),
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

/// One key on the scoring pad: sinks a little while pressed. [gradient] makes
/// a filled key (boundaries, wicket); otherwise it is a light key tinted with
/// [color].
class _PadKey extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final Color color;
  final Gradient? gradient;
  final String? caption;
  final IconData? icon;
  const _PadKey({
    required this.onTap,
    required this.label,
    required this.color,
    this.gradient,
    this.caption,
    this.icon,
  });

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.gradient != null;
    // Light keys: neutral for plain runs, tinted for extras.
    final neutral = widget.color == AppColors.textPrimary || widget.color == AppColors.textMuted;
    final fg = filled ? Colors.white : widget.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 58,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              color: filled
                  ? null
                  : neutral
                      ? (_down ? AppColors.border : AppColors.surfaceLight)
                      : widget.color.withValues(alpha: _down ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(16),
              border: filled
                  ? null
                  : Border.all(color: neutral ? AppColors.border : widget.color.withValues(alpha: 0.3)),
              boxShadow: filled && !_down
                  ? [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 17, color: fg),
                  const SizedBox(width: 7),
                ],
                Text(widget.label,
                    style: TextStyle(
                      fontSize: widget.label.length > 2 ? 15 : (widget.label == '•' ? 26 : 22),
                      fontWeight: FontWeight.w900,
                      letterSpacing: widget.label.length > 2 ? 1.2 : 0,
                      color: fg,
                      height: 1.05,
                    )),
              ]),
              if (widget.caption != null)
                Text(widget.caption!,
                    style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: fg.withValues(alpha: filled ? 0.85 : 0.7))),
            ]),
          ),
        ),
      ),
    );
  }
}
