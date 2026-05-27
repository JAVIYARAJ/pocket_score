import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player_bloc.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  PlayerRole _selectedRole = PlayerRole.batsman;

  void _addPlayer() {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    final names = text.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (names.length > 1) {
      context.read<PlayerBloc>().add(AddPlayers(names: names, role: _selectedRole));
    } else if (names.isNotEmpty) {
      context.read<PlayerBloc>().add(AddPlayer(name: names.first, role: _selectedRole));
    }

    _nameController.clear();
    _nameFocusNode.requestFocus();
  }

  IconData _roleIcon(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:      return Icons.sports_cricket_rounded;
      case PlayerRole.bowler:       return Icons.sports_baseball_rounded;
      case PlayerRole.allRounder:   return Icons.star_rounded;
      case PlayerRole.wicketKeeper: return Icons.front_hand_rounded;
    }
  }

  Color _roleColor(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:      return AppColors.info;
      case PlayerRole.bowler:       return AppColors.danger;
      case PlayerRole.allRounder:   return AppColors.accent;
      case PlayerRole.wicketKeeper: return AppColors.warning;
    }
  }

  void _confirmClearAll(BuildContext context, List<Player> players) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 14),
            const Text('Clear Squad?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Remove all ${players.length} players? This is permanent.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    for (var p in players) {
                      context.read<PlayerBloc>().add(RemovePlayer(p.id));
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CLEAR ALL', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      body: BlocBuilder<PlayerBloc, PlayerState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              // ── Gradient header ──────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(context, state)),

              // ── Add Player Form ──────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name input
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Player name (comma for multiple)',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.person_add_outlined),
                          suffixIcon: TapBounce(
                            onTap: _addPlayer,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _addPlayer(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SELECT ROLE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 10),
                      // Role chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PlayerRole.values.map((role) {
                            final isSelected = _selectedRole == role;
                            final color = _roleColor(role);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = role),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? color : color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_roleIcon(role), size: 14, color: isSelected ? Colors.white : color),
                                      const SizedBox(width: 6),
                                      Text(
                                        role.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Squad header ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Container(width: 3, height: 14, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      const Text(
                        'SQUAD',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('${state.players.length}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      const Icon(Icons.swipe_left_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      const Text('Swipe to remove', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),

              // ── Player list or empty state ───────────────────────
              if (state.players.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sports_cricket_outlined, size: 52, color: AppColors.primary),
                          ),
                          const SizedBox(height: 20),
                          const Text('No players yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text('Type names above to build your squad', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final reverseList = state.players.reversed.toList();
                        final player      = reverseList[index];
                        final roleCol     = _roleColor(player.role);

                        return Dismissible(
                          key: Key(player.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          ),
                          onDismissed: (_) => context.read<PlayerBloc>().add(RemovePlayer(player.id)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: AppDecorations.card(radius: 14),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 46, height: 46,
                                  decoration: BoxDecoration(
                                    color: roleCol.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: roleCol.withValues(alpha: 0.2)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    player.name[0].toUpperCase(),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: roleCol),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Name & role
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(player.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_roleIcon(player.role), size: 11, color: roleCol),
                                          const SizedBox(width: 4),
                                          Text(
                                            player.role.name.toUpperCase(),
                                            style: TextStyle(fontSize: 10, color: roleCol, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: state.players.length,
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

  Widget _buildHeader(BuildContext context, PlayerState state) {
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
                Text('MANAGE', style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white60, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Squad', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
          ),
          if (state.players.isNotEmpty)
            TapBounce(
              onTap: () => _confirmClearAll(context, state.players),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: const Text('CLEAR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),
        ],
      ),
    );
  }
}
