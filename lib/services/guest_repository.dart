import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

/// Reusable guest players (people without the app). A group's list is shared
/// with all its members; with no group, the signed-in user's personal list.
/// The saved id is reused as the guest's player id, so the same guest keeps
/// one identity across matches.
class GuestRepository {
  final SupabaseClient _client;
  GuestRepository(this._client);

  Future<List<Player>> getSavedGuests(String? groupId) async {
    final rows = await _client.rpc('get_saved_guests', params: {
      'p_group_id': groupId,
    }) as List;
    return rows.map((r) => _fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// Saves [name] to the list, or returns the existing guest with that name.
  Future<Player> saveGuest(String? groupId, String name, PlayerRole role) async {
    final row = await _client.rpc('save_guest', params: {
      'p_group_id': groupId,
      'p_name'    : name,
      'p_role'    : role.index,
    });
    return _fromRow(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deleteSavedGuest(String id) async {
    await _client.rpc('delete_saved_guest', params: {'p_id': id});
  }

  Player _fromRow(Map<String, dynamic> r) => Player(
    id     : r['id'] as String,
    name   : r['name'] as String,
    role   : PlayerRole.values[(r['role'] as num).toInt()],
    isGuest: true,
  );
}
