part of '../group_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Members
// ─────────────────────────────────────────────────────────────────────────────
class _MembersTab extends StatefulWidget {
  final GroupRepository repo;
  final String groupId;
  final bool isAdmin;
  final String currentUserId;

  const _MembersTab({
    required this.repo,
    required this.groupId,
    required this.isAdmin,
    required this.currentUserId,
  });

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab>
    with AutomaticKeepAliveClientMixin {
  late final MembersCubit _cubit;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cubit = MembersCubit(
      repo: widget.repo,
      guestRepo: GuestRepository(Supabase.instance.client),
      groupId: widget.groupId,
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _kickMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Member',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(
          'Remove "${member.displayName}" from this group? They can rejoin with the invite code.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _cubit.kickMember(member.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${member.displayName}" removed from group.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(groupErrorMessage(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showAddGuest() {
    // The sheet calls onAdd once per name (bulk mode), so collect them and
    // save as one batch after it closes.
    final added = <(String, PlayerRole)>[];
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddGuestSheet(onAdd: (name, role) => added.add((name, role))),
    ).then((_) async {
      if (added.isEmpty) return;
      final failed = await _cubit.addGuests(added);
      if (!mounted) return;
      final saved = added.length - failed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed == 0
            ? (saved == 1
                ? '${added.first.$1} added as a guest.'
                : '$saved guests added.')
            : "Couldn't add $failed of ${added.length} guests. Check your connection and try again."),
        backgroundColor: failed == 0 ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    });
  }

  Future<void> _removeGuest(Player guest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Guest',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(
          'Remove "${guest.name}" from this group\'s guests? Past scorecards keep their name.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _cubit.removeGuest(guest.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(groupErrorMessage(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<MembersCubit, MembersState>(
      bloc: _cubit,
      builder: (context, state) {
        if (state is MembersLoading) {
          return const SkeletonList(item: ListTileSkeleton());
        }
        if (state is MembersError) {
          return _CentreMsg(
              art: EmptyArt.offline,
              title: 'Could not load members',
              sub: state.message);
        }
        if (state is MembersLoaded) {
          final members = state.members;
          final guests  = state.guests;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _cubit.load(quiet: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                _MembersSectionHeader(
                  title: 'Members',
                  count: members.length,
                  icon: Icons.verified_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 10),
                for (final (i, m) in members.indexed)
                  FadeInEntrance(
                    key: ValueKey(m.userId),
                    delay: Duration(milliseconds: 50 * i),
                    offset: const Offset(0, 12),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      // Admins can kick non-admin members that are not themselves.
                      child: Builder(builder: (_) {
                        final canKick = widget.isAdmin &&
                            !m.isAdmin &&
                            m.userId != widget.currentUserId;
                        return _MemberTile(
                          member: m,
                          canKick: canKick,
                          onKick: canKick ? () => _kickMember(m) : null,
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 14),
                _MembersSectionHeader(
                  title: 'Guests',
                  count: guests.length,
                  icon: Icons.person_outline_rounded,
                  color: AppColors.accent,
                  action: _AddGuestButton(onTap: _showAddGuest),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Friends who play with you but don't have the app. "
                  'Everyone in the group can pick them when scoring.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 10),
                if (guests.isEmpty)
                  _NoGuestsCard(onAdd: _showAddGuest)
                else
                  for (final g in guests)
                    Padding(
                      key: ValueKey(g.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GuestTile(
                        guest: g,
                        onRemove: () => _removeGuest(g),
                      ),
                    ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMember member;
  final bool canKick;
  final VoidCallback? onKick;

  const _MemberTile({
    required this.member,
    this.canKick = false,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: () => context.push('/player/${member.userId}',
          extra: {'displayName': member.displayName}),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          // Name + join date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  'Joined ${_joinLabel(member.joinedAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Role badge
          if (member.isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Admin',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Member',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),

          // Kick button — only visible to admins for non-admin members
          if (canKick) ...[
            const SizedBox(width: 12),
            TapBounce(
              onTap: onKick!, // canKick guard ensures onKick != null
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    ),    // Container
    );    // TapBounce
  }

  String _joinLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()}mo ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MembersSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final Widget? action;

  const _MembersSectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _AddGuestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddGuestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 15, color: Colors.white),
            SizedBox(width: 6),
            Text('Add',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _NoGuestsCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoGuestsCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(height: 10),
            const Text('No guests yet',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            const Text('Tap to add players who join your games',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  final Player guest;
  final VoidCallback onRemove;
  const _GuestTile({required this.guest, required this.onRemove});

  static String _roleLabel(PlayerRole role) => switch (role) {
        PlayerRole.batsman      => 'Batsman',
        PlayerRole.bowler       => 'Bowler',
        PlayerRole.allRounder   => 'All-Rounder',
        PlayerRole.wicketKeeper => 'Wicketkeeper',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Outlined avatar sets guests apart from app members
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(_roleLabel(guest.role),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Guest',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
          const SizedBox(width: 12),
          TapBounce(
            onTap: onRemove,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable centered empty/error message
// ─────────────────────────────────────────────────────────────────────────────
class _CentreMsg extends StatelessWidget {
  final EmptyArt art;
  final String title;
  final String sub;

  const _CentreMsg({
    required this.art,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(art: art, title: title, message: sub);
  }
}
