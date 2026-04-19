import 'package:equatable/equatable.dart';

enum PlayerRole { batsman, bowler, allRounder, wicketKeeper }

class Player extends Equatable {
  final String id;
  final String name;
  final PlayerRole role;

  const Player({
    required this.id,
    required this.name,
    this.role = PlayerRole.batsman,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.index,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'],
    name: json['name'],
    role: PlayerRole.values[json['role']],
  );

  @override
  List<Object?> get props => [id, name, role];

  Player copyWith({
    String? id,
    String? name,
    PlayerRole? role,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}
