import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository(this._client);

  Future<UserProfile?> getMyProfile() async {
    final rows = await _client.rpc('get_my_profile') as List;
    if (rows.isEmpty) return null;
    return UserProfile.fromRow(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> updatePreferences({
    required String playerRole,
    required String battingStyle,
    required String bowlingStyle,
  }) async {
    await _client.rpc('update_player_preferences', params: {
      'p_role'          : playerRole,
      'p_batting_style' : battingStyle,
      'p_bowling_style' : bowlingStyle,
    });
  }
}
