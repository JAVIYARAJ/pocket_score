import '../models/match_models.dart';
import '../models/player_model.dart';
import '../models/innings_model.dart';
import '../bloc/score_bloc.dart';

class PlayerStats {
  final String id;
  final String name;
  final PlayerRole role;
  int matches = 0;
  int runs = 0;
  int wickets = 0;

  PlayerStats({required this.id, required this.name, required this.role});
}

Map<String, PlayerStats> calculateAllPlayerStats(List<MatchSummary> matches, List<Player> allPlayers) {
  final Map<String, PlayerStats> stats = {
    for (var p in allPlayers) p.id: PlayerStats(id: p.id, name: p.name, role: p.role)
  };

  for (var match in matches) {
    if (match.scoreData == null) continue;
    try {
      final score = ScoreState.fromJson(match.scoreData!);
      
      // Identify who played in this match
      final Set<String> playersInMatch = {};
      
      void processInningsData(Innings? inn) {
        if (inn == null) return;
        
        // Ensure all players in lineups are in stats map
        for (var p in inn.battingPlayers) {
          if (!stats.containsKey(p.id)) {
            stats[p.id] = PlayerStats(id: p.id, name: p.name, role: p.role);
          }
          playersInMatch.add(p.id);
        }
        for (var p in inn.bowlingPlayers) {
          if (!stats.containsKey(p.id)) {
            stats[p.id] = PlayerStats(id: p.id, name: p.name, role: p.role);
          }
          playersInMatch.add(p.id);
        }

        // Add performance stats
        inn.batsmanStats.forEach((id, s) {
          if (stats.containsKey(id)) {
            stats[id]!.runs += s.runs;
          }
        });
        
        inn.bowlerStatsMap.forEach((id, s) {
          if (stats.containsKey(id)) {
            stats[id]!.wickets += s.wickets;
          }
        });
      }

      processInningsData(score.firstInnings);
      processInningsData(score.secondInnings);
      
      // Increment match count for all participants
      for (var pId in playersInMatch) {
        if (stats.containsKey(pId)) {
          stats[pId]!.matches++;
        }
      }
    } catch (e) {
      // Skip invalid score data
    }
  }

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
  try {
    final Map<String, int> points = {};
    final Map<String, String> names = {};
    final Map<String, PlayerRole> roles = {};

    void processInnings(Innings? inn) {
      if (inn == null) return;
      
      // Cache names and roles from player lists
      for (var p in inn.battingPlayers) {
        names[p.id] = p.name;
        roles[p.id] = p.role;
      }
      for (var p in inn.bowlingPlayers) {
        names[p.id] = p.name;
        roles[p.id] = p.role;
      }
      
      // Batsman points: 1 per run
      inn.batsmanStats.forEach((id, s) {
        points[id] = (points[id] ?? 0) + s.runs;
      });

      // Bowler points: 25 per wicket
      inn.bowlerStatsMap.forEach((id, s) {
        points[id] = (points[id] ?? 0) + (s.wickets * 25);
      });
    }

    processInnings(score.firstInnings);
    processInnings(score.secondInnings);

    if (points.isEmpty) return null;

    // Filter out zero-point entries
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
