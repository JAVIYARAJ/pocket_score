import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/match_models.dart';

// Events
abstract class MatchListEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AddMatchToList extends MatchListEvent {
  final MatchSummary match;
  AddMatchToList(this.match);
  @override
  List<Object?> get props => [match];
}

class UpdateMatchInList extends MatchListEvent {
  final MatchSummary match;
  UpdateMatchInList(this.match);
  @override
  List<Object?> get props => [match];
}

class RemoveMatchFromList extends MatchListEvent {
  final String matchId;
  RemoveMatchFromList(this.matchId);
  @override
  List<Object?> get props => [matchId];
}

// State
class MatchListState extends Equatable {
  final List<MatchSummary> matches;
  const MatchListState({this.matches = const []});

  @override
  List<Object?> get props => [matches];

  Map<String, dynamic> toJson() => {
    'matches': matches.map((m) => m.toJson()).toList(),
  };

  factory MatchListState.fromJson(Map<String, dynamic> json) => MatchListState(
    matches: (json['matches'] as List?)?.map((m) => MatchSummary.fromJson(m)).toList() ?? const [],
  );
}

// Bloc
class MatchListBloc extends HydratedBloc<MatchListEvent, MatchListState> {
  MatchListBloc() : super(const MatchListState()) {
    on<AddMatchToList>((event, emit) {
      emit(MatchListState(matches: [event.match, ...state.matches]));
    });

    on<UpdateMatchInList>((event, emit) {
      final updated = state.matches.map((m) {
        return m.id == event.match.id ? event.match : m;
      }).toList();
      emit(MatchListState(matches: updated));
    });

    on<RemoveMatchFromList>((event, emit) {
      emit(MatchListState(
        matches: state.matches.where((m) => m.id != event.matchId).toList(),
      ));
    });
  }

  @override
  MatchListState? fromJson(Map<String, dynamic> json) {
    try { return MatchListState.fromJson(json); } catch (_) { return null; }
  }

  @override
  Map<String, dynamic>? toJson(MatchListState state) => state.toJson();
}
