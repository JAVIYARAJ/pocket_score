import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String userId;
  final String? fullName;
  final String? avatarUrl;
  final String? email;
  final String? playerRole;
  final String? battingStyle;
  final String? bowlingStyle;

  const UserProfile({
    required this.userId,
    this.fullName,
    this.avatarUrl,
    this.email,
    this.playerRole,
    this.battingStyle,
    this.bowlingStyle,
  });

  /// True only when all three preference fields have been set by the user.
  bool get hasPreferences =>
      playerRole != null && battingStyle != null && bowlingStyle != null;

  factory UserProfile.fromRow(Map<String, dynamic> r) => UserProfile(
    userId       : r['id'] as String,
    fullName     : r['full_name'] as String?,
    avatarUrl    : r['avatar_url'] as String?,
    email        : r['email'] as String?,
    playerRole   : r['player_role'] as String?,
    battingStyle : r['batting_style'] as String?,
    bowlingStyle : r['bowling_style'] as String?,
  );

  UserProfile copyWith({
    String? playerRole,
    String? battingStyle,
    String? bowlingStyle,
  }) => UserProfile(
    userId       : userId,
    fullName     : fullName,
    avatarUrl    : avatarUrl,
    email        : email,
    playerRole   : playerRole   ?? this.playerRole,
    battingStyle : battingStyle ?? this.battingStyle,
    bowlingStyle : bowlingStyle ?? this.bowlingStyle,
  );

  @override
  List<Object?> get props =>
      [userId, fullName, avatarUrl, email, playerRole, battingStyle, bowlingStyle];
}
