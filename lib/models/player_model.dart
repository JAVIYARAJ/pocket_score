import 'package:equatable/equatable.dart';

enum PlayerRole { batsman, bowler, allRounder, wicketKeeper }

class Player extends Equatable {
  final String id;
  final String name;
  final PlayerRole role;
  /// True for players who don't have the app (name-only entries).
  /// Guest stats are recorded per-match but excluded from the leaderboard.
  final bool isGuest;
  /// Supabase auth user_id for registered (group-member) players; null for guests.
  final String? userId;

  const Player({
    required this.id,
    required this.name,
    this.role = PlayerRole.allRounder,
    this.isGuest = false,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
    'id'      : id,
    'name'    : name,
    'role'    : role.index,
    'isGuest' : isGuest,
    if (userId != null) 'userId': userId,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id      : json['id'] as String,
    name    : json['name'] as String,
    role    : PlayerRole.values[json['role'] as int],
    isGuest : json['isGuest'] as bool? ?? false,
    userId  : json['userId'] as String?,
  );

  @override
  List<Object?> get props => [id, name, role, isGuest, userId];

  Player copyWith({
    String?     id,
    String?     name,
    PlayerRole? role,
    bool?       isGuest,
    String?     userId,
  }) => Player(
    id      : id      ?? this.id,
    name    : name    ?? this.name,
    role    : role    ?? this.role,
    isGuest : isGuest ?? this.isGuest,
    userId  : userId  ?? this.userId,
  );
}
