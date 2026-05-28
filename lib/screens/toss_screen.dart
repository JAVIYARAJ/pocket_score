import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';
import 'dart:math';

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
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<_TossStateData>(_TossStateData());
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _notifier.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _flipCoin() async {
    _notifier.value = _TossStateData(
      winner: _notifier.value.winner,
      decision: _notifier.value.decision,
      isTossing: true,
    );
    final ms = context.read<MatchBloc>().state;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final winner = Random().nextBool() ? ms.teamA!.name : ms.teamB!.name;
    _notifier.value = _TossStateData(
      winner: winner,
      decision: _notifier.value.decision,
      isTossing: false,
    );
    _animCtrl.forward();
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: ValueListenableBuilder<_TossStateData>(
          valueListenable: _notifier,
          builder: (context, selection, _) {
            return Column(
              children: [
                // ── Gradient header ──────────────────────────────────────
                _buildHeader(context),

                // ── Toss body ────────────────────────────────────────────
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      child: selection.winner == null ? _buildCoinSection(selection) : _buildResultSection(selection),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ), // Scaffold
    );   // AnnotatedRegion
  }

  Widget _buildHeader(BuildContext context) {
    return PremiumHeader(
      category: 'STEP 3',
      title: 'Coin Toss',
      trailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildCoinSection(_TossStateData selection) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        // Animated coin
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: selection.isTossing ? 130 : 150,
          height: selection.isTossing ? 130 : 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: selection.isTossing ? 0.55 : 0.3),
              blurRadius: selection.isTossing ? 40 : 20,
              spreadRadius: selection.isTossing ? 4 : 0,
            )],
          ),
          child: Center(
            child: selection.isTossing
                ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Icon(Icons.monetization_on_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          selection.isTossing ? 'Flipping...' : 'Ready to flip!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: selection.isTossing ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        const Text('May the best team win 🏏', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 32),
        if (!selection.isTossing)
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: ElevatedButton.icon(
              onPressed: _flipCoin,
              icon: const Text('🪙', style: TextStyle(fontSize: 18)),
              label: const Text('Flip Coin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResultSection(_TossStateData selection) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Winner card
        ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppColors.successGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text('TOSS WON BY', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(selection.winner!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Decision
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              const Text(
                'CHOOSE TO',
                style: TextStyle(fontSize: 11, letterSpacing: 2, color: AppColors.textMuted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _decisionBtn('Bat', Icons.sports_cricket_rounded, selection.decision == 'Bat', selection)),
                  const SizedBox(width: 16),
                  Expanded(child: _decisionBtn('Bowl', Icons.sports_baseball_rounded, selection.decision == 'Bowl', selection)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Proceed button
        AnimatedOpacity(
          opacity: selection.decision != null ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: selection.decision != null ? AppColors.primaryGradient : null,
              color: selection.decision != null ? null : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selection.decision != null ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
            ),
            child: ElevatedButton.icon(
              onPressed: selection.decision != null ? _proceed : null,
              icon: const Icon(Icons.people_alt_rounded, size: 18),
              label: const Text('Select Openers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(240, 52),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _decisionBtn(String label, IconData icon, bool selected, _TossStateData selection) {
    return GestureDetector(
      onTap: () => _notifier.value = _TossStateData(
        winner: selection.winner,
        decision: label,
        isTossing: selection.isTossing,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 110,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.border.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: selected ? AppColors.primary : AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
