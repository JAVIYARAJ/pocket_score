import 'dart:math';
import '../models/match_models.dart';
import '../models/player_model.dart';
import '../models/innings_model.dart';
import '../bloc/score_bloc.dart';

class PlayerStats {
  final String id;
  final String name;
  final PlayerRole role;
  
  // Basic info
  int matches = 0;
  int runs = 0;
  int wickets = 0;

  // Batting details
  int inningsBatted = 0;
  int dismissals = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  int fifties = 0;
  List<int> recentBattingInnings = []; // Stores runs for recent form

  // Bowling details
  int matchesBowled = 0;
  int runsConceded = 0;
  int ballsBowled = 0;
  int dotBalls = 0;
  List<int> recentBowlingInnings = []; // Stores wickets for recent form

  // Fielding details (Optional)
  int catches = 0;
  int runOuts = 0;

  // Rank caches
  double? battingRankScore;
  double? previousBattingRankScore;
  
  double? bowlingRankScore;
  double? previousBowlingRankScore;

  double? impactRankScore;
  double? previousImpactRankScore;
  
  // Other stats
  double get strikeRate => ballsFaced > 0 ? (runs / ballsFaced) * 100 : 0.0;
  double get average => dismissals > 0 ? runs / dismissals : runs.toDouble();
  double get boundaryPercent => ballsFaced > 0 ? ((fours + sixes) / ballsFaced) * 100 : 0.0;
  
  double get economy => ballsBowled > 0 ? (runsConceded / (ballsBowled / 6.0)) : 0.0;
  double get wicketsPerMatch => matchesBowled > 0 ? wickets / matchesBowled : 0.0;
  double get dotBallPercent => ballsBowled > 0 ? (dotBalls / ballsBowled) * 100 : 0.0;

  int get fieldingBonus {
    int bonus = (catches * 2) + (runOuts * 3);
    return min(bonus, 10);
  }

  PlayerStats({required this.id, required this.name, required this.role});
}

class RankCalculator {
  static double? calcGullyBattingRank(PlayerStats stats, String scope) {
    if (stats.inningsBatted < 1) return null; // Min 1 innings

    // SR (35%)
    double srScore = 0.0;
    if (stats.ballsFaced > 0) {
      srScore = (min(stats.strikeRate, 250.0) / 250.0) * 35.0;
    }

    // Average (25%)
    double avgScore = (min(stats.average, 50.0) / 50.0) * 25.0;

    // Recent form (25%) - last 3 innings
    double recentFormScore = 0.0;
    if (stats.recentBattingInnings.isNotEmpty) {
      final recent = stats.recentBattingInnings.reversed.take(3).toList(); // latest first
      double weightedRuns = 0;
      double weightSum = 0;
      for (int i = 0; i < recent.length; i++) {
        double w = i == 0 ? 3.0 : i == 1 ? 2.0 : 1.0;
        weightedRuns += recent[i] * w;
        weightSum += w;
      }
      double recentAvg = weightedRuns / weightSum;
      recentFormScore = (min(recentAvg, 50.0) / 50.0) * 25.0;
    }

    // Boundary % (15%)
    double boundScore = (min(stats.boundaryPercent, 100.0) / 100.0) * 15.0;

    double baseScore = srScore + avgScore + recentFormScore + boundScore;
    
    // Scale if 0 balls faced ever
    if (stats.ballsFaced == 0) {
      baseScore = (baseScore / 65.0) * 100.0;
    }

    return min(baseScore + stats.fieldingBonus, 100.0);
  }

  static double? calcGullyBowlingRank(PlayerStats stats, String scope) {
    if (stats.matchesBowled < 1) return null; // Min 1 match

    // Economy Rate (40%)
    double eco = stats.economy;
    double ecoScore = 0.0;
    if (eco > 0) {
      double invertedEco = max(15.0 - eco, 0.0);
      ecoScore = (min(invertedEco, 12.0) / 12.0) * 40.0;
    }

    // Wickets per match (30%)
    double wpmScore = (min(stats.wicketsPerMatch, 3.0) / 3.0) * 30.0;

    // Recent form (20%) - last 3 matches 
    double recentFormScore = 0.0;
    if (stats.recentBowlingInnings.isNotEmpty) {
      final recent = stats.recentBowlingInnings.reversed.take(3).toList();
      double weightedWickets = 0;
      double weightSum = 0;
      for (int i = 0; i < recent.length; i++) {
        double w = i == 0 ? 3.0 : i == 1 ? 2.0 : 1.0;
        weightedWickets += recent[i] * w;
        weightSum += w;
      }
      double recentWpm = weightedWickets / weightSum;
      recentFormScore = (min(recentWpm, 3.0) / 3.0) * 20.0;
    }

    // Dot ball % (10%)
    double dotScore = (min(stats.dotBallPercent, 100.0) / 100.0) * 10.0;

    double baseScore = ecoScore + wpmScore + recentFormScore + dotScore;
    return min(baseScore + stats.fieldingBonus, 100.0);
  }

  static double? calcImpactPlayerRank(PlayerStats stats, String scope) {
    final bat = calcGullyBattingRank(stats, scope);
    final bowl = calcGullyBowlingRank(stats, scope);

    // Need at least one discipline ranked
    if (bat == null && bowl == null) return null;

    // If only one is available, use it at 70% weight (penalised for being one-dimensional)
    if (bat == null) return bowl! * 0.70;
    if (bowl == null) return bat * 0.70;

    return (bat * 0.5) + (bowl * 0.5);
  }
}

Map<String, PlayerStats> calculateAllPlayerStats(List<MatchSummary> matches, List<Player> allPlayers, {String? scopeGroupId, String? scopeTournamentId}) {
  final Map<String, PlayerStats> stats = {
    for (var p in allPlayers) p.id: PlayerStats(id: p.id, name: p.name, role: p.role)
  };

  // Ensure matches are sorted chronologically
  final sortedMatches = List<MatchSummary>.from(matches)..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (var match in sortedMatches) {
    // Filter by group/tournament if specified
    if (scopeGroupId != null && match.groupId != scopeGroupId) continue;
    if (scopeTournamentId != null && match.tournamentId != scopeTournamentId) continue;

    if (match.scoreData == null) continue;
    
    try {
      final score = ScoreState.fromJson(match.scoreData!);
      
      // We will copy current rank to previousRank BEFORE processing this match for players in this match
      final Set<String> playersInMatch = {};
      void markPlayers(Innings? inn) {
        if (inn == null) return;
        playersInMatch.addAll(inn.battingPlayers.map((p) => p.id));
        playersInMatch.addAll(inn.bowlingPlayers.map((p) => p.id));
      }
      markPlayers(score.firstInnings);
      markPlayers(score.secondInnings);

      for (var pId in playersInMatch) {
         if (!stats.containsKey(pId)) continue;
         final p = stats[pId]!;
         p.previousBattingRankScore = RankCalculator.calcGullyBattingRank(p, 'gully');
         p.previousBowlingRankScore = RankCalculator.calcGullyBowlingRank(p, 'gully');
         p.previousImpactRankScore = RankCalculator.calcImpactPlayerRank(p, 'gully');
      }

      void processInningsData(Innings? inn) {
        if (inn == null) return;
        
        // Ensure all players are tracked
        for (var p in inn.battingPlayers) {
          if (!stats.containsKey(p.id)) stats[p.id] = PlayerStats(id: p.id, name: p.name, role: p.role);
        }
        for (var p in inn.bowlingPlayers) {
          if (!stats.containsKey(p.id)) stats[p.id] = PlayerStats(id: p.id, name: p.name, role: p.role);
        }

        // Batting stats
        inn.batsmanStats.forEach((id, s) {
          if (stats.containsKey(id)) {
            final p = stats[id]!;
            p.runs += s.runs;
            p.ballsFaced += s.ballsFaced;
            p.fours += s.fours;
            p.sixes += s.sixes;
            p.inningsBatted++;
            p.recentBattingInnings.add(s.runs);

            if (s.runs >= 50) p.fifties++;

            if (s.isOut && s.wicketType != 'Retired' && s.wicketType != 'Timed out') {
              p.dismissals++;
            }
          }
        });
        
        // Bowling stats
        inn.bowlerStatsMap.forEach((id, s) {
          if (stats.containsKey(id)) {
            final p = stats[id]!;
            p.wickets += s.wickets;
            p.runsConceded += s.runsConceded;
            p.ballsBowled += s.ballsBowled;
            p.dotBalls += s.dotBalls;
            p.matchesBowled++; // actually this should count per innings bowled in this match
            p.recentBowlingInnings.add(s.wickets);
          }
        });
        
        // Fielding stats mapping (optional extraction if stored in batsman stats as outFielderId)
        inn.batsmanStats.forEach((id, s) {
           if (s.isOut && s.outFielderId != null && stats.containsKey(s.outFielderId)) {
               final f = stats[s.outFielderId]!;
               if (s.wicketType == 'Run Out') f.runOuts++;
               else if (s.wicketType == 'Caught') f.catches++;
           }
        });
      }

      processInningsData(score.firstInnings);
      processInningsData(score.secondInnings);
      
      // Increment match count
      for (var pId in playersInMatch) {
        if (stats.containsKey(pId)) stats[pId]!.matches++;
      }
    } catch (e) {
      // Skip invalid
    }
  }

  // Set final computed ranks
  stats.forEach((key, p) {
     p.battingRankScore = RankCalculator.calcGullyBattingRank(p, 'gully');
     p.bowlingRankScore = RankCalculator.calcGullyBowlingRank(p, 'gully');
     p.impactRankScore = RankCalculator.calcImpactPlayerRank(p, 'gully');
  });

  return stats;
}

PlayerStats? calculateManOfTheMatch(MatchSummary match) {
  if (match.scoreData == null) return null;
  try {
    final score = ScoreState.fromJson(match.scoreData!);
    return calculateMoMFromState(score);
  } catch (e) {
    return null;
  }
}

PlayerStats? calculateMoMFromState(ScoreState score) {
  // Existing MOM logic
  try {
    final Map<String, int> points = {};
    final Map<String, String> names = {};
    final Map<String, PlayerRole> roles = {};

    void processInnings(Innings? inn) {
      if (inn == null) return;
      for (var p in inn.battingPlayers) {
        names[p.id] = p.name;
        roles[p.id] = p.role;
      }
      for (var p in inn.bowlingPlayers) {
        names[p.id] = p.name;
        roles[p.id] = p.role;
      }
      inn.batsmanStats.forEach((id, s) {
        points[id] = (points[id] ?? 0) + s.runs;
      });
      inn.bowlerStatsMap.forEach((id, s) {
        points[id] = (points[id] ?? 0) + (s.wickets * 25);
      });
    }

    processInnings(score.firstInnings);
    processInnings(score.secondInnings);

    if (points.isEmpty) return null;
    final activePoints = points.entries.where((e) => e.value > 0).toList();
    if (activePoints.isEmpty) return null;

    final bestEntry = activePoints.reduce((a, b) => a.value > b.value ? a : b);
    final bestId = bestEntry.key;

    return PlayerStats(
      id: bestId,
      name: names[bestId] ?? 'Unknown',
      role: roles[bestId] ?? PlayerRole.allRounder,
    );
  } catch (e) {
    return null;
  }
}
