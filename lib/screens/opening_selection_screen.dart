import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class OpeningSelectionScreen extends StatefulWidget {
  final String battingTeamName;
  final List<Player> battingPlayers;
  final List<Player> bowlingPlayers;
  final int target;

  const OpeningSelectionScreen({
    super.key,
    required this.battingTeamName,
    required this.battingPlayers,
    required this.bowlingPlayers,
    this.target = 0,
  });

  @override
  State<OpeningSelectionScreen> createState() => _OpeningSelectionScreenState();
}

class _OpeningSelectionScreenState extends State<OpeningSelectionScreen> {
  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;

  void _start() {
    if (_strikerId == null || _nonStrikerId == null || _bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select opener, non-striker and bowler')));
      return;
    }
    context.read<ScoreBloc>().add(StartInnings(
      battingTeamName : widget.battingTeamName,
      battingLineup   : widget.battingPlayers,
      bowlingLineup   : widget.bowlingPlayers,
      target          : widget.target,
      strikerId       : _strikerId!,
      nonStrikerId    : _nonStrikerId!,
      bowlerId        : _bowlerId!,
    ));
    final matchId = context.read<MatchBloc>().state.matchId;
    if (matchId != null) {
      final ml = context.read<MatchListBloc>().state.matches;
      final ex = ml.where((m) => m.id == matchId).firstOrNull;
      if (ex != null) {
        context.read<MatchListBloc>().add(UpdateMatchInList(ex.copyWith(status: 'in_progress')));
      }
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  String get _bowlingTeamName {
    final ms = context.read<MatchBloc>().state;
    return widget.battingTeamName == ms.teamA?.name ? (ms.teamB?.name ?? '') : (ms.teamA?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final allReady = _strikerId != null && _nonStrikerId != null && _bowlerId != null;
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
            // ── Gradient header ────────────────────────────────
            _buildHeader(context),

            // ── Content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target banner for 2nd innings
                    if (widget.target > 0) ...[
                      FadeInEntrance(
                        offset: const Offset(0, 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.dangerGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
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

                    // Opening Batsmen section
                    _sectionHeader('Opening Batsmen', widget.battingTeamName, AppColors.info, Icons.sports_cricket_rounded),
                    const SizedBox(height: 10),
                    ...widget.battingPlayers.asMap().entries.map((e) {
                      final p       = e.value;
                      final isStr   = _strikerId == p.id;
                      final isNon   = _nonStrikerId == p.id;
                      final sel     = isStr ? AppColors.success : isNon ? AppColors.info : null;
                      final badge   = isStr ? '⚡ Striker' : isNon ? '🏏 Non-Striker' : null;
                      return FadeInEntrance(
                        delay: Duration(milliseconds: 40 * e.key),
                        offset: const Offset(20, 0),
                        child: _playerTile(
                          p, sel, badge,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _chip('S', isStr, AppColors.success, () {
                                setState(() { if (_nonStrikerId == p.id) _nonStrikerId = null; _strikerId = p.id; });
                              }),
                              const SizedBox(width: 6),
                              _chip('NS', isNon, AppColors.info, () {
                                setState(() { if (_strikerId == p.id) _strikerId = null; _nonStrikerId = p.id; });
                              }),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Opening Bowler section
                    _sectionHeader('Opening Bowler', _bowlingTeamName, AppColors.danger, Icons.sports_baseball_rounded),
                    const SizedBox(height: 10),
                    ...widget.bowlingPlayers.asMap().entries.map((e) {
                      final p    = e.value;
                      final isSel = _bowlerId == p.id;
                      return FadeInEntrance(
                        delay: Duration(milliseconds: 40 * e.key),
                        offset: const Offset(20, 0),
                        child: _playerTile(
                          p, isSel ? AppColors.warning : null,
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
                          onTap: () => setState(() => _bowlerId = p.id),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Start button ────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: allReady ? AppColors.successGradient : null,
                    color: allReady ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: allReady ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))] : null,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: allReady ? _start : null,
                    icon: Text(allReady ? '🏏' : '⏳', style: const TextStyle(fontSize: 18)),
                    label: Text(
                      allReady ? 'Start ${widget.target > 0 ? "2nd Innings" : "Match"}' : 'Select all players first',
                      style: TextStyle(
                        fontSize: 16,
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
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final is2nd  = widget.target > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
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
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    is2nd ? 'STEP 4 OF 4' : 'STEP 4 OF 4',
                    style: const TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white60, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    is2nd ? '2nd Innings — Select Openers' : 'Select Openers',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                  if (badge != null)
                    Text(badge, style: TextStyle(fontSize: 11, color: highlight ?? AppColors.textMuted, fontWeight: FontWeight.w600))
                  else
                    Text(p.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5)),
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
