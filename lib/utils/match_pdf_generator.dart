import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../bloc/score_bloc.dart';
import '../models/innings_model.dart';
import '../utils/stats_utils.dart';

// ── Ultra Premium Color Palette ──────────────────────────────────────────
const _primary = PdfColor.fromInt(0xff064E3B);      // Dark green
const _primaryDark = PdfColor.fromInt(0xff022C22);  // Very dark green
const _accent = PdfColor.fromInt(0xffF59E0B);       // Golden amber
const _accentDark = PdfColor.fromInt(0xffB45309);   // Deep gold
const _bg = PdfColor.fromInt(0xffFAFAFA);           // Off-white background
const _surface = PdfColors.white;                   // White cards
const _textDark = PdfColor.fromInt(0xff111827);     // Dark text
const _textMuted = PdfColor.fromInt(0xff6B7280);    // Muted text
const _border = PdfColor.fromInt(0xffE5E7EB);       // Borders

Future<Uint8List> generateMatchResultPdf(
  ScoreState scoreState,
  String resultText,
  DateTime date,
  int totalOvers,
) async {
  final doc = pw.Document();
  final first = scoreState.firstInnings!;
  final second = scoreState.secondInnings!;
  final soFirst = scoreState.superOverFirstInnings;
  final soSecond = scoreState.superOverSecondInnings;
  final hasSuperOver = soFirst != null && soSecond != null;

  final mom = calculateMoMFromState(scoreState);

  // Take top 3 batsmen
  List<MapEntry<String, BatsmanStats>> _topBats(Innings inn) {
    final list = inn.batsmanStats.entries.toList()
      ..sort((a, b) => b.value.runs.compareTo(a.value.runs));
    return list.take(3).toList();
  }

  // Take top 3 bowlers
  List<MapEntry<String, BowlerStats>> _topBowls(Innings inn) {
    final list = inn.bowlerStatsMap.entries.toList()
      ..sort((a, b) {
        if (b.value.wickets != a.value.wickets) {
          return b.value.wickets.compareTo(a.value.wickets);
        }
        return a.value.economy.compareTo(b.value.economy);
      });
    return list.take(3).toList();
  }

  String _name(Innings inn, String id) {
    try { return inn.battingPlayers.firstWhere((p) => p.id == id).name; } catch (_) {}
    try { return inn.bowlingPlayers.firstWhere((p) => p.id == id).name; } catch (_) { return '—'; }
  }

  // ── Determine winner display ──────────────────────────────────────────────
  String winnerName = '';
  String winnerSub  = '';

  if (hasSuperOver) {
    if (soSecond.totalRuns > soFirst.totalRuns) {
      winnerName = soSecond.battingTeamName;
      winnerSub  = 'WON THE SUPER OVER';
    } else if (soSecond.totalRuns < soFirst.totalRuns) {
      winnerName = soFirst.battingTeamName;
      winnerSub  = 'WON THE SUPER OVER';
    } else {
      winnerName = 'MATCH TIED';
      winnerSub  = 'SUPER OVER TIED!';
    }
  } else if (second.totalRuns > first.totalRuns) {
    final w = scoreState.battingLineup.length - 1 - second.totalWickets;
    winnerName = second.battingTeamName;
    winnerSub  = 'WON BY $w WICKET${w != 1 ? "S" : ""}';
  } else if (second.totalRuns < first.totalRuns) {
    winnerName = first.battingTeamName;
    winnerSub  = 'WON BY ${first.totalRuns - second.totalRuns} RUNS';
  } else {
    winnerName = 'MATCH TIED';
    winnerSub  = 'SCORES LEVEL';
  }

  final dateStr = '${date.day} ${_monthName(date.month)} ${date.year}';

  pw.Widget _statCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor color = _textMuted}) {
    return pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  pw.Widget _inningsPerformers(String title, Innings batInn, Innings bowlInn) {
    final bats = _topBats(batInn);
    final bowls = _topBowls(bowlInn);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_primary, _primaryDark],
              ),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
            ),
          ),
          
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Batsmen Table
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BATTING', style: pw.TextStyle(fontSize: 8, color: _textMuted, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(flex: 4, child: _statCell('Batter', bold: true)),
                          pw.Expanded(flex: 1, child: _statCell('R', bold: true, align: pw.TextAlign.right, color: _textDark)),
                          pw.Expanded(flex: 1, child: _statCell('B', bold: true, align: pw.TextAlign.right)),
                          pw.Expanded(flex: 2, child: _statCell('SR', bold: true, align: pw.TextAlign.right)),
                        ]
                      ),
                      pw.Divider(color: const PdfColor(0.9, 0.9, 0.9), thickness: 0.5),
                      ...bats.map((e) {
                        final s = e.value;
                        final name = _name(batInn, e.key);
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Row(
                            children: [
                              pw.Expanded(flex: 4, child: pw.Text(s.isOut ? name : '$name *', style: pw.TextStyle(fontSize: 9, color: s.isOut ? _textDark : _primary, fontWeight: s.isOut ? pw.FontWeight.normal : pw.FontWeight.bold))),
                              pw.Expanded(flex: 1, child: _statCell('${s.runs}', bold: true, align: pw.TextAlign.right, color: _textDark)),
                              pw.Expanded(flex: 1, child: _statCell('${s.ballsFaced}', align: pw.TextAlign.right)),
                              pw.Expanded(flex: 2, child: _statCell(s.strikeRate.toStringAsFixed(1), align: pw.TextAlign.right)),
                            ]
                          )
                        );
                      }),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Container(width: 0.5, height: 80, color: _border),
                pw.SizedBox(width: 24),
                // Bowler Table
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BOWLING', style: pw.TextStyle(fontSize: 8, color: _textMuted, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(flex: 4, child: _statCell('Bowler', bold: true)),
                          pw.Expanded(flex: 1, child: _statCell('O', bold: true, align: pw.TextAlign.right)),
                          pw.Expanded(flex: 1, child: _statCell('R', bold: true, align: pw.TextAlign.right)),
                          pw.Expanded(flex: 1, child: _statCell('W', bold: true, align: pw.TextAlign.right, color: _textDark)),
                          pw.Expanded(flex: 2, child: _statCell('ECO', bold: true, align: pw.TextAlign.right)),
                        ]
                      ),
                      pw.Divider(color: const PdfColor(0.9, 0.9, 0.9), thickness: 0.5),
                      ...bowls.map((e) {
                        final s = e.value;
                        final name = _name(bowlInn, e.key);
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Row(
                            children: [
                              pw.Expanded(flex: 4, child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: _textDark))),
                              pw.Expanded(flex: 1, child: _statCell(s.oversBowled, align: pw.TextAlign.right)),
                              pw.Expanded(flex: 1, child: _statCell('${s.runsConceded}', align: pw.TextAlign.right)),
                              pw.Expanded(flex: 1, child: _statCell('${s.wickets}', bold: true, align: pw.TextAlign.right, color: _textDark)),
                              pw.Expanded(flex: 2, child: _statCell(s.economy.toStringAsFixed(1), align: pw.TextAlign.right)),
                            ]
                          )
                        );
                      }),
                    ],
                  ),
                ),
              ]
            ),
          )
        ],
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) {
        return pw.Container(
          color: _bg,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── PREMIUM HEADER ──────────────────────────────────────────
              pw.Container(
                height: 190,
                width: double.infinity,
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [_primary, _primaryDark],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                ),
                child: pw.Stack(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(40, 48, 40, 24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('POCKET SCORE', style: pw.TextStyle(color: PdfColors.white, fontSize: 28, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                                  pw.SizedBox(height: 4),
                                  pw.Text('OFFICIAL MATCH SCORECARD', style: pw.TextStyle(color: _accent, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
                                ],
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: pw.BoxDecoration(
                                  color: const PdfColor.fromInt(0xff022C22),
                                  borderRadius: pw.BorderRadius.circular(24),
                                  border: pw.Border.all(color: const PdfColor.fromInt(0xff065F46)),
                                ),
                                child: pw.Text('$dateStr  -  $totalOvers OVERS', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                              )
                            ]
                          ),
                          pw.Spacer(),
                          // Winner Text
                          pw.Row(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: pw.BoxDecoration(
                                  color: _accent,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text('WINNER', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    winnerName.toUpperCase(),
                                    style: pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    winnerSub.toUpperCase(),
                                    style: pw.TextStyle(color: const PdfColor(0.9, 0.9, 0.9), fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
                                  ),
                                ]
                              )
                            ]
                          )
                        ]
                      )
                    ),
                  ]
                )
              ),

              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                  child: pw.Column(
                    children: [
                      pw.SizedBox(height: 32),

                      // ── MAIN SCORE CARDS ──────────────────────────────────
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Team A Card
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(24),
                              decoration: pw.BoxDecoration(
                                color: _surface,
                                borderRadius: pw.BorderRadius.circular(12),
                                border: pw.Border.all(color: _border, width: 1.0),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text(first.battingTeamName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _textMuted, letterSpacing: 1)),
                                  pw.SizedBox(height: 12),
                                  pw.Text('${first.totalRuns}/${first.totalWickets}', style: pw.TextStyle(fontSize: 42, fontWeight: pw.FontWeight.bold, color: _textDark)),
                                  pw.SizedBox(height: 4),
                                  pw.Text('${first.overDisplay} Overs', style: pw.TextStyle(fontSize: 11, color: _textMuted)),
                                  pw.SizedBox(height: 12),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: pw.BoxDecoration(color: _bg, borderRadius: pw.BorderRadius.circular(6)),
                                    child: pw.Text('CRR: ${first.runRate.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: _textDark, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5))
                                  )
                                ]
                              )
                            )
                          ),
                          pw.SizedBox(width: 24),
                          // Sleek VS text
                          pw.Text('VS', style: pw.TextStyle(color: _textMuted, fontSize: 14, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic, letterSpacing: 2)),
                          pw.SizedBox(width: 24),
                          // Team B Card
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(24),
                              decoration: pw.BoxDecoration(
                                color: _surface,
                                borderRadius: pw.BorderRadius.circular(12),
                                border: pw.Border.all(color: _border, width: 1.0),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text(second.battingTeamName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _textMuted, letterSpacing: 1)),
                                  pw.SizedBox(height: 12),
                                  pw.Text('${second.totalRuns}/${second.totalWickets}', style: pw.TextStyle(fontSize: 42, fontWeight: pw.FontWeight.bold, color: _textDark)),
                                  pw.SizedBox(height: 4),
                                  pw.Text('${second.overDisplay} Overs', style: pw.TextStyle(fontSize: 11, color: _textMuted)),
                                  pw.SizedBox(height: 12),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: pw.BoxDecoration(color: _bg, borderRadius: pw.BorderRadius.circular(6)),
                                    child: pw.Text('CRR: ${second.runRate.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: _textDark, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5))
                                  )
                                ]
                              )
                            )
                          ),
                        ]
                      ),

                      pw.SizedBox(height: 32),

                      // ── SUPER OVER (Optional) ─────────────────────────────
                      if (hasSuperOver) ...[
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          margin: const pw.EdgeInsets.only(bottom: 24),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor(1, 0.98, 0.9),
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: _accent, width: 0.5),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('SUPER OVER TIE-BREAKER', style: pw.TextStyle(color: _accentDark, fontWeight: pw.FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                              pw.Row(
                                children: [
                                  pw.Text('${soFirst.battingTeamName}  ${soFirst.totalRuns}/${soFirst.totalWickets}', style: pw.TextStyle(color: _textDark, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                                    child: pw.Text('VS', style: pw.TextStyle(color: _accentDark, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                  ),
                                  pw.Text('${soSecond.battingTeamName}  ${soSecond.totalRuns}/${soSecond.totalWickets}', style: pw.TextStyle(color: _textDark, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                ]
                              )
                            ]
                          )
                        ),
                      ],

                      // ── DETAILED PERFORMANCES ─────────────────────────────
                      _inningsPerformers('1st Innings  -  ${first.battingTeamName}', first, first),
                      _inningsPerformers('2nd Innings  -  ${second.battingTeamName}', second, second),

                      pw.Spacer(),

                      // ── PLAYER OF THE MATCH ───────────────────────────────
                      if (mom != null)
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor(0.98, 0.98, 0.98),
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: const PdfColor(0.9, 0.9, 0.9)),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(10),
                                decoration: const pw.BoxDecoration(
                                  color: _accent,
                                  shape: pw.BoxShape.circle,
                                ),
                                child: pw.Text('POM', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.SizedBox(width: 16),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('PLAYER OF THE MATCH', style: pw.TextStyle(fontSize: 8, color: _accentDark, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(mom.name, style: pw.TextStyle(fontSize: 18, color: _textDark, fontWeight: pw.FontWeight.bold)),
                                ]
                              ),
                            ]
                          )
                        ),

                      pw.SizedBox(height: 24),
                      
                      // ── FOOTER ────────────────────────────────────────────
                      pw.Center(
                        child: pw.Text(
                          'PROUDLY GENERATED BY POCKET SCORE',
                          style: pw.TextStyle(fontSize: 7, color: const PdfColor(0.7, 0.7, 0.7), letterSpacing: 3, fontWeight: pw.FontWeight.bold)
                        )
                      ),
                      pw.SizedBox(height: 32),
                    ]
                  )
                )
              )
            ],
          )
        );
      },
    ),
  );

  return doc.save();
}

String _monthName(int month) {
  const names = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return names[month - 1];
}
