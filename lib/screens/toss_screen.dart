import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'opening_selection_screen.dart';
import 'dart:math';

class TossScreen extends StatefulWidget {
  const TossScreen({super.key});

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> with SingleTickerProviderStateMixin {
  String? _winner;
  String? _decision;
  bool _isTossing = false;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _flipCoin() async {
    setState(() => _isTossing = true);
    final ms = context.read<MatchBloc>().state;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final winner = Random().nextBool() ? ms.teamA!.name : ms.teamB!.name;
    setState(() { _winner = winner; _isTossing = false; });
    _animCtrl.forward();
  }

  void _proceed() {
    if (_winner == null || _decision == null) return;
    context.read<MatchBloc>().add(PerformToss(winnerTeamName: _winner!, decision: _decision!));
    final ms    = context.read<MatchBloc>().state;
    final teamA = ms.teamA!;
    final teamB = ms.teamB!;
    final teamABats = (_winner == teamA.name && _decision == 'Bat') ||
                      (_winner != teamA.name && _decision == 'Bowl');
    Navigator.push(context, MaterialPageRoute(builder: (_) => OpeningSelectionScreen(
      battingTeamName  : teamABats ? teamA.name : teamB.name,
      battingPlayers   : teamABats ? teamA.players : teamB.players,
      bowlingPlayers   : teamABats ? teamB.players : teamA.players,
    )));
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
      body: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────
          _buildHeader(context),

          // ── Toss body ────────────────────────────────────────────
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: _winner == null ? _buildCoinSection() : _buildResultSection(),
              ),
            ),
          ),
        ],
      ),
      ), // Scaffold
    );   // AnnotatedRegion
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          TapBounce(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STEP 3', style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white60, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Coin Toss', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        // Animated coin
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isTossing ? 130 : 150,
          height: _isTossing ? 130 : 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: _isTossing ? 0.55 : 0.3),
              blurRadius: _isTossing ? 40 : 20,
              spreadRadius: _isTossing ? 4 : 0,
            )],
          ),
          child: Center(
            child: _isTossing
                ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Icon(Icons.monetization_on_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _isTossing ? 'Flipping...' : 'Ready to flip!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isTossing ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        const Text('May the best team win 🏏', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 32),
        if (!_isTossing)
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

  Widget _buildResultSection() {
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
                Text(_winner!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
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
                  Expanded(child: _decisionBtn('Bat', Icons.sports_cricket_rounded, _decision == 'Bat')),
                  const SizedBox(width: 16),
                  Expanded(child: _decisionBtn('Bowl', Icons.sports_baseball_rounded, _decision == 'Bowl')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Proceed button
        AnimatedOpacity(
          opacity: _decision != null ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: _decision != null ? AppColors.primaryGradient : null,
              color: _decision != null ? null : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _decision != null ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
            ),
            child: ElevatedButton.icon(
              onPressed: _decision != null ? _proceed : null,
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

  Widget _decisionBtn(String label, IconData icon, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _decision = label),
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
