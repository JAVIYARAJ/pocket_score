import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/player_model.dart';

// Events
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

// State
class PlayerState extends Equatable {
  final List<Player> players;
  const PlayerState({this.players = const []});
  @override
  List<Object?> get props => [players];

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    players: (json['players'] as List?)?.map((p) => Player.fromJson(p)).toList() ?? const [],
  );
}

// Bloc
class PlayerBloc extends HydratedBloc<PlayerEvent, PlayerState> {
  PlayerBloc() : super(const PlayerState()) {
    on<AddPlayer>((event, emit) {
      final newPlayer = Player(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: event.name,
        role: event.role,
      );
      emit(PlayerState(players: [...state.players, newPlayer]));
    });

    on<AddPlayers>((event, emit) {
      final newPlayers = event.names.where((name) => name.trim().isNotEmpty).map((name) {
        return Player(
          id: (DateTime.now().microsecondsSinceEpoch + event.names.indexOf(name)).toString(),
          name: name.trim(),
          role: event.role,
        );
      }).toList();
      emit(PlayerState(players: [...state.players, ...newPlayers]));
    });

    on<RemovePlayer>((event, emit) {
      emit(PlayerState(
        players: state.players.where((p) => p.id != event.playerId).toList(),
      ));
    });
  }

  @override
  PlayerState? fromJson(Map<String, dynamic> json) => PlayerState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(PlayerState state) => state.toJson();
}
