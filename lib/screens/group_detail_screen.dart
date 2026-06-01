import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bloc/auth_cubit.dart' show AuthBloc;
import '../bloc/group_cubit.dart'
    show GroupBloc, LeaveGroupEvent, DeleteGroupEvent, RenameGroupEvent;
import '../bloc/match_bloc.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';
import '../services/group_repository.dart';
import '../bloc/score_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';
import '../widgets/leaderboard_widgets.dart';
import '../widgets/premium_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupDetailScreen — 3-tab view: Matches | Leaderboard | Members
// ─────────────────────────────────────────────────────────────────────────────
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final GroupRepository _repo;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _repo = GroupRepository(Supabase.instance.client);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Leave group ───────────────────────────────────────────────────────────
  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Group',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to leave "${widget.group.name}"? You can rejoin with the invite code.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<GroupBloc>().add(LeaveGroupEvent(widget.group.id));
      if (mounted) context.pop();
    }
  }

  // ── Delete group (admin only) ─────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Group',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'Permanently delete "${widget.group.name}"? All members will be removed. Match history is kept but de-associated from this group.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<GroupBloc>().add(DeleteGroupEvent(widget.group.id));
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authBloc    = context.read<AuthBloc>();
    final currentUser = authBloc.userId ?? '';

    // Use the live group from GroupBloc so the name updates after a rename.
    final stateGroups = context.watch<GroupBloc>().state.groups;
    final liveGroup   = stateGroups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );
    final isAdmin = liveGroup.createdBy == currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: _NewMatchFab(
            onTap: () {
              context.read<MatchBloc>().add(ResetMatch());
              context.read<ScoreBloc>().add(ResetScoreboard());
              context.push('/match/setup', extra: {'groupId': widget.group.id});
            },
          ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Column(
          children: [
            _GroupDetailHeader(
              group: liveGroup,
              isAdmin: isAdmin,
              onLeave: _confirmLeave,
              onDelete: _confirmDelete,
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tab,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(height: 38, text: 'Matches'),
                  Tab(height: 38, text: 'Leaderboard'),
                  Tab(height: 38, text: 'Members'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _MatchesTab(repo: _repo, groupId: widget.group.id),
                  _LeaderboardTab(repo: _repo, groupId: widget.group.id),
                  _MembersTab(
                    repo: _repo,
                    groupId: widget.group.id,
                    isAdmin: isAdmin,
                    currentUserId: currentUser,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — gradient + invite code chip + TabBar
// ─────────────────────────────────────────────────────────────────────────────
class _GroupDetailHeader extends StatelessWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  const _GroupDetailHeader({
    required this.group,
    required this.isAdmin,
    required this.onLeave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumHeader(
      title: group.name,
      bottomRadius: 0,
      subtitleWidget: TapBounce(
        onTap: () {
          Clipboard.setData(ClipboardData(text: group.inviteCode));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invite code "${group.inviteCode}" copied!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('INVITE: ',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: Colors.white60,
                    fontWeight: FontWeight.w800)),
            Text(group.inviteCode,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5)),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR code button
          TapBounce(
            onTap: () => _showQrSheet(context, group),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          // Overflow menu
          TapBounce(
            onTap: () => _showOptionsMenu(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      // Stack lets the TabBar fill the full width while the icons are
      // overlaid at the edges — tab labels are never clipped.
      bottomChild: SizedBox(
        height: 56,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 56.0;
            const topY    = h * 0.15;
            const bottomY = h * 0.95;

            // Mirror the same trapezoid used by RealisticPitchPainter.
            final pitchTopLeft     = w * 0.05;
            final pitchTopRight    = w * 0.95;
            final pitchBottomLeft  = -w * 0.05;
            final pitchBottomRight = w * 1.05;

            double getX(double pct, double y) => y == topY
                ? pitchTopLeft  + (pitchTopRight  - pitchTopLeft)  * pct
                : pitchBottomLeft + (pitchBottomRight - pitchBottomLeft) * pct;

            // Bowling crease percentages MUST match RealisticPitchPainter exactly (0.08 and 0.92).
            const leftPct  = 0.08;
            const rightPct = 0.92;

            // Calculate exact midpoint Y of the perspective pitch
            final midY = (topY + bottomY) / 2;

            // Calculate exact X at the midpoint Y
            final leftCreaseX  = (getX(leftPct,  topY) + getX(leftPct,  bottomY)) / 2;
            final rightCreaseX = (getX(rightPct, topY) + getX(rightPct, bottomY)) / 2;

            // Half-widths of each icon
            const leftIconHalfW  = 9.0;
            const rightIconHalfW = 10.0;

            // To make the base of the shadow sit EXACTLY on the midY line:
            // total height = image height + padding (2px)
            final leftIconTop = midY - 40.0;  // 38px image + 2px padding
            final rightIconTop = midY - 36.0; // 34px image + 2px padding

            // Calculate ball position (rolling away from the knocked wicket)
            final ballX = leftCreaseX + 36.0;
            final ballY = midY + 4.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Cricket pitch background ─────────────────────────────
                Positioned.fill(
                  child: CustomPaint(painter: RealisticPitchPainter()),
                ),

                // ── Cricket Ball ──────────────────────────────────────────
                Positioned(
                  left: ballX - 7,
                  top: ballY - 14,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Small shadow on the pitch
                      Positioned(
                        bottom: -1,
                        child: Container(
                          width: 10, height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.all(Radius.elliptical(5, 1.5)),
                          ),
                        ),
                      ),
                      // The ball
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Image.asset(
                          'assets/icons/ic_cricket_ball_icon.png',
                          height: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Left: knocked/fallen wicket ──────────────────────────
                Positioned(
                  left: leftCreaseX - leftIconHalfW,
                  top: leftIconTop,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 18, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.all(
                                Radius.elliptical(9, 2)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Image.asset(
                          'assets/icons/wicket_out_icon.png',
                          height: 38,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Right: standing wickets (three upright stumps) ────────
                Positioned(
                  left: rightCreaseX - rightIconHalfW,
                  top: rightIconTop,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 20, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.all(
                                Radius.elliptical(10, 2)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Image.asset(
                          'assets/icons/wickets.png',
                          height: 34,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showQrSheet(BuildContext context, Group group) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QrInviteSheet(group: group),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Group Options',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                if (isAdmin) ...[
                  // ── Admin: Rename Group ──────────────────────────────
                  TapBounce(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameSheet(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded,
                                color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rename Group',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('Change the group name',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Admin: Delete Group ──────────────────────────────
                  TapBounce(
                    onTap: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.delete_forever_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Delete Group',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger)),
                                SizedBox(height: 2),
                                Text('Permanently removes the group',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.danger),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Member: Leave Group ──────────────────────────────
                  TapBounce(
                    onTap: () {
                      Navigator.pop(ctx);
                      onLeave();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.exit_to_app_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Leave Group',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger)),
                                SizedBox(height: 2),
                                Text('You can rejoin with the invite code',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.danger),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameSheet(BuildContext context) {
    showModalBottomSheet(
      context       : context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RenameGroupSheet(group: group),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rename Group Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _RenameGroupSheet extends StatefulWidget {
  final Group group;
  const _RenameGroupSheet({required this.group});

  @override
  State<_RenameGroupSheet> createState() => _RenameGroupSheetState();
}

class _RenameGroupSheetState extends State<_RenameGroupSheet> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.group.name);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 100),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Rename Group',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Enter a new name for this group.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Group name',
                prefixIcon: const Icon(Icons.group_rounded,
                    color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _focusNode.unfocus();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _ctrl.text.trim();
                      if (name.isEmpty) return;
                      _focusNode.unfocus();
                      Navigator.pop(context);
                      context
                          .read<GroupBloc>()
                          .add(RenameGroupEvent(widget.group.id, name));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Group renamed to "$name".'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Matches
// Initial load via RPC (get_group_matches).
// Live updates via Supabase Realtime channel — on any change the tab
// re-fetches through the same RPC so there are zero raw table queries.
// ─────────────────────────────────────────────────────────────────────────────
class _MatchesTab extends StatefulWidget {
  final GroupRepository repo;
  final String groupId;
  const _MatchesTab({required this.repo, required this.groupId});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab>
    with AutomaticKeepAliveClientMixin {
  List<MatchSummary> _matches  = [];
  bool              _loading   = true;
  String?           _error;
  RealtimeChannel?  _channel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Initial + refresh fetch via RPC ────────────────────────────────────────
  Future<void> _fetch() async {
    try {
      final matches = await widget.repo.getGroupMatches(widget.groupId);
      if (mounted) {
        setState(() { _matches = matches; _loading = false; _error = null; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  // ── Realtime channel — no raw table queries ────────────────────────────────
  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('grp_matches_${widget.groupId}')
        .onPostgresChanges(
          event : PostgresChangeEvent.all,
          schema: 'public',
          table : 'matches',
          filter: PostgresChangeFilter(
            type  : PostgresChangeFilterType.eq,
            column: 'group_id',
            value : widget.groupId,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      );
    }

    if (_error != null) {
      return _CentreMsg(
          icon : Icons.wifi_off_rounded,
          title: 'Could not load matches',
          sub  : _error!);
    }

    if (_matches.isEmpty) {
      return const _CentreMsg(
        icon : Icons.sports_cricket_rounded,
        title: 'No matches yet',
        sub  : 'Start a match and assign it to this group.',
      );
    }

    return ListView.builder(
      padding    : const EdgeInsets.fromLTRB(16, 20, 16, 40),
      itemCount  : _matches.length,
      itemBuilder: (ctx, i) => FadeInEntrance(
        key  : ValueKey(_matches[i].id),
        delay: Duration(milliseconds: 50 * i),
        offset: const Offset(0, 16),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child  : _GroupMatchCard(match: _matches[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match card for the Matches tab
// ─────────────────────────────────────────────────────────────────────────────
class _GroupMatchCard extends StatelessWidget {
  final MatchSummary match;
  const _GroupMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == 'in_progress';
    final isCompleted = match.status == 'completed';

    return TapBounce(
      onTap: () {
        if (isLive) {
          context.push('/live/${match.id}', extra: {
            'teamAName' : match.teamAName,
            'teamBName' : match.teamBName,
            'totalOvers': match.totalOvers,
          });
        } else if (isCompleted && match.scoreData != null) {
          final state = ScoreState.fromJson(match.scoreData!);
          context.push('/scorecard', extra: state);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLive
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.5),
            width: isLive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isLive
                  ? AppColors.success.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status chip + date
            Row(
              children: [
                _StatusChip(status: match.status),
                const Spacer(),
                Text(
                  _dateLabel(match.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Teams + scores
            Row(
              children: [
                Expanded(
                  child: _TeamScore(
                    name: match.teamAName,
                    score: match.teamAScore,
                    wickets: match.teamAWickets,
                    overs: match.teamAOvers,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('VS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted)),
                ),
                Expanded(
                  child: _TeamScore(
                    name: match.teamBName,
                    score: match.teamBScore,
                    wickets: match.teamBWickets,
                    overs: match.teamBOvers,
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
            if (isCompleted && match.result != null) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              Text(match.result!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'in_progress';
    final isCompleted = status == 'completed';
    final color = isLive
        ? AppColors.success
        : isCompleted
            ? AppColors.textMuted
            : AppColors.warning;
    final label =
        isLive ? '● LIVE' : isCompleted ? 'COMPLETED' : status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

class _TeamScore extends StatelessWidget {
  final String name;
  final int? score;
  final int? wickets;
  final String? overs;
  final CrossAxisAlignment align;

  const _TeamScore({
    required this.name,
    this.score,
    this.wickets,
    this.overs,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(name,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (score != null) ...[
          const SizedBox(height: 2),
          Text(
            '$score/${wickets ?? 0}',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary),
          ),
          if (overs != null)
            Text('($overs ov)',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Leaderboard (embedded, group-filtered)
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardTab extends StatefulWidget {
  final GroupRepository repo;
  final String groupId;
  const _LeaderboardTab({required this.repo, required this.groupId});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  late final Future<List<MatchSummary>> _future;

  @override
  void initState() {
    super.initState();
    // Stored once — prevents a new network call on every rebuild.
    _future = widget.repo.getGroupMatches(widget.groupId);
  }

  @override
  void dispose() {
    _tabNotifier.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<MatchSummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        if (snap.hasError) {
          return _CentreMsg(
              icon: Icons.bar_chart_outlined,
              title: 'Could not load stats',
              sub: snap.error.toString());
        }
        final matches = snap.data ?? const [];
        final statsMap = calculateAllPlayerStats(
          matches,
          const [],
          scopeGroupId: widget.groupId,
        );
            final baseStatsList =
                statsMap.values.where((s) => s.matches > 0).toList();

            return ValueListenableBuilder<int>(
              valueListenable: _tabNotifier,
              builder: (context, tabIndex, child) {
                final statsList = List<PlayerStats>.from(baseStatsList);
                statsList.sort((a, b) {
                  double sA = tabIndex == 0
                      ? (a.battingRankScore ?? -1.0)
                      : tabIndex == 1
                          ? (a.bowlingRankScore ?? -1.0)
                          : (a.impactRankScore ?? -1.0);
                  double sB = tabIndex == 0
                      ? (b.battingRankScore ?? -1.0)
                      : tabIndex == 1
                          ? (b.bowlingRankScore ?? -1.0)
                          : (b.impactRankScore ?? -1.0);
                  return sB.compareTo(sA);
                });

                return Column(
                  children: [
                    // Tab selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
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
                            final tabWidth = constraints.maxWidth / 3;
                            return SizedBox(
                              height: 38,
                              child: Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.fastOutSlowIn,
                                    left: tabIndex * tabWidth,
                                    top: 0,
                                    bottom: 0,
                                    width: tabWidth,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(24),
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
                                      _tabChip('Batters', 0, tabIndex),
                                      _tabChip('Bowlers', 1, tabIndex),
                                      _tabChip('Impact', 2, tabIndex),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }
                        ),
                      ),
                    ),
                    // List
                    Expanded(
                      child: statsList.isEmpty
                          ? const _CentreMsg(
                              icon: Icons.analytics_outlined,
                              title: 'No stats yet',
                              sub: 'Complete matches in this group to see rankings.',
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: _LeaderboardList(
                                key: ValueKey('list_tab_$tabIndex'),
                                statsList: statsList,
                                tabIndex: tabIndex,
                                groupId: widget.groupId,
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
      },
    );
  }

  Widget _tabChip(String label, int i, int currentIndex) {
    final active = currentIndex == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tabNotifier.value = i,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<PlayerStats> statsList;
  final int tabIndex;
  final String groupId;

  const _LeaderboardList({
    required this.statsList,
    required this.tabIndex,
    required this.groupId, required ValueKey<String> key,
  });

  @override
  Widget build(BuildContext context) {
    final validStats = statsList.where((p) {
      final s = tabIndex == 0
          ? p.battingRankScore
          : tabIndex == 1
              ? p.bowlingRankScore
              : p.impactRankScore;
      return s != null;
    }).toList();
    final top3 = validStats.take(3).toList();
    final hasPodium = top3.isNotEmpty;

    return ListView.builder(
      key: ValueKey('grp_list_${tabIndex}_$groupId'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: statsList.length + (hasPodium ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasPodium && index == 0) {
          return LeaderboardTopThreePodium(
            key: ValueKey('grp_podium_${tabIndex}_$groupId'),
            top3,
            tabIndex,
          );
        }
        final itemIndex = hasPodium ? index - 1 : index;
        final p = statsList[itemIndex];
        final score = tabIndex == 0
            ? p.battingRankScore
            : tabIndex == 1
                ? p.bowlingRankScore
                : p.impactRankScore;
        final prevScore = tabIndex == 0
            ? p.previousBattingRankScore
            : tabIndex == 1
                ? p.previousBowlingRankScore
                : p.previousImpactRankScore;

        return FadeInEntrance(
          key: ValueKey('grp_item_${p.id}_$tabIndex'),
          delay: Duration(milliseconds: 60 * (index + 2)),
          offset: const Offset(0, 20),
          child: LeaderboardRankCard(
            key: ValueKey('grp_card_${p.id}'),
            stats: p,
            tabIndex: tabIndex,
            rank: itemIndex + 1,
            score: score,
            prevScore: prevScore,
          ),
        );
      },
    );
  }
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Members Cubit for clean local state
// ─────────────────────────────────────────────────────────────────────────────
abstract class MembersState {}
class MembersLoading extends MembersState {}
class MembersLoaded extends MembersState {
  final List<GroupMember> members;
  MembersLoaded(this.members);
}
class MembersError extends MembersState {
  final String message;
  MembersError(this.message);
}

class MembersCubit extends Cubit<MembersState> {
  final GroupRepository repo;
  final String groupId;

  MembersCubit({required this.repo, required this.groupId}) : super(MembersLoading()) {
    load();
  }

  Future<void> load() async {
    emit(MembersLoading());
    try {
      final members = await repo.getGroupMembers(groupId);
      emit(MembersLoaded(members));
    } catch (e) {
      emit(MembersError(e.toString()));
    }
  }

  Future<void> kickMember(String userId) async {
    try {
      await repo.kickMember(groupId, userId);
      await load(); // Reload members after kick
    } catch (e) {
      rethrow;
    }
  }
}

class _MembersTabState extends State<_MembersTab>
    with AutomaticKeepAliveClientMixin {
  late final MembersCubit _cubit;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cubit = MembersCubit(repo: widget.repo, groupId: widget.groupId);
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
          content: Text('Failed to remove: ${e.toString()}'),
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
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        if (state is MembersError) {
          return _CentreMsg(
              icon: Icons.people_outline_rounded,
              title: 'Could not load members',
              sub: state.message);
        }
        if (state is MembersLoaded) {
          final members = state.members;
          if (members.isEmpty) {
            return const _CentreMsg(
              icon: Icons.people_outline_rounded,
              title: 'No members yet',
              sub: 'Share the invite code to add friends.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            itemCount: members.length,
            itemBuilder: (ctx, i) {
              final m         = members[i];
              // Admins can kick non-admin members that are not themselves.
              final canKick   = widget.isAdmin &&
                  !m.isAdmin &&
                  m.userId != widget.currentUserId;
              return FadeInEntrance(
                key: ValueKey(m.userId),
                delay: Duration(milliseconds: 50 * i),
                offset: const Offset(0, 12),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemberTile(
                    member: m,
                    canKick: canKick,
                    onKick: canKick ? () => _kickMember(m) : null,
                  ),
                ),
              );
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable centered empty/error message
// ─────────────────────────────────────────────────────────────────────────────
class _CentreMsg extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _CentreMsg({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 52, color: AppColors.textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(sub,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Invite Sheet — shows a scannable QR code for the group invite code,
// with options to copy the code or share the QR as an image.
// ─────────────────────────────────────────────────────────────────────────────
class _QrInviteSheet extends StatefulWidget {
  final Group group;
  const _QrInviteSheet({required this.group});

  @override
  State<_QrInviteSheet> createState() => _QrInviteSheetState();
}

class _QrInviteSheetState extends State<_QrInviteSheet> {
  final _qrKey = GlobalKey();
  final ValueNotifier<bool> _sharingNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _sharingNotifier.dispose();
    super.dispose();
  }

  Future<void> _shareQr() async {
    _sharingNotifier.value = true;
    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = Uint8List.view(byteData!.buffer);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes,
                mimeType: 'image/png',
                name: 'invite_${widget.group.inviteCode}.png'),
          ],
          text:
              'Join "${widget.group.name}" on Pocket Score!\nUse code: ${widget.group.inviteCode}',
        ),
      );
    } finally {
      if (mounted) _sharingNotifier.value = false;
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Invite code "${widget.group.inviteCode}" copied!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 100),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Invite via QR',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan to get the invite code for ${widget.group.name}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // QR card — wrapped in RepaintBoundary for screenshot capture
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: widget.group.inviteCode,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF064E3B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF064E3B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.group.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF064E3B),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.group.inviteCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF064E3B),
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pocket Score',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _sharingNotifier,
                    builder: (context, isSharing, child) {
                      return ElevatedButton.icon(
                        onPressed: isSharing ? null : _shareQr,
                        icon: isSharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.share_rounded, size: 16),
                        label: Text(isSharing ? 'Preparing…' : 'Share QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated "New Match" FAB
// Two independent controllers keep entrance and glow from interfering:
//   _entranceCtrl — one-shot slide-up + fade-in
//   _glowCtrl     — endless shadow-opacity pulse
// ─────────────────────────────────────────────────────────────────────────────
class _NewMatchFab extends StatefulWidget {
  final VoidCallback onTap;
  const _NewMatchFab({required this.onTap});

  @override
  State<_NewMatchFab> createState() => _NewMatchFabState();
}

class _NewMatchFabState extends State<_NewMatchFab>
    with TickerProviderStateMixin {
  // Entrance (runs once)
  late final AnimationController _entranceCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double>  _fade;

  // Glow pulse (repeats forever)
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glow;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 2.5), end: Offset.zero)
        .animate(CurvedAnimation(
          parent: _entranceCtrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.22, end: 0.52).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Small delay so the FAB doesn't pop in while the screen is still settling.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceCtrl, _glowCtrl]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _glow.value),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.38),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(32),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_cricket_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'New Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal Pitch Painter — A creative background for the TabBar
// ─────────────────────────────────────────────────────────────────────────────
class RealisticPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle grass surrounding the pitch
    final grassRect = Rect.fromLTWH(0, 0, w, h);
    final grassPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF235326).withValues(alpha: 0.0), // Fade to header green
          const Color(0xFF235326).withValues(alpha: 0.6), // Rich grass
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(grassRect);
    canvas.drawRect(grassRect, grassPaint);

    // 2. The Horizontal Pitch Trapezoid
    final topY = h * 0.15;
    final bottomY = h * 0.95;
    
    // We want the left bowling crease to be exactly at screen x = ~26.
    final pitchTopLeft = w * 0.05;
    final pitchTopRight = w * 0.95;
    final pitchBottomLeft = -w * 0.05;
    final pitchBottomRight = w * 1.05;

    final pitchPath = Path()
      ..moveTo(pitchTopLeft, topY)
      ..lineTo(pitchTopRight, topY)
      ..lineTo(pitchBottomRight, bottomY)
      ..lineTo(pitchBottomLeft, bottomY)
      ..close();

    // Realistic clay/dirt texture
    final pitchPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFB19B74), // deep dirt
          const Color(0xFFDCC39A), // standard dry pitch clay
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    
    // Add subtle shadow for the pitch edges
    canvas.drawShadow(pitchPath, Colors.black.withValues(alpha: 0.3), 3.0, false);
    canvas.drawPath(pitchPath, pitchPaint);

    // 3. Crease Lines with 3D projection
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    double getX(double percent, double y) {
      if (y == topY) {
        return pitchTopLeft + (pitchTopRight - pitchTopLeft) * percent;
      } else {
        return pitchBottomLeft + (pitchBottomRight - pitchBottomLeft) * percent;
      }
    }

    // Positions for creases
    final leftBowlingPct = 0.08;
    final leftPoppingPct = 0.24;
    
    final rightBowlingPct = 0.92;
    final rightPoppingPct = 0.76;

    // Left Bowling
    canvas.drawLine(Offset(getX(leftBowlingPct, topY), topY), Offset(getX(leftBowlingPct, bottomY), bottomY), creasePaint);
    // Left Popping
    canvas.drawLine(Offset(getX(leftPoppingPct, topY), topY), Offset(getX(leftPoppingPct, bottomY), bottomY), creasePaint);

    // Right Bowling
    canvas.drawLine(Offset(getX(rightBowlingPct, topY), topY), Offset(getX(rightBowlingPct, bottomY), bottomY), creasePaint);
    // Right Popping
    canvas.drawLine(Offset(getX(rightPoppingPct, topY), topY), Offset(getX(rightPoppingPct, bottomY), bottomY), creasePaint);
    
    // Return Creases (horizontal lines)
    canvas.drawLine(Offset(getX(0.0, topY), topY), Offset(getX(leftPoppingPct, topY), topY), creasePaint);
    canvas.drawLine(Offset(getX(0.0, bottomY), bottomY), Offset(getX(leftPoppingPct, bottomY), bottomY), creasePaint);

    canvas.drawLine(Offset(getX(rightPoppingPct, topY), topY), Offset(getX(1.0, topY), topY), creasePaint);
    canvas.drawLine(Offset(getX(rightPoppingPct, bottomY), bottomY), Offset(getX(1.0, bottomY), bottomY), creasePaint);

    // Subtle middle pitch line (faded)
    final midPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(getX(0.5, topY), topY), Offset(getX(0.5, bottomY), bottomY), midPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
