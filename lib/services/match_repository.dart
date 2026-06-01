import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_models.dart';
import '../models/innings_model.dart';

/// All match operations go through server-side RPC functions.
/// The only exception is watchLiveScore / watchGroupMatches which use
/// Supabase Realtime (WebSocket subscriptions) — there is no RPC equivalent
/// for streaming push events.
class MatchRepository {
  final SupabaseClient _client;
  MatchRepository(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  // ── Fetch all matches for the signed-in user ──────────────────────────────
  Future<List<MatchSummary>> getAll() async {
    final rows = await _client.rpc('get_my_matches') as List;
    return rows.map<MatchSummary>((r) => _fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  // ── Fetch a single match by ID (public — for spectators) ──────────────────
  Future<MatchSummary?> getById(String matchId) async {
    final rows = await _client.rpc('get_match_by_id', params: {'p_match_id': matchId}) as List;
    if (rows.isEmpty) return null;
    return _fromRow(Map<String, dynamic>.from(rows.first as Map));
  }

  // ── Upsert (create or update) a match ────────────────────────────────────
  Future<void> upsert(MatchSummary match) async {
    await _client.rpc('upsert_match', params: {'p_match': _toJson(match)});
  }

  // ── Delete a match (also removes its live_score row atomically) ───────────
  Future<void> delete(String matchId) async {
    await _client.rpc('delete_match', params: {'p_match_id': matchId});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Real-time Live Score
  // ══════════════════════════════════════════════════════════════════════════

  /// Publish the current ScoreState JSON to Supabase (called every ball).
  Future<void> upsertLiveScore(String matchId, Map<String, dynamic> scoreStateJson) async {
    await _client.rpc('upsert_live_score', params: {
      'p_match_id'   : matchId,
      'p_score_state': scoreStateJson,
    });
  }

  /// Delete the live-score row when a match finishes.
  Future<void> deleteLiveScore(String matchId) async {
    await _client.rpc('delete_live_score', params: {'p_match_id': matchId});
  }

  /// One-shot fetch of the current score state via RPC (no raw table query).
  /// Returns null if the match has ended (live_score row deleted).
  Future<Map<String, dynamic>?> getLiveScore(String matchId) async {
    final result = await _client
        .rpc('get_live_score', params: {'p_match_id': matchId});
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Player Match Stats
  // ══════════════════════════════════════════════════════════════════════════

  /// Parses [match.scoreData] and writes one row per player per innings
  /// via the upsert_player_match_stats RPC.
  Future<void> upsertPlayerMatchStats(MatchSummary match) async {
    if (_uid == null || match.scoreData == null) return;
    try {
      final scoreJson = match.scoreData!;

      Innings? parseInnings(dynamic raw) {
        if (raw == null) return null;
        return Innings.fromJson(Map<String, dynamic>.from(raw as Map));
      }

      final firstInnings  = parseInnings(scoreJson['firstInnings']);
      final secondInnings = parseInnings(scoreJson['secondInnings']);
      final rows = <Map<String, dynamic>>[];

      void processInnings(Innings? inn, int inningsNum) {
        if (inn == null) return;
        final nameMap   = <String, String>{
          for (final p in inn.battingPlayers) p.id: p.name,
          for (final p in inn.bowlingPlayers) p.id: p.name,
        };
        // Track guest status so it can be stored and filtered from leaderboard.
        final guestMap  = <String, bool>{
          for (final p in inn.battingPlayers) p.id: p.isGuest,
          for (final p in inn.bowlingPlayers) p.id: p.isGuest,
        };
        final batStats  = inn.batsmanStats;
        final bowlStats = inn.bowlerStatsMap;
        final seen      = <String>{};

        batStats.forEach((pid, s) {
          seen.add(pid);
          rows.add({
            'match_id'     : match.id,
            'player_id'    : pid,
            'player_name'  : nameMap[pid],
            'innings_num'  : inningsNum,
            'runs'         : s.runs,
            'balls_faced'  : s.ballsFaced,
            'fours'        : s.fours,
            'sixes'        : s.sixes,
            'is_out'       : s.isOut,
            'wicket_type'  : s.wicketType,
            'balls_bowled' : 0,
            'runs_conceded': 0,
            'wickets_taken': 0,
            'wides'        : 0,
            'no_balls'     : 0,
            'dot_balls'    : 0,
            'catches'      : 0,
            'run_outs'     : 0,
            'is_guest'     : guestMap[pid] ?? true,
          });
        });

        bowlStats.forEach((pid, s) {
          if (seen.contains(pid)) {
            final row = rows.lastWhere(
              (r) => r['player_id'] == pid && r['innings_num'] == inningsNum,
              orElse: () => <String, dynamic>{},
            );
            if (row.isNotEmpty) {
              row['balls_bowled']  = s.ballsBowled;
              row['runs_conceded'] = s.runsConceded;
              row['wickets_taken'] = s.wickets;
              row['wides']         = s.wides;
              row['no_balls']      = s.noBalls;
              row['dot_balls']     = s.dotBalls;
            }
          } else {
            seen.add(pid);
            rows.add({
              'match_id'     : match.id,
              'player_id'    : pid,
              'player_name'  : nameMap[pid],
              'innings_num'  : inningsNum,
              'runs'         : 0,
              'balls_faced'  : 0,
              'fours'        : 0,
              'sixes'        : 0,
              'is_out'       : false,
              'wicket_type'  : null,
              'balls_bowled' : s.ballsBowled,
              'runs_conceded': s.runsConceded,
              'wickets_taken': s.wickets,
              'wides'        : s.wides,
              'no_balls'     : s.noBalls,
              'dot_balls'    : s.dotBalls,
              'catches'      : 0,
              'run_outs'     : 0,
              'is_guest'     : guestMap[pid] ?? true,
            });
          }
        });

        batStats.forEach((_, s) {
          final fid = s.outFielderId;
          if (!s.isOut || fid == null) return;
          final row = rows.lastWhere(
            (r) => r['player_id'] == fid && r['innings_num'] == inningsNum,
            orElse: () => <String, dynamic>{},
          );
          if (row.isNotEmpty) {
            if (s.wicketType == 'Caught') {
              row['catches'] = (row['catches'] as int) + 1;
            } else if (s.wicketType == 'Run Out') {
              row['run_outs'] = (row['run_outs'] as int) + 1;
            }
          }
        });
      }

      processInnings(firstInnings,  1);
      processInnings(secondInnings, 2);

      if (rows.isNotEmpty) {
        await _client.rpc('upsert_player_match_stats', params: {'p_stats': rows});
      }
    } catch (_) {
      // Stats are supplementary — silently ignore failures.
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Row ↔ Model mapping
  // ══════════════════════════════════════════════════════════════════════════

  MatchSummary _fromRow(Map<String, dynamic> r) => MatchSummary(
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

  Map<String, dynamic> _toJson(MatchSummary m) => {
    'id'             : m.id,
    'team_a_name'    : m.teamAName,
    'team_b_name'    : m.teamBName,
    'team_a'         : m.teamA?.toJson(),
    'team_b'         : m.teamB?.toJson(),
    'total_overs'    : m.totalOvers,
    'status'         : m.status,
    'result'         : m.result,
    'team_a_score'   : m.teamAScore,
    'team_a_wickets' : m.teamAWickets,
    'team_a_overs'   : m.teamAOvers,
    'team_b_score'   : m.teamBScore,
    'team_b_wickets' : m.teamBWickets,
    'team_b_overs'   : m.teamBOvers,
    'score_data'     : m.scoreData,
    'group_id'       : m.groupId,
  };
}
