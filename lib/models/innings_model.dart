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

  BowlerStats(this.playerId);

  String get oversBowled {
    int overs = ballsBowled ~/ 6;
    int balls = ballsBowled % 6;
    return '$overs.$balls';
  }

  double get economy => ballsBowled > 0 ? (runsConceded / ballsBowled) * 6 : 0.0;
}

class Innings extends Equatable {
  final String battingTeamName;
  final List<Ball> balls;
  final int target;
  final List<Player> battingPlayers;
  final List<Player> bowlingPlayers;

  const Innings({
    required this.battingTeamName,
    this.balls = const [],
    this.target = 0,
    this.battingPlayers = const [],
    this.bowlingPlayers = const [],
  });

  int get totalRuns => balls.fold(0, (sum, ball) => sum + ball.totalRuns);
  int get totalWickets => balls.where((ball) => ball.isWicket).length;
  int get legalBallsCount => balls.where((ball) => ball.isLegalBall).length;

  String get overDisplay {
    int overs = legalBallsCount ~/ 6;
    int ballsInOver = legalBallsCount % 6;
    return "$overs.$ballsInOver";
  }

  double get runRate => legalBallsCount > 0 ? (totalRuns / legalBallsCount) * 6 : 0.0;

  /// Compute over-wise summary: [{overNum, runs, wickets, balls: [Ball]}]
  List<OverSummary> get overSummaries {
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


  /// Compute batting stats per batsman
  Map<String, BatsmanStats> get batsmanStats {
    final Map<String, BatsmanStats> stats = {};
    for (var ball in balls) {
      stats.putIfAbsent(ball.strikerId, () => BatsmanStats(ball.strikerId));
      final s = stats[ball.strikerId]!;
      s.runs += ball.runs;
      if (ball.isLegalBall) s.ballsFaced++;
      if (ball.type == BallType.normal && ball.runs == 4) s.fours++;
      if (ball.type == BallType.normal && ball.runs == 6) s.sixes++;
      
      if (ball.isWicket) {
         s.isOut = true;
         s.wicketType = ball.wicketType;
         s.outBowlerId = ball.bowlerId;
         s.outFielderId = ball.fielderId;
      }
    }
    return stats;
  }

  /// Compute bowling stats per bowler
  Map<String, BowlerStats> get bowlerStatsMap {
    final Map<String, BowlerStats> stats = {};
    for (var ball in balls) {
      stats.putIfAbsent(ball.bowlerId, () => BowlerStats(ball.bowlerId));
      final s = stats[ball.bowlerId]!;
      s.runsConceded += ball.totalRuns;
      if (ball.isLegalBall) s.ballsBowled++;
      if (ball.isWicket) s.wickets++;
      if (ball.type == BallType.wide) s.wides++;
      if (ball.type == BallType.noBall) s.noBalls++;
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
