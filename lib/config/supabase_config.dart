// ── Supabase + Google Sign-In Configuration ───────────────────────────────
//
// Values are loaded at runtime from the .env file (bundled as a Flutter asset).
// Do NOT hard-code secrets here. Copy .env.example → .env and fill in real values.
//
// HOW TO GET SUPABASE VALUES:
//  1. Go to https://supabase.com → your project → Settings → API
//  2. Copy "Project URL"  → set SUPABASE_URL in .env
//  3. Copy "anon / public" key → set SUPABASE_ANON_KEY in .env
//
// HOW TO GET GOOGLE CLIENT IDs (for native in-app sign-in):
//  1. Go to https://console.cloud.google.com → APIs & Services → Credentials
//  2. Create "OAuth 2.0 Client ID" → type "Web application"
//       Authorised redirect URI: <SUPABASE_URL>/auth/v1/callback
//       → set GOOGLE_WEB_CLIENT_ID in .env
//  3. Create "OAuth 2.0 Client ID" → type "iOS"
//       Bundle ID: com.example.pocketScore
//       → set GOOGLE_IOS_CLIENT_ID in .env
//       → set GOOGLE_IOS_REVERSED_CLIENT_ID in .env (reversed form of the iOS Client ID)
//         and update ios/Runner/Info.plist CFBundleURLSchemes with the same value.
//  4. Supabase Dashboard → Authentication → Providers → Google → Enable
//       Paste the "Web application" Client ID + Secret there.
//
// ──────────────────────────────────────────────────────────────────────────

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Your Supabase project URL
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? (throw Exception('SUPABASE_URL not set in .env'));

  // Your Supabase anon/public API key
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? (throw Exception('SUPABASE_ANON_KEY not set in .env'));

  // ── Native Google Sign-In ─────────────────────────────────────────────────

  // Web application Client ID — needed on both Android and iOS to request
  // the idToken that Supabase [signInWithIdToken] accepts.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? (throw Exception('GOOGLE_WEB_CLIENT_ID not set in .env'));

  // iOS Client ID — needed on iOS so the native sign-in sheet appears.
  // (Android uses the Web client ID as serverClientId instead.)
  static String get googleIosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? (throw Exception('GOOGLE_IOS_CLIENT_ID not set in .env'));
}
