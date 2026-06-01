import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String userId;
  final String? fullName;
  final String? avatarUrl;
  final String? email;
  final String? playerRole;
  final String? battingStyle;
  final String? bowlingStyle;
  final DateTime? deletedAt;

  const UserProfile({
    required this.userId,
    this.fullName,
    this.avatarUrl,
    this.email,
    this.playerRole,
    this.battingStyle,
    this.bowlingStyle,
    this.deletedAt,
  });

  bool get hasPreferences =>
      playerRole != null && battingStyle != null && bowlingStyle != null;

  bool get isPendingDeletion => deletedAt != null;

  factory UserProfile.fromRow(Map<String, dynamic> r) => UserProfile(
    userId       : r['id'] as String,
    fullName     : r['full_name'] as String?,
    avatarUrl    : r['avatar_url'] as String?,
    email        : r['email'] as String?,
    playerRole   : r['player_role'] as String?,
    battingStyle : r['batting_style'] as String?,
    bowlingStyle : r['bowling_style'] as String?,
    deletedAt    : r['deleted_at'] != null
        ? DateTime.parse(r['deleted_at'] as String)
        : null,
  );

  UserProfile copyWith({
    String? playerRole,
    String? battingStyle,
    String? bowlingStyle,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => UserProfile(
    userId       : userId,
    fullName     : fullName,
    avatarUrl    : avatarUrl,
    email        : email,
    playerRole   : playerRole   ?? this.playerRole,
    battingStyle : battingStyle ?? this.battingStyle,
    bowlingStyle : bowlingStyle ?? this.bowlingStyle,
    deletedAt    : clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  @override
  List<Object?> get props =>
      [userId, fullName, avatarUrl, email, playerRole, battingStyle, bowlingStyle, deletedAt];
}
