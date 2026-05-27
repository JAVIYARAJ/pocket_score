import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/player_model.dart';
import '../services/player_repository.dart';

// ── Events ─────────────────────────────────────────────────────
abstract class PlayerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AddPlayer extends PlayerEvent {
  final String name;
  final PlayerRole role;
  AddPlayer({required this.name, required this.role});
  @override
  List<Object?> get props => [name, role];
}

class AddPlayers extends PlayerEvent {
  final List<String> names;
  final PlayerRole role;
  AddPlayers({required this.names, required this.role});
  @override
  List<Object?> get props => [names, role];
}

class RemovePlayer extends PlayerEvent {
  final String playerId;
  RemovePlayer(this.playerId);
  @override
  List<Object?> get props => [playerId];
}

/// Fired once after sign-in to pull the player list from Supabase.
class SyncPlayersFromSupabase extends PlayerEvent {}

// ── State ──────────────────────────────────────────────────────
class PlayerState extends Equatable {
  final List<Player> players;
  const PlayerState({this.players = const []});

  @override
  List<Object?> get props => [players];

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    players: (json['players'] as List?)
        ?.map((p) => Player.fromJson(p))
        .toList() ??
        const [],
  );
}

// ── Bloc ───────────────────────────────────────────────────────
class PlayerBloc extends HydratedBloc<PlayerEvent, PlayerState> {
  final PlayerRepository _repo;

  PlayerBloc(this._repo) : super(const PlayerState()) {
    // ── Sync from Supabase on sign-in ─────────────────────
    on<SyncPlayersFromSupabase>((event, emit) async {
      try {
        final players = await _repo.getAll();
        if (players.isNotEmpty) emit(PlayerState(players: players));
      } catch (_) {
        // Silently fail — local cache still works offline
      }
    });

    // ── Add a single player ────────────────────────────────
    on<AddPlayer>((event, emit) async {
      final newPlayer = Player(
        id  : DateTime.now().microsecondsSinceEpoch.toString(),
        name: event.name,
        role: event.role,
      );
      final updated = [...state.players, newPlayer];
      emit(PlayerState(players: updated));
      // Cloud sync (fire-and-forget)
      _repo.upsert(newPlayer).ignore();
    });

    // ── Add many players at once ───────────────────────────
    on<AddPlayers>((event, emit) async {
      final newPlayers = event.names
          .where((n) => n.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map((e) => Player(
                id  : (DateTime.now().microsecondsSinceEpoch + e.key).toString(),
                name: e.value.trim(),
                role: event.role,
              ))
          .toList();
      final updated = [...state.players, ...newPlayers];
      emit(PlayerState(players: updated));
      _repo.upsertAll(newPlayers).ignore();
    });

    // ── Remove a player ────────────────────────────────────
    on<RemovePlayer>((event, emit) async {
      emit(PlayerState(
        players: state.players.where((p) => p.id != event.playerId).toList(),
      ));
      _repo.delete(event.playerId).ignore();
    });
  }

  @override
  PlayerState? fromJson(Map<String, dynamic> json) {
    try { return PlayerState.fromJson(json); } catch (_) { return null; }
  }

  @override
  Map<String, dynamic>? toJson(PlayerState state) => state.toJson();
}
