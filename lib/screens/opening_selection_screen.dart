import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';


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

class _OpeningSelectionScreenState extends State<OpeningSelectionScreen> {
  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;

  void _start() {
    if (_strikerId == null || _nonStrikerId == null || _bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select all opening players')));
      return;
    }
    context.read<ScoreBloc>().add(StartInnings(
      battingTeamName: widget.battingTeamName,
      battingLineup: widget.battingPlayers,
      bowlingLineup: widget.bowlingPlayers,
      target: widget.target,
      strikerId: _strikerId!,
      nonStrikerId: _nonStrikerId!,
      bowlerId: _bowlerId!,
    ));
    final matchId = context.read<MatchBloc>().state.matchId;
    if (matchId != null) {
      final ml = context.read<MatchListBloc>().state.matches;
      final ex = ml.where((m) => m.id == matchId).firstOrNull;
      if (ex != null) context.read<MatchListBloc>().add(UpdateMatchInList(ex.copyWith(status: 'in_progress')));
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  String get _bowlingTeamName {
    final ms = context.read<MatchBloc>().state;
    return widget.battingTeamName == ms.teamA?.name ? (ms.teamB?.name ?? '') : (ms.teamA?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final allReady = _strikerId != null && _nonStrikerId != null && _bowlerId != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.target > 0 ? '2nd Innings Openers' : 'Select Openers')),
      body: Column(
        children: [
          // Target banner for 2nd innings
          if (widget.target > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.gradientCard(AppColors.dangerGradient),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flag, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Target: ${widget.target}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Batting
                  _sectionHeader('Opening Batsmen', widget.battingTeamName, AppColors.info),
                  const SizedBox(height: 12),
                  ...widget.battingPlayers.map((p) {
                    final isStriker = _strikerId == p.id;
                    final isNon = _nonStrikerId == p.id;
                    return _playerTile(
                      p, isStriker ? AppColors.success : isNon ? AppColors.info : null,
                      isStriker ? '⚡ Striker' : isNon ? '🏏 Non-Striker' : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _chip('S', isStriker, AppColors.success, () {
                            setState(() { if (_nonStrikerId == p.id) _nonStrikerId = null; _strikerId = p.id; });
                          }),
                          const SizedBox(width: 6),
                          _chip('NS', isNon, AppColors.info, () {
                            setState(() { if (_strikerId == p.id) _strikerId = null; _nonStrikerId = p.id; });
                          }),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Bowling
                  _sectionHeader('Opening Bowler', _bowlingTeamName, AppColors.danger),
                  const SizedBox(height: 12),
                  ...widget.bowlingPlayers.map((p) {
                    final isSel = _bowlerId == p.id;
                    return _playerTile(
                      p, isSel ? AppColors.warning : null,
                      isSel ? '🎯 Bowling' : null,
                      trailing: isSel
                          ? const Icon(Icons.check_circle, color: AppColors.warning, size: 22)
                          : const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted, size: 22),
                      onTap: () => setState(() => _bowlerId = p.id),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Start button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: allReady ? _start : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: allReady ? AppColors.success : AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    allReady ? 'Start Match 🏏' : 'Select all players first',
                    style: TextStyle(fontSize: 16, color: allReady ? Colors.white : AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String sub, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(title.contains('Bat') ? Icons.sports_cricket : Icons.sports_baseball, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _playerTile(Player p, Color? highlight, String? badge, {Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlight != null ? highlight.withValues(alpha: 0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight != null ? highlight.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: (highlight ?? AppColors.surfaceLight).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(p.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: highlight ?? AppColors.textSecondary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (badge != null)
                    Text(badge, style: TextStyle(fontSize: 11, color: highlight ?? AppColors.textMuted, fontWeight: FontWeight.w500))
                  else
                    Text(p.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? color : AppColors.textMuted)),
      ),
    );
  }
}
