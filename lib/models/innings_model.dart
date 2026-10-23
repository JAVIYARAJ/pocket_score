import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:pocket_score/models/player_model.dart';
import 'ball_model.dart';

/// Summary for a single over
class OverSummary {
  final int overNumber;
  final int runs;
  final int wickets;
  final List<Ball> balls;
  const OverSummary({required this.overNumber, required this.runs, required this.wickets, required this.balls});
}

/// Individual batsman's stats computed from ball data
class BatsmanStats {
  final String playerId;
  int runs = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  bool isOut = false;
  String? wicketType;
  String? outBowlerId;
  String? outFielderId;

  BatsmanStats(this.playerId);

  double get strikeRate => ballsFaced > 0 ? (runs / ballsFaced) * 100 : 0.0;
}

/// Individual bowler's stats computed from ball data
class BowlerStats {
  final String playerId;
  int runsConceded = 0;
  int ballsBowled = 0; // legal balls
  int wickets = 0;
  int wides = 0;
  int noBalls = 0;
  int dotBalls = 0;

  BowlerStats(this.playerId);

  String get oversBowled {
    int overs = ballsBowled ~/ 6;
    int balls = ballsBowled % 6;
    return '$overs.$balls';
  }

  double get economy => ballsBowled > 0 ? (runsConceded / ballsBowled) * 6 : 0.0;
}

/// One innings: the balls bowled plus who batted and bowled.
///
/// Immutable — a new ball produces a new Innings (see ScoreBloc). That lets
/// every derived figure below be computed once, on first use, and cached:
/// the scoring screen reads these many times per rebuild.
class Innings extends Equatable {
  final String battingTeamName;
  final List<Ball> balls;
  final int target;
  final List<Player> battingPlayers;
  final List<Player> bowlingPlayers;

  /// Looks a player up in either side of this innings.
  Player? playerById(String id) =>
      battingPlayers.where((p) => p.id == id).firstOrNull ??
      bowlingPlayers.where((p) => p.id == id).firstOrNull;

  Innings({
    required this.battingTeamName,
    List<Ball> balls = const [],
    this.target = 0,
    this.battingPlayers = const [],
    this.bowlingPlayers = const [],
  }) : balls = UnmodifiableListView(balls); // guards the caches below

  late final int totalRuns = balls.fold(0, (sum, ball) => sum + ball.totalRuns);
  late final int totalWickets = balls.where((ball) => ball.isWicket).length;
  late final int legalBallsCount = balls.where((ball) => ball.isLegalBall).length;

  String get overDisplay {
    int overs = legalBallsCount ~/ 6;
    int ballsInOver = legalBallsCount % 6;
    return "$overs.$ballsInOver";
  }

  double get runRate => legalBallsCount > 0 ? (totalRuns / legalBallsCount) * 6 : 0.0;

  /// Wickets this side still has. Pocket Score plays last-man-standing, so a
  /// side of N players can lose N wickets (not N-1). [fallbackSquadSize] covers
  /// older saved innings that didn't store their batting players.
  int wicketsInHand({int fallbackSquadSize = 0}) {
    final squad = battingPlayers.isNotEmpty ? battingPlayers.length : fallbackSquadSize;
    final left = squad - totalWickets;
    return left < 0 ? 0 : left;
  }

  /// Over-by-over summary, including the over in progress (if any).
  late final List<OverSummary> overSummaries = List.unmodifiable(_computeOverSummaries());

  List<OverSummary> _computeOverSummaries() {
    final List<OverSummary> overs = [];
    int legalCount = 0;
    int currentOverRuns = 0;
    int currentOverWickets = 0;
    List<Ball> currentOverBalls = [];

    for (var ball in balls) {
      currentOverRuns += ball.totalRuns;
      currentOverBalls.add(ball);
      if (ball.isWicket) currentOverWickets++;

      if (ball.isLegalBall) {
        legalCount++;
        if (legalCount % 6 == 0) {
          overs.add(OverSummary(
            overNumber: overs.length + 1,
            runs: currentOverRuns,
            wickets: currentOverWickets,
            balls: List.from(currentOverBalls),
          ));
          currentOverRuns = 0;
          currentOverWickets = 0;
          currentOverBalls = [];
        }
      }
    }

    // current incomplete over
    if (currentOverBalls.isNotEmpty) {
      overs.add(OverSummary(
        overNumber: overs.length + 1,
        runs: currentOverRuns,
        wickets: currentOverWickets,
        balls: List.from(currentOverBalls),
      ));
    }

    return overs;
  }


  /// Batting figures per batter (read-only).
  late final Map<String, BatsmanStats> batsmanStats = UnmodifiableMapView(_computeBatsmanStats());

  Map<String, BatsmanStats> _computeBatsmanStats() {
    final Map<String, BatsmanStats> stats = {};
    for (var ball in balls) {
      stats.putIfAbsent(ball.strikerId, () => BatsmanStats(ball.strikerId));
      final s = stats[ball.strikerId]!;
      s.runs += ball.runs;
      if (ball.isLegalBall) s.ballsFaced++;
      if (ball.type == BallType.normal && ball.runs == 4) s.fours++;
      if (ball.type == BallType.normal && ball.runs == 6) s.sixes++;

      if (ball.isWicket) {
        // A run out can dismiss the non-striker, not the batter on strike.
        final outId = ball.dismissedId;
        final out = stats.putIfAbsent(outId, () => BatsmanStats(outId));
        out.isOut = true;
        out.wicketType = ball.wicketType;
        out.outBowlerId = ball.bowlerId;
        out.outFielderId = ball.fielderId;
      }
    }
    return stats;
  }

  /// Bowling figures per bowler (read-only).
  late final Map<String, BowlerStats> bowlerStatsMap = UnmodifiableMapView(_computeBowlerStats());

  Map<String, BowlerStats> _computeBowlerStats() {
    final Map<String, BowlerStats> stats = {};
    for (var ball in balls) {
      stats.putIfAbsent(ball.bowlerId, () => BowlerStats(ball.bowlerId));
      final s = stats[ball.bowlerId]!;
      s.runsConceded += ball.totalRuns;
      if (ball.isLegalBall) s.ballsBowled++;
      if (ball.isWicket && Dismissal.creditsBowler(ball.wicketType)) s.wickets++;
      if (ball.type == BallType.wide) s.wides++;
      if (ball.type == BallType.noBall) s.noBalls++;
      if (ball.isLegalBall && ball.runs == 0 && ball.extraRuns == 0) s.dotBalls++;
    }
    return stats;
  }

  Map<String, dynamic> toJson() => {
    'battingTeamName': battingTeamName,
    'balls': balls.map((b) => b.toJson()).toList(),
    'target': target,
    'battingPlayers': battingPlayers.map((p) => p.toJson()).toList(),
    'bowlingPlayers': bowlingPlayers.map((p) => p.toJson()).toList(),
  };

  factory Innings.fromJson(Map<String, dynamic> json) => Innings(
    battingTeamName: json['battingTeamName'],
    balls: (json['balls'] as List).map((b) => Ball.fromJson(b)).toList(),
    target: json['target'],
    battingPlayers: (json['battingPlayers'] as List?)?.map((p) => Player.fromJson(p)).toList() ?? const [],
    bowlingPlayers: (json['bowlingPlayers'] as List?)?.map((p) => Player.fromJson(p)).toList() ?? const [],
  );

  @override
  List<Object?> get props => [battingTeamName, balls, target, battingPlayers, bowlingPlayers];

  Innings copyWith({
    String? battingTeamName,
    List<Ball>? balls,
    int? target,
    List<Player>? battingPlayers,
    List<Player>? bowlingPlayers,
  }) {
    return Innings(
      battingTeamName: battingTeamName ?? this.battingTeamName,
      balls: balls ?? this.balls,
      target: target ?? this.target,
      battingPlayers: battingPlayers ?? this.battingPlayers,
      bowlingPlayers: bowlingPlayers ?? this.bowlingPlayers,
    );
  }
}
