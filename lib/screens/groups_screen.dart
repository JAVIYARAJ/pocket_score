import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/group_cubit.dart';
import '../models/group_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'group_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupsScreen — "My Groups" list with create / join actions
// ─────────────────────────────────────────────────────────────────────────────
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

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
        body: Column(
          children: [
            // ── Gradient header ──────────────────────────────────
            _GroupsHeader(
              onCreate: () => _showCreateSheet(context),
              onJoin: () => _showJoinSheet(context),
            ),

            // ── Groups list ──────────────────────────────────────
            Expanded(
              child: BlocBuilder<GroupCubit, GroupState>(
                builder: (context, state) {
                  if (state is GroupLoading || state is GroupInitial) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    );
                  }
                  if (state is GroupError) {
                    return _ErrorView(
                      message: state.message,
                      onRetry: () =>
                          context.read<GroupCubit>().loadMyGroups(),
                    );
                  }
                  final groups =
                      state is GroupLoaded ? state.myGroups : <Group>[];
                  if (groups.isEmpty) {
                    return _EmptyGroups(
                      onCreate: () => _showCreateSheet(context),
                      onJoin: () => _showJoinSheet(context),
                    );
                  }
                  return ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => FadeInEntrance(
                      key: ValueKey(groups[i].id),
                      delay: Duration(milliseconds: 60 * i),
                      offset: const Offset(0, 20),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupCard(
                          group: groups[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GroupDetailScreen(group: groups[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => BlocProvider.value(
          value: context.read<GroupCubit>(),
          child: const _CreateGroupSheet(),
        ),
      );

  void _showJoinSheet(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => BlocProvider.value(
          value: context.read<GroupCubit>(),
          child: const _JoinGroupSheet(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _GroupsHeader extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _GroupsHeader({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: FadeInEntrance(
        delay: const Duration(milliseconds: 80),
        offset: const Offset(0, -16),
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
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CRICKET CIRCLES',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2.5,
                          color: Colors.white60,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('My Groups',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            // Join
            TapBounce(
              onTap: onJoin,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            // Create
            TapBounce(
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12)
                  ],
                ),
                child:
                    const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                group.name.isNotEmpty
                    ? group.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            // Name + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          size: 13,
                          color: AppColors.textMuted.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text('${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(group.inviteCode,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 1.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyGroups extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _EmptyGroups({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('No Groups Yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            const Text(
              'Create a group and invite your cricket friends, or join one with an invite code.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _EmptyBtn(
                    label: 'Create Group',
                    icon: Icons.add_rounded,
                    primary: true,
                    onTap: onCreate),
                const SizedBox(width: 12),
                _EmptyBtn(
                    label: 'Join Group',
                    icon: Icons.group_add_rounded,
                    primary: false,
                    onTap: onJoin),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _EmptyBtn(
      {required this.label,
      required this.icon,
      required this.primary,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: primary ? AppColors.primaryGradient : null,
          color: primary ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(color: AppColors.border),
          boxShadow: primary
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primary ? Colors.white : AppColors.primary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary ? Colors.white : AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error view
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TapBounce(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Group bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final group =
        await context.read<GroupCubit>().createGroup(_ctrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (group != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "${group.name}" created!  Code: ${group.inviteCode}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create group. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Create Group',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('A 6-character invite code is generated automatically.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Friday Cricket Friends',
                prefixIcon: const Icon(Icons.group_rounded,
                    color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 2),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name cannot be empty' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Create Group',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Join Group bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet();

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final group = await context
        .read<GroupCubit>()
        .joinGroup(_ctrl.text.trim().toUpperCase());
    if (!mounted) return;
    setState(() => _loading = false);
    if (group != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${group.name}"!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid invite code. Please check and try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Join a Group',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Enter the 6-character code from your group admin.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Invite Code',
                hintText: 'e.g. XK7P2M',
                prefixIcon: const Icon(Icons.vpn_key_rounded,
                    color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                counterText: '',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter the invite code';
                if (v.trim().length != 6) return 'Code must be 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Join Group',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
