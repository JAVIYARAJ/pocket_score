import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../config/supabase_config.dart';

// ── States ────────────────────────────────────────────────────
// Named "PocketAuthState" to avoid collision with supabase_flutter's AuthState.
abstract class PocketAuthState extends Equatable {
  const PocketAuthState();
  @override
  List<Object?> get props => [];
}

/// Checking stored session on cold start
class AuthInitial extends PocketAuthState {
  const AuthInitial();
}

/// Google Sign-In in progress
class AuthLoading extends PocketAuthState {
  const AuthLoading();
}

/// User is signed in
class AuthAuthenticated extends PocketAuthState {
  final sb.User user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user.id];
}

/// No active session
class AuthUnauthenticated extends PocketAuthState {
  const AuthUnauthenticated();
}

/// Error (network, cancelled, etc.)
class AuthError extends PocketAuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────
class AuthCubit extends Cubit<PocketAuthState> {
  final sb.SupabaseClient _client;
  StreamSubscription<PocketAuthState>? _authSub;

  // Native Google Sign-In — shows the in-app account picker sheet.
  // serverClientId (Web) is required to receive an idToken on Android.
  // clientId (iOS)       is required for the native sheet on iOS.
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: SupabaseConfig.googleWebClientId,
    clientId: (!kIsWeb && Platform.isIOS) ? SupabaseConfig.googleIosClientId : null,
    scopes: const ['email', 'profile'],
  );

  AuthCubit(this._client) : super(const AuthInitial()) {
    _init();
  }

  void _init() {
    final session = _client.auth.currentSession;
    if (session != null) {
      emit(AuthAuthenticated(session.user));
    } else {
      emit(const AuthUnauthenticated());
    }

    _authSub = _client.auth.onAuthStateChange
        .map<PocketAuthState>((data) {
          final s = data.session;
          if (s != null) return AuthAuthenticated(s.user);
          return const AuthUnauthenticated();
        })
        .listen(
          (state) { if (!isClosed) emit(state); },
          onError: (e) { if (!isClosed) emit(AuthError(e.toString())); },
        );
  }

  // ── Sign in with Google (native in-app account picker) ────────
  Future<void> signInWithGoogle() async {
    try {
      emit(const AuthLoading());

      debugPrint('[Auth] Starting Google Sign-In...');
      debugPrint('[Auth] serverClientId = ${SupabaseConfig.googleWebClientId}');

      // Show the native Google account picker sheet
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[Auth] Google sign-in cancelled by user');
        emit(const AuthUnauthenticated());
        return;
      }

      debugPrint('[Auth] Google account selected: ${googleUser.email}');

      // Get the ID token from Google
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      debugPrint('[Auth] idToken is ${idToken == null ? "NULL ❌" : "present ✓"}');
      debugPrint('[Auth] accessToken is ${accessToken == null ? "NULL" : "present ✓"}');

      if (idToken == null) {
        // Most common cause: serverClientId is wrong or the Android OAuth
        // client isn't registered in Google Cloud Console with this app's SHA-1.
        emit(const AuthError(
          'No ID token from Google.\n'
          'Check: Web Client ID is correct in SupabaseConfig, '
          'and Android OAuth client is registered in Google Cloud Console.',
        ));
        return;
      }

      debugPrint('[Auth] Sending token to Supabase...');

      // Exchange Google token with Supabase — no browser redirect needed
      await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('[Auth] Supabase signInWithIdToken succeeded ✓');
      // onAuthStateChange fires → AuthAuthenticated

    } on sb.AuthException catch (e) {
      debugPrint('[Auth] Supabase AuthException: ${e.message} (status: ${e.statusCode})');
      emit(AuthError('Supabase error: ${e.message}'));
    } catch (e) {
      debugPrint('[Auth] Unexpected error: $e');
      emit(AuthError(e.toString()));
    }
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _client.auth.signOut(),
      _googleSignIn.signOut(),   // also clears Google session so picker shows again
    ]);
    // onAuthStateChange → AuthUnauthenticated
  }

  // ── Helpers ───────────────────────────────────────────────
  sb.User? get currentUser => _client.auth.currentUser;
  String?  get userId    => currentUser?.id;
  String?  get userEmail => currentUser?.email;
  String?  get userName  =>
    currentUser?.userMetadata?['full_name'] as String? ??
    currentUser?.userMetadata?['name']      as String? ??
    currentUser?.email?.split('@').first;
  String?  get avatarUrl => currentUser?.userMetadata?['avatar_url'] as String?;

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
