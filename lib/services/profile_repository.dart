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

  Future<DateTime> requestAccountDeletion() async {
    final result = await _client.rpc('request_account_deletion') as Map;
    return DateTime.parse(result['hard_delete_at'] as String);
  }

  Future<void> cancelAccountDeletion() async {
    await _client.rpc('cancel_account_deletion');
  }

  Future<Map<String, dynamic>?> getDeletionStatus() async {
    final rows = await _client.rpc('get_deletion_status') as List;
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }
}
