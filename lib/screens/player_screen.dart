import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player_bloc.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';

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

    // Handle multi-add: split by comma, semicolon, or newline
    final names = text.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (names.length > 1) {
      context.read<PlayerBloc>().add(AddPlayers(names: names, role: _selectedRole));
    } else if (names.isNotEmpty) {
      context.read<PlayerBloc>().add(AddPlayer(name: names.first, role: _selectedRole));
    }

    _nameController.clear();
    // Keep focus for fast adding
    _nameFocusNode.requestFocus();
  }

  IconData _roleIcon(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:
        return Icons.sports_cricket;
      case PlayerRole.bowler:
        return Icons.sports_baseball;
      case PlayerRole.allRounder:
        return Icons.star;
      case PlayerRole.wicketKeeper:
        return Icons.shield;
    }
  }

  Color _roleColor(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:
        return AppColors.info;
      case PlayerRole.bowler:
        return AppColors.danger;
      case PlayerRole.allRounder:
        return AppColors.accent;
      case PlayerRole.wicketKeeper:
        return AppColors.warning;
    }
  }

  void _confirmClearAll(BuildContext context, List<Player> players) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger, size: 24),
            ),
            const SizedBox(width: 16),
            const Text('Clear Squad?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove all ${players.length} players? This action is permanent and will empty your squad list.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('CLEAR ALL', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12)),
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
    return Scaffold(
        appBar: AppBar(
          title: const Text('MANAGE SQUAD'),
          actions: [
            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, state) {
                if (state.players.isEmpty) return const SizedBox();
                return TextButton(
                  onPressed: () => _confirmClearAll(context, state.players),
                  child: const Text('CLEAR ALL', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                // ─── Add Player Form ───
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: AppDecorations.glassCard(opacity: 0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Enter name (use comma for multiple)',
                            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                            prefixIcon: const Icon(Icons.person_add_outlined),
                            suffixIcon: IconButton(
                              onPressed: _addPlayer,
                              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                            ),
                          ),
                          onSubmitted: (_) => _addPlayer(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 20),
                        const Text('SELECT ROLE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: PlayerRole.values.map((role) {
                              final isSelected = _selectedRole == role;
                              final color = _roleColor(role);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(role.name.toUpperCase()),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedRole = role);
                                  },
                                  avatar: Icon(_roleIcon(role), size: 14, color: isSelected ? Colors.white : color),
                                  selectedColor: color,
                                  backgroundColor: color.withValues(alpha: 0.1),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : color,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Squad Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        const Text('SQUAD LIST',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.5)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('${state.players.length}', style: const TextStyle(
                              color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        const Text('Swipe to remove', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),

                // ─── Player List or Empty State ───
                if (state.players.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.5,
                            child: Icon(Icons.sports_cricket_outlined, size: 80, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 24),
                          const Text('NO PLAYERS ADDED', style: TextStyle(color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                          const SizedBox(height: 8),
                          const Text('Type names above to build your team', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 100), // Avoid keyboard overlap
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final reverseList = state.players.reversed.toList();
                          final player = reverseList[index];
                          final roleCol = _roleColor(player.role);
                          return Dismissible(
                            key: Key(player.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
                            ),
                            onDismissed: (_) => context.read<PlayerBloc>().add(RemovePlayer(player.id)),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: AppDecorations.glassCard(opacity: 0.04),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [roleCol.withValues(alpha: 0.2), roleCol.withValues(alpha: 0.05)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: roleCol.withValues(alpha: 0.1)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                        player.name[0].toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: roleCol)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(player.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: roleCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_roleIcon(player.role), size: 10, color: roleCol),
                                              const SizedBox(width: 4),
                                              Text(player.role.name.toUpperCase(),
                                                  style: TextStyle(fontSize: 9, color: roleCol, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted, size: 20),
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
        )
    );
  }
}
