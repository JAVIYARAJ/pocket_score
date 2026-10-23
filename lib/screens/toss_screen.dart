import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../theme/animations.dart';
import '../theme/app_theme.dart';
import '../widgets/setup_flow.dart';

class TossScreen extends StatefulWidget {
  const TossScreen({super.key});

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossStateData {
  final String? winner;
  final String? decision;
  final bool isTossing;

  _TossStateData({
    this.winner,
    this.decision,
    this.isTossing = false,
  });
}

class _TossScreenState extends State<TossScreen> with SingleTickerProviderStateMixin {
  late final ValueNotifier<_TossStateData> _notifier;
  late final AnimationController _flip;
  // Half-turns for the current flip: even lands on Team A's face, odd on B's.
  int _halfTurns = 0;

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<_TossStateData>(_TossStateData());
    _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  }

  @override
  void dispose() {
    _notifier.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _flipCoin() async {
    final ms = context.read<MatchBloc>().state;
    final teamAWins = Random().nextBool();
    // Pick the outcome first, then spin an exact number of half-turns so the
    // coin visibly lands on the winner's crest.
    _halfTurns = 10 + (teamAWins ? 0 : 1);
    _notifier.value = _TossStateData(isTossing: true);
    await _flip.forward(from: 0);
    if (!mounted) return;
    _notifier.value = _TossStateData(
      winner: teamAWins ? ms.teamA!.name : ms.teamB!.name,
      isTossing: false,
    );
  }

  void _proceed() {
    final state = _notifier.value;
    if (state.winner == null || state.decision == null) return;
    context.read<MatchBloc>().add(PerformToss(winnerTeamName: state.winner!, decision: state.decision!));
    final ms    = context.read<MatchBloc>().state;
    final teamA = ms.teamA!;
    final teamB = ms.teamB!;
    final teamABats = (state.winner == teamA.name && state.decision == 'Bat') ||
                      (state.winner != teamA.name && state.decision == 'Bowl');
    context.push('/match/opening', extra: {
      'battingTeamName': teamABats ? teamA.name : teamB.name,
      'battingPlayers' : teamABats ? teamA.players : teamB.players,
      'bowlingPlayers' : teamABats ? teamB.players : teamA.players,
      'target'         : 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.read<MatchBloc>().state;
    final teamA = ms.teamA?.name ?? 'Team A';
    final teamB = ms.teamB?.name ?? 'Team B';

    return ValueListenableBuilder<_TossStateData>(
      valueListenable: _notifier,
      builder: (context, toss, _) {
        final decided = toss.winner != null;
        return SetupScaffold(
          step: SetupStep.toss,
          title: 'Coin Toss',
          subtitle: Text(decided ? 'Over to the winning captain' : 'Captains, call it!'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                // Which face belongs to whom
                Row(
                  children: [
                    Expanded(child: _FaceLabel(name: teamA, color: TeamColors.a, face: 'HEADS',
                        dimmed: decided && toss.winner != teamA)),
                    const SizedBox(width: 12),
                    Expanded(child: _FaceLabel(name: teamB, color: TeamColors.b, face: 'TAILS',
                        dimmed: decided && toss.winner != teamB)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 250,
                  child: AnimatedBuilder(
                    animation: _flip,
                    builder: (context, _) => _FlippingCoin(
                      progress: _flip.value,
                      halfTurns: _halfTurns,
                      teamA: teamA,
                      teamB: teamB,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: decided
                      ? _ResultPanel(
                          key: const ValueKey('result'),
                          winner: toss.winner!,
                          winnerColor: toss.winner == teamA ? TeamColors.a : TeamColors.b,
                          decision: toss.decision,
                          onDecide: (d) => _notifier.value = _TossStateData(
                            winner: toss.winner,
                            decision: d,
                          ),
                        )
                      : Text(
                          key: ValueKey(toss.isTossing),
                          toss.isTossing ? 'It\'s in the air…' : 'Tap below to flip the coin',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: toss.isTossing ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                ),
              ],
            ),
          ),
          bottomBar: decided
              ? SetupCta(
                  label: 'Pick Openers',
                  icon: Icons.sports_cricket_rounded,
                  onTap: toss.decision != null ? _proceed : null,
                  hint: toss.decision == null ? const Text('Choose to bat or bowl first') : null,
                )
              : SetupCta(
                  label: toss.isTossing ? 'Flipping…' : 'Flip the Coin',
                  icon: Icons.autorenew_rounded,
                  onTap: toss.isTossing ? null : _flipCoin,
                ),
        );
      },
    );
  }
}

class _FaceLabel extends StatelessWidget {
  final String name;
  final Color color;
  final String face;
  final bool dimmed;
  const _FaceLabel({required this.name, required this.color, required this.face, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            TeamCrest(name: name, color: color, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(face,
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gold coin with a team crest on each face. It spins about its horizontal
/// axis while arcing up and back down, and lands after [halfTurns] half-turns.
class _FlippingCoin extends StatelessWidget {
  final double progress;
  final int halfTurns;
  final String teamA;
  final String teamB;

  const _FlippingCoin({
    required this.progress,
    required this.halfTurns,
    required this.teamA,
    required this.teamB,
  });

  @override
  Widget build(BuildContext context) {
    final spin = Curves.easeOutCubic.transform(progress);
    final angle = spin * halfTurns * pi;
    final height = sin(progress * pi); // 0 → 1 → 0 arc
    final showA = cos(angle) >= 0;
    const coin = 150.0;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Shadow shrinks while the coin is high
        Positioned(
          bottom: 8,
          child: Container(
            width: coin * (0.8 - height * 0.4),
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.12 - height * 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: 30 + height * 70,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(angle),
            child: Transform(
              // The back face is mirrored by the rotation; flip it back so
              // Team B's crest reads the right way up.
              alignment: Alignment.center,
              transform: showA ? Matrix4.identity() : (Matrix4.identity()..rotateX(pi)),
              child: _CoinFace(
                name: showA ? teamA : teamB,
                color: showA ? TeamColors.a : TeamColors.b,
                size: coin,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoinFace extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const _CoinFace({required this.name, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFB45309)],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.1)!, Color.lerp(color, Colors.black, 0.3)!],
          ),
          border: Border.all(color: const Color(0xFFFEF3C7).withValues(alpha: 0.7), width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(initial,
                style: TextStyle(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1)),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.12),
              child: Text(name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: size * 0.065,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final String winner;
  final Color winnerColor;
  final String? decision;
  final ValueChanged<String> onDecide;

  const _ResultPanel({
    super.key,
    required this.winner,
    required this.winnerColor,
    required this.decision,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Winner banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOSS WON BY',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.8))),
                    Text(winner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$winner elect to…',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChoiceCard(
                label: 'BAT',
                caption: 'Set a target',
                icon: Icons.sports_cricket_rounded,
                color: AppColors.primary,
                selected: decision == 'Bat',
                onTap: () => onDecide('Bat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceCard(
                label: 'BOWL',
                caption: 'Chase it down',
                icon: Icons.sports_baseball_rounded,
                color: AppColors.danger,
                selected: decision == 'Bowl',
                onTap: () => onDecide('Bowl'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.25)!])
              : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border, width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 28, color: selected ? Colors.white : color),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 17,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(caption,
                style: TextStyle(
                    fontSize: 11.5,
                    color: selected ? Colors.white.withValues(alpha: 0.85) : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
