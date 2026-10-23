import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/match_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/setup_flow.dart';

/// Screen between team preview and toss where the user configures optional
/// match rules (max overs per bowler, power play). Shown after team selection
/// so smart defaults can be based on actual player counts.
class MatchRulesScreen extends StatefulWidget {
  const MatchRulesScreen({super.key});

  @override
  State<MatchRulesScreen> createState() => _MatchRulesScreenState();
}

class _MatchRulesScreenState extends State<MatchRulesScreen> {
  late final ValueNotifier<bool> _maxOversEnabledNotifier;
  late final ValueNotifier<int>  _maxOversPerBowlerNotifier;
  late final ValueNotifier<bool> _powerPlayEnabledNotifier;
  late final ValueNotifier<int>  _powerPlayOversNotifier;

  @override
  void initState() {
    super.initState();
    final ms         = context.read<MatchBloc>().state;
    final settings   = ms.settings;
    final totalOvers = settings?.totalOvers ?? 5;

    // Use actual bowling team size (smaller team = worst case for bowlers)
    final teamASize  = ms.teamA?.players.length ?? 5;
    final teamBSize  = ms.teamB?.players.length ?? 5;
    final bowlerCount = [teamASize, teamBSize].reduce((a, b) => a < b ? a : b);

    // Smart default: ceil(totalOvers / bowlerCount)
    final smartMax = ((totalOvers - 1) ~/ bowlerCount + 1).clamp(1, totalOvers);

    final existingMax = settings?.maxOversPerBowler;
    _maxOversEnabledNotifier    = ValueNotifier(existingMax != null);
    _maxOversPerBowlerNotifier  = ValueNotifier(existingMax ?? smartMax);

    final existingPP = settings?.powerPlayOvers;
    _powerPlayEnabledNotifier   = ValueNotifier(existingPP != null && totalOvers > 1);
    _powerPlayOversNotifier     = ValueNotifier(existingPP ?? _defaultPowerPlay(totalOvers));
  }

  @override
  void dispose() {
    _maxOversEnabledNotifier.dispose();
    _maxOversPerBowlerNotifier.dispose();
    _powerPlayEnabledNotifier.dispose();
    _powerPlayOversNotifier.dispose();
    super.dispose();
  }

  // A power play needs at least one non-power-play over, so it only exists for
  // matches of 2+ overs (clamp(1, 0) would throw for a 1-over match).
  int _defaultPowerPlay(int totalOvers) =>
      totalOvers < 2 ? 1 : (totalOvers / 3).ceil().clamp(1, totalOvers - 1);

  void _continue() {
    context.read<MatchBloc>().add(UpdateMatchSettings(
      maxOversPerBowler : _maxOversEnabledNotifier.value
          ? _maxOversPerBowlerNotifier.value
          : null,
      powerPlayOvers    : _powerPlayEnabledNotifier.value
          ? _powerPlayOversNotifier.value
          : null,
    ));
    context.push('/match/toss');
  }

  @override
  Widget build(BuildContext context) {
    final ms         = context.read<MatchBloc>().state;
    final totalOvers = ms.settings?.totalOvers ?? 5;
    final teamASize  = ms.teamA?.players.length ?? 5;
    final teamBSize  = ms.teamB?.players.length ?? 5;
    final bowlerCount = [teamASize, teamBSize].reduce((a, b) => a < b ? a : b);

    return SetupScaffold(
      step: SetupStep.rules,
      title: 'Match Rules',
      subtitle: Text('$totalOvers overs  ·  ${ms.teamA?.name ?? "Team A"} ${teamASize}p vs ${ms.teamB?.name ?? "Team B"} ${teamBSize}p'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // Hint banner
          FadeInEntrance(
            offset: const Offset(0, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Both rules are optional — leave them off for a casual game. '
                      'Turn one on and we\'ll suggest a fair value for $totalOvers overs.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDark, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Max Overs Per Bowler
          FadeInEntrance(
            delay: const Duration(milliseconds: 80),
            offset: const Offset(0, 20),
            child: _RulesCard(
              icon: Icons.sports_baseball_rounded,
              color: AppColors.danger,
              title: 'Max overs per bowler',
              description: 'Stops one bowler from bowling the whole innings.',
              enabledNotifier: _maxOversEnabledNotifier,
              valueNotifier: _maxOversPerBowlerNotifier,
              onSummary: (v) => 'Max $v over${v == 1 ? "" : "s"} each',
              offSummary: 'No limit',
              onToggle: (v) {
                _maxOversEnabledNotifier.value = v;
                if (v) {
                  final smart = ((totalOvers - 1) ~/ bowlerCount + 1).clamp(1, totalOvers);
                  _maxOversPerBowlerNotifier.value = smart;
                }
              },
              pickerChild: ValueListenableBuilder<int>(
                valueListenable: _maxOversPerBowlerNotifier,
                builder: (context, limit, _) {
                  final minRequired = ((totalOvers - 1) ~/ bowlerCount + 1).clamp(1, totalOvers);
                  final isSmartDefault = limit == minRequired;
                  return Column(
                    children: [
                      _NumberPicker(
                        value: limit,
                        min: 1,
                        max: totalOvers,
                        color: AppColors.danger,
                        label: 'OVERS EACH',
                        onDecrement: () { if (limit > 1) _maxOversPerBowlerNotifier.value--; },
                        onIncrement: () { if (limit < totalOvers) _maxOversPerBowlerNotifier.value++; },
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(
                            icon: isSmartDefault ? Icons.auto_awesome_rounded : Icons.edit_rounded,
                            color: isSmartDefault ? AppColors.success : AppColors.warning,
                            text: isSmartDefault
                                ? 'Smart pick for $bowlerCount bowlers'
                                : 'Custom · suggested $minRequired',
                          ),
                          _minBowlersHint(totalOvers, limit),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          if (totalOvers > 1) ...[
            const SizedBox(height: 14),

            // Power Play
            FadeInEntrance(
              delay: const Duration(milliseconds: 160),
              offset: const Offset(0, 20),
              child: _RulesCard(
                icon: Icons.bolt_rounded,
                color: AppColors.info,
                title: 'Power play',
                description: 'Opening overs with fielding restrictions — shown on the scoreboard.',
                enabledNotifier: _powerPlayEnabledNotifier,
                valueNotifier: _powerPlayOversNotifier,
                onSummary: (v) => 'First $v over${v == 1 ? "" : "s"}',
                offSummary: 'Off',
                onToggle: (v) {
                  _powerPlayEnabledNotifier.value = v;
                  if (v) _powerPlayOversNotifier.value = _defaultPowerPlay(totalOvers);
                },
                pickerChild: ValueListenableBuilder<int>(
                  valueListenable: _powerPlayOversNotifier,
                  builder: (context, pp, _) {
                    return _NumberPicker(
                      value: pp,
                      min: 1,
                      max: totalOvers - 1,
                      color: AppColors.info,
                      label: 'POWER PLAY',
                      onDecrement: () { if (pp > 1) _powerPlayOversNotifier.value--; },
                      onIncrement: () { if (pp < totalOvers - 1) _powerPlayOversNotifier.value++; },
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
      bottomBar: SetupCta(
        label: 'Go to the Toss',
        icon: Icons.toll_rounded,
        onTap: _continue,
      ),
    );
  }

  Widget _minBowlersHint(int totalOvers, int limit) {
    final minBowlers = ((totalOvers - 1) ~/ limit + 1);
    final isOk = minBowlers <= 3;
    return _InfoPill(
      icon: isOk ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
      color: isOk ? AppColors.info : AppColors.warning,
      text: 'Needs $minBowlers+ bowler${minBowlers > 1 ? "s" : ""} per side',
    );
  }
}

// ── Reusable rule card ─────────────────────────────────────────────────────────
class _RulesCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   description;
  final ValueNotifier<bool> enabledNotifier;
  final ValueNotifier<int>  valueNotifier;
  final String Function(int value) onSummary;
  final String   offSummary;
  final ValueChanged<bool>  onToggle;
  final Widget   pickerChild;

  const _RulesCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.enabledNotifier,
    required this.valueNotifier,
    required this.onSummary,
    required this.offSummary,
    required this.onToggle,
    required this.pickerChild,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabledNotifier,
      builder: (context, enabled, _) {
        return SetupCard(
          tint: enabled ? color : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggle(!enabled),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: enabled ? color : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 22, color: enabled ? Colors.white : color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(description,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted, height: 1.35)),
                          const SizedBox(height: 8),
                          // Current setting, in words
                          ValueListenableBuilder<int>(
                            valueListenable: valueNotifier,
                            builder: (context, v, _) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: enabled ? color.withValues(alpha: 0.12) : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                enabled ? onSummary(v) : offSummary,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: enabled ? color : AppColors.textMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PillSwitch(value: enabled, color: color),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: enabled
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: pickerChild,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// On/off pill; the whole card header is the tap target.
class _PillSwitch extends StatelessWidget {
  final bool value;
  final Color color;
  const _PillSwitch({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 50,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? color : AppColors.border,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoPill({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Number picker: scoreboard panel between round steppers ─────────────────────
class _NumberPicker extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final Color color;
  final String label;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _NumberPicker({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.label,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _btn(Icons.remove_rounded, value > min ? onDecrement : null),
        const SizedBox(width: 18),
        Container(
          width: 112,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B), width: 3),
          ),
          child: Column(
            children: [
              AnimatedCounter(
                value: value,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentLight,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: [Shadow(color: Color(0x99FCD34D), blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
        ),
        const SizedBox(width: 18),
        _btn(Icons.add_rounded, value < max ? onIncrement : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    final on = onTap != null;
    return TapBounce(
      onTap: onTap ?? () {},
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.08) : AppColors.borderLight,
          shape: BoxShape.circle,
          border: Border.all(color: on ? color.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Icon(icon, size: 22, color: on ? color : AppColors.textMuted),
      ),
    );
  }
}
