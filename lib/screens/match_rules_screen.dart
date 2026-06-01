import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/match_bloc.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

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
    _powerPlayEnabledNotifier   = ValueNotifier(existingPP != null);
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

  int _defaultPowerPlay(int totalOvers) => (totalOvers / 3).ceil().clamp(1, totalOvers - 1);

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
            PremiumHeader(
              category: 'STEP 3 OF 4',
              title: 'Match Rules',
              showBackButton: true,
              subtitleWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_rounded, size: 11, color: Colors.white60),
                  const SizedBox(width: 4),
                  Text(
                    '${ms.teamA?.name ?? "Team A"}: ${teamASize}p  ·  ${ms.teamB?.name ?? "Team B"}: ${teamBSize}p',
                    style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hint banner
                    FadeInEntrance(
                      delay: const Duration(milliseconds: 60),
                      offset: const Offset(0, 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Both rules are optional. Defaults are calculated from your '
                                '$totalOvers overs and $bowlerCount-player bowling team.',
                                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Max Overs Per Bowler
                    FadeInEntrance(
                      delay: const Duration(milliseconds: 120),
                      offset: const Offset(0, 20),
                      child: _RulesCard(
                        icon: Icons.shield_rounded,
                        iconColor: AppColors.info,
                        title: 'Max Overs Per Bowler',
                        enabledNotifier: _maxOversEnabledNotifier,
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
                                  color: AppColors.info,
                                  label: 'overs / bowler',
                                  onDecrement: () { if (limit > 1) _maxOversPerBowlerNotifier.value--; },
                                  onIncrement: () { if (limit < totalOvers) _maxOversPerBowlerNotifier.value++; },
                                ),
                                const SizedBox(height: 8),
                                // Smart default badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSmartDefault
                                            ? AppColors.success.withValues(alpha: 0.1)
                                            : AppColors.warning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSmartDefault
                                              ? AppColors.success.withValues(alpha: 0.3)
                                              : AppColors.warning.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSmartDefault ? Icons.auto_awesome_rounded : Icons.edit_rounded,
                                            size: 11,
                                            color: isSmartDefault ? AppColors.success : AppColors.warning,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isSmartDefault
                                                ? 'Smart default for $bowlerCount bowlers'
                                                : 'Custom · smart default: $minRequired',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isSmartDefault ? AppColors.success : AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _minBowlersHint(totalOvers, limit),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Power Play
                    FadeInEntrance(
                      delay: const Duration(milliseconds: 180),
                      offset: const Offset(0, 20),
                      child: _RulesCard(
                        icon: Icons.security_rounded,
                        iconColor: AppColors.info,
                        title: 'Power Play Overs',
                        enabledNotifier: _powerPlayEnabledNotifier,
                        onToggle: (v) {
                          _powerPlayEnabledNotifier.value = v;
                          if (v) _powerPlayOversNotifier.value = _defaultPowerPlay(totalOvers);
                        },
                        pickerChild: ValueListenableBuilder<int>(
                          valueListenable: _powerPlayOversNotifier,
                          builder: (context, pp, _) {
                            return Column(
                              children: [
                                _NumberPicker(
                                  value: pp,
                                  min: 1,
                                  max: totalOvers - 1,
                                  color: AppColors.info,
                                  label: 'power play overs',
                                  onDecrement: () { if (pp > 1) _powerPlayOversNotifier.value--; },
                                  onIncrement: () { if (pp < totalOvers - 1) _powerPlayOversNotifier.value++; },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'First $pp over${pp > 1 ? "s" : ""} have fielding restrictions',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14, offset: const Offset(0, 5),
                    )],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _continue,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Continue to Toss'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _minBowlersHint(int totalOvers, int limit) {
    final minBowlers = ((totalOvers - 1) ~/ limit + 1);
    final isOk = minBowlers <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isOk
            ? AppColors.info.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk
              ? AppColors.info.withValues(alpha: 0.25)
              : AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 12,
            color: isOk ? AppColors.info : AppColors.warning,
          ),
          const SizedBox(width: 5),
          Text(
            'Needs at least $minBowlers bowler${minBowlers > 1 ? "s" : ""} per team',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOk ? AppColors.info : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable rule card ─────────────────────────────────────────────────────────
class _RulesCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final ValueNotifier<bool> enabledNotifier;
  final ValueChanged<bool>  onToggle;
  final Widget   pickerChild;

  const _RulesCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.enabledNotifier,
    required this.onToggle,
    required this.pickerChild,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabledNotifier,
      builder: (context, enabled, _) {
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
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: onToggle,
                    activeThumbColor: iconColor,
                    activeTrackColor: iconColor.withValues(alpha: 0.4),
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: 16),
                pickerChild,
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Number picker ──────────────────────────────────────────────────────────────
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
        SizedBox(
          width: 120,
          child: Column(
            children: [
              Text('$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: color, height: 1)),
              Text(label,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _btn(Icons.add_rounded, value < max ? onIncrement : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.surfaceLight : AppColors.borderLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 22, color: onTap != null ? AppColors.textSecondary : AppColors.textMuted),
      ),
    );
  }
}
