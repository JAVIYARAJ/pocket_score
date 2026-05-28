import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      children: [
                        FadeInEntrance(
                          delay: const Duration(milliseconds: 100),
                          offset: const Offset(0, 20),
                          child: _buildTeamCard(teamA, AppColors.info, true),
                        ),
                        const SizedBox(height: 20),
                        _buildVsDivider(),
                        const SizedBox(height: 20),
                        FadeInEntrance(
                          delay: const Duration(milliseconds: 180),
                          offset: const Offset(0, 20),
                          child: _buildTeamCard(teamB, AppColors.accent, false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Sticky bottom button ────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/match/toss'),
                    icon: const Icon(Icons.sports_cricket_rounded, size: 20),
                    label: const Text('Looks Good — Start Match!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PremiumHeader(
      category: 'STEP 2 OF 4',
      title: 'Lineup Preview',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countBadge(teamA.players.length, AppColors.info),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('vs', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          _countBadge(teamB.players.length, AppColors.accentLight),
        ],
      ),
    );
  }

  Widget _countBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
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
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    team.name[0].toUpperCase(),
                    style: TextStyle(color: teamColor, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
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
                        '${team.players.length} players',
                        style: TextStyle(fontSize: 12, color: teamColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.shield_rounded, color: teamColor, size: 18),
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
