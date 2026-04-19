import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player_bloc.dart';
import '../bloc/match_bloc.dart';
import '../models/player_model.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'toss_screen.dart';
import 'team_preview_screen.dart';

class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  final List<String> _teamAIds = [];
  final List<String> _teamBIds = [];
  String? _captainA;
  String? _captainB;

  @override
  void initState() {
    super.initState();
    final ms = context.read<MatchBloc>().state;
    if (ms.teamA != null) {
      _teamAIds.addAll(ms.teamA!.players.map((p) => p.id));
      _captainA = ms.teamA!.captainId;
    }
    if (ms.teamB != null) {
      _teamBIds.addAll(ms.teamB!.players.map((p) => p.id));
      _captainB = ms.teamB!.captainId;
    }
  }

  void _toggle(String id, bool forA) {
    setState(() {
      if (forA) {
        if (_teamAIds.contains(id)) { _teamAIds.remove(id); if (_captainA == id) _captainA = null; }
        else { _teamAIds.add(id); _teamBIds.remove(id); if (_captainB == id) _captainB = null; }
      } else {
        if (_teamBIds.contains(id)) { _teamBIds.remove(id); if (_captainB == id) _captainB = null; }
        else { _teamBIds.add(id); _teamAIds.remove(id); if (_captainA == id) _captainA = null; }
      }
    });
  }

  void _submit() {
    if (_teamAIds.length < 2 || _teamBIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Each team needs at least 2 players')));
      return;
    }
    if (_captainA == null || _captainB == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select captains for both teams')));
      return;
    }

    final matchState = context.read<MatchBloc>().state;
    final players = context.read<PlayerBloc>().state.players;
    final teamA = Team(name: matchState.settings?.teamAName ?? 'Team A', players: players.where((p) => _teamAIds.contains(p.id)).toList(), captainId: _captainA!);
    final teamB = Team(name: matchState.settings?.teamBName ?? 'Team B', players: players.where((p) => _teamBIds.contains(p.id)).toList(), captainId: _captainB!);

    context.read<MatchBloc>().add(SelectTeams(teamA, teamB));
    Navigator.push(context, MaterialPageRoute(builder: (_) => TeamPreviewScreen(teamA: teamA, teamB: teamB)));
  }

  @override
  Widget build(BuildContext context) {
    final matchState = context.read<MatchBloc>().state;
    final teamAName = matchState.settings?.teamAName ?? 'Team A';
    final teamBName = matchState.settings?.teamBName ?? 'Team B';

    return Scaffold(
      appBar: AppBar(title: const Text('Select Teams')),
      body: Column(
        children: [
          // Summary header
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.glassCard(opacity: 0.06),
            child: Row(
              children: [
                _teamBadge(teamAName, AppColors.info, _teamAIds.length),
                const Spacer(),
                const Text('vs', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                const Spacer(),
                _teamBadge(teamBName, AppColors.accent, _teamBIds.length),
              ],
            ),
          ),

          // Player list
          Expanded(
            child: BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, pState) {
                if (pState.players.isEmpty) {
                  return const Center(child: Text('No players. Go back and add some!', style: TextStyle(color: AppColors.textMuted)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: pState.players.length,
                  itemBuilder: (context, index) {
                    final p = pState.players[index];
                    final isA = _teamAIds.contains(p.id);
                    final isB = _teamBIds.contains(p.id);
                    final isCaptain = (isA && _captainA == p.id) || (isB && _captainB == p.id);

                    return FadeInEntrance(
                      delay: Duration(milliseconds: 30 * index),
                      offset: const Offset(30, 0), // Slide from right
                      child: SelectionPulse(
                        isSelected: isA || isB,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isA
                                ? AppColors.info.withValues(alpha: 0.08)
                                : isB
                                    ? AppColors.accent.withValues(alpha: 0.08)
                                    : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isA ? AppColors.info.withValues(alpha: 0.2) : isB ? AppColors.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Captain star
                              GestureDetector(
                                onTap: () {
                                  if (isA) setState(() => _captainA = p.id);
                                  if (isB) setState(() => _captainB = p.id);
                                },
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: isCaptain ? AppColors.warning.withValues(alpha: 0.2) : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(isCaptain ? Icons.star : Icons.star_border, size: 18, color: isCaptain ? AppColors.warning : AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(p.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                              // Team buttons
                              _teamToggle(teamAName, isA, AppColors.info, () => _toggle(p.id, true)),
                              const SizedBox(width: 8),
                              _teamToggle(teamBName, isB, AppColors.accent, () => _toggle(p.id, false)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Submit
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Text('Preview Lineups', style: TextStyle(fontSize: 16)), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamBadge(String name, Color color, int count) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(height: 6),
        Text('$count players', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _teamToggle(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label.length > 6 ? '${label.substring(0, 5)}..' : label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? color : AppColors.textMuted),
        ),
      ),
    );
  }
}
