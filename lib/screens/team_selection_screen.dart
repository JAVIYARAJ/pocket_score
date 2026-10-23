import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/match_bloc.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../services/group_repository.dart';
import '../services/guest_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import '../widgets/add_guest_sheet.dart';
import '../widgets/empty_state.dart';
import '../theme/animations.dart';
import '../widgets/setup_flow.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TeamSelectionScreen
//
// Player pool comes from two sources:
//   • Group members (registered players with the app) — loaded from Supabase
//   • Guest players (no app) — excluded from the leaderboard. A group's guests
//     are managed in its Members tab and just listed here; solo matches have
//     no group, so their guests are added (and saved to the user's personal
//     list) right on this screen.
// ─────────────────────────────────────────────────────────────────────────────
class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  // All selectable players (group members + saved and newly added guests)
  List<Player> _pool = [];
  bool _loading = false;
  // Guests stored in the saved list (vs. kept for this match only).
  final Set<String> _savedGuestIds = {};
  late final _guestRepo = GuestRepository(Supabase.instance.client);

  bool get _isGroupMatch =>
      context.read<MatchBloc>().state.settings?.groupId != null;

  // Selection state
  final List<String> _teamAIds = [];
  final List<String> _teamBIds = [];
  String? _captainA;
  String? _captainB;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
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

  Future<void> _loadPlayers() async {
    final ms      = context.read<MatchBloc>().state;
    final groupId = ms.settings?.groupId;

    setState(() => _loading = true);
    final members = groupId == null
        ? Future.value(<Player>[])
        : GroupRepository(Supabase.instance.client)
            .getGroupMembers(groupId)
            .then((list) => list
                .map((m) => Player(
                      id    : m.userId,
                      name  : m.displayName,
                      role  : PlayerRole.allRounder,
                      isGuest: false,
                      userId : m.userId,
                    ))
                .toList())
            .catchError((Object _) => <Player>[]); // can still add guests
    final saved = _guestRepo
        .getSavedGuests(groupId)
        .catchError((Object _) => <Player>[]);

    final results = await Future.wait([members, saved]);
    if (!mounted) return;
    setState(() {
      _savedGuestIds.addAll(results[1].map((g) => g.id));
      _pool = [...results[0], ...results[1]];
      // Coming back to this screen: keep players already picked for this
      // match, including unsaved guests that no list would return.
      final picked = [...?ms.teamA?.players, ...?ms.teamB?.players];
      for (final p in picked) {
        if (!_pool.any((x) => x.id == p.id)) _pool.add(p);
      }
      _loading = false;
    });
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
  Future<void> _onRemoveGuest(Player p) async {
    if (!_savedGuestIds.contains(p.id)) {
      _removeGuest(p.id);
      return;
    }
    final deleteForGood = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RemoveGuestSheet(name: p.name),
    );
    if (deleteForGood == null || !mounted) return;
    _removeGuest(p.id);
    if (!deleteForGood) return;
    try {
      await _guestRepo.deleteSavedGuest(p.id);
      _savedGuestIds.remove(p.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Couldn't delete ${p.name} from saved guests.")));
      }
    }
  }

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
      builder: (_) => AddGuestSheet(onAdd: _addGuest),
    );
  }

  Future<void> _addGuest(String name, PlayerRole role) async {
    final groupId = context.read<MatchBloc>().state.settings?.groupId;
    Player guest;
    try {
      // Returns the existing guest for a known name, so re-adding "Ravi"
      // keeps one Ravi (and one stats identity).
      guest = await _guestRepo.saveGuest(groupId, name, role);
      _savedGuestIds.add(guest.id);
    } catch (_) {
      // Still usable for this match, just not remembered.
      guest = Player(
        id     : DateTime.now().microsecondsSinceEpoch.toString(),
        name   : name,
        role   : role,
        isGuest: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$name added for this match, but couldn't be saved for next time.")));
      }
    }
    if (!mounted || _pool.any((p) => p.id == guest.id)) return;
    setState(() => _pool.add(guest));
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

    return SetupScaffold(
      step: SetupStep.squads,
      title: 'Pick Squads',
      subtitle: const Text('Put each player in A or B, then pick captains'),
      trailing: _isGroupMatch
          ? null
          : TapBounce(
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
      headerBottom: Row(
        children: [
          Expanded(child: _teamBadge(teamAName, TeamColors.a,
              _teamAIds.length, _captainA != null)),
          const SizedBox(width: 10),
          Text('VS',
              style: TextStyle(
                  color: AppColors.accentLight.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(child: _teamBadge(teamBName, TeamColors.b,
              _teamBIds.length, _captainB != null)),
        ],
      ),
      body: _loading
                  ? const SkeletonList(
                      item: ListTileSkeleton(),
                      count: 6,
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                    )
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
                              const SizedBox(height: 2),
                              Text(
                                _isGroupMatch
                                    ? "Add or remove guests in the group's Members tab."
                                    : 'Saved to your list for your next match.',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 8),
                              ...guests.asMap().entries.map(
                                (e) => _playerTile(
                                  e.value,
                                  registered.length + e.key,
                                  teamAName, teamBName,
                                  canRemove: !_isGroupMatch,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // ── Add guest prompt (solo only) ───────────
                            if (_isGroupMatch)
                              _groupGuestsHint()
                            else
                              _addGuestPrompt(),
                            const SizedBox(height: 80),
                          ],
                        )),
      bottomBar: SetupCta(
        label: 'Review Line-ups',
        icon: Icons.fact_check_rounded,
        onTap: _submit,
        hint: Text(_squadHint()),
      ),
    );
  }

  /// What's still needed before the line-ups can be reviewed.
  String _squadHint() {
    if (_teamAIds.length < 2 || _teamBIds.length < 2) {
      return 'Each team needs at least 2 players';
    }
    if (_captainA == null || _captainB == null) {
      return 'Tap the star to pick a captain for each team';
    }
    return '${_teamAIds.length} vs ${_teamBIds.length} — ready to review';
  }

  // ── Empty state (no group + no guests added) ──────────────────────────────
  Widget _buildEmptyState() {
    // A group always has at least its creator, so an empty pool here means
    // the members (and saved guests) failed to load.
    if (_isGroupMatch) {
      return EmptyState(
        art: EmptyArt.offline,
        title: "Couldn't load the group's players",
        message: 'Check your connection and try again.',
        action: TextButton.icon(
          onPressed: _loadPlayers,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    }
    return EmptyState(
      art: EmptyArt.members,
      title: 'No players at the crease',
      message: 'Solo matches use guest players.\n'
          'Add the people playing today — they\'re saved for next time.',
      action: TapBounce(
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

  // Group matches take guests from the group's Members tab.
  Widget _groupGuestsHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.tintedCard(AppColors.info),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Playing with someone who doesn't have the app? Add them as a "
              "guest from the group's Members tab.",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
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
                    '${_roleLabel(p.role)}${p.isGuest ? '  •  GUEST' : ''}',
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
                onTap: () => _onRemoveGuest(p),
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
            _teamToggle('A', isA, TeamColors.a,
                () => _toggle(p.id, true)),
            const SizedBox(width: 4),
            _teamToggle('B', isB, TeamColors.b,
                () => _toggle(p.id, false)),
          ],
        ),
      ),
    );
  }

  Widget _teamBadge(
      String name, Color color, int count, bool hasCaptain) {
    final letter = color == TeamColors.a ? 'A' : 'B';
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(letter,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          if (hasCaptain)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.star_rounded, size: 14, color: AppColors.accentLight),
            ),
        ],
      ),
    );
  }

  // Team letters, not names: names can be long or share an initial
  // ("Team A" / "Team B"). The header badges map A/B to the team names.
  Widget _teamToggle(
      String letter, bool selected, Color color, VoidCallback onTap) {
    return TapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(
              color: selected ? color : AppColors.border, width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : AppColors.textMuted),
        ),
      ),
    );
  }

  static String _roleLabel(PlayerRole r) => switch (r) {
        PlayerRole.batsman      => 'BATTER',
        PlayerRole.bowler       => 'BOWLER',
        PlayerRole.allRounder   => 'ALL-ROUNDER',
        PlayerRole.wicketKeeper => 'KEEPER',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Remove a saved guest — from this match only, or from the saved list.
// Pops `false` for this match only, `true` to delete for good.
// ─────────────────────────────────────────────────────────────────────────────
class _RemoveGuestSheet extends StatelessWidget {
  final String name;
  const _RemoveGuestSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Remove $name?',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Guests are saved so you can reuse them in later matches.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _option(
            context,
            icon: Icons.event_busy_rounded,
            color: AppColors.textSecondary,
            title: 'Only from this match',
            subtitle: 'Stays in the saved list for next time',
            result: false,
          ),
          const SizedBox(height: 10),
          _option(
            context,
            icon: Icons.delete_outline_rounded,
            color: AppColors.danger,
            title: 'Delete from saved guests',
            subtitle: "Won't appear in future matches",
            result: true,
          ),
        ],
      ),
    );
  }

  Widget _option(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required bool result}) {
    return TapBounce(
      onTap: () => Navigator.pop(context, result),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
