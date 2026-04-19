import 'package:flutter/material.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import 'toss_screen.dart';

class TeamPreviewScreen extends StatelessWidget {
  final Team teamA;
  final Team teamB;

  const TeamPreviewScreen({
    super.key,
    required this.teamA,
    required this.teamB,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -100,
            child: _blurGlow(AppColors.info.withValues(alpha: 0.15)),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: _blurGlow(AppColors.accent.withValues(alpha: 0.15)),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        _buildTeamCard(teamA, AppColors.info, true),
                        const SizedBox(height: 24),
                        _buildVsDivider(),
                        const SizedBox(height: 24),
                        _buildTeamCard(teamB, AppColors.accent, false),
                        const SizedBox(height: 100), // Space for button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bg.withValues(alpha: 0),
                    AppColors.bg.withValues(alpha: 0.9),
                    AppColors.bg,
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TossScreen()));
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: AppColors.primary,
                  elevation: 8,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Looks Good, Start Match'),
                    SizedBox(width: 12),
                    Icon(Icons.sports_cricket_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurGlow(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('CHALLENGE ACCEPTED', style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                )),
                SizedBox(height: 2),
                Text('Lineup Preview', style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                )),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildVsDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white10])
        ))),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
            color: AppColors.surface,
          ),
          child: const Text('VS', style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AppColors.textMuted,
            letterSpacing: 1,
          )),
        ),
        Expanded(child: Container(height: 1, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white10, Colors.white.withValues(alpha: 0)])
        ))),
      ],
    );
  }

  Widget _buildTeamCard(Team team, Color teamColor, bool isTeamA) {
    return Container(
      decoration: AppDecorations.glassCard(opacity: 0.05).copyWith(
        border: Border.all(color: teamColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shield_rounded, color: teamColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(team.name.toUpperCase(), style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
                const Spacer(),
                Text('${team.players.length} PLAYERS', style: TextStyle(
                  color: teamColor.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
          ),
          ...team.players.map((p) => _buildPlayerRow(p, team.captainId == p.id, teamColor)),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player p, bool isCaptain, Color teamColor) {
    IconData roleIcon;
    switch(p.role) {
      case PlayerRole.batsman: roleIcon = Icons.sports_cricket_rounded; break;
      case PlayerRole.bowler: roleIcon = Icons.adjust_rounded; break;
      case PlayerRole.allRounder: roleIcon = Icons.sports_baseball_rounded; break;
      case PlayerRole.wicketKeeper: roleIcon = Icons.front_hand_rounded; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCaptain ? teamColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(p.name[0].toUpperCase(), style: TextStyle(
                  color: isCaptain ? teamColor : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                )),
              ),
              if (isCaptain)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 2)),
                    child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: TextStyle(
                  fontWeight: isCaptain ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                  color: isCaptain ? Colors.white : AppColors.textPrimary,
                )),
                if (isCaptain)
                  Text('CAPTAIN', style: TextStyle(color: teamColor, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ],
            ),
          ),
          Icon(roleIcon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(p.role.name.toUpperCase(), style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          )),
        ],
      ),
    );
  }
}
