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
      final w = second.wicketsInHand(fallbackSquadSize: widget.scoreState.battingLineup.length);
      return '${second.battingTeamName} won by $w wicket${w != 1 ? "s" : ""}';
    }

    final isSecondAllOut = second.wicketsInHand(
            fallbackSquadSize: widget.scoreState.battingLineup.length) == 0;
    // Compare against the match length, not the first innings: a side bowled
    // out early doesn't shorten the chase.
    final isSecondOversFinished = widget.totalOvers > 0
        ? second.legalBallsCount >= widget.totalOvers * 6
        : second.legalBallsCount >= first.legalBallsCount;

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
            ),
            Expanded(
              child: ScorecardView(
                state: widget.scoreState,
                isFullScreen: true,
              ),
            ),
            _PdfBar(onTap: _openPdfPreview),
          ],
        ),
      ),
    );
  }
}

/// Pinned at the bottom: always in reach and clearly labelled, unlike a bare
/// icon in the header.
class _PdfBar extends StatelessWidget {
  final VoidCallback onTap;
  const _PdfBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.dangerGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Scorecard PDF',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text('Download or share the full scorecard',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.download_rounded, color: AppColors.danger, size: 18),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
