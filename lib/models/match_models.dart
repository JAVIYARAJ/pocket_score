import 'package:equatable/equatable.dart';
import 'player_model.dart';

class Team extends Equatable {
  final String name;
  final List<Player> players;
  final String captainId;

  const Team({
    required this.name,
    required this.players,
    required this.captainId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'players': players.map((p) => p.toJson()).toList(),
    'captainId': captainId,
  };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    name: json['name'],
    players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
    captainId: json['captainId'],
  );

  @override
  List<Object?> get props => [name, players, captainId];
}

class MatchSettings extends Equatable {
  final int totalOvers;
  final String teamAName;
  final String teamBName;
  final String? groupId;
  final String? tournamentId;

  const MatchSettings({
    required this.totalOvers,
    required this.teamAName,
    required this.teamBName,
    this.groupId,
    this.tournamentId,
  });

  Map<String, dynamic> toJson() => {
    'totalOvers': totalOvers,
    'teamAName': teamAName,
    'teamBName': teamBName,
    'groupId': groupId,
    'tournamentId': tournamentId,
  };

  factory MatchSettings.fromJson(Map<String, dynamic> json) => MatchSettings(
    totalOvers: json['totalOvers'],
    teamAName: json['teamAName'],
    teamBName: json['teamBName'],
    groupId: json['groupId'],
    tournamentId: json['tournamentId'],
  );

  @override
  List<Object?> get props => [totalOvers, teamAName, teamBName, groupId, tournamentId];
}

/// A lightweight summary stored in the match list
class MatchSummary extends Equatable {
  final String id;
  final String teamAName;
  final String teamBName;
  final Team? teamA;
  final Team? teamB;
  final int totalOvers;
  final String status;
  final String? result;
  final int? teamAScore;
  final int? teamAWickets;
  final String? teamAOvers;
  final int? teamBScore;
  final int? teamBWickets;
  final String? teamBOvers;
  final DateTime createdAt;
  final Map<String, dynamic>? scoreData;
  final String? groupId;
  final String? tournamentId;

  const MatchSummary({
    required this.id,
    required this.teamAName,
    required this.teamBName,
    this.teamA,
    this.teamB,
    required this.totalOvers,
    required this.status,
    this.result,
    this.teamAScore,
    this.teamAWickets,
    this.teamAOvers,
    this.teamBScore,
    this.teamBWickets,
    this.teamBOvers,
    required this.createdAt,
    this.scoreData,
    this.groupId,
    this.tournamentId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'teamAName': teamAName,
    'teamBName': teamBName,
    'teamA': teamA?.toJson(),
    'teamB': teamB?.toJson(),
    'totalOvers': totalOvers,
    'status': status,
    'result': result,
    'teamAScore': teamAScore,
    'teamAWickets': teamAWickets,
    'teamAOvers': teamAOvers,
    'teamBScore': teamBScore,
    'teamBWickets': teamBWickets,
    'teamBOvers': teamBOvers,
    'createdAt': createdAt.toIso8601String(),
    'scoreData': scoreData,
    'groupId': groupId,
    'tournamentId': tournamentId,
  };

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
    id: json['id'],
    teamAName: json['teamAName'],
    teamBName: json['teamBName'],
    teamA: json['teamA'] != null ? Team.fromJson(json['teamA']) : null,
    teamB: json['teamB'] != null ? Team.fromJson(json['teamB']) : null,
    totalOvers: json['totalOvers'],
    status: json['status'] ?? 'setup',
    result: json['result'],
    teamAScore: json['teamAScore'],
    teamAWickets: json['teamAWickets'],
    teamAOvers: json['teamAOvers'],
    teamBScore: json['teamBScore'],
    teamBWickets: json['teamBWickets'],
    teamBOvers: json['teamBOvers'],
    createdAt: DateTime.parse(json['createdAt']),
    scoreData: json['scoreData'] != null ? Map<String, dynamic>.from(json['scoreData']) : null,
    groupId: json['groupId'],
    tournamentId: json['tournamentId'],
  );

  MatchSummary copyWith({
    String? status,
    String? result,
    int? teamAScore,
    int? teamAWickets,
    String? teamAOvers,
    int? teamBScore,
    int? teamBWickets,
    String? teamBOvers,
    Map<String, dynamic>? scoreData,
    Team? teamA,
    Team? teamB,
    String? groupId,
    String? tournamentId,
  }) {
    return MatchSummary(
      id: id,
      teamAName: teamAName,
      teamBName: teamBName,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      totalOvers: totalOvers,
      status: status ?? this.status,
      result: result ?? this.result,
      teamAScore: teamAScore ?? this.teamAScore,
      teamAWickets: teamAWickets ?? this.teamAWickets,
      teamAOvers: teamAOvers ?? this.teamAOvers,
      teamBScore: teamBScore ?? this.teamBScore,
      teamBWickets: teamBWickets ?? this.teamBWickets,
      teamBOvers: teamBOvers ?? this.teamBOvers,
      createdAt: createdAt,
      scoreData: scoreData ?? this.scoreData,
      groupId: groupId ?? this.groupId,
      tournamentId: tournamentId ?? this.tournamentId,
    );
  }

  @override
  List<Object?> get props => [id, teamAName, teamBName, teamA, teamB, totalOvers, status, result,
    teamAScore, teamAWickets, teamAOvers, teamBScore, teamBWickets, teamBOvers, createdAt, scoreData, groupId, tournamentId];
}
