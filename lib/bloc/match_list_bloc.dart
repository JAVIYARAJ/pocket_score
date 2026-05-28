import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/match_models.dart';
import '../services/match_repository.dart';

// ── Events ──────────────────────────────────────────────────────
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

/// Fired once after sign-in to pull all matches from Supabase.
class SyncMatchesFromSupabase extends MatchListEvent {}

// ── State ───────────────────────────────────────────────────────
class MatchListState extends Equatable {
  final List<MatchSummary> matches;
  const MatchListState({this.matches = const []});

  @override
  List<Object?> get props => [matches];

  Map<String, dynamic> toJson() => {
    'matches': matches.map((m) => m.toJson()).toList(),
  };

  factory MatchListState.fromJson(Map<String, dynamic> json) => MatchListState(
    matches: (json['matches'] as List?)
        ?.map((m) => MatchSummary.fromJson(m))
        .toList() ??
        const [],
  );
}

// ── Bloc ────────────────────────────────────────────────────────
class MatchListBloc extends Bloc<MatchListEvent, MatchListState> {
  final MatchRepository _repo;

  MatchListBloc(this._repo) : super(const MatchListState()) {
    // ── Sync from Supabase on sign-in ────────────────────
    on<SyncMatchesFromSupabase>((event, emit) async {
      try {
        final matches = await _repo.getAll();
        emit(MatchListState(matches: matches));
      } catch (_) {}
    });

    // ── Add ────────────────────────────────────────────────
    on<AddMatchToList>((event, emit) {
      emit(MatchListState(matches: [event.match, ...state.matches]));
      _repo.upsert(event.match).ignore();
    });

    // ── Update ─────────────────────────────────────────────
    on<UpdateMatchInList>((event, emit) {
      final updated = state.matches.map((m) {
        return m.id == event.match.id ? event.match : m;
      }).toList();
      emit(MatchListState(matches: updated));
      _repo.upsert(event.match).ignore();

      // When a match is finalised, persist per-player stats to the
      // relational `player_match_stats` table (fire-and-forget).
      if (event.match.status == 'completed' && event.match.scoreData != null) {
        _repo.upsertPlayerMatchStats(event.match).ignore();
      }
    });

    // ── Remove ─────────────────────────────────────────────
    on<RemoveMatchFromList>((event, emit) {
      emit(MatchListState(
        matches: state.matches.where((m) => m.id != event.matchId).toList(),
      ));
      _repo.delete(event.matchId).ignore();
    });
  }

}
