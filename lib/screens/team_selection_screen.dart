import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player_bloc.dart';
import '../bloc/match_bloc.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
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
        if (_teamAIds.contains(id)) {
          _teamAIds.remove(id);
          if (_captainA == id) _captainA = null;
        } else {
          _teamAIds.add(id);
          _teamBIds.remove(id);
          if (_captainB == id) _captainB = null;
        }
      } else {
        if (_teamBIds.contains(id)) {
          _teamBIds.remove(id);
          if (_captainB == id) _captainB = null;
        } else {
          _teamBIds.add(id);
          _teamAIds.remove(id);
          if (_captainA == id) _captainA = null;
        }
      }
    });
  }

  void _submit() {
    if (_teamAIds.length < 2 || _teamBIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each team needs at least 2 players')));
      return;
    }
    if (_captainA == null || _captainB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select captains for both teams')));
      return;
    }

    final matchState = context.read<MatchBloc>().state;
    final players    = context.read<PlayerBloc>().state.players;
    final teamA = Team(
      name      : matchState.settings?.teamAName ?? 'Team A',
      players   : players.where((p) => _teamAIds.contains(p.id)).toList(),
      captainId : _captainA!,
    );
    final teamB = Team(
      name      : matchState.settings?.teamBName ?? 'Team B',
      players   : players.where((p) => _teamBIds.contains(p.id)).toList(),
      captainId : _captainB!,
    );

    context.read<MatchBloc>().add(SelectTeams(teamA, teamB));
    Navigator.push(context, MaterialPageRoute(builder: (_) => TeamPreviewScreen(teamA: teamA, teamB: teamB)));
  }

  @override
  Widget build(BuildContext context) {
    final matchState = context.read<MatchBloc>().state;
    final teamAName  = matchState.settings?.teamAName ?? 'Team A';
    final teamBName  = matchState.settings?.teamBName ?? 'Team B';

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
          _buildHeader(context, teamAName, teamBName),

          // ── Player list ──────────────────────────────────────────
          Expanded(
            child: BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, pState) {
                if (pState.players.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('No players yet', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Go back and add players first', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  itemCount: pState.players.length,
                  itemBuilder: (context, index) {
                    final p       = pState.players[index];
                    final isA     = _teamAIds.contains(p.id);
                    final isB     = _teamBIds.contains(p.id);
                    final isCaptain = (isA && _captainA == p.id) || (isB && _captainB == p.id);
                    final teamColor = isA ? AppColors.info : isB ? AppColors.accent : null;

                    return FadeInEntrance(
                      delay: Duration(milliseconds: 30 * index),
                      offset: const Offset(20, 0),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: teamColor != null ? teamColor.withValues(alpha: 0.07) : AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: teamColor != null ? teamColor.withValues(alpha: 0.2) : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar with captain star
                            Stack(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: teamColor != null ? teamColor.withValues(alpha: 0.15) : AppColors.surfaceLight,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    p.name[0].toUpperCase(),
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: teamColor ?? AppColors.textMuted),
                                  ),
                                ),
                                if (isCaptain)
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      width: 14, height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(Icons.star_rounded, size: 8, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Name & role
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                                  Text(p.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                            // Captain tap if already in a team
                            if (isA || isB)
                              GestureDetector(
                                onTap: () {
                                  if (isA) setState(() => _captainA = p.id);
                                  if (isB) setState(() => _captainB = p.id);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isCaptain ? AppColors.warning.withValues(alpha: 0.15) : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isCaptain ? Icons.star_rounded : Icons.star_border_rounded,
                                    size: 16,
                                    color: isCaptain ? AppColors.warning : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            // Team toggle buttons
                            _teamToggle(teamAName, isA, AppColors.info, () => _toggle(p.id, true)),
                            const SizedBox(width: 8),
                            _teamToggle(teamBName, isB, AppColors.accent, () => _toggle(p.id, false)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Submit button ────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Preview Lineups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ), // Scaffold
    );   // AnnotatedRegion
  }

  Widget _buildHeader(BuildContext context, String teamAName, String teamBName) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: FadeInEntrance(
        offset: const Offset(0, -20),
        child: Column(
          children: [
            Row(
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
                      Text('STEP 2', style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white60, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Select Teams', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Team count badges
            Row(
              children: [
                Expanded(child: _teamBadge(teamAName, AppColors.info, _teamAIds.length, _captainA != null)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                ),
                const SizedBox(width: 12),
                Expanded(child: _teamBadge(teamBName, AppColors.accentLight, _teamBIds.length, _captainB != null)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamBadge(String name, Color color, int count, bool hasCaptain) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          Row(
            children: [
              Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              if (hasCaptain) const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.star_rounded, size: 12, color: Colors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamToggle(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label.length > 6 ? '${label.substring(0, 5)}..' : label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? color : AppColors.textMuted),
        ),
      ),
    );
  }
}
