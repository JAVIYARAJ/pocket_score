import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_list_bloc.dart';
import '../bloc/score_bloc.dart';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

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

class _OpeningStateData {
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;

  _OpeningStateData({
    this.strikerId,
    this.nonStrikerId,
    this.bowlerId,
  });
}

class _OpeningSelectionScreenState extends State<OpeningSelectionScreen> {
  late final ValueNotifier<_OpeningStateData> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ValueNotifier<_OpeningStateData>(_OpeningStateData());
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  void _start() {
    final sel = _notifier.value;
    if (sel.strikerId == null || sel.nonStrikerId == null || sel.bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select opener, non-striker and bowler')));
      return;
    }

    if (widget.target == 0) {
      // ── First innings: show confirmation before creating DB record ──────
      final ms           = context.read<MatchBloc>().state;
      final strikerName  = widget.battingPlayers.firstWhere((p) => p.id == sel.strikerId!).name;
      final nonStriker   = widget.battingPlayers.firstWhere((p) => p.id == sel.nonStrikerId!).name;
      final bowlerName   = widget.bowlingPlayers.firstWhere((p) => p.id == sel.bowlerId!).name;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        isDismissible: true,
        builder: (_) => _MatchConfirmSheet(
          matchState    : ms,
          battingTeam   : widget.battingTeamName,
          bowlingTeam   : _bowlingTeamName,
          strikerName   : strikerName,
          nonStrikerName: nonStriker,
          bowlerName    : bowlerName,
          onConfirm     : () => _createAndStart(sel),
        ),
      );
    } else {
      // ── Second innings: match already exists in DB, just start ──────────
      _doStartInnings(sel);
      context.go('/home');
    }
  }

  /// Called after the user confirms in the confirmation sheet (first innings only).
  void _createAndStart(_OpeningStateData sel) {
    final ms      = context.read<MatchBloc>().state;
    final matchId = ms.matchId!;

    // 1. Create the match record in the database for the first time.
    context.read<MatchListBloc>().add(AddMatchToList(MatchSummary(
      id         : matchId,
      teamAName  : ms.settings!.teamAName,
      teamBName  : ms.settings!.teamBName,
      teamA      : ms.teamA,
      teamB      : ms.teamB,
      totalOvers : ms.settings!.totalOvers,
      status     : 'in_progress',
      createdAt  : DateTime.now(),
      groupId    : ms.settings?.groupId,
    )));

    // 2. Register match ID so every ball publishes a live score.
    context.read<ScoreBloc>().activeMatchId = matchId;

    // 3. Start the innings in the ScoreBloc.
    _doStartInnings(sel);

    // 4. Navigate home — the shell overlay shows ScoringScreen automatically.
    context.go('/home');
  }

  void _doStartInnings(_OpeningStateData sel) {
    context.read<ScoreBloc>().add(StartInnings(
      battingTeamName: widget.battingTeamName,
      battingLineup  : widget.battingPlayers,
      bowlingLineup  : widget.bowlingPlayers,
      target         : widget.target,
      strikerId      : sel.strikerId!,
      nonStrikerId   : sel.nonStrikerId!,
      bowlerId       : sel.bowlerId!,
    ));
  }

  String get _bowlingTeamName {
    final ms = context.read<MatchBloc>().state;
    return widget.battingTeamName == ms.teamA?.name
        ? (ms.teamB?.name ?? '')
        : (ms.teamA?.name ?? '');
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
        body: ValueListenableBuilder<_OpeningStateData>(
          valueListenable: _notifier,
          builder: (context, selection, _) {
            final allReady = selection.strikerId != null && selection.nonStrikerId != null && selection.bowlerId != null;
            return Column(
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
                          final isStr   = selection.strikerId == p.id;
                          final isNon   = selection.nonStrikerId == p.id;
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
                                    _notifier.value = _OpeningStateData(
                                      strikerId: p.id,
                                      nonStrikerId: selection.nonStrikerId == p.id ? null : selection.nonStrikerId,
                                      bowlerId: selection.bowlerId,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  _chip('NS', isNon, AppColors.info, () {
                                    _notifier.value = _OpeningStateData(
                                      strikerId: selection.strikerId == p.id ? null : selection.strikerId,
                                      nonStrikerId: p.id,
                                      bowlerId: selection.bowlerId,
                                    );
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
                          final isSel = selection.bowlerId == p.id;
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
                              onTap: () {
                                _notifier.value = _OpeningStateData(
                                  strikerId: selection.strikerId,
                                  nonStrikerId: selection.nonStrikerId,
                                  bowlerId: p.id,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final is2nd  = widget.target > 0;
    return PremiumHeader(
      category: is2nd ? 'STEP 4 OF 4' : 'STEP 4 OF 4',
      title: is2nd ? '2nd Innings — Select Openers' : 'Select Openers',
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
                        child: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.isGuest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('GUEST',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.3)),
                        ),
                      ],
                    ],
                  ),
                  if (badge != null)
                    Text(badge, style: TextStyle(fontSize: 11, color: highlight ?? AppColors.textMuted, fontWeight: FontWeight.w600))
                  else
                    Text(
                      '${p.role.name.toUpperCase()}${p.isGuest ? '  •  GUEST' : ''}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Match confirmation sheet — shown before the first ball of a new match.
// Creates the DB record only after the user taps "Start Match".
// ─────────────────────────────────────────────────────────────────────────────
class _MatchConfirmSheet extends StatelessWidget {
  final MatchState matchState;
  final String battingTeam;
  final String bowlingTeam;
  final String strikerName;
  final String nonStrikerName;
  final String bowlerName;
  final VoidCallback onConfirm;

  const _MatchConfirmSheet({
    required this.matchState,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.strikerName,
    required this.nonStrikerName,
    required this.bowlerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final settings   = matchState.settings;
    final overs      = settings?.totalOvers ?? 0;
    final tossWinner = matchState.tossWinner ?? '';
    final decision   = matchState.tossDecision ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16)],
            ),
            child: const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Ready to start?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Review your match details before the first ball.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // Match summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Teams
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(settings?.teamAName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('vs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted.withValues(alpha: 0.6))),
                    ),
                    Text(settings?.teamBName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                // Overs pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$overs overs',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Toss result
                _Row(icon: Icons.monetization_on_rounded, color: AppColors.accent,
                    label: 'Toss', value: '$tossWinner won · elected to $decision'),
                const SizedBox(height: 10),

                // Batting first
                _Row(icon: Icons.sports_cricket_rounded, color: AppColors.info,
                    label: 'Batting first', value: battingTeam),
                const SizedBox(height: 10),

                // Openers
                _Row(icon: Icons.people_rounded, color: AppColors.success,
                    label: 'Openers', value: '$strikerName (striker) & $nonStrikerName'),
                const SizedBox(height: 10),

                // Opening bowler
                _Row(icon: Icons.sports_baseball_rounded, color: AppColors.danger,
                    label: 'Bowler', value: bowlerName),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Start Match', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Row({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
