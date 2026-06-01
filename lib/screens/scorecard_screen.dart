import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bloc/score_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';
import '../widgets/scorecard_widget.dart';

class ScorecardScreen extends StatelessWidget {
  final ScoreState scoreState;

  const ScorecardScreen({super.key, required this.scoreState});

  static void show(BuildContext context, ScoreState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScorecardScreen(scoreState: state),
      ),
    );
  }

  String? _getWinMessage() {
    final first = scoreState.firstInnings;
    final second = scoreState.secondInnings;
    if (first == null || second == null) return null;

    if (second.totalRuns > first.totalRuns) {
      final w = scoreState.battingLineup.length - 1 - second.totalWickets;
      return '${second.battingTeamName} won by $w wicket${w != 1 ? "s" : ""}';
    }

    final maxWkts = scoreState.battingLineup.length - 1;
    final isSecondAllOut = second.totalWickets >= maxWkts;
    final isSecondOversFinished = second.legalBallsCount >= first.legalBallsCount;

    if (isSecondAllOut || isSecondOversFinished) {
      if (second.totalRuns < first.totalRuns) {
        return '${first.battingTeamName} won by ${first.totalRuns - second.totalRuns} runs';
      } else if (second.totalRuns == first.totalRuns) {
        return "It's a TIE!";
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final winMsg = _getWinMessage();
    Widget? trailingWidget;
    if (winMsg != null) {
      trailingWidget = Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                winMsg,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

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
              category: 'MATCH DETAILS',
              title: 'Scorecard',
              showBackButton: true,
              trailing: trailingWidget,
            ),
            Expanded(
              child: ScorecardView(
                state: scoreState,
                isFullScreen: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
