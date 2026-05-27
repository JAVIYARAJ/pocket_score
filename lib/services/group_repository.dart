import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import '../models/match_models.dart';

/// All Supabase operations for groups and group membership.
class GroupRepository {
  final SupabaseClient _client;
  GroupRepository(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  // ── Invite-code generation ─────────────────────────────────────────────────
  // 32-char alphabet omits I / O / 0 / 1 (easily confused when read aloud).
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    final rng = Random.secure();
    return List.generate(
      6,
      (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)],
    ).join();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Group CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new group.  The caller becomes an admin member automatically.
  /// Retries once on invite-code unique-constraint collision.
  Future<Group> createGroup(String name) async {
    if (_uid == null) throw Exception('Not authenticated');
    Map<String, dynamic> row;
    try {
      row = await _insertGroup(name.trim(), _generateCode());
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique violation on invite_code — retry with a fresh code.
        row = await _insertGroup(name.trim(), _generateCode());
      } else {
        rethrow;
      }
    }
    final groupId = row['id'] as String;
    await _client.from('group_members').insert({
      'group_id': groupId,
      'user_id': _uid!,
      'role': 'admin',
    });
    return Group.fromRow({...row, 'member_count': 1});
  }

  Future<Map<String, dynamic>> _insertGroup(String name, String code) async {
    return await _client.from('groups').insert({
      'name': name,
      'invite_code': code,
      'created_by': _uid!,
    }).select().single();
  }

  /// Join a group using its 6-character invite code.
  /// Returns the joined [Group].  Throws if the code is invalid.
  Future<Group> joinGroup(String inviteCode) async {
    if (_uid == null) throw Exception('Not authenticated');
    final rows = await _client
        .from('groups')
        .select()
        .eq('invite_code', inviteCode.trim().toUpperCase())
        .limit(1);
    if (rows.isEmpty) throw Exception('No group found with that invite code.');
    final groupRow = Map<String, dynamic>.from(rows.first as Map);
    final groupId = groupRow['id'] as String;

    await _client.from('group_members').upsert(
      {'group_id': groupId, 'user_id': _uid!, 'role': 'member'},
      onConflict: 'group_id,user_id',
      ignoreDuplicates: true,
    );

    final count = await _memberCount(groupId);
    return Group.fromRow({...groupRow, 'member_count': count});
  }

  /// Leave a group.  (Admin leaving is allowed; the group persists.)
  Future<void> leaveGroup(String groupId) async {
    if (_uid == null) return;
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', _uid!);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Queries
  // ══════════════════════════════════════════════════════════════════════════

  /// All groups the signed-in user belongs to, newest first.
  Future<List<Group>> getMyGroups() async {
    if (_uid == null) return const [];

    // Step 1 — which groups is the user in?
    final memberRows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', _uid!);
    if (memberRows.isEmpty) return const [];

    final groupIds =
        memberRows.map((r) => r['group_id'] as String).toList();

    // Step 2 — fetch those group rows
    final groupRows = await _client
        .from('groups')
        .select()
        .inFilter('id', groupIds);

    // Step 3 — member counts (one query per group; acceptable for small lists)
    final countMap = <String, int>{};
    for (final gid in groupIds) {
      countMap[gid] = await _memberCount(gid);
    }

    return (groupRows as List)
        .map<Group>((r) {
          final m = Map<String, dynamic>.from(r as Map);
          return Group.fromRow({...m, 'member_count': countMap[m['id']] ?? 0});
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Members of a group with display names and avatars from their profiles.
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    if (_uid == null) return const [];
    final rows = await _client
        .from('group_members')
        .select('*, profiles(full_name, avatar_url, email)')
        .eq('group_id', groupId)
        .order('joined_at');
    return (rows as List)
        .map((r) => GroupMember.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// One-shot fetch of all matches belonging to a group.
  Future<List<MatchSummary>> getGroupMatches(String groupId) async {
    final rows = await _client
        .from('matches')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _matchFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Supabase Realtime stream — emits a new list whenever a group match
  /// is inserted or updated (status changes, score updates, etc.).
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

  Future<int> _memberCount(String groupId) async {
    final res = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .count(CountOption.exact);
    return res.count;
  }

  MatchSummary _matchFromRow(Map<String, dynamic> r) => MatchSummary(
        id: r['id'] as String,
        teamAName: r['team_a_name'] as String,
        teamBName: r['team_b_name'] as String,
        teamA: r['team_a'] != null
            ? Team.fromJson(Map<String, dynamic>.from(r['team_a'] as Map))
            : null,
        teamB: r['team_b'] != null
            ? Team.fromJson(Map<String, dynamic>.from(r['team_b'] as Map))
            : null,
        totalOvers: (r['total_overs'] as num).toInt(),
        status: r['status'] as String? ?? 'setup',
        result: r['result'] as String?,
        teamAScore: r['team_a_score'] as int?,
        teamAWickets: r['team_a_wickets'] as int?,
        teamAOvers: r['team_a_overs'] as String?,
        teamBScore: r['team_b_score'] as int?,
        teamBWickets: r['team_b_wickets'] as int?,
        teamBOvers: r['team_b_overs'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        scoreData: r['score_data'] != null
            ? Map<String, dynamic>.from(r['score_data'] as Map)
            : null,
        groupId: r['group_id'] as String?,
      );
}
