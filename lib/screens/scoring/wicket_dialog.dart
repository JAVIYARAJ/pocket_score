part of '../scoring_screen.dart';

// Wicket flow, player picker sheet and shared picker helpers.

// ── Wicket Dialog ──────────────────────────────────────────────
/// Whether a delivery can be recorded right now. False once the innings is
/// over (e.g. a quick double tap on the final ball), or while a batting slot
/// is empty after a retirement — the ball would have no batter to credit.
bool _acceptsBalls(BuildContext context) {
  final state = context.read<ScoreBloc>().state;
  final totalOvers = context.read<MatchBloc>().state.settings?.totalOvers ?? 0;
  if (state.isInningsOver(totalOvers)) return false;
  final missing = state.strikerId.isEmpty
      ? 'striker'
      : (!state.isLastManStanding && state.nonStrikerId.isEmpty)
          ? 'non-striker'
          : null;
  if (missing != null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('Pick the $missing first — tap the empty batter slot.')));
    return false;
  }
  return true;
}

void _wicketDialog(BuildContext context, ScoreState state) {
  if (!_acceptsBalls(context)) return;
  final bloc = context.read<ScoreBloc>();
  final avail = _BatTile._available(state);

  String? wktType;
  String? playerId = state.strikerId;
  int runs = 0;
  bool runOutRunsConfirmed = false;
  bool runOutVictimPicked = false;
  String? fielderId;
  String? nextId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSt) {
        final isRunOut = wktType == 'RUN OUT';
        final needsFielder = ['CAUGHT', 'STUMPED', 'RUN OUT'].contains(wktType);

        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _handle()),
              const SizedBox(height: 20),

              if (wktType == null) ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.wicket.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_baseball_rounded,
                        color: AppColors.wicket, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Wicket Fallen! 🎯',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text('Select dismissal type',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: (state.isFreeHit
                          ? ['RUN OUT']
                          : [
                              'BOWLED', 'CAUGHT', 'LBW',
                              'STUMPED', 'RUN OUT', 'OTHERS'
                            ])
                      .map((t) => GestureDetector(
                            onTap: () => setSt(() => wktType = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.wicket.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.wicket
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.wicket)),
                            ),
                          ))
                      .toList(),
                ),
                if (state.isFreeHit) ...[
                  const SizedBox(height: 12),
                  const Text('Only Run Out is possible on a Free Hit',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ] else if (isRunOut && !runOutRunsConfirmed) ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.run_circle_rounded,
                        color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Run Out!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'How many runs were completed before the run out?',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [0, 1, 2, 3].map((r) {
                    final sel = runs == r;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: () => setSt(() => runs = r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 72,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.warning.withValues(alpha: 0.12)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: sel ? AppColors.warning : AppColors.border,
                                  width: sel ? 2 : 1),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$r',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                        color: sel
                                            ? AppColors.warning
                                            : AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(r == 1 ? 'run' : 'runs',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? AppColors.warning
                                            : AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => setSt(() => runOutRunsConfirmed = true),
                    child: Text(
                      runs == 0
                          ? 'No runs completed  →'
                          : '$runs run${runs == 1 ? "" : "s"} completed  →',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ] else if (needsFielder && fielderId == null) ...[
                Text(
                  wktType == 'RUN OUT' ? 'Fielder Involved?' : 'Who Caught It?',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.bowlingLineup.length,
                    itemBuilder: (_, i) {
                      final p = state.bowlingLineup[i];
                      return GestureDetector(
                        onTap: () => setSt(() => fielderId = p.id),
                        child: _pickerChip(p.name, false),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setSt(() => fielderId = state.bowlerId),
                  child: const Text('By Bowler'),
                ),
              ] else if (isRunOut && nextId == null && avail.isNotEmpty) ...[
                // Runs already captured in step 1; now ask who's out and next batsman
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      runs == 0
                          ? 'Run Out · 0 runs'
                          : 'Run Out · $runs run${runs == 1 ? "" : "s"} completed',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                          letterSpacing: 0.5),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                const Text('WHO IS OUT?',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Row(children: [
                  _selBtn(
                      state.battingLineup
                          .firstWhere((p) => p.id == state.strikerId)
                          .name,
                      state.strikerId,
                      playerId,
                      (id) => setSt(() => playerId = id)),
                  const SizedBox(width: 10),
                  if (state.nonStrikerId.isNotEmpty)
                    _selBtn(
                        state.battingLineup
                            .firstWhere((p) => p.id == state.nonStrikerId)
                            .name,
                        state.nonStrikerId,
                        playerId,
                        (id) => setSt(() => playerId = id)),
                ]),
                const SizedBox(height: 20),
                const Text('WHO WALKS IN?',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.scoreBlueLight,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                _BatterPicker(
                  state: state,
                  players: avail,
                  compact: true,
                  onPick: (id) => setSt(() => nextId = id),
                ),
              ] else if (isRunOut &&
                  avail.isEmpty &&
                  state.nonStrikerId.isNotEmpty &&
                  !runOutVictimPicked) ...[
                // Last pair: no next batter to pick, but either end can be run out.
                const Text('Who is out?',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('The other batter stays on as the last man.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                Row(children: [
                  _selBtn(
                      state.battingLineup
                          .firstWhere((p) => p.id == state.strikerId)
                          .name,
                      state.strikerId,
                      playerId,
                      (id) => setSt(() => playerId = id)),
                  const SizedBox(width: 10),
                  _selBtn(
                      state.battingLineup
                          .firstWhere((p) => p.id == state.nonStrikerId)
                          .name,
                      state.nonStrikerId,
                      playerId,
                      (id) => setSt(() => playerId = id)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setSt(() => runOutVictimPicked = true),
                    child: const Text('Continue'),
                  ),
                ),
              ] else if (nextId == null && avail.isNotEmpty) ...[
                _BatterPicker(
                  state: state,
                  players: avail,
                  board: _wicketBoard(state, playerId, wktType!, runs),
                  subtitle: _partnerLine(state, playerId),
                  onPick: (id) => setSt(() => nextId = id),
                ),
              ] else ...[
                const Text('Confirm Wicket',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration:
                      AppDecorations.tintedCard(AppColors.wicket),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Type: $wktType',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    if (isRunOut)
                      Text(
                          'Runs before out: $runs',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    if (nextId != null && avail.any((p) => p.id == nextId))
                      Text(
                          'Next: ${avail.firstWhere((p) => p.id == nextId).name}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wicket,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      bloc.add(RecordBall(
                        runs: runs,
                        type: BallType.wicket,
                        isWicket: true,
                        wicketType: wktType,
                        outPlayerId: playerId,
                        fielderId: fielderId,
                        nextBatsmanId:
                            nextId == 'none' ? null : nextId,
                      ));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Record Wicket 🎯',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

// ── Player Picker Sheet ────────────────────────────────────────
class _PlayerPickerSheet extends StatelessWidget {
  final bool isStriker;
  final List<Player> players;
  final ScoreState state;
  final void Function(String id) onPick;

  const _PlayerPickerSheet({
    required this.isStriker,
    required this.players,
    required this.state,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings;
    final partnerId = isStriker ? state.nonStrikerId : state.strikerId;
    final partner = state.battingLineup.where((p) => p.id == partnerId).firstOrNull;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: _handle()),
        const SizedBox(height: 16),
        _BatterPicker(
          state: state,
          players: players,
          board: _BatterBoard(
            'NEW BATTER',
            isStriker ? 'Striker' : 'Non-striker',
            partner != null ? '${partner.name} is at the other end' : 'Last batter in',
            inn != null ? '${inn.totalRuns}/${inn.totalWickets}' : '–',
          ),
          onPick: onPick,
        ),
      ]),
    );
  }
}

/// LED recap for the batter just dismissed (this ball included).
_BatterBoard _wicketBoard(ScoreState state, String? outId, String wicketType, int runsThisBall) {
  final inn = state.currentInnings;
  final out = state.battingLineup.where((p) => p.id == outId).firstOrNull;
  final st = outId == null ? null : inn?.batsmanStats[outId];
  final onStrike = outId == state.strikerId;
  // The ball isn't recorded yet: count it for the striker.
  final r = (st?.runs ?? 0) + (onStrike ? runsThisBall : 0);
  final b = (st?.ballsFaced ?? 0) + (onStrike ? 1 : 0);
  return _BatterBoard(
    'WICKET',
    out?.name ?? 'Batter',
    '$r ($b)  ·  ${wicketType.toLowerCase()}',
    inn != null ? '${inn.totalRuns + runsThisBall}/${inn.totalWickets + 1}' : '–',
  );
}

String? _partnerLine(ScoreState state, String? outId) {
  final partnerId = outId == state.strikerId ? state.nonStrikerId : state.strikerId;
  final partner = state.battingLineup.where((p) => p.id == partnerId).firstOrNull;
  return partner == null ? null : '${partner.name} is waiting at the other end';
}

// ── Shared helpers ─────────────────────────────────────────────
Widget _handle() => Container(
  width: 40, height: 4,
  decoration: BoxDecoration(
      color: AppColors.border, borderRadius: BorderRadius.circular(2)),
);

Widget _pickerChip(String name, bool selected) => Container(
  width: 80,
  margin: const EdgeInsets.only(right: 10),
  decoration: AppDecorations.card(radius: 14),
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.surfaceLight,
      child: Text(name[0],
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
    ),
    const SizedBox(height: 6),
    Text(name,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis),
  ]),
);

Widget _selBtn(String name, String id, String? current,
    Function(String) onSelect) {
  final sel = id == current;
  return Expanded(
    child: GestureDetector(
      onTap: () => onSelect(id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: sel
                    ? AppColors.primary
                    : AppColors.textSecondary)),
      ),
    ),
  );
}
