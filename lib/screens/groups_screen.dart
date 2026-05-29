import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../bloc/group_cubit.dart'
    show
        GroupBloc,
        GroupState,
        GroupInitial,
        GroupLoading,
        GroupCreated,
        GroupJoined,
        GroupError,
        LoadGroups,
        CreateGroupEvent,
        JoinGroupEvent;
import '../models/group_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

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
            PremiumHeader(
              category: 'CRICKET CIRCLES',
              title: 'My Groups',
              showBackButton: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TapBounce(
                    onTap: () => _showJoinSheet(context),
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
                  TapBounce(
                    onTap: () => _showCreateSheet(context),
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
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // ── Groups list ──────────────────────────────────────
            Expanded(
              child: BlocBuilder<GroupBloc, GroupState>(
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
                          context.read<GroupBloc>().add(const LoadGroups()),
                    );
                  }
                  final groups = state.groups;
                  if (groups.isEmpty) {
                    return _EmptyGroups(
                      onCreate: () => _showCreateSheet(context),
                      onJoin: () => _showJoinSheet(context),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => FadeInEntrance(
                      key: ValueKey(groups[i].id),
                      delay: Duration(milliseconds: 60 * i),
                      offset: const Offset(0, 20),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupCard(
                          group: groups[i],
                          onTap: () => context.push(
                            '/groups/${groups[i].id}',
                            extra: groups[i],
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

  void _showCreateSheet(BuildContext context) => showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => BlocProvider.value(
          value: context.read<GroupBloc>(),
          child: const _CreateGroupSheet(),
        ),
      );

  void _showJoinSheet(BuildContext context) => showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => BlocProvider.value(
          value: context.read<GroupBloc>(),
          child: const _JoinGroupSheet(),
        ),
      );
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
                group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
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
                      Text(
                          '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  fontSize: 13, color: AppColors.textMuted, height: 1.5),
              textAlign: TextAlign.center,
              maxLines: 3,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: primary ? AppColors.primaryGradient : null,
          color: primary ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: AppColors.border),
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
            Icon(icon,
                size: 16, color: primary ? Colors.white : AppColors.primary),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
  final _loading = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _ctrl.dispose();
    _loading.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _loading.value = true;
    context.read<GroupBloc>().add(CreateGroupEvent(_ctrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupCreated) {
          final messenger = ScaffoldMessenger.of(context);
          context.pop();
          messenger.showSnackBar(SnackBar(
            content: Text(
                'Group "${state.created.name}" created!  Code: ${state.created.inviteCode}'),
            backgroundColor: AppColors.success,
          ));
        } else if (state is GroupError) {
          _loading.value = false;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to create group. Please try again.'),
            backgroundColor: AppColors.danger,
          ));
        }
      },
      child: Container(
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
              const Text(
                  'A 6-character invite code is generated automatically.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g. Friday Cricket Friends',
                  prefixIcon:
                      const Icon(Icons.group_rounded, color: AppColors.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Name cannot be empty'
                    : null,
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: _loading,
                builder: (context, isLoading, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: isLoading
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Join Group bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Join Group Sheet — two modes: enter code manually or scan QR
// ─────────────────────────────────────────────────────────────────────────────
class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet();

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _ctrl    = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _useQr    = false;  // false = code input, true = QR scanner
  bool _loading  = false;
  bool _scanned  = false;  // guard against multiple QR events

  late final MobileScannerController _qrCtrl;

  @override
  void initState() {
    super.initState();
    _qrCtrl = MobileScannerController(autoStart: false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _qrCtrl.dispose();
    super.dispose();
  }

  // ── Mode toggle ────────────────────────────────────────────────────────────
  void _switchMode(bool useQr) {
    if (_useQr == useQr) return;
    setState(() {
      _useQr   = useQr;
      _scanned = false;
      _loading = false;
    });
    if (useQr) {
      _qrCtrl.start();
    } else {
      _qrCtrl.stop();
    }
  }

  // ── Code submit ────────────────────────────────────────────────────────────
  void _submitCode() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    context.read<GroupBloc>().add(
      JoinGroupEvent(_ctrl.text.trim().toUpperCase()),
    );
  }

  // ── QR detected ────────────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_scanned || _loading) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final code = raw.trim().toUpperCase();
    // Accept a bare 6-char code OR a code embedded in any longer string.
    final match = RegExp(r'[A-Z0-9]{6}').firstMatch(code)?.group(0);
    if (match == null) return;

    _qrCtrl.stop();
    setState(() { _scanned = true; _loading = true; });
    context.read<GroupBloc>().add(JoinGroupEvent(match));
  }

  // ── Shared join button ─────────────────────────────────────────────────────
  Widget _joinButton(String label, VoidCallback? onTap) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupJoined) {
          final messenger = ScaffoldMessenger.of(context);
          context.pop();
          messenger.showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Joined "${state.joined.name}" successfully! 🎉')),
            ]),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        } else if (state is GroupError) {
          if (_useQr) _qrCtrl.start();   // allow re-scan
          setState(() { _loading = false; _scanned = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Invalid code. Check the QR / code and try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 28),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Title
            const Text('Join a Group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // ── Mode selector ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                _modeTab(Icons.vpn_key_rounded, 'Enter Code', !_useQr,
                    () => _switchMode(false)),
                _modeTab(Icons.qr_code_scanner_rounded, 'Scan QR', _useQr,
                    () => _switchMode(true)),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Content: code input OR QR scanner ───────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _useQr ? _buildQrMode() : _buildCodeMode(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab chip ───────────────────────────────────────────────────────────────
  Widget _modeTab(IconData icon, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textMuted,
            )),
          ]),
        ),
      ),
    );
  }

  // ── Code input mode ────────────────────────────────────────────────────────
  Widget _buildCodeMode() {
    return Column(
      key: const ValueKey('code'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter the 6-character invite code from your group admin.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(letterSpacing: 4,
                fontWeight: FontWeight.w800, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Invite Code',
              hintText: 'e.g. XK7P2M',
              prefixIcon: const Icon(Icons.vpn_key_rounded,
                  color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter the invite code';
              if (v.trim().length != 6) return 'Code must be 6 characters';
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        _loading
            ? const Center(child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2))
            : _joinButton('Join Group', _submitCode),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── QR scanner mode ────────────────────────────────────────────────────────
  Widget _buildQrMode() {
    return Column(
      key: const ValueKey('qr'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Point your camera at the group\'s QR code to join instantly.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),

        // Camera view
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 240,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _qrCtrl,
                  onDetect: _onDetect,
                ),
                // Scan-area overlay
                Center(
                  child: Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(children: [
                      _corner(top: 0, left: 0),
                      _corner(top: 0, right: 0, flipH: true),
                      _corner(bottom: 0, left: 0, flipV: true),
                      _corner(bottom: 0, right: 0, flipH: true, flipV: true),
                    ]),
                  ),
                ),
                // Loading overlay once a code is detected
                if (_loading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          const Text('Hold the QR code steady inside the frame.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 4),
      ],
    );
  }

  // Small L-shaped corner markers for the scan-area overlay
  Widget _corner({
    double? top, double? bottom, double? left, double? right,
    bool flipH = false, bool flipV = false,
  }) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Transform.scale(
        scaleX: flipH ? -1 : 1,
        scaleY: flipV ? -1 : 1,
        child: Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.primary, width: 3.5),
              left: BorderSide(color: AppColors.primary, width: 3.5),
            ),
          ),
        ),
      ),
    );
  }
}
