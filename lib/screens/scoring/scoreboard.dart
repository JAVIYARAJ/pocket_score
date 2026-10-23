part of '../scoring_screen.dart';

// Score header (top bar, score, rates, this over) and the batters/bowler card.

// ── Score header ───────────────────────────────────────────────
/// Dark header that holds everything the scorer glances at between balls:
/// score, overs, rates, match-state badges and the over in progress.
class _ScoreHero extends StatelessWidget {
  final ScoreState state;
  const _ScoreHero({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    final settings = context.read<MatchBloc>().state.settings;
    final total = settings?.totalOvers ?? 1;
    // Super over is always 1 over; use regular totalOvers otherwise
    final effectiveOvers = state.isSuperOver ? 1 : total;
    final rem = (effectiveOvers * 6 - inn.legalBallsCount).clamp(0, 9999);
    final ppOvers = state.isSuperOver ? null : settings?.powerPlayOvers;
    final inPowerPlay = ppOvers != null && inn.legalBallsCount ~/ 6 < ppOvers;

    // Chasing: second innings, or the second super-over innings.
    final int? target = state.isSuperOver
        ? (state.isSuperOverFirstInnings ? null : (state.superOverFirstInnings?.totalRuns ?? 0) + 1)
        : (state.isFirstInnings ? null : (state.firstInnings?.totalRuns ?? 0) + 1);
    final need = target == null ? 0 : target - inn.totalRuns;
    final rrr = target != null && rem > 0 ? need / rem * 6 : 0.0;
    final projected = inn.legalBallsCount > 0
        ? (inn.totalRuns / inn.legalBallsCount * effectiveOvers * 6).round().toString()
        : '—';

    final current = _currentOverBalls(state);
    final legal = current.where((b) => b.isLegalBall).length;
    final lastBall = inn.balls.isEmpty ? null : inn.balls.last;

    final stage = state.isSuperOver
        ? 'SUPER OVER'
        : (state.isFirstInnings ? '1ST INNINGS' : '2ND INNINGS');

    return EventGlow(
      eventKey: inn.balls.length,
      color: highlightFor(lastBall),
      radius: 28,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 16),
        decoration: BoxDecoration(
          gradient: state.isSuperOver
              ? const LinearGradient(
                  colors: [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : AppColors.headerGradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top bar ──
          Row(children: [
            _glassBtn(Icons.close_rounded, () {
              ScoringScreen._syncMatchList(context, state);
              context.go('/home');
            }),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (state.isSuperOver) ...[
                    const Icon(Icons.bolt_rounded, size: 11, color: AppColors.accentLight),
                    const SizedBox(width: 2),
                  ],
                  Text(stage,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: Colors.white.withValues(alpha: 0.6))),
                ]),
                Text(inn.battingTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: state.history.isEmpty ? 0.35 : 1,
              child: _glassBtn(Icons.undo_rounded, () {
                if (state.history.isEmpty) return;
                HapticFeedback.mediumImpact();
                context.read<ScoreBloc>().add(UndoBall());
              }),
            ),
            const SizedBox(width: 8),
            _glassBtn(Icons.leaderboard_rounded, () => context.push('/scorecard', extra: {
                  'state': state,
                  'overs': context.read<MatchBloc>().state.settings?.totalOvers ?? 0,
                })),
            const SizedBox(width: 8),
            _glassBtn(Icons.more_horiz_rounded, () => _matchMenu(context)),
          ]),
          const SizedBox(height: 16),

          // ── Score + overs ──
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: RollingScore(runs: inn.totalRuns, wickets: inn.totalWickets, size: 56),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(inn.overDisplay,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                  Text(' / $effectiveOvers',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.55))),
                ],
              ),
              const SizedBox(height: 4),
              Text('$rem ball${rem == 1 ? '' : 's'} left',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.55))),
            ]),
          ]),

          // ── Match-state badges ──
          if (state.isFreeHit || inPowerPlay || state.isLastManStanding) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (state.isFreeHit)
                PulseAnimation(child: _badge(Icons.lock_open_rounded, 'FREE HIT', AppColors.accentLight)),
              if (inPowerPlay) _badge(Icons.flash_on_rounded, 'POWER PLAY', const Color(0xFF93C5FD)),
              if (state.isLastManStanding)
                _badge(Icons.person_rounded, 'LAST MAN STANDING', const Color(0xFFFCA5A5)),
            ]),
          ],

          // ── Chase ──
          if (target != null) ...[
            const SizedBox(height: 14),
            ChaseMeter(runs: inn.totalRuns, target: target, height: 6),
          ],
          const SizedBox(height: 12),

          // ── Rates strip ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(children: [
              _rate('CRR', inn.runRate.toStringAsFixed(2)),
              _divider(),
              if (target != null) ...[
                _rate('NEED', need <= 0 ? '0' : '$need', highlight: true),
                _divider(),
                _rate('RRR', rrr > 0 ? rrr.toStringAsFixed(2) : '—'),
                _divider(),
                _rate('TARGET', '$target'),
              ] else
                _rate('PROJECTED', projected),
            ]),
          ),
          const SizedBox(height: 12),

          // ── This over ──
          Row(children: [
            Text('THIS OVER',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.55))),
            const SizedBox(width: 10),
            Expanded(child: OverTrack(balls: current, size: 28, onDark: true)),
            const SizedBox(width: 8),
            Text('$legal/6',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6))),
          ]),
        ]),
      ),
    );
  }

  void _matchMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          const SizedBox(height: 18),
          _menuTile(ctx, Icons.flag_rounded, 'End match', 'Finish now and record the result',
              AppColors.warning, () => ScoringScreen._confirmEndGame(context, state)),
          const SizedBox(height: 10),
          _menuTile(ctx, Icons.delete_outline_rounded, 'Discard match', 'Delete this match and its score',
              AppColors.danger, () => ScoringScreen._confirmDiscard(context)),
        ]),
      ),
    );
  }

  Widget _menuTile(BuildContext sheetCtx, IconData icon, String title, String sub, Color c,
      VoidCallback action) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        action();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: c.withValues(alpha: 0.6)),
        ]),
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      );

  Widget _badge(IconData icon, String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: c)),
        ]),
      );

  Widget _rate(String label, String value, {bool highlight = false}) => Expanded(
        child: Column(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(value,
                key: ValueKey(value),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: highlight ? AppColors.accentLight : Colors.white)),
          ),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.5))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.12));
}

// ── Player Status ──────────────────────────────────────────────
class _PlayerStatus extends StatelessWidget {
  final ScoreState state;
  const _PlayerStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    final bowler = state.bowlingLineup.where((p) => p.id == state.bowlerId).firstOrNull;
    final bS = inn.bowlerStatsMap[state.bowlerId];
    final canSwap = !state.isLastManStanding &&
        state.strikerId.isNotEmpty &&
        state.nonStrikerId.isNotEmpty;

    Widget tile(String id, bool striker) => _BatTile(
          name: state.battingLineup.where((p) => p.id == id).firstOrNull?.name ?? '—',
          stats: inn.batsmanStats[id],
          isStriker: striker,
          playerId: id,
          state: state,
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(radius: 20),
      child: Column(children: [
        // Batters, with the swap-strike button between them.
        Stack(alignment: Alignment.center, children: [
          Row(children: [
            Expanded(child: tile(state.strikerId, true)),
            if (!state.isLastManStanding) ...[
              const SizedBox(width: 10),
              Expanded(child: tile(state.nonStrikerId, false)),
            ],
          ]),
          if (canSwap)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<ScoreBloc>().add(SwapStriker());
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: const Icon(Icons.swap_horiz_rounded, size: 17, color: AppColors.primary),
              ),
            ),
        ]),

        // Bowler strip
        if (bowler != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_baseball_rounded, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bowler.isGuest ? '${bowler.name} (Guest)' : bowler.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary)),
                  Text('${bS?.oversBowled ?? '0.0'} ov  ·  Econ ${bS?.economy.toStringAsFixed(1) ?? '0.0'}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.wicket.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text('${bS?.wickets ?? 0}-${bS?.runsConceded ?? 0}',
                      key: ValueKey('${bS?.wickets}-${bS?.runsConceded}'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.wicket)),
                ),
              ),
            ]),
          ),
        ],
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

    // Empty slot (after a retirement): tap to bring a batter in.
    if (playerId.isEmpty) {
      return GestureDetector(
        onTap: () => _showPicker(context, bloc, state, isStriker),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 22),
            SizedBox(height: 4),
            Text('Select batter',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
      );
    }

    final player = state.battingLineup.where((p) => p.id == playerId).firstOrNull;
    final isGuest = player?.isGuest ?? false;
    final runs = stats?.runs ?? 0;
    final balls = stats?.ballsFaced ?? 0;

    // Tapping a batter also swaps the strike, as before.
    return GestureDetector(
      onTap: () {
        if (state.isLastManStanding || state.strikerId.isEmpty || state.nonStrikerId.isEmpty) return;
        HapticFeedback.selectionClick();
        bloc.add(SwapStriker());
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 92,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: isStriker
            ? const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        color: isStriker ? null : AppColors.surfaceLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isStriker ? AppColors.primaryLight.withValues(alpha: 0.6) : Colors.transparent,
            width: 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isStriker ? Icons.sports_cricket_rounded : Icons.directions_run_rounded,
              size: 13, color: isStriker ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(isGuest ? '$name (Guest)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isStriker ? FontWeight.w800 : FontWeight.w600,
                    color: isStriker ? AppColors.textPrimary : AppColors.textSecondary)),
          ),
          GestureDetector(
            onTap: () => _retire(context, bloc, state, playerId),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.exit_to_app_rounded, size: 14, color: AppColors.textMuted),
            ),
          ),
        ]),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(end: runs),
              duration: const Duration(milliseconds: 450),
              builder: (_, v, __) => Text('$v',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1)),
            ),
            Text(' ($balls)',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          balls > 0
              ? '${stats!.fours}×4  ${stats!.sixes}×6  ·  SR ${stats!.strikeRate.toStringAsFixed(0)}'
              : isStriker
                  ? 'On strike'
                  : 'Non-striker',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isStriker ? AppColors.primary : AppColors.textMuted),
        ),
      ]),
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
