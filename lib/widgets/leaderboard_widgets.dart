/// Shared "Hall of Fame" leaderboard used by both LeaderboardScreen and the
/// embedded leaderboard inside GroupDetailScreen.
///
/// Three races, named after cricket's awards: the Orange Cap (runs), the
/// Purple Cap (wickets) and MVP (overall impact). The top three stand on a
/// floodlit podium; everyone else follows as rank cards.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Races
// ─────────────────────────────────────────────────────────────────────────────
class _Race {
  final String label;
  final String award;
  final IconData icon;
  final Color color;
  final Color deep;
  const _Race(this.label, this.award, this.icon, this.color, this.deep);
}

const _races = [
  _Race('Batters', 'Orange Cap', Icons.sports_cricket_rounded, Color(0xFFF97316), Color(0xFFC2410C)),
  _Race('Bowlers', 'Purple Cap', Icons.sports_baseball_rounded, Color(0xFF8B5CF6), Color(0xFF6D28D9)),
  _Race('Impact', 'MVP', Icons.bolt_rounded, Color(0xFFF59E0B), Color(0xFFB45309)),
];

double? _score(PlayerStats p, int race) => race == 0
    ? p.battingRankScore
    : race == 1
        ? p.bowlingRankScore
        : p.impactRankScore;

double? _prevScore(PlayerStats p, int race) => race == 0
    ? p.previousBattingRankScore
    : race == 1
        ? p.previousBowlingRankScore
        : p.previousImpactRankScore;

/// The number people care about for each race, with its unit.
(String, String) _headline(PlayerStats p, int race) => switch (race) {
      0 => ('${p.runs}', p.runs == 1 ? 'run' : 'runs'),
      1 => ('${p.wickets}', p.wickets == 1 ? 'wkt' : 'wkts'),
      _ => ((_score(p, 2) ?? 0).toStringAsFixed(1), 'pts'),
    };

String _overs(int balls) => '${balls ~/ 6}.${balls % 6}';

/// Supporting line under a player's name.
String _subline(PlayerStats p, int race) => switch (race) {
      0 => 'SR ${p.strikeRate.toStringAsFixed(0)}  ·  Avg ${p.average.toStringAsFixed(1)}',
      1 => 'Econ ${p.economy.toStringAsFixed(1)}  ·  ${_overs(p.ballsBowled)} ov',
      _ => '${p.runs} runs  ·  ${p.wickets} wkts',
    };

/// Ranked players first (best score, then more matches, then — for batters —
/// boundary %); players without a score yet come last.
List<PlayerStats> rankPlayers(List<PlayerStats> players, int race) {
  final list = List<PlayerStats>.from(players);
  list.sort((a, b) {
    var cmp = (_score(b, race) ?? -1).compareTo(_score(a, race) ?? -1);
    if (cmp == 0) cmp = b.matches.compareTo(a.matches);
    if (cmp == 0 && race == 0) cmp = b.boundaryPercent.compareTo(a.boundaryPercent);
    return cmp;
  });
  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardBoard — the whole board: race switcher, podium, ranks, unranked
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardBoard extends StatefulWidget {
  /// Players with at least one match.
  final List<PlayerStats> players;
  /// Optional full-width content above the race switcher (scrolls with it).
  final Widget? header;
  /// Shown when nobody has played yet.
  final Widget empty;
  final double bottomPadding;

  const LeaderboardBoard({
    super.key,
    required this.players,
    required this.empty,
    this.header,
    this.bottomPadding = 40,
  });

  @override
  State<LeaderboardBoard> createState() => _LeaderboardBoardState();
}

class _LeaderboardBoardState extends State<LeaderboardBoard> {
  int _race = 0;

  @override
  Widget build(BuildContext context) {
    final race = _races[_race];
    final ranked = rankPlayers(widget.players, _race)
        .where((p) => _score(p, _race) != null)
        .toList();
    final unranked = widget.players.where((p) => _score(p, _race) == null).toList();
    final top3 = ranked.take(3).toList();
    final rest = ranked.skip(3).toList();
    final leaderScore = ranked.isEmpty ? 1.0 : math.max(_score(ranked.first, _race)!, 0.0001);

    const side = EdgeInsets.symmetric(horizontal: 16);
    return ListView(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      children: [
        if (widget.header != null) widget.header!,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _RaceSwitcher(selected: _race, onSelect: (i) => setState(() => _race = i)),
        ),
        if (widget.players.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 24), child: widget.empty)
        else ...[
          if (top3.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _Podium(key: ValueKey('podium_$_race'), race: race, raceIndex: _race, top3: top3),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _NoRaceYet(race: race),
            ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: side,
              child: Text('THE CHASING PACK',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                      color: race.deep)),
            ),
            const SizedBox(height: 10),
            for (final (i, p) in rest.indexed)
              Padding(
                padding: side,
                child: LeaderboardRankCard(
                  key: ValueKey('rank_${p.id}'),
                  stats: p,
                  raceIndex: _race,
                  rank: i + 4,
                  leaderScore: leaderScore,
                ),
              ),
          ],
          if (unranked.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(padding: side, child: _Unranked(players: unranked, race: race)),
          ],
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Race switcher: one slim segmented bar with a sliding highlight
// ─────────────────────────────────────────────────────────────────────────────
class _RaceSwitcher extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _RaceSwitcher({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final active = _races[selected];
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(children: [
        // Highlight slides under the selected tab
        AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment(-1 + selected * 1.0, 0),
          child: FractionallySizedBox(
            widthFactor: 1 / _races.length,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              decoration: BoxDecoration(
                color: active.color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Fill the bar so the labels sit centred, not at the top.
        Positioned.fill(
          child: Row(children: [
          for (final (i, r) in _races.indexed)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(r.icon, size: 16, color: i == selected ? Colors.white : r.color),
                  const SizedBox(width: 6),
                  Text(r.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == selected ? FontWeight.w800 : FontWeight.w600,
                          color: i == selected ? Colors.white : AppColors.textSecondary)),
                ]),
              ),
            ),
        ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The podium: a compact night-stage card with the top three.
//
// Intro (plays when it appears / on race switch): blocks spring up 3rd → 2nd
// → 1st, players pop in, stats count up, the crown drops onto #1.
// Idle loop: a shine sweeps the medal blocks, the leader's glow breathes and
// sparkles twinkle — slow and subtle.
// ─────────────────────────────────────────────────────────────────────────────
class _Podium extends StatefulWidget {
  final _Race race;
  final int raceIndex;
  final List<PlayerStats> top3;
  const _Podium({super.key, required this.race, required this.raceIndex, required this.top3});

  @override
  State<_Podium> createState() => _PodiumState();
}

class _PodiumState extends State<_Podium> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  static const _metal = [
    [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)], // gold
    [Color(0xFFF1F5F9), Color(0xFF94A3B8), Color(0xFF475569)], // silver
    [Color(0xFFFED7AA), Color(0xFFEA580C), Color(0xFF9A3412)], // bronze
  ];

  /// Intro progress for [begin]..[end] of the timeline with [curve].
  double _phase(double begin, double end, Curve curve) =>
      curve.transform(((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0));

  /// Headline stat counted up by [t] (0..1).
  String _counted(PlayerStats p, double t) {
    if (widget.raceIndex == 2) return ((_score(p, 2) ?? 0) * t).toStringAsFixed(1);
    final n = widget.raceIndex == 0 ? p.runs : p.wickets;
    return (n * t).round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final race = widget.race;
    final leader = widget.top3.first;
    final (_, unit) = _headline(leader, widget.raceIndex);

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _idle]),
      builder: (context, _) {
        final header = _phase(0.0, 0.25, Curves.easeOut);
        final leaderCount = _phase(0.45, 0.95, Curves.easeOutCubic);
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF172036), Color(0xFF0B1220)],
              ),
            ),
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StageGlowPainter(
                    race.color,
                    breathe: _idle.value,
                    intro: _phase(0.3, 0.9, Curves.easeOut),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(children: [
                  // Leader line slides in from the top
                  Opacity(
                    opacity: header,
                    child: Transform.translate(
                      offset: Offset(0, -10 * (1 - header)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: race.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: race.color.withValues(alpha: 0.55)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(race.icon, size: 11, color: race.color),
                            const SizedBox(width: 5),
                            Text(race.award.toUpperCase(),
                                style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: race.color)),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: leader.name, style: const TextStyle(color: Colors.white)),
                              TextSpan(
                                  text: '  ${_counted(leader, leaderCount)} $unit',
                                  style: TextStyle(color: race.color)),
                            ]),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 2nd · 1st · 3rd
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final rank in [2, 1, 3])
                      Expanded(
                        child: rank <= widget.top3.length
                            ? _spot(context, widget.top3[rank - 1], rank)
                            : const SizedBox(),
                      ),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _spot(BuildContext context, PlayerStats p, int rank) {
    final race = widget.race;
    final metal = _metal[rank - 1];
    final first = rank == 1;
    final avatar = first ? 58.0 : 46.0;
    final blockHeight = first ? 52.0 : rank == 2 ? 38.0 : 28.0;
    final (_, unit) = _headline(p, widget.raceIndex);

    // Build order: 3rd, then 2nd, then 1st — the winner arrives last.
    final start = rank == 3 ? 0.05 : rank == 2 ? 0.15 : 0.25;
    final block = _phase(start, start + 0.35, Curves.easeOutBack);
    final pop = _phase(start + 0.2, start + 0.5, Curves.easeOutBack);
    final text = _phase(start + 0.3, start + 0.55, Curves.easeOut);
    final count = _phase(start + 0.3, start + 0.7, Curves.easeOutCubic);
    final crown = _phase(0.7, 1.0, Curves.bounceOut);

    // Shine band position for this block (each starts a little later)
    final shine = ((_idle.value + (3 - rank) * 0.08) % 1.0) * 2.2 - 0.6;

    return GestureDetector(
      onTap: () => context.push('/player/${p.id}', extra: {'displayName': p.name}),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Avatar pops in; crown drops onto #1
        Transform.scale(
          scale: pop.clamp(0.0, 1.2),
          child: Opacity(
            opacity: pop.clamp(0.0, 1.0),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              Container(
                width: avatar,
                height: avatar,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    // Ring colours slowly rotate for a living medal rim
                    transform: GradientRotation(_idle.value * 2 * math.pi),
                    colors: [metal[0], metal[1], metal[2], metal[1], metal[0]],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (first ? race.color : metal[1]).withValues(alpha: first ? 0.5 : 0.25),
                      blurRadius: first ? 16 : 8,
                    ),
                  ],
                ),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111827)),
                  alignment: Alignment.center,
                  child: Text(p.name[0].toUpperCase(),
                      style: TextStyle(fontSize: avatar * 0.4, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              if (first)
                Positioned(
                  top: -18 - 26 * (1 - crown),
                  child: Opacity(
                    opacity: crown,
                    child: Icon(Icons.workspace_premium_rounded,
                        size: 22,
                        color: metal[1],
                        shadows: [Shadow(color: metal[1].withValues(alpha: 0.7), blurRadius: 10)]),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: text,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - text)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(p.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: first ? 13 : 12, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: _counted(p, count),
                    style: TextStyle(
                        fontSize: first ? 16 : 14,
                        fontWeight: FontWeight.w900,
                        color: first ? race.color : Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.55))),
              ])),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        // Metallic block springs up, with a shine sweeping across it. Its full
        // height is reserved and the rise is a transform, so the card keeps
        // its size during the intro and nothing below jumps.
        Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1, block.clamp(0.0, 1.15), 1),
          child: Container(
          height: blockHeight,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [metal[0], metal[1], metal[2]],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Stack(fit: StackFit.expand, children: [
            // Shine band
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + shine * 2 - 0.4, -1),
                  end: Alignment(-1 + shine * 2 + 0.4, 1),
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            if (block > 0.6)
              Center(
                child: Text('$rank',
                    style: TextStyle(
                        fontSize: first ? 24 : 18,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: Colors.white,
                        shadows: [Shadow(color: metal[2].withValues(alpha: 0.6), blurRadius: 3, offset: const Offset(0, 1))])),
              ),
          ]),
        ),
        ),
      ]),
    );
  }
}

/// Race-coloured glow behind the leader (fades in, then gently breathes) and
/// a few twinkling sparkles.
class _StageGlowPainter extends CustomPainter {
  final Color tint;
  final double breathe; // 0..1 looping
  final double intro;   // 0..1 once
  _StageGlowPainter(this.tint, {required this.breathe, required this.intro});

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = (1 - math.cos(breathe * 2 * math.pi)) / 2; // 0→1→0
    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = size.width * (0.40 + 0.06 * pulse);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [tint.withValues(alpha: (0.22 + 0.10 * pulse) * intro), tint.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final rnd = math.Random(3);
    for (var i = 0; i < 16; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.6);
      final r = rnd.nextDouble() * 1.1 + 0.5;
      final phase = rnd.nextDouble();
      final twinkle = (1 - math.cos((breathe + phase) * 2 * math.pi)) / 2;
      canvas.drawCircle(o, r, Paint()..color = Colors.white.withValues(alpha: (0.12 + 0.45 * twinkle) * intro));
    }
  }

  @override
  bool shouldRepaint(_StageGlowPainter old) =>
      old.tint != tint || old.breathe != breathe || old.intro != intro;
}

class _NoRaceYet extends StatelessWidget {
  final _Race race;
  const _NoRaceYet({required this.race});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: race.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: race.color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(race.icon, color: race.color, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text('The ${race.award} race hasn\'t started — play a few more matches to rank.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: race.deep)),
        ),
      ]),
    );
  }
}

class _Unranked extends StatelessWidget {
  final List<PlayerStats> players;
  final _Race race;
  const _Unranked({required this.players, required this.race});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.hourglass_bottom_rounded, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          const Text('NOT RANKED YET',
              style: TextStyle(fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const Spacer(),
          Text('needs more ${race.label.toLowerCase() == 'batters' ? 'batting' : race.label.toLowerCase() == 'bowlers' ? 'bowling' : 'games'}',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in players)
            GestureDetector(
              onTap: () => context.push('/player/${p.id}', extra: {'displayName': p.name}),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.border,
                    child: Text(p.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 6),
                  Text(p.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardRankCard — #4 onwards
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardRankCard extends StatefulWidget {
  final PlayerStats stats;
  final int raceIndex; // 0 Batting · 1 Bowling · 2 Impact
  final int rank;
  /// Leader's score, for the "distance to the top" bar.
  final double leaderScore;

  const LeaderboardRankCard({
    super.key,
    required this.stats,
    required this.raceIndex,
    required this.rank,
    required this.leaderScore,
  });

  @override
  State<LeaderboardRankCard> createState() => _LeaderboardRankCardState();
}

class _LeaderboardRankCardState extends State<LeaderboardRankCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final race = _races[widget.raceIndex];
    final score = _score(s, widget.raceIndex) ?? 0;
    final prev = _prevScore(s, widget.raceIndex);
    final (value, unit) = _headline(s, widget.raceIndex);
    final progress = (score / widget.leaderScore).clamp(0.0, 1.0);

    final (IconData trendIcon, Color trendColor) = prev == null || score > prev
        ? (Icons.trending_up_rounded, AppColors.success)
        : score < prev
            ? (Icons.trending_down_rounded, AppColors.danger)
            : (Icons.trending_flat_rounded, AppColors.textMuted);

    return TapBounce(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _expanded ? race.color.withValues(alpha: 0.4) : AppColors.border),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(children: [
            Row(children: [
              // Outlined rank numeral
              SizedBox(
                width: 34,
                child: Text('${widget.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1.4
                        ..color = race.color,
                    )),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [race.color.withValues(alpha: 0.18), race.color.withValues(alpha: 0.06)],
                  ),
                  border: Border.all(color: race.color.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(s.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: race.deep)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/player/${s.id}', extra: {'displayName': s.name}),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 1),
                    Text(_subline(s, widget.raceIndex),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(value,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: race.deep, height: 1.1)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(trendIcon, size: 13, color: trendColor),
                  const SizedBox(width: 3),
                  Text(unit.toUpperCase(),
                      style: const TextStyle(fontSize: 9, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                ]),
              ]),
            ]),
            const SizedBox(height: 10),
            // Distance to the leader
            Row(children: [
              const SizedBox(width: 42),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 6, color: AppColors.surfaceLight),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => FractionallySizedBox(widthFactor: v, child: child),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [race.color.withValues(alpha: 0.6), race.color]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}% of #1',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ]),
            if (_expanded) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 12),
              _details(s),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _details(PlayerStats s) {
    final items = switch (widget.raceIndex) {
      0 => [
          ('INNS', '${s.inningsBatted}'),
          ('HS', '${s.highestScore}'),
          ('AVG', s.average.toStringAsFixed(1)),
          ('SR', s.strikeRate.toStringAsFixed(1)),
          ('4s', '${s.fours}'),
          ('6s', '${s.sixes}'),
          ('50s', '${s.fifties}'),
          ('BND%', '${s.boundaryPercent.toStringAsFixed(0)}%'),
        ],
      1 => [
          ('MAT', '${s.matchesBowled}'),
          ('OVERS', _overs(s.ballsBowled)),
          ('RUNS', '${s.runsConceded}'),
          ('ECON', s.economy.toStringAsFixed(1)),
          ('BEST', s.bestBowlingWickets != null ? '${s.bestBowlingWickets}/${s.bestBowlingRuns}' : '–'),
          ('W/M', s.wicketsPerMatch.toStringAsFixed(1)),
          ('DOT%', '${s.dotBallPercent.toStringAsFixed(0)}%'),
          ('AVG', s.bowlingAverage?.toStringAsFixed(1) ?? '–'),
        ],
      _ => [
          ('BAT', s.battingRankScore?.toStringAsFixed(1) ?? '–'),
          ('BOWL', s.bowlingRankScore?.toStringAsFixed(1) ?? '–'),
          ('FIELD', '${s.fieldingBonus}'),
          ('MAT', '${s.matches}'),
        ],
    };
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / 4;
      return Wrap(runSpacing: 10, children: [
        for (final (label, val) in items)
          SizedBox(
            width: w,
            child: Column(children: [
              Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            ]),
          ),
      ]);
    });
  }
}
