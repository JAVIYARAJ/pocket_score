import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/match_bloc.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../services/group_repository.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TeamSelectionScreen
//
// Player pool comes from two sources:
//   • Group members (registered players with the app) — loaded from Supabase
//   • Guest players (no app) — added by name inline, excluded from leaderboard
// ─────────────────────────────────────────────────────────────────────────────
class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  // All selectable players (group members + guests added this session)
  List<Player> _pool = [];
  bool _loading = false;

  // Selection state
  final List<String> _teamAIds = [];
  final List<String> _teamBIds = [];
  String? _captainA;
  String? _captainB;

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
    // Pre-fill from existing MatchBloc state (e.g. user navigated back)
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

  Future<void> _loadGroupMembers() async {
    final groupId = context.read<MatchBloc>().state.settings?.groupId;
    if (groupId == null) return; // No group — all players will be guests

    setState(() => _loading = true);
    try {
      final members = await GroupRepository(Supabase.instance.client)
          .getGroupMembers(groupId);
      setState(() {
        _pool = members
            .map((m) => Player(
                  id    : m.userId,
                  name  : m.displayName,
                  role  : PlayerRole.allRounder,
                  isGuest: false,
                  userId : m.userId,
                ))
            .toList();
      });
    } catch (_) {
      // If fetch fails, the user can still add guests
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Team toggle ───────────────────────────────────────────────────────────
  void _toggle(String id, bool forTeamA) {
    setState(() {
      if (forTeamA) {
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

  void _setCaptain(String id, bool inTeamA) {
    setState(() {
      if (inTeamA) { _captainA = id; } else { _captainB = id; }
    });
  }

  // ── Remove guest ──────────────────────────────────────────────────────────
  void _removeGuest(String id) {
    setState(() {
      _pool.removeWhere((p) => p.id == id);
      _teamAIds.remove(id);
      _teamBIds.remove(id);
      if (_captainA == id) _captainA = null;
      if (_captainB == id) _captainB = null;
    });
  }

  // ── Add guest bottom sheet ────────────────────────────────────────────────
  void _showAddGuest() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddGuestSheet(
        onAdd: (name, role) {
          setState(() {
            _pool.add(Player(
              id     : DateTime.now().microsecondsSinceEpoch.toString(),
              name   : name,
              role   : role,
              isGuest: true,
            ));
          });
        },
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  void _submit() {
    if (_teamAIds.length < 2 || _teamBIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each team needs at least 2 players')));
      return;
    }
    if (_captainA == null || _captainB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a captain for each team')));
      return;
    }

    final ms   = context.read<MatchBloc>().state;
    final teamA = Team(
      name     : ms.settings?.teamAName ?? 'Team A',
      players  : _pool.where((p) => _teamAIds.contains(p.id)).toList(),
      captainId: _captainA!,
    );
    final teamB = Team(
      name     : ms.settings?.teamBName ?? 'Team B',
      players  : _pool.where((p) => _teamBIds.contains(p.id)).toList(),
      captainId: _captainB!,
    );

    context.read<MatchBloc>().add(SelectTeams(teamA, teamB));
    context.push('/match/preview', extra: {'teamA': teamA, 'teamB': teamB});
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ms        = context.read<MatchBloc>().state;
    final teamAName = ms.settings?.teamAName ?? 'Team A';
    final teamBName = ms.settings?.teamBName ?? 'Team B';

    // Split pool into registered and guests for section display
    final registered = _pool.where((p) => !p.isGuest).toList();
    final guests     = _pool.where((p) =>  p.isGuest).toList();

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
            // ── Header ──────────────────────────────────────────────────
            PremiumHeader(
              category: 'STEP 2',
              title: 'Select Teams',
              trailing: TapBounce(
                onTap: _showAddGuest,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              bottomChild: Row(
                children: [
                  Expanded(child: _teamBadge(teamAName, AppColors.info,
                      _teamAIds.length, _captainA != null)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('VS',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _teamBadge(teamBName, AppColors.accentLight,
                      _teamBIds.length, _captainB != null)),
                ],
              ),
            ),

            // ── Player list ──────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : (_pool.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          children: [
                            // ── Registered group members ───────────────
                            if (registered.isNotEmpty) ...[
                              _sectionLabel('Group Members',
                                  Icons.verified_rounded, AppColors.primary),
                              const SizedBox(height: 8),
                              ...registered.asMap().entries.map(
                                (e) => _playerTile(
                                  e.value, e.key,
                                  teamAName, teamBName,
                                  canRemove: false,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── Guest players ──────────────────────────
                            if (guests.isNotEmpty) ...[
                              _sectionLabel('Guest Players',
                                  Icons.person_outline_rounded,
                                  AppColors.textMuted),
                              const SizedBox(height: 8),
                              ...guests.asMap().entries.map(
                                (e) => _playerTile(
                                  e.value,
                                  registered.length + e.key,
                                  teamAName, teamBName,
                                  canRemove: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // ── Add guest prompt ───────────────────────
                            _addGuestPrompt(),
                            const SizedBox(height: 80),
                          ],
                        )),
            ),

            // ── Submit button ────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Preview Lineups',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
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
      ),
    );
  }

  // ── Empty state (no group + no guests added) ──────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('No players yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'This match has no group, or the group has no members.\n'
              'Tap + to add guest players.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            TapBounce(
              onTap: _showAddGuest,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12)
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Add Guest Player',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.8)),
      ],
    );
  }

  Widget _addGuestPrompt() {
    return TapBounce(
      onTap: _showAddGuest,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Guest Player',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  // ── Player tile ───────────────────────────────────────────────────────────
  Widget _playerTile(
    Player p, int index,
    String teamAName, String teamBName, {
    required bool canRemove,
  }) {
    final isA       = _teamAIds.contains(p.id);
    final isB       = _teamBIds.contains(p.id);
    final isCaptain = (isA && _captainA == p.id) ||
                      (isB && _captainB == p.id);
    final teamColor = isA
        ? AppColors.info
        : isB
            ? AppColors.accent
            : null;

    return FadeInEntrance(
      delay: Duration(milliseconds: 30 * index),
      offset: const Offset(20, 0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: teamColor != null
              ? teamColor.withValues(alpha: 0.07)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: teamColor != null
                ? teamColor.withValues(alpha: 0.2)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // ── Avatar + captain star ──────────────────────────────────
            Stack(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.isGuest
                        ? AppColors.textMuted.withValues(alpha: 0.1)
                        : (teamColor != null
                            ? teamColor.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.1)),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: p.isGuest
                      ? Icon(Icons.person_outline_rounded,
                          size: 18,
                          color: teamColor ?? AppColors.textMuted)
                      : Text(
                          p.name[0].toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: teamColor ?? AppColors.primary),
                        ),
                ),
                if (isCaptain)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.star_rounded,
                          size: 7, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // ── Name + role / guest badge ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.role.name.toUpperCase()}${p.isGuest ? '  •  GUEST' : ''}',
                    style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // ── Captain button OR Delete guest button (mutually exclusive) ──
            if (isA || isB) ...[
              GestureDetector(
                onTap: () => _setCaptain(p.id, isA),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isCaptain
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCaptain
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 16,
                    color: isCaptain ? AppColors.warning : AppColors.textMuted,
                  ),
                ),
              ),
            ] else if (canRemove) ...[
              GestureDetector(
                onTap: () => _removeGuest(p.id),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.danger),
                ),
              ),
            ],

            // ── Team toggles ───────────────────────────────────────────
            _teamToggle(teamAName, isA, AppColors.info,
                () => _toggle(p.id, true)),
            const SizedBox(width: 4),
            _teamToggle(teamBName, isB, AppColors.accent,
                () => _toggle(p.id, false)),
          ],
        ),
      ),
    );
  }

  Widget _teamBadge(
      String name, Color color, int count, bool hasCaptain) {
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
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Row(
            children: [
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              if (hasCaptain)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.star_rounded,
                      size: 12, color: Colors.amber),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamToggle(
      String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(maxWidth: 72),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? color : AppColors.textMuted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Guest Player bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddGuestSheet extends StatefulWidget {
  final void Function(String name, PlayerRole role) onAdd;
  const _AddGuestSheet({required this.onAdd});

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _ctrl = TextEditingController();
  final ValueNotifier<PlayerRole> _roleNotifier = ValueNotifier<PlayerRole>(PlayerRole.allRounder);
  final ValueNotifier<bool> _multiLineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _hasTextNotifier.value = _ctrl.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _roleNotifier.dispose();
    _multiLineNotifier.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final names = _multiLineNotifier.value
        ? text
            .split(RegExp(r'[,;\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : [text];

    for (final name in names) {
      widget.onAdd(name, _roleNotifier.value);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Add Guest Player',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                  'Guest scores are tracked per match but not shown in the leaderboard.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),

                // Mode Selector Segmented Control (Single vs Bulk)
                ValueListenableBuilder<bool>(
                  valueListenable: _multiLineNotifier,
                  builder: (context, isBulk, _) {
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tabWidth = constraints.maxWidth / 2;
                          return SizedBox(
                            height: 38,
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.fastOutSlowIn,
                                  left: isBulk ? tabWidth : 0,
                                  top: 0,
                                  bottom: 0,
                                  width: tabWidth,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    _modeTab('Single Player', false, isBulk),
                                    _modeTab('Bulk Add (Multiple)', true, isBulk),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    );
                  }
                ),
                const SizedBox(height: 20),

                // Name field
                ValueListenableBuilder<bool>(
                  valueListenable: _multiLineNotifier,
                  builder: (context, isBulk, _) {
                    return TextField(
                      controller: _ctrl,
                      autofocus: true,
                      maxLines: isBulk ? 4 : 1,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: isBulk ? 'Player Names' : 'Player Name',
                        hintText: isBulk
                            ? 'One name per line, or comma-separated'
                            : 'Enter player name',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: isBulk
                            ? null
                            : const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    );
                  }
                ),
                const SizedBox(height: 20),

                // Role selector
                const Text('ROLE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ValueListenableBuilder<PlayerRole>(
                  valueListenable: _roleNotifier,
                  builder: (context, currentRole, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlayerRole.values.map((role) {
                        final selected = currentRole == role;
                        return TapBounce(
                          onTap: () => _roleNotifier.value = role,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border),
                            ),
                            child: Text(
                              _roleLabel(role),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }
                ),
                const SizedBox(height: 24),

                // Add button
                ValueListenableBuilder<bool>(
                  valueListenable: _hasTextNotifier,
                  builder: (context, hasText, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _multiLineNotifier,
                      builder: (context, isBulk, _) {
                        final isEnabled = hasText;
                        return SizedBox(
                          width: double.infinity,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: isEnabled ? AppColors.primaryGradient : null,
                              color: isEnabled ? null : AppColors.border.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isEnabled
                                  ? [
                                      BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4))
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton(
                              onPressed: isEnabled ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                disabledForegroundColor: AppColors.textMuted,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                isBulk ? 'Add Players' : 'Add Player',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isEnabled ? Colors.white : AppColors.textMuted),
                              ),
                            ),
                          ),
                        );
                      }
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, bool value, bool currentValue) {
    final bool active = currentValue == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _multiLineNotifier.value = value,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  String _roleLabel(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:      return 'Batsman';
      case PlayerRole.bowler:       return 'Bowler';
      case PlayerRole.allRounder:   return 'All-Rounder';
      case PlayerRole.wicketKeeper: return 'WK';
    }
  }
}
