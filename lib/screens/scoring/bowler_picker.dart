part of '../scoring_screen.dart';

// End-of-over bowler picker and the innings-over panel.

// ── Bowler Picker ──────────────────────────────────────────────
/// Shown in place of the scoring pad once the innings can take no more balls
/// (e.g. after coming back from the innings break or result screen).
class _InningsOverPanel extends StatelessWidget {
  final ScoreState state;
  const _InningsOverPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final inn = state.currentInnings!;
    final next = state.isSuperOver
        ? (state.isSuperOverFirstInnings ? 'Super Over break' : 'See the result')
        : (state.isFirstInnings ? 'Innings break' : 'See the result');
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).padding.bottom + 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Innings complete',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text('${inn.battingTeamName} ${inn.totalRuns}/${inn.totalWickets} (${inn.overDisplay} ov)',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        TapBounce(
          onTap: () => ScoringScreen.goToInningsEnd(context, state),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(next,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// End-of-over break: an LED-scoreboard recap of the over just bowled, then
/// the bowling attack as swipeable cards — "Bring on …" picks the next bowler.
class _BowlerPicker extends StatefulWidget {
  final ScoreState state;
  const _BowlerPicker({required this.state});

  @override
  State<_BowlerPicker> createState() => _BowlerPickerState();
}

/// One candidate bowler with everything the card needs.
class _BowlerOption {
  final Player player;
  final BowlerStats? stats;
  final int oversUsed;
  final bool blocked;
  final String? tag;
  const _BowlerOption(this.player, this.stats, this.oversUsed, this.blocked, this.tag);
}

class _BowlerPickerState extends State<_BowlerPicker> {
  late final PageController _pages = PageController(viewportFraction: 0.64);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state        = widget.state;
    final inn          = state.currentInnings!;
    final settings     = context.read<MatchBloc>().state.settings;
    final configuredMax = settings?.maxOversPerBowler;
    final bowlStats    = inn.bowlerStatsMap;
    final lastBowler   = state.bowlingLineup.where((p) => p.id == state.bowlerId).firstOrNull;
    // The same bowler can't bowl two overs in a row.
    final candidates   = state.bowlingLineup.where((p) => p.id != state.bowlerId).toList();

    // ── Intelligent effective max ──────────────────────────────────────────
    // If the bowling lineup is too small to cover all overs within the
    // configured limit, auto-extend the limit so the game is never stuck.
    // effectiveMax = max(configuredMax, ceil(totalOvers / totalBowlers))
    int? effectiveMax;
    bool limitAutoAdjusted = false;
    if (configuredMax != null && !state.isSuperOver) {
      final totalOvers   = settings?.totalOvers ?? 1;
      final totalBowlers = state.bowlingLineup.length;
      if (totalBowlers > 0) {
        final minRequired = (totalOvers + totalBowlers - 1) ~/ totalBowlers; // ceil
        effectiveMax       = max(configuredMax, minRequired);
        limitAutoAdjusted  = effectiveMax > configuredMax;
      } else {
        effectiveMax = configuredMax;
      }
    }

    int used(Player p) => (bowlStats[p.id]?.ballsBowled ?? 0) ~/ 6;
    // All candidates exhausted their effective limit (should never permanently block)
    final allAtLimit = effectiveMax != null && candidates.every((p) => used(p) >= effectiveMax!);
    bool blocked(Player p) => effectiveMax != null && used(p) >= effectiveMax && !allAtLimit;

    // Smart tags: who took wickets, who's been tight, who's fresh.
    final bowled = candidates.where((p) => (bowlStats[p.id]?.ballsBowled ?? 0) > 0).toList();
    final topWickets = bowled.fold<int>(0, (m, p) => max(m, bowlStats[p.id]!.wickets));
    final econCandidates = bowled.where((p) => bowlStats[p.id]!.ballsBowled >= 6).toList()
      ..sort((a, b) => bowlStats[a.id]!.economy.compareTo(bowlStats[b.id]!.economy));
    final mostEconomical = econCandidates.firstOrNull?.id;
    String? tagFor(Player p) {
      if (blocked(p)) return 'LIMIT REACHED';
      final st = bowlStats[p.id];
      if (st == null || st.ballsBowled == 0) return 'FRESH LEGS';
      if (topWickets > 0 && st.wickets == topWickets) return 'WICKET TAKER';
      if (p.id == mostEconomical) return 'MOST ECONOMICAL';
      return null;
    }

    final options = [
      for (final p in candidates)
        _BowlerOption(p, bowlStats[p.id], used(p), blocked(p), tagFor(p)),
    ]..sort((a, b) => (a.blocked ? 1 : 0).compareTo(b.blocked ? 1 : 0));
    if (options.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, options.length - 1);
    final chosen = options[index];

    final completed = inn.legalBallsCount ~/ 6;
    final ovs = inn.overSummaries;
    final lastOver = completed > 0 && completed <= ovs.length ? ovs[completed - 1] : null;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, 14, 0, MediaQuery.of(context).padding.bottom + 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (lastOver != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LedOverBoard(
                overNumber: completed,
                bowlerName: lastBowler?.name,
                over: lastOver,
                totalRuns: inn.totalRuns,
                totalWickets: inn.totalWickets,
              ),
            ),
          const SizedBox(height: 16),

          // ── Title + resting bowler ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('OVER ${completed + 1}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.wicket)),
                  const Text('Bring on the bowler',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                ]),
              ),
              if (lastBowler != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.airline_seat_recline_normal_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('${lastBowler.name} resting',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ]),
                ),
            ]),
          ),
          if (limitAutoAdjusted || allAtLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(children: [
                Icon(allAtLimit ? Icons.warning_amber_rounded : Icons.auto_fix_high_rounded,
                    size: 14, color: allAtLimit ? AppColors.warning : AppColors.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    allAtLimit
                        ? 'Everyone has bowled $effectiveMax overs — pick anyone to continue'
                        : 'Limit raised to $effectiveMax overs each so ${state.bowlingLineup.length} bowlers cover ${settings?.totalOvers} overs',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: allAtLimit ? AppColors.warning : AppColors.info),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 12),

          // ── The bowling attack ───────────────────────────────────────
          SizedBox(
            height: 212,
            child: PageView.builder(
              controller: _pages,
              itemCount: options.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  final page = _pages.hasClients && _pages.position.haveDimensions
                      ? (_pages.page ?? index.toDouble())
                      : index.toDouble();
                  final focus = (1 - (page - i).abs()).clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: 0.86 + 0.14 * focus,
                    child: Opacity(opacity: 0.55 + 0.45 * focus, child: child),
                  );
                },
                child: GestureDetector(
                  onTap: () => _pages.animateToPage(i,
                      duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                  child: _BowlerCard(option: options[i], limit: effectiveMax),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Page dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < options.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: i == index ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == index ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
          const SizedBox(height: 14),

          // ── Bring on … ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TapBounce(
              onTap: chosen.blocked
                  ? () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text('${chosen.player.name} has bowled '
                              '${chosen.oversUsed}/$effectiveMax overs — limit reached'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ));
                    }
                  : () => context.read<ScoreBloc>().add(ChangeBowler(chosen.player.id)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 56,
                decoration: BoxDecoration(
                  gradient: chosen.blocked
                      ? null
                      : const LinearGradient(colors: [Color(0xFFB91C1C), AppColors.wicket]),
                  color: chosen.blocked ? AppColors.surfaceLight : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: chosen.blocked
                      ? null
                      : [BoxShadow(color: AppColors.wicket.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (!chosen.blocked) ...[
                    const SizedBox.square(dimension: 20, child: CustomPaint(painter: CricketBallPainter())),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      chosen.blocked
                          ? '${chosen.player.name} has hit the limit'
                          : 'Bring on ${chosen.player.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: chosen.blocked ? AppColors.textMuted : Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Stadium-style LED board summarising the over just bowled.
class _LedOverBoard extends StatelessWidget {
  final int overNumber;
  final String? bowlerName;
  final OverSummary over;
  final int totalRuns;
  final int totalWickets;

  const _LedOverBoard({
    required this.overNumber,
    required this.bowlerName,
    required this.over,
    required this.totalRuns,
    required this.totalWickets,
  });

  static const _amber = Color(0xFFFCD34D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'END OF OVER $overNumber${bowlerName != null ? '  ·  ${bowlerName!.toUpperCase()}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
                color: _amber,
                shadows: [Shadow(color: Color(0x99FCD34D), blurRadius: 8)],
              ),
            ),
          ),
          Text('$totalRuns/$totalWickets',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          // Runs in the over, big LED digits
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${over.runs}',
                style: const TextStyle(
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: _amber,
                  shadows: [Shadow(color: Color(0x99FCD34D), blurRadius: 14)],
                )),
            Text(over.wickets > 0 ? 'RUNS · ${over.wickets}W' : 'RUNS',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.5))),
          ]),
          const SizedBox(width: 14),
          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(width: 12),
          // Each delivery as a lit bulb
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final b in over.balls) _bulb(b)],
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _bulb(Ball b) {
    final (label, color) = ballFace(b);
    final isDot = color == AppColors.dot;
    final glow = isDot ? Colors.white.withValues(alpha: 0.25) : color;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDot ? const Color(0xFF1E293B) : color,
        boxShadow: isDot ? null : [BoxShadow(color: glow.withValues(alpha: 0.7), blurRadius: 8)],
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: label.length > 2 ? 8 : (label.length > 1 ? 9.5 : 12),
              fontWeight: FontWeight.w900,
              color: isDot ? Colors.white.withValues(alpha: 0.6) : Colors.white)),
    );
  }
}

/// Trading-card style bowler: tag, avatar, spell figures and an over-limit
/// meter drawn as cricket balls.
class _BowlerCard extends StatelessWidget {
  final _BowlerOption option;
  final int? limit;
  const _BowlerCard({required this.option, required this.limit});

  static const _tagColors = {
    'WICKET TAKER': Color(0xFFFCA5A5),
    'MOST ECONOMICAL': Color(0xFF93C5FD),
    'FRESH LEGS': Color(0xFFFCD34D),
    'LIMIT REACHED': Color(0xFFE5E7EB),
  };

  @override
  Widget build(BuildContext context) {
    final p = option.player;
    final st = option.stats;
    final blocked = option.blocked;
    final hasBowled = st != null && st.ballsBowled > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: blocked
            ? const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF4B5563)])
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF065F46), Color(0xFF064E3B), Color(0xFF022C22)],
              ),
        boxShadow: [
          BoxShadow(
            color: (blocked ? Colors.black : AppColors.primaryDark).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          // Big faint ball in the corner for texture
          Positioned(
            right: -26,
            top: -26,
            child: Opacity(
              opacity: blocked ? 0.08 : 0.16,
              child: const SizedBox.square(dimension: 110, child: CustomPaint(painter: CricketBallPainter())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (option.tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_tagColors[option.tag] ?? Colors.white).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (_tagColors[option.tag] ?? Colors.white).withValues(alpha: 0.5)),
                  ),
                  child: Text(option.tag!,
                      style: TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                          color: _tagColors[option.tag] ?? Colors.white)),
                )
              else
                const SizedBox(height: 19),
              const Spacer(),
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(p.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(p.isGuest ? 'GUEST' : 'BOWLER',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.55))),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              // Spell figures
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  _fig('O', hasBowled ? st.oversBowled : '0'),
                  _fig('R', '${st?.runsConceded ?? 0}'),
                  _fig('W', '${st?.wickets ?? 0}', highlight: (st?.wickets ?? 0) > 0),
                  _fig('ECON', hasBowled ? st.economy.toStringAsFixed(1) : '–'),
                ]),
              ),
              if (limit != null) ...[
                const SizedBox(height: 9),
                // Over limit as cricket balls: bowled ones solid, the rest outlined
                Row(children: [
                  for (var i = 0; i < limit! && i < 8; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: i < option.oversUsed
                          ? const SizedBox.square(dimension: 13, child: CustomPaint(painter: CricketBallPainter()))
                          : Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.4),
                              ),
                            ),
                    ),
                  const Spacer(),
                  Text('${option.oversUsed}/$limit OV',
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.7))),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _fig(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: highlight ? const Color(0xFFFCA5A5) : Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 8,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.5))),
      ]),
    );
  }
}
