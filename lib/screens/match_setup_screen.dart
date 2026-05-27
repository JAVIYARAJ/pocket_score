import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/group_cubit.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'team_selection_screen.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _teamAController = TextEditingController();
  final _teamBController = TextEditingController();
  int _overs = 5;
  String? _selectedGroupId;
  List<Group> _myGroups = [];

  @override
  void initState() {
    super.initState();
    final ms = context.read<MatchBloc>().state;
    _teamAController.text = ms.settings?.teamAName ?? 'Team A';
    _teamBController.text = ms.settings?.teamBName ?? 'Team B';
    _overs = ms.settings?.totalOvers ?? 5;

    // Pre-populate group list from the already-loaded GroupCubit state.
    final groupState = context.read<GroupCubit>().state;
    if (groupState is GroupLoaded) {
      _myGroups = groupState.myGroups;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final matchId  = DateTime.now().millisecondsSinceEpoch.toString();
      final settings = MatchSettings(
        teamAName  : _teamAController.text.trim(),
        teamBName  : _teamBController.text.trim(),
        totalOvers : _overs,
        groupId    : _selectedGroupId,
      );
      context.read<MatchBloc>().add(CreateMatch(settings, matchId));
      // Register the match ID in ScoreBloc so live scores are published to
      // Supabase from the very first ball onwards.
      context.read<ScoreBloc>().activeMatchId = matchId;
      context.read<MatchListBloc>().add(AddMatchToList(MatchSummary(
        id         : matchId,
        teamAName  : settings.teamAName,
        teamBName  : settings.teamBName,
        totalOvers : settings.totalOvers,
        status     : 'setup',
        createdAt  : DateTime.now(),
        groupId    : _selectedGroupId,
      )));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamSelectionScreen()));
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
                        label  : 'Team A',
                        icon   : Icons.shield_rounded,
                        color  : AppColors.info,
                        child  : TextFormField(
                          controller : _teamAController,
                          decoration : const InputDecoration(
                            labelText  : 'Team Name',
                            prefixIcon : Icon(Icons.shield_outlined),
                          ),
                          validator  : (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Team B
                    FadeInEntrance(
                      delay: const Duration(milliseconds: 180),
                      offset: const Offset(0, 20),
                      child: _fieldCard(
                        label  : 'Team B',
                        icon   : Icons.shield_rounded,
                        color  : AppColors.accent,
                        child  : TextFormField(
                          controller : _teamBController,
                          decoration : const InputDecoration(
                            labelText  : 'Team Name',
                            prefixIcon : Icon(Icons.shield_outlined),
                          ),
                          validator  : (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.timer_rounded, size: 16, color: AppColors.warning),
                                ),
                                const SizedBox(width: 10),
                                const Text('Match Overs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _overBtn(Icons.remove_rounded, () {
                                  if (_overs > 1) setState(() => _overs--);
                                }),
                                SizedBox(
                                  width: 120,
                                  child: Column(
                                    children: [
                                      AnimatedCounter(
                                        value: _overs,
                                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.primary, height: 1),
                                      ),
                                      const Text('overs', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                _overBtn(Icons.add_rounded, () => setState(() => _overs++)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Quick presets
                            Wrap(
                              spacing: 8,
                              children: [5, 10, 15, 20].map((o) {
                                final sel = _overs == o;
                                return GestureDetector(
                                  onTap: () => setState(() => _overs = o),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: sel ? AppColors.primary : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                                    ),
                                    child: Text(
                                      '$o ov',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: sel ? Colors.white : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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
                                      color: AppColors.primary.withValues(alpha: 0.12),
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
                                  const Text('Optional',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.group_outlined,
                                        size: 18,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButton<String?>(
                                        value: _selectedGroupId,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        dropdownColor: AppColors.surface,
                                        hint: const Text(
                                            'No group (personal match)',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textMuted)),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(
                                                'No group (personal match)',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        AppColors.textMuted)),
                                          ),
                                          ..._myGroups.map(
                                            (g) => DropdownMenuItem(
                                              value: g.id,
                                              child: Text(g.name,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors
                                                          .textPrimary)),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) => setState(
                                            () => _selectedGroupId = val),
                                      ),
                                    ),
                                  ],
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
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Select Teams', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
    );   // AnnotatedRegion
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: FadeInEntrance(
        offset: const Offset(0, -20),
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
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEW MATCH', style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white60, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Match Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldCard({required String label, required IconData icon, required Color color, required Widget child}) {
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
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
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
}
