import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class SuperOverOpeningScreen extends StatefulWidget {
  final Team battingTeam;
  final Team bowlingTeam;
  final int target;

  const SuperOverOpeningScreen({
    super.key,
    required this.battingTeam,
    required this.bowlingTeam,
    this.target = 0,
  });

  @override
  State<SuperOverOpeningScreen> createState() => _SuperOverOpeningScreenState();
}

class _SOSelectionData {
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;

  _SOSelectionData({this.strikerId, this.nonStrikerId, this.bowlerId});
}

class _SuperOverOpeningScreenState extends State<SuperOverOpeningScreen> {
  late final ValueNotifier<_SOSelectionData> _notifier;

  static const _soHeaderGradient = LinearGradient(
    colors: [Color(0xFF78350F), Color(0xFF92400E), Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<_SOSelectionData>(_SOSelectionData());
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  void _startSuperOver() {
    final sel = _notifier.value;
    if (sel.strikerId == null || sel.nonStrikerId == null || sel.bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select striker, non-striker and bowler')),
      );
      return;
    }

    context.read<ScoreBloc>().add(StartSuperOverInnings(
      battingTeamName: widget.battingTeam.name,
      battingLineup  : widget.battingTeam.players,
      bowlingLineup  : widget.bowlingTeam.players,
      target         : widget.target,
      strikerId      : sel.strikerId!,
      nonStrikerId   : sel.nonStrikerId!,
      bowlerId       : sel.bowlerId!,
    ));

    // Navigate home — the shell overlay shows ScoringScreen automatically.
    context.go('/home');
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
        body: ValueListenableBuilder<_SOSelectionData>(
          valueListenable: _notifier,
          builder: (context, selection, _) {
            final allReady = selection.strikerId != null &&
                selection.nonStrikerId != null &&
                selection.bowlerId != null;
            return Column(
              children: [
                // ── Header ────────────────────────────────────────
                _buildHeader(context),

                // ── Content ───────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Target banner for second SO innings
                        if (widget.target > 0) ...[
                          FadeInEntrance(
                            offset: const Offset(0, 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF92400E), Color(0xFFD97706)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    children: [
                                      const Text('TARGET', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white70, fontWeight: FontWeight.w700)),
                                      Text('${widget.target}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Opening Batsmen
                        _sectionHeader('Opening Batsmen', widget.battingTeam.name, AppColors.info, Icons.sports_cricket_rounded),
                        const SizedBox(height: 10),
                        ...widget.battingTeam.players.asMap().entries.map((e) {
                          final p     = e.value;
                          final isStr = selection.strikerId == p.id;
                          final isNon = selection.nonStrikerId == p.id;
                          final col   = isStr ? AppColors.success : isNon ? AppColors.info : null;
                          final badge = isStr ? '⚡ Striker' : isNon ? '🏏 Non-Striker' : null;
                          return FadeInEntrance(
                            delay: Duration(milliseconds: 40 * e.key),
                            offset: const Offset(20, 0),
                            child: _playerTile(
                              p, col, badge,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _chip('S', isStr, AppColors.success, () {
                                    _notifier.value = _SOSelectionData(
                                      strikerId   : p.id,
                                      nonStrikerId: selection.nonStrikerId == p.id ? null : selection.nonStrikerId,
                                      bowlerId    : selection.bowlerId,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  _chip('NS', isNon, AppColors.info, () {
                                    _notifier.value = _SOSelectionData(
                                      strikerId   : selection.strikerId == p.id ? null : selection.strikerId,
                                      nonStrikerId: p.id,
                                      bowlerId    : selection.bowlerId,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 24),

                        // Opening Bowler
                        _sectionHeader('Opening Bowler', widget.bowlingTeam.name, AppColors.danger, Icons.sports_baseball_rounded),
                        const SizedBox(height: 10),
                        ...widget.bowlingTeam.players.asMap().entries.map((e) {
                          final p    = e.value;
                          final isSel = selection.bowlerId == p.id;
                          return FadeInEntrance(
                            delay: Duration(milliseconds: 40 * e.key),
                            offset: const Offset(20, 0),
                            child: _playerTile(
                              p,
                              isSel ? AppColors.warning : null,
                              isSel ? '🎯 Bowling' : null,
                              trailing: isSel
                                  ? Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), shape: BoxShape.circle),
                                      child: const Icon(Icons.check_circle_rounded, color: AppColors.warning, size: 20),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
                                      child: const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted, size: 20),
                                    ),
                              onTap: () {
                                _notifier.value = _SOSelectionData(
                                  strikerId   : selection.strikerId,
                                  nonStrikerId: selection.nonStrikerId,
                                  bowlerId    : p.id,
                                );
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Start button ──────────────────────────────────
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: allReady ? const LinearGradient(
                          colors: [Color(0xFF92400E), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ) : null,
                        color: allReady ? null : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: allReady
                            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))]
                            : null,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: allReady ? _startSuperOver : null,
                        icon: Text(allReady ? '⚡' : '⏳', style: const TextStyle(fontSize: 18)),
                        label: Text(
                          allReady
                              ? (widget.target > 0 ? 'Start Super Over (Team 2)' : 'Start Super Over (Team 1)')
                              : 'Select all players first',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: allReady ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: _soHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('SUPER OVER', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.target > 0 ? 'Team 2 — Select Openers' : 'Team 1 — Select Openers',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.battingTeam.name} batting · 1 over to win',
            style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String sub, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _playerTile(Player p, Color? highlight, String? badge, {Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlight != null ? highlight.withValues(alpha: 0.07) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight != null ? highlight.withValues(alpha: 0.2) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: (highlight ?? AppColors.surfaceLight).withValues(alpha: highlight != null ? 0.2 : 1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(p.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: highlight ?? AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                      ),
                      if (p.isGuest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                          child: const Text('GUEST', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.3)),
                        ),
                      ],
                    ],
                  ),
                  badge != null
                      ? Text(badge, style: TextStyle(fontSize: 11, color: highlight ?? AppColors.textMuted, fontWeight: FontWeight.w600))
                      : Text('${p.role.name.toUpperCase()}${p.isGuest ? '  •  GUEST' : ''}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? color : AppColors.textMuted)),
      ),
    );
  }
}
