import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Group
// ─────────────────────────────────────────────────────────────────────────────
class Group extends Equatable {
  final String id;          // UUID from Supabase
  final String name;
  final String inviteCode;  // 6-char uppercase alphanumeric  e.g. "XK7P2M"
  final String createdBy;   // UUID of creator
  final int memberCount;    // denormalised — populated by GroupRepository
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.memberCount,
    required this.createdAt,
  });

  // ── Supabase row → model ─────────────────────────────────────────────────
  // Expects a `groups` table row. The caller adds a synthetic `member_count`
  // key (derived from a separate aggregate query) before calling this.
  factory Group.fromRow(Map<String, dynamic> r) => Group(
        id: r['id'] as String,
        name: r['name'] as String,
        inviteCode: r['invite_code'] as String,
        createdBy: r['created_by'] as String,
        memberCount: (r['member_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  // ── Local JSON serialisation (for passing between screens) ───────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'inviteCode': inviteCode,
        'createdBy': createdBy,
        'memberCount': memberCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['inviteCode'] as String,
        createdBy: json['createdBy'] as String,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props =>
      [id, name, inviteCode, createdBy, memberCount, createdAt];
}

// ─────────────────────────────────────────────────────────────────────────────
// GroupMember
// ─────────────────────────────────────────────────────────────────────────────
class GroupMember extends Equatable {
  final String groupId;
  final String userId;
  final String role;       // 'admin' | 'member'
  final DateTime joinedAt;
  final String displayName;
  final String? avatarUrl;

  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.displayName,
    this.avatarUrl,
  });

  bool get isAdmin => role == 'admin';

  // ── Supabase JOIN row → model ────────────────────────────────────────────
  // Expects: group_members.* joined with profiles(full_name, avatar_url, email)
  factory GroupMember.fromRow(Map<String, dynamic> r) {
    final profile = r['profiles'] as Map?;
    final displayName = profile?['full_name'] as String? ??
        profile?['email'] as String? ??
        'Unknown';
    return GroupMember(
      groupId: r['group_id'] as String,
      userId: r['user_id'] as String,
      role: r['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(r['joined_at'] as String),
      displayName: displayName,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'userId': userId,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };

  @override
  List<Object?> get props =>
      [groupId, userId, role, joinedAt, displayName, avatarUrl];
}
