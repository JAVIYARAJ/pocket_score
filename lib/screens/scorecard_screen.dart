import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pdf_preview_screen.dart';
import '../bloc/score_bloc.dart';
import '../theme/app_theme.dart';
import '../utils/match_pdf_generator.dart';
import '../widgets/premium_header.dart';
import '../widgets/scorecard_widget.dart';

class ScorecardScreen extends StatefulWidget {
  final ScoreState scoreState;
  final int totalOvers;

  const ScorecardScreen({
    super.key,
    required this.scoreState,
    this.totalOvers = 0,
  });

  static void show(BuildContext context, ScoreState state, {int totalOvers = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScorecardScreen(scoreState: state, totalOvers: totalOvers),
      ),
    );
  }

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {

  String? _getWinMessage() {
    final first  = widget.scoreState.firstInnings;
    final second = widget.scoreState.secondInnings;
    if (first == null || second == null) return null;

    final soFirst  = widget.scoreState.superOverFirstInnings;
    final soSecond = widget.scoreState.superOverSecondInnings;
    if (soFirst != null && soSecond != null) {
      if (soSecond.totalRuns > soFirst.totalRuns) return '⚡ ${soSecond.battingTeamName} won SO';
      if (soSecond.totalRuns < soFirst.totalRuns) return '⚡ ${soFirst.battingTeamName} won SO';
      return 'Super Over Tied!';
    }

    if (second.totalRuns > first.totalRuns) {
      final w = widget.scoreState.battingLineup.length - 1 - second.totalWickets;
      return '${second.battingTeamName} won by $w wicket${w != 1 ? "s" : ""}';
    }

    final maxWkts = widget.scoreState.battingLineup.length - 1;
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

  void _openPdfPreview() {
    final resultText = _getWinMessage() ?? 'Match Scorecard';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          buildPdf: () => generateMatchResultPdf(
            widget.scoreState, resultText, DateTime.now(), widget.totalOvers),
          filename: 'match_scorecard.pdf',
          title: resultText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final winMsg = _getWinMessage();

    final winChip = winMsg != null
        ? Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    winMsg.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : null;

    final shareBtn = GestureDetector(
      onTap: _openPdfPreview,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
      ),
    );

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
              subtitleWidget: winChip,
              trailing: shareBtn,
            ),
            Expanded(
              child: ScorecardView(
                state: widget.scoreState,
                isFullScreen: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
