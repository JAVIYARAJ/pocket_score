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
    show GroupBloc, LeaveGroupEvent, DeleteGroupEvent, RenameGroupEvent, groupErrorMessage;
import '../bloc/match_bloc.dart';
import '../bloc/members_cubit.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../services/group_repository.dart';
import '../services/guest_repository.dart';
import '../bloc/score_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import '../widgets/add_guest_sheet.dart';
import '../widgets/empty_state.dart';
import '../theme/animations.dart';
import '../utils/stats_utils.dart';
import '../widgets/leaderboard_widgets.dart';
import '../widgets/premium_header.dart';

part 'group_detail/header.dart';
part 'group_detail/rename_sheet.dart';
part 'group_detail/matches_tab.dart';
part 'group_detail/leaderboard_tab.dart';
part 'group_detail/members_tab.dart';
part 'group_detail/qr_invite_sheet.dart';
part 'group_detail/new_match_fab.dart';

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
