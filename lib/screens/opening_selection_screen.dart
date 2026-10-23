import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/setup_flow.dart';

class OpeningSelectionScreen extends StatefulWidget {
  final String battingTeamName;
  final List<Player> battingPlayers;
  final List<Player> bowlingPlayers;
  final int target;

  const OpeningSelectionScreen({
    super.key,
    required this.battingTeamName,
    required this.battingPlayers,
    required this.bowlingPlayers,
    this.target = 0,
  });

  @override
  State<OpeningSelectionScreen> createState() => _OpeningSelectionScreenState();
}

class _OpeningStateData {
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;

  _OpeningStateData({
    this.strikerId,
    this.nonStrikerId,
    this.bowlerId,
  });
}

class _OpeningSelectionScreenState extends State<OpeningSelectionScreen> {
  late final ValueNotifier<_OpeningStateData> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<_OpeningStateData>(_OpeningStateData());
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  void _start() {
    final sel = _notifier.value;
    if (sel.strikerId == null || sel.nonStrikerId == null || sel.bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select opener, non-striker and bowler')));
      return;
    }

    if (widget.target == 0) {
      // ── First innings: show confirmation before creating DB record ──────
      final ms           = context.read<MatchBloc>().state;
      final strikerName  = widget.battingPlayers.firstWhere((p) => p.id == sel.strikerId!).name;
      final nonStriker   = widget.battingPlayers.firstWhere((p) => p.id == sel.nonStrikerId!).name;
      final bowlerName   = widget.bowlingPlayers.firstWhere((p) => p.id == sel.bowlerId!).name;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        isDismissible: true,
        builder: (_) => _MatchConfirmSheet(
          matchState    : ms,
          battingTeam   : widget.battingTeamName,
          bowlingTeam   : _bowlingTeamName,
          strikerName   : strikerName,
          nonStrikerName: nonStriker,
          bowlerName    : bowlerName,
          onConfirm     : () => _createAndStart(sel),
        ),
      );
    } else {
      // ── Second innings: match already exists in DB, just start ──────────
      _doStartInnings(sel);
      context.go('/home');
    }
  }

  /// Called after the user confirms in the confirmation sheet (first innings only).
  void _createAndStart(_OpeningStateData sel) {
    final ms      = context.read<MatchBloc>().state;
    final matchId = ms.matchId!;

    // 1. Create the match record in the database for the first time.
    context.read<MatchListBloc>().add(AddMatchToList(MatchSummary(
      id                : matchId,
      teamAName         : ms.settings!.teamAName,
      teamBName         : ms.settings!.teamBName,
      teamA             : ms.teamA,
      teamB             : ms.teamB,
      totalOvers        : ms.settings!.totalOvers,
      status            : 'in_progress',
      createdAt         : DateTime.now(),
      groupId           : ms.settings?.groupId,
      maxOversPerBowler : ms.settings?.maxOversPerBowler,
      powerPlayOvers    : ms.settings?.powerPlayOvers,
    )));

    // 2. Register match ID so every ball publishes a live score.
    context.read<ScoreBloc>().activeMatchId = matchId;

    // 3. Start the innings in the ScoreBloc.
    _doStartInnings(sel);

    // 4. Navigate home — the shell overlay shows ScoringScreen automatically.
    context.go('/home');
  }

  void _doStartInnings(_OpeningStateData sel) {
    context.read<ScoreBloc>().add(StartInnings(
      battingTeamName: widget.battingTeamName,
      battingLineup  : widget.battingPlayers,
      bowlingLineup  : widget.bowlingPlayers,
      target         : widget.target,
      strikerId      : sel.strikerId!,
      nonStrikerId   : sel.nonStrikerId!,
      bowlerId       : sel.bowlerId!,
    ));
  }

  String get _bowlingTeamName {
    final ms = context.read<MatchBloc>().state;
    return widget.battingTeamName == ms.teamA?.name
        ? (ms.teamB?.name ?? '')
        : (ms.teamA?.name ?? '');
  }

  // Which batting slot the next tapped batter goes into.
  _BatSlot _activeSlot = _BatSlot.striker;

  void _pickBatter(Player p) {
    final sel = _notifier.value;
    String? striker = sel.strikerId;
    String? nonStriker = sel.nonStrikerId;

    if (p.id == striker) {
      // Tapping a picked batter frees their slot and makes it the next to fill.
      striker = null;
      _activeSlot = _BatSlot.striker;
    } else if (p.id == nonStriker) {
      nonStriker = null;
      _activeSlot = _BatSlot.nonStriker;
    } else if (_activeSlot == _BatSlot.striker) {
      striker = p.id;
      if (nonStriker == null) _activeSlot = _BatSlot.nonStriker;
    } else {
      nonStriker = p.id;
      if (striker == null) _activeSlot = _BatSlot.striker;
    }
    setState(() {});
    _notifier.value = _OpeningStateData(
      strikerId: striker,
      nonStrikerId: nonStriker,
      bowlerId: sel.bowlerId,
    );
  }

  void _swapBatters() {
    final sel = _notifier.value;
    _notifier.value = _OpeningStateData(
      strikerId: sel.nonStrikerId,
      nonStrikerId: sel.strikerId,
      bowlerId: sel.bowlerId,
    );
  }

  String? _name(List<Player> players, String? id) =>
      id == null ? null : players.where((p) => p.id == id).firstOrNull?.name;

  @override
  Widget build(BuildContext context) {
    final is2nd = widget.target > 0;
    return ValueListenableBuilder<_OpeningStateData>(
      valueListenable: _notifier,
      builder: (context, selection, _) {
        final missing = [
          if (selection.strikerId == null) 'striker',
          if (selection.nonStrikerId == null) 'non-striker',
          if (selection.bowlerId == null) 'bowler',
        ];
        return SetupScaffold(
          step: is2nd ? null : SetupStep.openers,
          eyebrow: is2nd ? 'SECOND INNINGS' : null,
          title: is2nd ? 'The Chase' : 'Pick Openers',
          subtitle: Text('${widget.battingTeamName} bat  ·  $_bowlingTeamName bowl'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              if (is2nd) ...[
                FadeInEntrance(offset: const Offset(0, 16), child: _targetBanner()),
                const SizedBox(height: 16),
              ],
              FadeInEntrance(
                offset: const Offset(0, 16),
                child: _CreaseCard(
                  striker: _name(widget.battingPlayers, selection.strikerId),
                  nonStriker: _name(widget.battingPlayers, selection.nonStrikerId),
                  bowler: _name(widget.bowlingPlayers, selection.bowlerId),
                  activeSlot: _activeSlot,
                  onSlotTap: (slot) => setState(() => _activeSlot = slot),
                  onSwap: selection.strikerId != null && selection.nonStrikerId != null
                      ? _swapBatters
                      : null,
                ),
              ),
              const SizedBox(height: 22),

              // ── Batters ──────────────────────────────────────────────
              SetupSectionTitle(
                icon: Icons.sports_cricket_rounded,
                color: AppColors.primary,
                title: 'Opening batters',
                caption: widget.battingTeamName,
                trailing: _PickingPill(
                  text: _activeSlot == _BatSlot.striker ? 'Picking striker' : 'Picking non-striker',
                  color: _activeSlot == _BatSlot.striker ? AppColors.primary : AppColors.info,
                ),
              ),
              const SizedBox(height: 12),
              _PlayerGrid(
                players: widget.battingPlayers,
                badgeFor: (p) => p.id == selection.strikerId
                    ? ('STRIKER', AppColors.primary)
                    : p.id == selection.nonStrikerId
                        ? ('NON-STRIKER', AppColors.info)
                        : null,
                onTap: _pickBatter,
              ),
              const SizedBox(height: 22),

              // ── Bowler ───────────────────────────────────────────────
              SetupSectionTitle(
                icon: Icons.sports_baseball_rounded,
                color: AppColors.danger,
                title: 'Opening bowler',
                caption: _bowlingTeamName,
              ),
              const SizedBox(height: 12),
              _PlayerGrid(
                players: widget.bowlingPlayers,
                badgeFor: (p) => p.id == selection.bowlerId ? ('BOWLING', AppColors.danger) : null,
                onTap: (p) => _notifier.value = _OpeningStateData(
                  strikerId: selection.strikerId,
                  nonStrikerId: selection.nonStrikerId,
                  bowlerId: selection.bowlerId == p.id ? null : p.id,
                ),
              ),
            ],
          ),
          bottomBar: SetupCta(
            label: is2nd ? 'Start the Chase' : 'Start Match',
            icon: Icons.play_arrow_rounded,
            onTap: missing.isEmpty ? _start : null,
            hint: missing.isEmpty ? null : Text('Still to pick: ${missing.join(', ')}'),
          ),
        );
      },
    );
  }

  Widget _targetBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.scoreGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.scoreBlue.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.battingTeamName} need',
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
                Text('${widget.target} to win',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
          Column(
            children: [
              Text('TARGET',
                  style: TextStyle(fontSize: 9.5, letterSpacing: 1.8, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6))),
              Text('${widget.target}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.accentLight, height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BatSlot { striker, nonStriker }

/// The pitch from above: bowler and non-striker at one end, striker at the
/// other. Batting slots are tappable to choose which one to fill next.
class _CreaseCard extends StatelessWidget {
  final String? striker;
  final String? nonStriker;
  final String? bowler;
  final _BatSlot activeSlot;
  final ValueChanged<_BatSlot> onSlotTap;
  final VoidCallback? onSwap;

  const _CreaseCard({
    required this.striker,
    required this.nonStriker,
    required this.bowler,
    required this.activeSlot,
    required this.onSlotTap,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15803D), Color(0xFF166534)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF166534).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Slot(
                          role: 'BOWLER',
                          name: bowler,
                          color: AppColors.danger,
                          icon: Icons.sports_baseball_rounded,
                          active: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Slot(
                          role: 'NON-STRIKER',
                          name: nonStriker,
                          color: AppColors.info,
                          icon: Icons.directions_run_rounded,
                          active: activeSlot == _BatSlot.nonStriker,
                          onTap: () => onSlotTap(_BatSlot.nonStriker),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Swap sits mid-pitch, between the two ends
                  TapBounce(
                    onTap: onSwap ?? () {},
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: onSwap != null ? 1 : 0.4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.primaryDark),
                            SizedBox(width: 4),
                            Text('Swap ends',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(flex: 1),
                      Expanded(
                        flex: 4,
                        child: _Slot(
                          role: 'STRIKER',
                          name: striker,
                          color: AppColors.primary,
                          icon: Icons.sports_cricket_rounded,
                          active: activeSlot == _BatSlot.striker,
                          onTap: () => onSlotTap(_BatSlot.striker),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final String role;
  final String? name;
  final Color color;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _Slot({
    required this.role,
    required this.name,
    required this.color,
    required this.icon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = name != null;
    return TapBounce(
      onTap: onTap ?? () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          // Solid even when empty, so pitch markings don't show through.
          color: filled ? Colors.white : const Color(0xFF14532D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.accentLight : Colors.white.withValues(alpha: filled ? 0 : 0.45),
            width: active ? 2.5 : 1.2,
          ),
          boxShadow: active
              ? [BoxShadow(color: AppColors.accentLight.withValues(alpha: 0.45), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: filled ? color : Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: filled
                  ? Text(name![0].toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white))
                  : Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role,
                      style: TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: filled ? color : Colors.white.withValues(alpha: 0.8))),
                  Text(name ?? (active ? 'Tap a player' : 'Empty'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: filled ? AppColors.textPrimary : Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pitch strip, creases and stumps drawn over the outfield.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Mowing bands
    final band = Paint()..color = Colors.white.withValues(alpha: 0.04);
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 18), band);
    }
    // Pitch strip down the middle
    final pitch = Rect.fromCenter(
        center: size.center(Offset.zero), width: size.width * 0.3, height: size.height + 20);
    canvas.drawRect(pitch, Paint()..color = const Color(0xFFD9C38E).withValues(alpha: 0.35));
    final crease = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    // Popping creases at the two ends of the pitch (card edges), clear of the slots.
    for (final y in [9.0, size.height - 9]) {
      canvas.drawLine(Offset(pitch.left - 10, y), Offset(pitch.right + 10, y), crease);
      // Stumps
      final stump = Paint()..color = const Color(0xFFF5DEB3).withValues(alpha: 0.8);
      for (var i = -1; i <= 1; i++) {
        canvas.drawCircle(Offset(size.width / 2 + i * 5, y), 2.2, stump);
      }
    }
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}

class _PickingPill extends StatelessWidget {
  final String text;
  final Color color;
  const _PickingPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Two-column grid of player chips; a badge marks the chosen ones.
class _PlayerGrid extends StatelessWidget {
  final List<Player> players;
  final (String, Color)? Function(Player) badgeFor;
  final ValueChanged<Player> onTap;

  const _PlayerGrid({required this.players, required this.badgeFor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in players)
            SizedBox(width: w, child: _chip(p, badgeFor(p))),
        ],
      );
    });
  }

  Widget _chip(Player p, (String, Color)? badge) {
    final color = badge?.$2;
    return TapBounce(
      onTap: () => onTap(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
        decoration: BoxDecoration(
          color: color != null ? color.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color ?? AppColors.border, width: color != null ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color ?? AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(p.name[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: color != null ? Colors.white : AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(badge?.$1 ?? (p.isGuest ? 'GUEST' : _role(p.role)),
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: color ?? AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _role(PlayerRole r) => switch (r) {
        PlayerRole.batsman      => 'BATTER',
        PlayerRole.bowler       => 'BOWLER',
        PlayerRole.allRounder   => 'ALL-ROUNDER',
        PlayerRole.wicketKeeper => 'KEEPER',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Match confirmation sheet — shown before the first ball of a new match.
// Creates the DB record only after the user taps "Start Match".
// ─────────────────────────────────────────────────────────────────────────────
class _MatchConfirmSheet extends StatelessWidget {
  final MatchState matchState;
  final String battingTeam;
  final String bowlingTeam;
  final String strikerName;
  final String nonStrikerName;
  final String bowlerName;
  final VoidCallback onConfirm;

  const _MatchConfirmSheet({
    required this.matchState,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.strikerName,
    required this.nonStrikerName,
    required this.bowlerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final settings   = matchState.settings;
    final overs      = settings?.totalOvers ?? 0;
    final tossWinner = matchState.tossWinner ?? '';
    final decision   = matchState.tossDecision ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16)],
            ),
            child: const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Ready to start?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Review your match details before the first ball.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // Match summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Teams
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(settings?.teamAName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('vs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted.withValues(alpha: 0.6))),
                    ),
                    Text(settings?.teamBName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                // Overs pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$overs overs',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Toss result
                _Row(icon: Icons.monetization_on_rounded, color: AppColors.accent,
                    label: 'Toss', value: '$tossWinner won · elected to $decision'),
                const SizedBox(height: 10),

                // Batting first
                _Row(icon: Icons.sports_cricket_rounded, color: AppColors.info,
                    label: 'Batting first', value: battingTeam),
                const SizedBox(height: 10),

                // Openers
                _Row(icon: Icons.people_rounded, color: AppColors.success,
                    label: 'Openers', value: '$strikerName (striker) & $nonStrikerName'),
                const SizedBox(height: 10),

                // Opening bowler
                _Row(icon: Icons.sports_baseball_rounded, color: AppColors.danger,
                    label: 'Bowler', value: bowlerName),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          SwipeToStart(
            text: 'SWIPE TO START',
            onSwipe: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Row({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe to Start Component
// ─────────────────────────────────────────────────────────────────────────────
class SwipeToStart extends StatefulWidget {
  final VoidCallback onSwipe;
  final String text;

  const SwipeToStart({super.key, required this.onSwipe, required this.text});

  @override
  State<SwipeToStart> createState() => _SwipeToStartState();
}

class _SwipeToStartState extends State<SwipeToStart> {
  late final ValueNotifier<double> _dragNotifier;
  late final ValueNotifier<bool> _dragStateNotifier;
  bool _completed = false;
  
  // Outer height = 64. Border = 2x2. Padding = 4x2.
  // Inner Stack Height = 64 - 4 - 8 = 52.
  // Thumb perfectly matches this to avoid any overflow.
  final double _thumbSize = 52;

  @override
  void initState() {
    super.initState();
    _dragNotifier = ValueNotifier<double>(0);
    _dragStateNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    _dragStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Border is 2px on each side. Padding is 4px on each side.
        // Total horizontal inset = 4 + 8 = 12.
        final stackWidth = constraints.maxWidth - 12;
        final maxDrag = stackWidth - _thumbSize;

        return ValueListenableBuilder<bool>(
          valueListenable: _dragStateNotifier,
          builder: (context, isDragging, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDragging
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDragging ? AppColors.primary : AppColors.border,
                  width: 2.0, // Fixed border width for precise math
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none, // Extremely important: prevents any flat slicing!
                alignment: Alignment.centerLeft,
                children: [
                  // Background track text
                  Positioned.fill(
                    left: _thumbSize,
                    child: Center(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _dragNotifier,
                        builder: (context, dragOffset, child) {
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: dragOffset > maxDrag * 0.2 ? 0.0 : 1.0,
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.text,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: isDragging
                                      ? AppColors.primary
                                      : AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.keyboard_double_arrow_right_rounded,
                                size: 20,
                                color: (isDragging
                                        ? AppColors.primary
                                        : AppColors.textPrimary)
                                    .withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Draggable Thumb with synchronized position animation
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, dragOffset, _) {
                      return TweenAnimationBuilder<double>(
                        duration: isDragging
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        tween: Tween<double>(begin: 0, end: dragOffset),
                        builder: (context, value, child) {
                          return Positioned(
                            left: value,
                            child: GestureDetector(
                              onHorizontalDragStart: (_) {
                                if (_completed) return;
                                _dragStateNotifier.value = true;
                              },
                              onHorizontalDragUpdate: (details) {
                                if (_completed) return;
                                double newOffset =
                                    _dragNotifier.value + details.delta.dx;
                                if (newOffset < 0) newOffset = 0;

                                // Auto-trigger the moment it hits the end!
                                if (newOffset >= maxDrag) {
                                  newOffset = maxDrag;
                                  _completed = true;
                                  _dragStateNotifier.value = false;
                                  _dragNotifier.value = newOffset;
                                  Future.delayed(
                                      const Duration(milliseconds: 200),
                                      widget.onSwipe);
                                  return;
                                }
                                _dragNotifier.value = newOffset;
                              },
                              onHorizontalDragEnd: (details) {
                                if (_completed) return;
                                _dragStateNotifier.value = false;
                                if (_dragNotifier.value > maxDrag * 0.7) {
                                  _completed = true;
                                  _dragNotifier.value = maxDrag;
                                  Future.delayed(
                                      const Duration(milliseconds: 300),
                                      widget.onSwipe);
                                } else {
                                  _dragNotifier.value = 0; // Snap back
                                }
                              },
                              child: Container(
                                width: _thumbSize,
                                height: _thumbSize,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.transparent, // Ensure transparent background
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isDragging ? 0.4 : 0.2),
                                      blurRadius: isDragging ? 12 : 8,
                                      offset: const Offset(0, 4), // Stays static!
                                    )
                                  ],
                                ),
                                // Rotate ONLY the image, so the shadow stays locked downward
                                child: Transform.rotate(
                                  angle: value / 20,
                                  child: Image.asset(
                                    'assets/icons/ic_cricket_ball_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
