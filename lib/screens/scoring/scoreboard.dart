part of '../scoring_screen.dart';

// App bar, scoreboard and the batters/bowler status strip.

// ── App Bar ────────────────────────────────────────────────────
class _ScoringAppBar extends StatelessWidget {
  final ScoreState state;
  const _ScoringAppBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12, right: 12, bottom: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        // Close
        _iconBtn(
          icon: Icons.close_rounded,
          color: AppColors.textSecondary,
          bg: AppColors.surfaceLight,
          onTap: () {
            ScoringScreen._syncMatchList(context, state);
            context.go('/home');
          },
        ),
        // Innings info
        Expanded(
          child: Column(children: [
            if (state.isSuperOver)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 10, color: AppColors.accent),
                    SizedBox(width: 3),
                    Text('SUPER OVER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.accent, letterSpacing: 1.5)),
                  ],
                ),
              )
            else
              Text(
                state.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.5),
              ),
            const SizedBox(height: 1),
            Text(
              state.currentInnings!.battingTeamName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ]),
        ),
        // Undo
        if (state.history.isNotEmpty)
          _iconBtn(
            icon: Icons.undo_rounded,
            color: AppColors.warning,
            bg: AppColors.warning.withValues(alpha: 0.1),
            onTap: () => context.read<ScoreBloc>().add(UndoBall()),
          ),
        const SizedBox(width: 8),
        // Scorecard
        _iconBtn(
          icon: Icons.bar_chart_rounded,
          color: AppColors.primary,
          bg: AppColors.primary.withValues(alpha: 0.1),
          onTap: () => context.push('/scorecard', extra: {
            'state': state,
            'overs': context.read<MatchBloc>().state.settings?.totalOvers ?? 0,
          }),
        ),
        const SizedBox(width: 8),
        // End Game
        _iconBtn(
          icon: Icons.flag_rounded,
          color: AppColors.warning,
          bg: AppColors.warning.withValues(alpha: 0.1),
          onTap: () => ScoringScreen._confirmEndGame(context, state),
        ),
        const SizedBox(width: 8),
        // Delete
        _iconBtn(
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger,
          bg: AppColors.danger.withValues(alpha: 0.08),
          onTap: () => ScoringScreen._confirmDiscard(context),
        ),
      ]),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

// ── Scoreboard ─────────────────────────────────────────────────
class _Scoreboard extends StatelessWidget {
  final ScoreState state;
  const _Scoreboard({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    final matchSettings = context.read<MatchBloc>().state.settings;
    final total = matchSettings?.totalOvers ?? 1;
    // Super over is always 1 over; use regular totalOvers otherwise
    final effectiveOvers = state.isSuperOver ? 1 : total;
    final rem = effectiveOvers * 6 - inn.legalBallsCount;
    final ppOvers = state.isSuperOver ? null : matchSettings?.powerPlayOvers;
    final inPowerPlay = ppOvers != null && inn.legalBallsCount ~/ 6 < ppOvers;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: AppDecorations.gradientCard(AppColors.headerGradient, radius: 24),
      child: Column(children: [
        // Main score + overs
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Runs / Wickets
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SCORE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 1.2)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedCounter(
                    value: inn.totalRuns,
                    style: const TextStyle(
                        fontSize: 68,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2),
                  ),
                  Text(' / ${inn.totalWickets}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60)),
                ],
              ),
            ]),
            const Spacer(),
            // Overs
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('OVERS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 1.2)),
              Text(inn.overDisplay,
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1)),
              Text('$rem balls left',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500)),
            ]),
          ],
        ),
        // Free Hit badge
        if (state.isFreeHit) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.lock_open_rounded, size: 13, color: Colors.white),
                SizedBox(width: 6),
                Text('FREE HIT',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1)),
              ]),
            ),
          ),
        ],
        // Power Play badge
        if (inPowerPlay) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.security_rounded, size: 13, color: Colors.white),
                SizedBox(width: 6),
                Text('POWER PLAY',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1)),
              ]),
            ),
          ),
        ],
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
        ),
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat('CRR', inn.runRate.toStringAsFixed(2)),
            if (state.isSuperOver) ...[
              // Super over: first SO innings shows projected; second shows SO target
              if (state.isSuperOverFirstInnings)
                _stat('PROJECTED',
                    inn.legalBallsCount > 0
                        ? (inn.totalRuns / inn.legalBallsCount * 6).round().toString()
                        : '—')
              else
                Builder(builder: (ctx) {
                  final target = (state.superOverFirstInnings?.totalRuns ?? 0) + 1;
                  final need = target - inn.totalRuns;
                  final rrr = rem > 0 ? need / (rem / 6) : 0.0;
                  return Row(children: [
                    _stat('NEED', '$need'),
                    const SizedBox(width: 28),
                    _stat('RRR', rrr.toStringAsFixed(2)),
                    const SizedBox(width: 28),
                    _stat('TARGET', '$target'),
                  ]);
                }),
            ] else if (state.isFirstInnings)
              _stat('PROJECTED',
                  inn.legalBallsCount > 0
                      ? (inn.totalRuns / inn.legalBallsCount * total * 6)
                          .round()
                          .toString()
                      : '—')
            else ...[
              Builder(builder: (ctx) {
                final target = (state.firstInnings?.totalRuns ?? 0) + 1;
                final need = target - inn.totalRuns;
                final rrr = rem > 0 ? need / (rem / 6) : 0.0;
                return Row(children: [
                  _stat('NEED', '$need'),
                  const SizedBox(width: 28),
                  _stat('RRR', rrr.toStringAsFixed(2)),
                  const SizedBox(width: 28),
                  _stat('TARGET', '$target'),
                ]);
              }),
            ],
          ],
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      );
}

// ── Player Status ──────────────────────────────────────────────
class _PlayerStatus extends StatelessWidget {
  final ScoreState state;
  const _PlayerStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    final striker = state.battingLineup.where((p) => p.id == state.strikerId).firstOrNull;
    final nonStriker = state.battingLineup.where((p) => p.id == state.nonStrikerId).firstOrNull;
    final bowler = state.bowlingLineup.where((p) => p.id == state.bowlerId).firstOrNull;

    final sS = inn.batsmanStats[state.strikerId];
    final nsS = inn.batsmanStats[state.nonStrikerId];
    final bS = inn.bowlerStatsMap[state.bowlerId];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: AppDecorations.card(),
      child: Column(children: [
        // Batters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Expanded(child: _BatTile(
              name: striker?.name ?? '—',
              stats: sS,
              isStriker: true,
              playerId: state.strikerId,
              state: state,
            )),
            if (!state.isLastManStanding) ...[
              Container(width: 1, height: 50, color: AppColors.border),
              Expanded(child: _BatTile(
                name: nonStriker?.name ?? '—',
                stats: nsS,
                isStriker: false,
                playerId: state.nonStrikerId,
                state: state,
              )),
            ],
          ]),
        ),
        if (state.isLastManStanding)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.warning),
              SizedBox(width: 6),
              Text('LAST MAN STANDING',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      letterSpacing: 0.8)),
            ]),
          ),
        // Bowler strip
        if (bowler != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_baseball_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    bowler.isGuest ? '${bowler.name} (Guest)' : bowler.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
              ),
              _bStat('O', bS?.oversBowled ?? '0.0'),
              _bStat('R', '${bS?.runsConceded ?? 0}'),
              _bStat('W', '${bS?.wickets ?? 0}',
                  color: (bS?.wickets ?? 0) > 0 ? AppColors.wicket : null),
              _bStat('E', bS?.economy.toStringAsFixed(1) ?? '0.0'),
            ]),
          ),
      ]),
    );
  }

  Widget _bStat(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700)),
        Text(val,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textSecondary)),
      ]),
    );
  }
}

class _BatTile extends StatelessWidget {
  final String name;
  final BatsmanStats? stats;
  final bool isStriker;
  final String playerId;
  final ScoreState state;
  const _BatTile({
    required this.name,
    required this.stats,
    required this.isStriker,
    required this.playerId,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoreBloc>();
    final player = state.battingLineup.where((p) => p.id == playerId).firstOrNull;
    final isGuest = player?.isGuest ?? false;

    return GestureDetector(
      onTap: () {
        if (playerId.isEmpty) {
          _showPicker(context, bloc, state, isStriker);
        } else if (!state.isLastManStanding &&
            state.strikerId.isNotEmpty &&
            state.nonStrikerId.isNotEmpty) {
          bloc.add(SwapStriker());
        }
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment:
              isStriker ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Name row
            Row(
              mainAxisAlignment: isStriker
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              children: [
                if (isStriker && playerId.isNotEmpty)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                Flexible(
                  child: Text(isGuest ? '$name (Guest)' : name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isStriker ? FontWeight.w700 : FontWeight.w500,
                          color: isStriker
                              ? AppColors.textPrimary
                              : AppColors.textSecondary)),
                ),
                if (playerId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _retire(context, bloc, state, playerId),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(Icons.exit_to_app_rounded,
                          size: 13, color: AppColors.textMuted),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(Icons.add_circle_outline_rounded,
                        size: 13, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: isStriker
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${stats?.runs ?? 0}',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1)),
                Text('  (${stats?.ballsFaced ?? 0})',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            if (stats != null && stats!.ballsFaced > 0)
              Text('SR ${stats!.strikeRate.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  static void _showPicker(BuildContext context, ScoreBloc bloc,
      ScoreState state, bool isStriker) {
    final avail = _available(state);
    if (avail.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No batsmen left!')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlayerPickerSheet(
        isStriker: isStriker,
        players: avail,
        state: state,
        onPick: (id) {
          bloc.add(SelectNextBatsman(playerId: id, isStriker: isStriker));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  static void _retire(BuildContext context, ScoreBloc bloc,
      ScoreState state, String playerId) {
    final rem = state.battingLineup.where((p) =>
        !state.outPlayerIds.contains(p.id) &&
        !state.retiredHurtIds.contains(p.id) &&
        p.id != state.strikerId &&
        p.id != state.nonStrikerId).toList();
    String? nextId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          final pName = state.battingLineup
              .firstWhere((p) => p.id == playerId)
              .name;
          return Container(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _handle(),
              const SizedBox(height: 20),
              Text('Retire $pName?',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Mark as retired hurt & bring in replacement.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),
              if (rem.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('REPLACEMENT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: rem.length,
                    itemBuilder: (c, i) {
                      final p = rem[i];
                      final sel = nextId == p.id;
                      return GestureDetector(
                        onTap: () => setSt(() => nextId = p.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.border),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: sel
                                      ? AppColors.primary
                                      : AppColors.border,
                                  child: Text(p.name[0],
                                      style: TextStyle(
                                          color: sel
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 6),
                                 Text(p.isGuest ? '${p.name} (Guest)' : p.name,
                                     style: const TextStyle(fontSize: 10),
                                     overflow: TextOverflow.ellipsis),
                              ]),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.tintedCard(AppColors.warning),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'No replacements. Innings continues as Last Man Standing.',
                            style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    bloc.add(RetirePlayer(
                        playerId: playerId, nextBatsmanId: nextId));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Confirm Retirement'),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  static List<Player> _available(ScoreState state) {
    final rem = state.battingLineup.where((p) =>
        !state.outPlayerIds.contains(p.id) &&
        !state.retiredHurtIds.contains(p.id) &&
        p.id != state.strikerId &&
        p.id != state.nonStrikerId).toList();
    final retired = state.retiredHurtIds
        .where((id) =>
            !state.outPlayerIds.contains(id) &&
            id != state.strikerId &&
            id != state.nonStrikerId)
        .map((id) =>
            state.battingLineup.firstWhere((p) => p.id == id))
        .toList();
    return {...rem, ...retired}.toList();
  }
}
