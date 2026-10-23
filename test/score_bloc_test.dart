import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_score/bloc/score_bloc.dart';
import 'package:pocket_score/models/ball_model.dart';
import 'package:pocket_score/models/player_model.dart';
import 'package:pocket_score/services/match_repository.dart';

/// The bloc only talks to the repository when a live match id is set, which
/// these tests never do — so every call can be a no-op.
class _NoopRepo implements MatchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Records live-score writes in the order they *complete*. The first upsert
/// is slow, so unordered writes would finish out of order.
class _RecordingRepo implements MatchRepository {
  final completed = <String>[];
  var _upserts = 0;

  @override
  Future<void> upsertLiveScore(String matchId, Map<String, dynamic> json) async {
    final n = ++_upserts;
    await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 0));
    completed.add('upsert$n');
  }

  @override
  Future<void> deleteLiveScore(String matchId) async => completed.add('delete');

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

const a1 = Player(id: 'a1', name: 'A1');
const a2 = Player(id: 'a2', name: 'A2');
const a3 = Player(id: 'a3', name: 'A3');
const b1 = Player(id: 'b1', name: 'B1');
const b2 = Player(id: 'b2', name: 'B2');

void main() {
  late ScoreBloc bloc;

  setUp(() => bloc = ScoreBloc(_NoopRepo()));
  tearDown(() => bloc.close());

  Future<ScoreState> send(ScoreEvent e) async {
    bloc.add(e);
    await Future<void>.delayed(Duration.zero);
    return bloc.state;
  }

  Future<ScoreState> start({
    List<Player> batting = const [a1, a2, a3],
    int target = 0,
  }) =>
      send(StartInnings(
        battingTeamName: 'A',
        battingLineup: batting,
        bowlingLineup: const [b1, b2],
        target: target,
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      ));

  Future<ScoreState> runs(int r) =>
      send(RecordBall(runs: r, type: BallType.normal));

  group('strike and overs', () {
    test('odd runs rotate strike, even runs do not', () async {
      await start();
      var s = await runs(1);
      expect((s.strikerId, s.nonStrikerId), ('a2', 'a1'));
      s = await runs(2);
      expect((s.strikerId, s.nonStrikerId), ('a2', 'a1'));
    });

    test('end of over swaps strike and asks for a new bowler', () async {
      await start();
      ScoreState s = bloc.state;
      for (var i = 0; i < 6; i++) {
        s = await runs(0);
      }
      expect(s.currentInnings!.overDisplay, '1.0');
      expect(s.pendingBowlerChange, isTrue);
      expect(s.strikerId, 'a2');

      s = await send(ChangeBowler('b2'));
      expect(s.bowlerId, 'b2');
      expect(s.pendingBowlerChange, isFalse);
    });
  });

  group('extras and free hit', () {
    test('wide adds a run but no legal ball and no strike change', () async {
      await start();
      final s = await send(RecordBall(runs: 0, type: BallType.wide, extraRuns: 1));
      final inn = s.currentInnings!;
      expect(inn.totalRuns, 1);
      expect(inn.legalBallsCount, 0);
      expect(s.strikerId, 'a1');
      expect(s.isFreeHit, isFalse);
      expect(inn.bowlerStatsMap['b1']!.wides, 1);
    });

    test('no-ball gives runs to the batter and a free hit that survives a wide',
        () async {
      await start();
      var s = await send(RecordBall(runs: 4, type: BallType.noBall, extraRuns: 1));
      final bat = s.currentInnings!.batsmanStats['a1']!;
      expect(s.currentInnings!.totalRuns, 5);
      expect(bat.runs, 4);
      expect(s.currentInnings!.legalBallsCount, 0);
      expect(s.isFreeHit, isTrue);

      s = await send(RecordBall(runs: 0, type: BallType.wide, extraRuns: 1));
      expect(s.isFreeHit, isTrue, reason: 'free hit carries over a wide');

      s = await runs(0);
      expect(s.isFreeHit, isFalse);
    });
  });

  group('dismissals', () {
    test('bowled: striker out, bowler credited, next batter takes strike',
        () async {
      await start();
      final s = await send(RecordBall(
          runs: 0,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.bowled,
          outPlayerId: 'a1',
          nextBatsmanId: 'a3'));
      final inn = s.currentInnings!;
      expect(inn.batsmanStats['a1']!.isOut, isTrue);
      expect(inn.bowlerStatsMap['b1']!.wickets, 1);
      expect(s.strikerId, 'a3');
      expect(s.outPlayerIds, ['a1']);
    });

    test('run out of the non-striker marks the right batter out', () async {
      await start();
      final s = await send(RecordBall(
          runs: 1,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.runOut,
          outPlayerId: 'a2',
          fielderId: 'b2',
          nextBatsmanId: 'a3'));
      final stats = s.currentInnings!.batsmanStats;
      expect(stats['a2']!.isOut, isTrue);
      expect(stats['a1']!.isOut, isFalse);
      expect(stats['a1']!.runs, 1, reason: 'completed run still counts');
      expect(stats['a2']!.outFielderId, 'b2');
    });

    test('run outs are not credited to the bowler', () async {
      await start();
      final s = await send(RecordBall(
          runs: 0,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.runOut,
          outPlayerId: 'a1',
          nextBatsmanId: 'a3'));
      expect(s.currentInnings!.bowlerStatsMap['b1']!.wickets, 0);
      expect(s.currentInnings!.totalWickets, 1);
    });

    test('last pair: non-striker run out leaves the striker as last man',
        () async {
      await start(batting: const [a1, a2]);
      final s = await send(RecordBall(
          runs: 0,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.runOut,
          outPlayerId: 'a2'));
      expect(s.isLastManStanding, isTrue);
      expect(s.strikerId, 'a1');
      expect(s.nonStrikerId, '');
      expect(s.isInningsOver(5), isFalse);
    });

    test('last man is all out only when he is dismissed too', () async {
      await start(batting: const [a1, a2]);
      await send(RecordBall(
          runs: 0,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.bowled,
          outPlayerId: 'a1'));
      expect(bloc.state.strikerId, 'a2');
      final s = await send(RecordBall(
          runs: 0,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.caught,
          outPlayerId: 'a2',
          fielderId: 'b2'));
      expect(s.isInningsOver(5), isTrue);
    });
  });

  group('retirement', () {
    test('no ball is recorded while the striker slot is empty', () async {
      await start();
      var s = await send(RetirePlayer(playerId: 'a1'));
      expect(s.strikerId, '');
      s = await runs(4);
      expect(s.currentInnings!.balls, isEmpty);

      s = await send(SelectNextBatsman(playerId: 'a3', isStriker: true));
      s = await runs(4);
      expect(s.currentInnings!.batsmanStats['a3']!.runs, 4);
    });
  });

  group('undo', () {
    test('undo restores the previous ball, strike and free hit', () async {
      await start();
      await runs(1);
      await send(RecordBall(runs: 0, type: BallType.noBall, extraRuns: 1));
      final s = await send(UndoBall());
      expect(s.currentInnings!.balls.length, 1);
      expect(s.isFreeHit, isFalse);
      expect(s.strikerId, 'a2');
    });
  });

  group('innings end', () {
    test('overs used up ends the innings', () async {
      await start();
      for (var i = 0; i < 6; i++) {
        await runs(0);
      }
      expect(bloc.state.isInningsOver(1), isTrue);
      expect(bloc.state.isInningsOver(2), isFalse);
    });

    test('chase ends as soon as the target is passed', () async {
      await start();
      await runs(4); // first innings: 4
      await send(StartInnings(
        battingTeamName: 'B',
        battingLineup: const [b1, b2],
        bowlingLineup: const [a1, a2, a3],
        target: 5,
        strikerId: 'b1',
        nonStrikerId: 'b2',
        bowlerId: 'a1',
      ));
      var s = await runs(4);
      expect(s.isInningsOver(5), isFalse, reason: 'scores level');
      s = await runs(1);
      expect(s.isInningsOver(5), isTrue);
    });

    test('wickets in hand follow last-man-standing (N, not N-1)', () async {
      await start(batting: const [a1, a2]);
      await send(RecordBall(
          runs: 0,
          type: BallType.wicket,
          isWicket: true,
          wicketType: Dismissal.bowled,
          outPlayerId: 'a1'));
      expect(bloc.state.currentInnings!.wicketsInHand(), 1);
    });

    test('super over ends after two wickets', () async {
      await start();
      await send(StartSuperOverInnings(
        battingTeamName: 'A',
        battingLineup: const [a1, a2, a3],
        bowlingLineup: const [b1, b2],
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      ));
      for (final out in ['a1', 'a3']) {
        await send(RecordBall(
            runs: 0,
            type: BallType.wicket,
            isWicket: true,
            wicketType: Dismissal.bowled,
            outPlayerId: out,
            nextBatsmanId: out == 'a1' ? 'a3' : null));
      }
      expect(bloc.state.isInningsOver(20), isTrue);
    });
  });

  group('live score', () {
    test('writes reach the server in order, and the delete comes last',
        () async {
      final repo = _RecordingRepo();
      final live = ScoreBloc(repo);
      Future<void> sendLive(ScoreEvent e) async {
        live.add(e);
        await Future<void>.delayed(Duration.zero);
      }

      await sendLive(StartInnings(
        battingTeamName: 'A',
        battingLineup: const [a1, a2, a3],
        bowlingLineup: const [b1, b2],
        strikerId: 'a1',
        nonStrikerId: 'a2',
        bowlerId: 'b1',
      ));
      live.activeMatchId = 'm1';
      await sendLive(RecordBall(runs: 1, type: BallType.normal));
      await sendLive(RecordBall(runs: 4, type: BallType.normal));
      await sendLive(ResetScoreboard());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(repo.completed, ['upsert1', 'upsert2', 'delete']);
      await live.close();
    });
  });

  group('persistence', () {
    test('ball JSON round-trips who was out; old data falls back to striker',
        () {
      const ball = Ball(
          runs: 0,
          type: BallType.wicket,
          strikerId: 'a1',
          bowlerId: 'b1',
          isWicket: true,
          wicketType: Dismissal.runOut,
          outPlayerId: 'a2');
      expect(Ball.fromJson(ball.toJson()), ball);

      final legacy = Ball.fromJson(
          Map.of(ball.toJson())..remove('outPlayerId'));
      expect(legacy.dismissedId, 'a1');
    });

    test('dismissal names compare case-insensitively (old title-case data)',
        () {
      expect(Dismissal.normalize('Run Out'), Dismissal.runOut);
      expect(Dismissal.normalize('caught'), Dismissal.caught);
      expect(Dismissal.creditsBowler('Run Out'), isFalse);
      expect(Dismissal.creditsBowler('LBW'), isTrue);
    });
  });
}
