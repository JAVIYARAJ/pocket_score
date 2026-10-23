import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/group_cubit.dart' show GroupBloc;
import '../bloc/match_bloc.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/setup_flow.dart';

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

  bool get _groupLocked => widget.preselectedGroupId != null || widget.isRematch;

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: SetupStep.match,
      title: widget.isRematch ? 'Rematch' : 'New Match',
      subtitle: const Text('Name the sides and set the overs'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            FadeInEntrance(
              offset: const Offset(0, 20),
              child: _matchupCard(),
            ),
            const SizedBox(height: 16),
            FadeInEntrance(
              delay: const Duration(milliseconds: 80),
              offset: const Offset(0, 20),
              child: _oversCard(),
            ),
            // Group selector (only shown when user has groups)
            if (_myGroups.isNotEmpty) ...[
              const SizedBox(height: 16),
              FadeInEntrance(
                delay: const Duration(milliseconds: 160),
                offset: const Offset(0, 20),
                child: _groupCard(),
              ),
            ],
          ],
        ),
      ),
      bottomBar: SetupCta(
        label: 'Pick Squads',
        icon: Icons.groups_rounded,
        onTap: _submit,
      ),
    );
  }

  // ── The matchup: two crests facing off ─────────────────────────────────────
  Widget _matchupCard() {
    return SetupCard(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
      child: Column(
        children: [
          const Text('THE MATCHUP',
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _teamSide(_teamAController, TeamColors.a, 'TEAM A', _teamBController)),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('VS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
              Expanded(child: _teamSide(_teamBController, TeamColors.b, 'TEAM B', _teamAController)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamSide(TextEditingController ctrl, Color color, String tag,
      TextEditingController other) {
    return Column(
      children: [
        // Crest follows the name as it's typed
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (context, v, _) => TeamCrest(name: v.text, color: color, size: 68),
        ),
        const SizedBox(height: 10),
        Text(tag,
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: 'Team name',
            filled: true,
            fillColor: color.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            suffixIcon: Icon(Icons.edit_rounded, size: 14, color: color.withValues(alpha: 0.6)),
            suffixIconConstraints: const BoxConstraints(minWidth: 26),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            errorMaxLines: 2,
          ),
          validator: (v) {
            final name = v?.trim() ?? '';
            if (name.isEmpty) return 'Required';
            // Teams are told apart by name (toss, innings), so they must differ.
            if (name.toLowerCase() == other.text.trim().toLowerCase()) {
              return 'Use a different name';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── Overs: scoreboard-style counter ────────────────────────────────────────
  Widget _oversCard() {
    return SetupCard(
      child: ValueListenableBuilder<int>(
        valueListenable: _oversNotifier,
        builder: (context, overs, _) {
          return Column(
            children: [
              SetupSectionTitle(
                icon: Icons.timer_rounded,
                color: AppColors.warning,
                title: 'Overs per side',
                caption: '${overs * 6} balls for each team',
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepBtn(Icons.remove_rounded,
                      overs > 1 ? () => _oversNotifier.value-- : null),
                  const SizedBox(width: 18),
                  // LED scoreboard panel
                  Container(
                    width: 116,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1220),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E293B), width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        AnimatedCounter(
                          value: overs,
                          style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentLight,
                            height: 1,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(color: Color(0x99FCD34D), blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('OVERS',
                            style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  _stepBtn(Icons.add_rounded,
                      overs < 50 ? () => _oversNotifier.value++ : null),
                ],
              ),
              const SizedBox(height: 18),
              // Quick presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [5, 6, 8, 10, 15, 20].map((o) {
                  final sel = overs == o;
                  return TapBounce(
                    onTap: () => _oversNotifier.value = o,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text('$o',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : AppColors.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return TapBounce(
      onTap: onTap ?? () {},
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.primary.withValues(alpha: 0.08) : AppColors.borderLight,
          shape: BoxShape.circle,
          border: Border.all(
              color: onTap != null ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border),
        ),
        child: Icon(icon,
            size: 24,
            color: onTap != null ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }

  // ── Group (optional, or locked when started from a group / rematch) ────────
  Widget _groupCard() {
    return SetupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetupSectionTitle(
            icon: Icons.groups_rounded,
            color: AppColors.primary,
            title: 'Play for a group',
            caption: _groupLocked
                ? 'Locked to this group'
                : 'Optional — group members join the squads',
            trailing: _groupLocked
                ? const Icon(Icons.lock_rounded, size: 16, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 14),
          TapBounce(
            onTap: _groupLocked ? () {} : _showGroupPicker,
            child: ValueListenableBuilder<String?>(
              valueListenable: _selectedGroupIdNotifier,
              builder: (context, selectedGroup, _) {
                final hasGroup = selectedGroup != null;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: hasGroup
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasGroup
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasGroup ? Icons.group_rounded : Icons.person_outline_rounded,
                        size: 20,
                        color: hasGroup ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getSelectedGroupName(selectedGroup),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: hasGroup ? FontWeight.w700 : FontWeight.w500,
                            color: hasGroup ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (!_groupLocked)
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 22, color: AppColors.textMuted),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getSelectedGroupName(String? selectedGroupId) {
    if (selectedGroupId == null) return 'No group selected (Solo Match)';
    return _myGroups.where((g) => g.id == selectedGroupId).firstOrNull?.name ?? 'Unknown Group';
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
