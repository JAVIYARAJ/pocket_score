import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/setup_flow.dart';

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
    return SetupScaffold(
      step: SetupStep.lineups,
      title: 'Line-ups',
      subtitle: const Text('Check both sides before setting the rules'),
      headerBottom: _matchupStrip(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          FadeInEntrance(
            delay: const Duration(milliseconds: 80),
            offset: const Offset(0, 20),
            child: _buildTeamCard(teamA, TeamColors.a, true),
          ),
          const SizedBox(height: 18),
          _buildVsDivider(),
          const SizedBox(height: 18),
          FadeInEntrance(
            delay: const Duration(milliseconds: 160),
            offset: const Offset(0, 20),
            child: _buildTeamCard(teamB, TeamColors.b, false),
          ),
        ],
      ),
      bottomBar: SetupCta(
        label: 'Set the Rules',
        icon: Icons.rule_rounded,
        onTap: () => context.push('/match/rules'),
      ),
    );
  }

  // Crest · name · count  vs  count · name · crest
  Widget _matchupStrip() {
    Widget side(Team t, Color c, bool left) {
      final parts = [
        TeamCrest(name: t.name, color: c, size: 34),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              Text('${t.players.length} players',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ];
      return Expanded(
        child: Row(
          mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: left ? parts : parts.reversed.toList(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          side(teamA, TeamColors.a, true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('VS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentLight.withValues(alpha: 0.9))),
          ),
          side(teamB, TeamColors.b, false),
        ],
      ),
    );
  }

  Widget _buildVsDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, AppColors.border]),
        ))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textMuted, letterSpacing: 1)),
        ),
        Expanded(child: Container(height: 1, decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.border, Colors.transparent]),
        ))),
      ],
    );
  }

  Widget _buildTeamCard(Team team, Color teamColor, bool isTeamA) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.card(radius: 22),
      child: Column(
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                TeamCrest(name: team.name, color: teamColor, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${team.players.length} players  ·  Captain ${team.players.where((p) => p.id == team.captainId).firstOrNull?.name ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: teamColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(isTeamA ? 'TEAM A' : 'TEAM B',
                      style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800, color: teamColor)),
                ),
              ],
            ),
          ),
          // Player rows
          ...team.players.asMap().entries.map((e) =>
            _buildPlayerRow(e.value, team.captainId == e.value.id, teamColor, e.key == team.players.length - 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player p, bool isCaptain, Color teamColor, bool isLast) {
    IconData roleIcon;
    String roleLabel;
    switch (p.role) {
      case PlayerRole.batsman:      roleIcon = Icons.sports_cricket_rounded;   roleLabel = 'BAT'; break;
      case PlayerRole.bowler:       roleIcon = Icons.sports_baseball_rounded;  roleLabel = 'BOWL'; break;
      case PlayerRole.allRounder:   roleIcon = Icons.star_rounded;             roleLabel = 'AR'; break;
      case PlayerRole.wicketKeeper: roleIcon = Icons.front_hand_rounded;       roleLabel = 'WK'; break;
    }

    Color roleColor;
    switch (p.role) {
      case PlayerRole.batsman:      roleColor = AppColors.info; break;
      case PlayerRole.bowler:       roleColor = AppColors.danger; break;
      case PlayerRole.allRounder:   roleColor = AppColors.accent; break;
      case PlayerRole.wicketKeeper: roleColor = AppColors.warning; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: AppColors.border),
          bottom: isLast ? BorderSide.none : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: isCaptain ? teamColor.withValues(alpha: 0.15) : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  p.name[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isCaptain ? teamColor : AppColors.textMuted,
                    fontSize: 14,
                  ),
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
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: const Icon(Icons.star_rounded, size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: isCaptain ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isGuest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('GUEST',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                                letterSpacing: 0.3)),
                      ),
                    ],
                  ],
                ),
                if (isCaptain)
                  Text('Captain', style: TextStyle(color: teamColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(roleIcon, size: 11, color: roleColor),
                const SizedBox(width: 4),
                Text(roleLabel, style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
