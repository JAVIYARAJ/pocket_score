import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';

/// All group operations go through server-side RPC functions.
/// watchGroupMatches uses Supabase Realtime (WebSocket) — no RPC equivalent
/// exists for push-based streaming.
class GroupRepository {
  final SupabaseClient _client;
  GroupRepository(this._client);

  // ══════════════════════════════════════════════════════════════════════════
  //  Group CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new group. Invite code is generated server-side.
  /// The caller is automatically added as admin — all in one transaction.
  Future<Group> createGroup(String name) async {
    final data = await _client.rpc('create_group', params: {'p_name': name.trim()});
    return Group.fromRow(Map<String, dynamic>.from(data as Map));
  }

  /// Join a group via invite code. Idempotent — rejoining is harmless.
  Future<Group> joinGroup(String inviteCode) async {
    final data = await _client.rpc('join_group', params: {
      'p_invite_code': inviteCode.trim().toUpperCase(),
    });
    return Group.fromRow(Map<String, dynamic>.from(data as Map));
  }

  /// Leave a group. Admin leaving is allowed; the group persists.
  Future<void> leaveGroup(String groupId) async {
    await _client.rpc('leave_group', params: {'p_group_id': groupId});
  }

  /// Delete a group permanently. Only the admin may call this.
  /// Member list is wiped; matches are de-associated (history preserved).
  Future<void> deleteGroup(String groupId) async {
    await _client.rpc('delete_group', params: {'p_group_id': groupId});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Queries
  // ══════════════════════════════════════════════════════════════════════════

  /// All groups the signed-in user belongs to, with member counts, newest first.
  /// Single query — no N+1 round-trips.
  Future<List<Group>> getMyGroups() async {
    final data = await _client.rpc('get_my_groups') as List;
    return data
        .map<Group>((r) => Group.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Members of a group with display names and avatars.
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final data = await _client.rpc(
      'get_group_members',
      params: {'p_group_id': groupId},
    ) as List;
    return data
        .map<GroupMember>((r) => GroupMember.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// One-shot fetch of all matches for a group.
  Future<List<MatchSummary>> getGroupMatches(String groupId) async {
    final rows = await _client.rpc(
      'get_group_matches',
      params: {'p_group_id': groupId},
    ) as List;
    return rows.map<MatchSummary>((r) => _matchFromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// Realtime stream — emits a new list whenever a group match changes.
  /// Uses Supabase Realtime (WebSocket) — not a PostgREST query.
  Stream<List<MatchSummary>> watchGroupMatches(String groupId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => _matchFromRow(Map<String, dynamic>.from(r)))
            .toList());
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Private helpers
  // ══════════════════════════════════════════════════════════════════════════

  MatchSummary _matchFromRow(Map<String, dynamic> r) => MatchSummary(
    id           : r['id'] as String,
    teamAName    : r['team_a_name'] as String,
    teamBName    : r['team_b_name'] as String,
    teamA        : r['team_a'] != null ? Team.fromJson(Map<String, dynamic>.from(r['team_a'] as Map)) : null,
    teamB        : r['team_b'] != null ? Team.fromJson(Map<String, dynamic>.from(r['team_b'] as Map)) : null,
    totalOvers   : (r['total_overs'] as num).toInt(),
    status       : r['status'] as String? ?? 'setup',
    result       : r['result'] as String?,
    teamAScore   : r['team_a_score'] as int?,
    teamAWickets : r['team_a_wickets'] as int?,
    teamAOvers   : r['team_a_overs'] as String?,
    teamBScore   : r['team_b_score'] as int?,
    teamBWickets : r['team_b_wickets'] as int?,
    teamBOvers   : r['team_b_overs'] as String?,
    createdAt    : DateTime.parse(r['created_at'] as String),
    scoreData    : r['score_data'] != null ? Map<String, dynamic>.from(r['score_data'] as Map) : null,
    groupId      : r['group_id'] as String?,
  );
}
