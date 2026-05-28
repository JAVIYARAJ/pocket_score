import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/match_models.dart';

// Events
abstract class MatchEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CreateMatch extends MatchEvent {
  final MatchSettings settings;
  final String matchId;
  CreateMatch(this.settings, this.matchId);
  @override
  List<Object?> get props => [settings, matchId];
}

class SelectTeams extends MatchEvent {
  final Team teamA;
  final Team teamB;
  SelectTeams(this.teamA, this.teamB);
  @override
  List<Object?> get props => [teamA, teamB];
}

class PerformToss extends MatchEvent {
  final String winnerTeamName;
  final String decision;
  PerformToss({required this.winnerTeamName, required this.decision});
  @override
  List<Object?> get props => [winnerTeamName, decision];
}

class ResetMatch extends MatchEvent {}

// State
enum MatchStatus { setup, teamsSelected, tossDone, inProgress, finished }

class MatchState extends Equatable {
  final String? matchId;
  final MatchSettings? settings;
  final Team? teamA;
  final Team? teamB;
  final String? tossWinner;
  final String? tossDecision;
  final MatchStatus status;

  const MatchState({
    this.matchId,
    this.settings,
    this.teamA,
    this.teamB,
    this.tossWinner,
    this.tossDecision,
    this.status = MatchStatus.setup,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'settings': settings?.toJson(),
    'teamA': teamA?.toJson(),
    'teamB': teamB?.toJson(),
    'tossWinner': tossWinner,
    'tossDecision': tossDecision,
    'status': status.index,
  };

  factory MatchState.fromJson(Map<String, dynamic> json) => MatchState(
    matchId: json['matchId'],
    settings: json['settings'] != null ? MatchSettings.fromJson(json['settings']) : null,
    teamA: json['teamA'] != null ? Team.fromJson(json['teamA']) : null,
    teamB: json['teamB'] != null ? Team.fromJson(json['teamB']) : null,
    tossWinner: json['tossWinner'],
    tossDecision: json['tossDecision'],
    status: json['status'] != null ? MatchStatus.values[json['status']] : MatchStatus.setup,
  );

  @override
  List<Object?> get props => [matchId, settings, teamA, teamB, tossWinner, tossDecision, status];

  MatchState copyWith({
    String? matchId,
    MatchSettings? settings,
    Team? teamA,
    Team? teamB,
    String? tossWinner,
    String? tossDecision,
    MatchStatus? status,
  }) {
    return MatchState(
      matchId: matchId ?? this.matchId,
      settings: settings ?? this.settings,
      teamA: teamA ?? this.teamA,
      teamB: teamB ?? this.teamB,
      tossWinner: tossWinner ?? this.tossWinner,
      tossDecision: tossDecision ?? this.tossDecision,
      status: status ?? this.status,
    );
  }
}

// Bloc
class MatchBloc extends Bloc<MatchEvent, MatchState> {
  MatchBloc() : super(const MatchState()) {
    on<CreateMatch>((event, emit) {
      emit(state.copyWith(
        matchId: event.matchId,
        settings: event.settings,
        status: MatchStatus.setup,
      ));
    });

    on<SelectTeams>((event, emit) {
      emit(state.copyWith(
        teamA: event.teamA,
        teamB: event.teamB,
        status: MatchStatus.teamsSelected,
      ));
    });

    on<PerformToss>((event, emit) {
      emit(state.copyWith(
        tossWinner: event.winnerTeamName,
        tossDecision: event.decision,
        status: MatchStatus.tossDone,
      ));
    });

    on<ResetMatch>((event, emit) {
      emit(const MatchState());
    });
  }

}
