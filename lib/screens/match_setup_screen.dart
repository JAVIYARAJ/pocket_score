import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/group_cubit.dart' show GroupBloc;
import '../bloc/match_bloc.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

class MatchSetupScreen extends StatefulWidget {
  /// When set, this group is pre-selected in the group dropdown.
  /// Passed when launching a match directly from a GroupDetailScreen.
  final String? preselectedGroupId;
  final bool isRematch;

  const MatchSetupScreen({
    super.key,
    this.preselectedGroupId,
    this.isRematch = false,
  });

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamAController = TextEditingController();
  final _teamBController = TextEditingController();
  final ValueNotifier<int>    _oversNotifier              = ValueNotifier<int>(5);
  final ValueNotifier<String?> _selectedGroupIdNotifier  = ValueNotifier<String?>(null);
  List<Group> _myGroups = [];

  @override
  void dispose() {
    _oversNotifier.dispose();
    _selectedGroupIdNotifier.dispose();
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final ms = context.read<MatchBloc>().state;
    _teamAController.text = ms.settings?.teamAName ?? 'Team A';
    _teamBController.text = ms.settings?.teamBName ?? 'Team B';
    _oversNotifier.value = ms.settings?.totalOvers ?? 5;

    _myGroups = context.read<GroupBloc>().state.groups;

    // Pre-select the group when launched from GroupDetailScreen or rematch.
    // Use the provided groupId directly — no need to verify it exists in
    // _myGroups, which could be empty if GroupBloc hasn't loaded yet.
    final preselect = widget.preselectedGroupId ?? (widget.isRematch ? ms.settings?.groupId : null);
    if (preselect != null) {
      _selectedGroupIdNotifier.value = preselect;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final matchId = DateTime.now().millisecondsSinceEpoch.toString();
      final settings = MatchSettings(
        teamAName  : _teamAController.text.trim(),
        teamBName  : _teamBController.text.trim(),
        totalOvers : _oversNotifier.value,
        groupId    : _selectedGroupIdNotifier.value,
      );
      // Store match settings in memory only.
      // The database record is created only after the user confirms at the
      // end of the setup flow (OpeningSelectionScreen).
      context.read<MatchBloc>().add(CreateMatch(settings, matchId));
      context.push('/match/teams');
    }
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
        body: Column(
          children: [
            // ── Gradient header ──────────────────────────────────────
            _buildHeader(context),
            // ── Form ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Team A
                      FadeInEntrance(
                        delay: const Duration(milliseconds: 100),
                        offset: const Offset(0, 20),
                        child: _fieldCard(
                          label: 'Team A',
                          icon: Icons.shield_rounded,
                          color: AppColors.info,
                          child: TextFormField(
                            controller: _teamAController,
                            decoration: const InputDecoration(
                              labelText: 'Team Name',
                              prefixIcon: Icon(Icons.shield_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Team B
                      FadeInEntrance(
                        delay: const Duration(milliseconds: 180),
                        offset: const Offset(0, 20),
                        child: _fieldCard(
                          label: 'Team B',
                          icon: Icons.shield_rounded,
                          color: AppColors.accent,
                          child: TextFormField(
                            controller: _teamBController,
                            decoration: const InputDecoration(
                              labelText: 'Team Name',
                              prefixIcon: Icon(Icons.shield_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Overs selector
                      FadeInEntrance(
                        delay: const Duration(milliseconds: 260),
                        offset: const Offset(0, 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppDecorations.card(),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.timer_rounded,
                                        size: 16, color: AppColors.warning),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Match Overs',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ValueListenableBuilder<int>(
                                  valueListenable: _oversNotifier,
                                  builder: (context, overs, _) {
                                    return Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _overBtn(Icons.remove_rounded, () {
                                              if (overs > 1) { _oversNotifier.value--; }
                                            }),
                                            SizedBox(
                                              width: 120,
                                              child: Column(
                                                children: [
                                                  AnimatedCounter(
                                                    value: overs,
                                                    style: const TextStyle(
                                                        fontSize: 48,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            AppColors.primary,
                                                        height: 1),
                                                  ),
                                                  const Text('overs',
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .textMuted,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                ],
                                              ),
                                            ),
                                            _overBtn(Icons.add_rounded,
                                                () => _oversNotifier.value++),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Quick presets
                                        Wrap(
                                          spacing: 8,
                                          children: [5, 10, 15, 20].map((o) {
                                            final sel = overs == o;
                                            return GestureDetector(
                                              onTap: () =>
                                                  _oversNotifier.value = o,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: sel
                                                      ? AppColors.primary
                                                      : AppColors.surfaceLight,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                      color: sel
                                                          ? AppColors.primary
                                                          : AppColors.border),
                                                ),
                                                child: Text(
                                                  '$o ov',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: sel
                                                        ? Colors.white
                                                        : AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    );
                                  }),
                            ],
                          ),
                        ),
                      ),
                      // Group selector (only shown when user has groups)
                      if (_myGroups.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FadeInEntrance(
                          delay: const Duration(milliseconds: 320),
                          offset: const Offset(0, 20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppDecorations.card(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.group_rounded,
                                          size: 16, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Assign to Group',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary)),
                                    const Spacer(),
                                    // "Optional" when free to change; locked badge when from a group
                                    if (widget.preselectedGroupId != null || widget.isRematch)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_rounded,
                                                size: 10,
                                                color: AppColors.primary),
                                            SizedBox(width: 4),
                                            Text('Locked',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary)),
                                          ],
                                        ),
                                      )
                                    else
                                      const Text('Optional',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                GestureDetector(
                                  // Disable tap when group is pre-selected from a GroupDetailScreen or isRematch
                                  onTap: (widget.preselectedGroupId != null || widget.isRematch)
                                      ? null
                                      : _showGroupPicker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: (widget.preselectedGroupId != null || widget.isRematch)
                                          ? AppColors.primary
                                              .withValues(alpha: 0.06)
                                          : AppColors.surfaceLight
                                              .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: (widget.preselectedGroupId != null || widget.isRematch)
                                            ? AppColors.primary
                                                .withValues(alpha: 0.25)
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: ValueListenableBuilder<String?>(
                                        valueListenable:
                                            _selectedGroupIdNotifier,
                                        builder: (context, selectedGroup, _) {
                                          return Row(
                                            children: [
                                              Icon(
                                                selectedGroup == null
                                                    ? Icons.person_outline
                                                    : Icons.group_outlined,
                                                size: 20,
                                                color: selectedGroup == null
                                                    ? AppColors.textMuted
                                                    : AppColors.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _getSelectedGroupName(
                                                      selectedGroup),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        selectedGroup == null
                                                            ? FontWeight.w500
                                                            : FontWeight.w600,
                                                    color: selectedGroup == null
                                                        ? AppColors.textMuted
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              // Chevron when editable, lock when locked
                                              Icon(
                                                (widget.preselectedGroupId != null || widget.isRematch)
                                                    ? Icons.lock_rounded
                                                    : Icons
                                                        .keyboard_arrow_down_rounded,
                                                size: (widget.preselectedGroupId != null || widget.isRematch)
                                                    ? 16
                                                    : 22,
                                                color: (widget.preselectedGroupId != null || widget.isRematch)
                                                    ? AppColors.primary
                                                        .withValues(alpha: 0.5)
                                                    : AppColors.textMuted,
                                              ),
                                            ],
                                          );
                                        }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Submit button
                      FadeInEntrance(
                        delay: const Duration(milliseconds: 400),
                        offset: const Offset(0, 20),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Select Teams',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // AnnotatedRegion
  }

  Widget _buildHeader(BuildContext context) {
    return PremiumHeader(
      category: 'NEW MATCH',
      title: 'Match Setup',
      trailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sports_cricket_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }

  Widget _fieldCard(
      {required String label,
      required IconData icon,
      required Color color,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _overBtn(IconData icon, VoidCallback onTap) {
    return TapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 22, color: AppColors.textSecondary),
      ),
    );
  }

  String _getSelectedGroupName(String? selectedGroupId) {
    if (selectedGroupId == null) return 'No group selected (Solo Match)';
    try {
      return _myGroups.firstWhere((g) => g.id == selectedGroupId).name;
    } catch (_) {
      return 'Unknown Group';
    }
  }

  void _showGroupPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Assign to Group',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      _buildGroupOption(null, 'No group (personal match)'),
                      ..._myGroups.map((g) => _buildGroupOption(g.id, g.name)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupOption(String? id, String name) {
    return ValueListenableBuilder<String?>(
        valueListenable: _selectedGroupIdNotifier,
        builder: (context, selectedGroupId, _) {
          final isSelected = selectedGroupId == id;
          return GestureDetector(
            onTap: () {
              _selectedGroupIdNotifier.value = id;
              Navigator.pop(context);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Icon(
                      id == null ? Icons.person_rounded : Icons.group_rounded,
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 24),
                ],
              ),
            ),
          );
        });
  }
}
