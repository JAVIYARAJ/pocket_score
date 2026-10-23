import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_score/bloc/score_bloc.dart';
import 'package:pocket_score/models/ball_model.dart';
import 'package:pocket_score/models/innings_model.dart';
import 'package:pocket_score/models/player_model.dart';
import 'package:pocket_score/utils/stats_utils.dart';

const _bat = Player(id: 'b1', name: 'Bat One');
const _bowl = Player(id: 'w1', name: 'Bowl One');

Innings _innings() => Innings(
      battingTeamName: 'A',
      battingPlayers: const [_bat],
      bowlingPlayers: const [_bowl],
      balls: const [
        Ball(runs: 4, type: BallType.normal, strikerId: 'b1', bowlerId: 'w1'),
        Ball(runs: 0, type: BallType.wide, extraRuns: 1, strikerId: 'b1', bowlerId: 'w1'),
        Ball(runs: 0, type: BallType.wicket, isWicket: true, strikerId: 'b1', bowlerId: 'w1'),
      ],
    );

void main() {
  test('cached innings totals match the balls', () {
    final inn = _innings();
    expect(inn.totalRuns, 5);
    expect(inn.totalWickets, 1);
    expect(inn.legalBallsCount, 2);
    // Same instance on every read: computed once.
    expect(identical(inn.batsmanStats, inn.batsmanStats), isTrue);
  });

  test('innings balls cannot be mutated behind the caches', () {
    final inn = _innings();
    expect(() => inn.balls.add(inn.balls.first), throwsUnsupportedError);
  });

  test('playerById searches both sides', () {
    final inn = _innings();
    expect(inn.playerById('b1')?.name, 'Bat One');
    expect(inn.playerById('w1')?.name, 'Bowl One');
    expect(inn.playerById('nobody'), isNull);
  });

  test('parsedScore parses each stored map once', () {
    final data = ScoreState(firstInnings: _innings()).toJson();
    final a = parsedScore(data);
    expect(identical(a, parsedScore(data)), isTrue);
    expect(a.firstInnings!.totalRuns, 5);
    // A different map (e.g. a reloaded match) is parsed afresh.
    expect(identical(a, parsedScore(Map.of(data))), isFalse);
  });
}
