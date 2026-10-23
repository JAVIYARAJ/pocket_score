import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Internal — fired by the Realtime subscription to refresh the list quietly.
class _RefreshMatchList extends MatchListEvent {}

// ── State ───────────────────────────────────────────────────────
class MatchListState extends Equatable {
  final List<MatchSummary> matches;
  /// False until the first sync from Supabase finishes (successfully or not),
  /// so screens can show a loading skeleton instead of a misleading "no
  /// matches yet".
  final bool synced;
  const MatchListState({this.matches = const [], this.synced = false});

  @override
  List<Object?> get props => [matches, synced];

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
  RealtimeChannel? _channel;
  Timer? _refreshDebounce;
  int _fetchSeq = 0;

  // Writes to Supabase run one at a time, in order. Scoring saves the match on
  // every ball; fired concurrently, an older "in_progress" save could commit
  // after the final "completed" one and leave the match live forever.
  Future<void> _writeQueue = Future.value();
  // Matches with local changes not yet saved — a server refresh must not roll
  // them back (or resurrect ones being deleted).
  final Map<String, int> _pendingWrites = {};
  final Set<String> _pendingDeletes = {};

  MatchListBloc(this._repo) : super(const MatchListState()) {
    // ── Sync from Supabase on sign-in ────────────────────
    on<SyncMatchesFromSupabase>((event, emit) async {
      final seq = ++_fetchSeq;
      try {
        final matches = await _repo.getAll();
        if (seq == _fetchSeq) emit(MatchListState(matches: _withLocal(matches), synced: true));
        _startRealtimeSync(); // watch for status changes from other devices
      } catch (_) {
        // Stop the loading skeleton; the list stays as it was.
        emit(MatchListState(matches: state.matches, synced: true));
      }
    });

    // ── Silent refresh triggered by Realtime ─────────────
    on<_RefreshMatchList>((event, emit) async {
      final seq = ++_fetchSeq;
      try {
        final matches = await _repo.getAll();
        // A newer refresh may have finished first; don't overwrite it.
        if (seq == _fetchSeq) emit(MatchListState(matches: _withLocal(matches), synced: true));
      } catch (_) {
        // Background refresh: keep the current list; the next event retries.
      }
    });

    // ── Add ────────────────────────────────────────────────
    on<AddMatchToList>((event, emit) {
      emit(MatchListState(matches: [event.match, ...state.matches], synced: state.synced));
      _enqueueWrite(event.match.id, () => _repo.upsert(event.match));
    });

    // ── Update ─────────────────────────────────────────────
    on<UpdateMatchInList>((event, emit) {
      final updated = state.matches.map((m) {
        return m.id == event.match.id ? event.match : m;
      }).toList();
      emit(MatchListState(matches: updated, synced: state.synced));
      _enqueueWrite(event.match.id, () => _repo.upsert(event.match));

      // When a match is finalised, persist per-player stats to the
      // relational `player_match_stats` table — after the match row is saved.
      if (event.match.status == 'completed' && event.match.scoreData != null) {
        _enqueueWrite(
            event.match.id, () => _repo.upsertPlayerMatchStats(event.match));
      }
    });

    // ── Remove ─────────────────────────────────────────────
    on<RemoveMatchFromList>((event, emit) {
      emit(MatchListState(
        matches: state.matches.where((m) => m.id != event.matchId).toList(),
        synced: state.synced,
      ));
      _pendingDeletes.add(event.matchId);
      _enqueueWrite(event.matchId, () => _repo.delete(event.matchId),
          onDone: () => _pendingDeletes.remove(event.matchId));
    });
  }

  void _enqueueWrite(String matchId, Future<void> Function() write,
      {void Function()? onDone}) {
    _pendingWrites[matchId] = (_pendingWrites[matchId] ?? 0) + 1;
    _writeQueue = _writeQueue
        .then((_) => write())
        .catchError((Object _) {}) // best-effort, as before
        .whenComplete(() {
      final left = (_pendingWrites[matchId] ?? 1) - 1;
      if (left <= 0) {
        _pendingWrites.remove(matchId);
      } else {
        _pendingWrites[matchId] = left;
      }
      onDone?.call();
    });
  }

  /// Server list with unsaved local changes laid on top.
  List<MatchSummary> _withLocal(List<MatchSummary> server) {
    if (_pendingWrites.isEmpty) return server;
    final local = {for (final m in state.matches) m.id: m};
    final serverIds = server.map((m) => m.id).toSet();
    final merged = [
      // Added locally, not on the server yet.
      for (final m in state.matches)
        if (_pendingWrites.containsKey(m.id) && !serverIds.contains(m.id)) m,
      for (final m in server)
        if (!_pendingDeletes.contains(m.id))
          _pendingWrites.containsKey(m.id) ? (local[m.id] ?? m) : m,
    ];
    return merged;
  }

  void _startRealtimeSync() {
    if (_channel != null) return; // already subscribed
    _channel = Supabase.instance.client
        .channel('match_list_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          // Every ball anywhere updates `matches`; coalesce bursts into one
          // refetch instead of one per event.
          callback: (_) {
            _refreshDebounce?.cancel();
            _refreshDebounce = Timer(const Duration(milliseconds: 800), () {
              if (!isClosed) add(_RefreshMatchList());
            });
          },
        )
        // Resync after (re)connecting — changes while offline were missed.
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && !isClosed) {
            add(_RefreshMatchList());
          }
        });
  }

  @override
  Future<void> close() {
    _refreshDebounce?.cancel();
    _channel?.unsubscribe();
    return super.close();
  }
}
