import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

/// Handles all Supabase operations for the `players` table.
class PlayerRepository {
  final SupabaseClient _client;
  PlayerRepository(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  // ── Fetch all players for the signed-in user ──────────────
  Future<List<Player>> getAll() async {
    if (_uid == null) return const [];
    final rows = await _client
        .from('players')
        .select()
        .eq('user_id', _uid!)
        .order('created_at');
    return rows.map<Player>((r) => _fromRow(r)).toList();
  }

  // ── Upsert a single player ────────────────────────────────
  Future<void> upsert(Player player) async {
    if (_uid == null) return;
    await _client.from('players').upsert({
      'id'      : player.id,
      'user_id' : _uid!,
      'name'    : player.name,
      'role'    : player.role.name,
    });
  }

  // ── Upsert many players at once ───────────────────────────
  Future<void> upsertAll(List<Player> players) async {
    if (_uid == null || players.isEmpty) return;
    await _client.from('players').upsert(
      players.map((p) => {
        'id'      : p.id,
        'user_id' : _uid!,
        'name'    : p.name,
        'role'    : p.role.name,
      }).toList(),
    );
  }

  // ── Delete a player ───────────────────────────────────────
  Future<void> delete(String playerId) async {
    await _client.from('players').delete().eq('id', playerId);
  }

  // ── Map Supabase row → Player model ──────────────────────
  Player _fromRow(Map<String, dynamic> r) => Player(
    id  : r['id'] as String,
    name: r['name'] as String,
    role: PlayerRole.values.firstWhere(
      (e) => e.name == r['role'],
      orElse: () => PlayerRole.batsman,
    ),
  );
}
