import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_score/bloc/score_bloc.dart';
import 'package:pocket_score/models/ball_model.dart';
import 'package:pocket_score/models/innings_model.dart';
import 'package:pocket_score/models/player_model.dart';
import 'package:pocket_score/utils/match_pdf_generator.dart';

const _a = [Player(id: 'a1', name: 'Raj'), Player(id: 'a2', name: 'Aman')];
const _b = [Player(id: 'b1', name: 'Dev'), Player(id: 'b2', name: 'Arjun')];

Innings _innings(String team, List<Player> bat, List<Player> bowl, List<int> runs) => Innings(
      battingTeamName: team,
      battingPlayers: bat,
      bowlingPlayers: bowl,
      balls: [
        for (final r in runs)
          Ball(runs: r, type: BallType.normal, strikerId: bat.first.id, bowlerId: bowl.first.id),
      ],
    );

void main() {
  // The scorecard's "share PDF" can be used at any point in a match.
  test('PDF builds while the first innings is still in progress', () async {
    final state = ScoreState(firstInnings: _innings('Thunder', _a, _b, [4, 1, 0]), battingLineup: _a);
    final bytes = await generateMatchResultPdf(state, 'Match Scorecard', DateTime(2026), 2);
    expect(bytes, isNotEmpty);
  });

  test('PDF builds mid-chase and for a finished match', () async {
    final first = _innings('Thunder', _a, _b, [4, 1, 0]);
    final midChase = ScoreState(
      firstInnings: first,
      secondInnings: _innings('Storm', _b, _a, [1]),
      isFirstInnings: false,
      battingLineup: _b,
    );
    expect(await generateMatchResultPdf(midChase, 'Match Scorecard', DateTime(2026), 2), isNotEmpty);

    final finished = ScoreState(
      firstInnings: first,
      secondInnings: _innings('Storm', _b, _a, [6]),
      isFirstInnings: false,
      battingLineup: _b,
    );
    expect(await generateMatchResultPdf(finished, 'Storm won', DateTime(2026), 2), isNotEmpty);
  });
}
