import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _teamAController = TextEditingController();
  final _teamBController = TextEditingController();
  int _overs = 5;

  @override
  void initState() {
    super.initState();
    final ms = context.read<MatchBloc>().state;
    _teamAController.text = ms.settings?.teamAName ?? 'Team A';
    _teamBController.text = ms.settings?.teamBName ?? 'Team B';
    _overs = ms.settings?.totalOvers ?? 5;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final matchId = DateTime.now().millisecondsSinceEpoch.toString();
      final settings = MatchSettings(
        teamAName: _teamAController.text.trim(),
        teamBName: _teamBController.text.trim(),
        totalOvers: _overs,
      );
      context.read<MatchBloc>().add(CreateMatch(settings, matchId));
      context.read<MatchListBloc>().add(AddMatchToList(MatchSummary(
        id: matchId,
        teamAName: settings.teamAName,
        teamBName: settings.teamBName,
        totalOvers: settings.totalOvers,
        status: 'setup',
        createdAt: DateTime.now(),
      )));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamSelectionScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              FadeInEntrance(
                offset: const Offset(0, -30),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppDecorations.gradientCard(AppColors.scoreGradient),
                  child: const Column(
                    children: [
                      Icon(Icons.sports_cricket, size: 48, color: Colors.white54),
                      SizedBox(height: 12),
                      Text('Create Match', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Set up your cricket match', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Team A
              FadeInEntrance(
                delay: const Duration(milliseconds: 100),
                offset: const Offset(40, 0), // Slide from right
                child: Column(children: [
                  _sectionLabel('Team A', Icons.groups, AppColors.info),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _teamAController,
                    decoration: const InputDecoration(labelText: 'Team Name', prefixIcon: Icon(Icons.shield_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],)
              ),

              const SizedBox(height: 24),

              // Team B
              FadeInEntrance(
                delay: const Duration(milliseconds: 200),
                offset: const Offset(40, 0), // Slide from right
                child: Column(children: [
                  _sectionLabel('Team B', Icons.groups_outlined, AppColors.accent),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _teamBController,
                    decoration: const InputDecoration(labelText: 'Team Name', prefixIcon: Icon(Icons.shield_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],)
              ),

              const SizedBox(height: 28),

              // Overs Selector
              FadeInEntrance(
                delay: const Duration(milliseconds: 300),
                offset: const Offset(40, 0), // Slide from right
                child: Column(children: [
                  _sectionLabel('Overs', Icons.timer_outlined, AppColors.warning),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: AppDecorations.glassCard(opacity: 0.06),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _overBtn(Icons.remove, () { if (_overs > 1) setState(() => _overs--); }),
                        const SizedBox(width: 24),
                        Column(
                          children: [
                            AnimatedCounter(
                              value: _overs,
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            const Text('overs', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        _overBtn(Icons.add, () => setState(() => _overs++)),
                      ],
                    ),
                  ),
                ],)
              ),

              const SizedBox(height: 36),

              // Submit
              FadeInEntrance(
                delay: const Duration(milliseconds: 400),
                offset: const Offset(0, 30),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Team Selection', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
