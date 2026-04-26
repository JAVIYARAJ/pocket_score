import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../theme/app_theme.dart';
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
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _flipCoin() async {
    setState(() => _isTossing = true);
    final ms = context.read<MatchBloc>().state;
    await Future.delayed(const Duration(milliseconds: 1200));
    final winner = Random().nextBool() ? ms.teamA!.name : ms.teamB!.name;
    if (!mounted) return;
    setState(() { _winner = winner; _isTossing = false; });
    _animCtrl.forward();
  }

  void _proceed() {
    if (_winner == null || _decision == null) return;
    context.read<MatchBloc>().add(PerformToss(winnerTeamName: _winner!, decision: _decision!));
    final ms = context.read<MatchBloc>().state;
    final teamA = ms.teamA!;
    final teamB = ms.teamB!;
    bool teamABats = (_winner == teamA.name && _decision == 'Bat') || (_winner != teamA.name && _decision == 'Bowl');
    Navigator.push(context, MaterialPageRoute(builder: (_) => OpeningSelectionScreen(
      battingTeamName: teamABats ? teamA.name : teamB.name,
      battingPlayers: teamABats ? teamA.players : teamB.players,
      bowlingPlayers: teamABats ? teamB.players : teamA.players,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coin Toss')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_winner == null) ...[
                // Coin
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isTossing ? 140 : 160,
                  height: _isTossing ? 140 : 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(_isTossing ? 0.6 : 0.3), blurRadius: _isTossing ? 40 : 20, spreadRadius: _isTossing ? 4 : 0),
                    ],
                  ),
                  child: Center(
                    child: _isTossing
                        ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Icon(Icons.monetization_on_outlined, size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
                Text(_isTossing ? 'Flipping...' : 'Tap to flip coin', style: TextStyle(fontSize: 16, color: _isTossing ? AppColors.primary : AppColors.textMuted)),
                const SizedBox(height: 24),
                if (!_isTossing)
                  ElevatedButton(
                    onPressed: _flipCoin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Flip Coin 🪙', style: TextStyle(fontSize: 16)),
                  ),
              ] else ...[
                // Winner reveal
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: AppDecorations.gradientCard(AppColors.successGradient),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events, size: 48, color: Colors.white),
                        const SizedBox(height: 12),
                        const Text('TOSS WON BY', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text(_winner!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Text('Choose to', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _decisionBtn('Bat', Icons.sports_cricket, _decision == 'Bat'),
                    const SizedBox(width: 16),
                    _decisionBtn('Bowl', Icons.sports_baseball, _decision == 'Bowl'),
                  ],
                ),
                const SizedBox(height: 40),
                AnimatedOpacity(
                  opacity: _decision != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: _decision != null ? _proceed : null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('Select Openers', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _decisionBtn(String label, IconData icon, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _decision = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120, height: 100,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : Colors.white.withOpacity(0.08), width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(label.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: selected ? AppColors.primary : AppColors.textSecondary, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
